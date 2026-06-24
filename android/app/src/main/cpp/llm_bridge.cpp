#include <jni.h>
#include <string>
#include <vector>
#include <atomic>
#include <android/log.h>

#include "llama.h"

#define LTAG "LlmBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LTAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LTAG, __VA_ARGS__)

static std::atomic<bool> g_stop{false};

struct ModelState {
    llama_model*        model = nullptr;
    llama_context*      ctx   = nullptr;
    const llama_vocab*  vocab = nullptr;
};

static void batch_add(llama_batch& batch, llama_token id, llama_pos pos, bool logits) {
    batch.token   [batch.n_tokens] = id;
    batch.pos     [batch.n_tokens] = pos;
    batch.n_seq_id[batch.n_tokens] = 1;
    batch.seq_id  [batch.n_tokens][0] = 0;
    batch.logits  [batch.n_tokens] = logits ? 1 : 0;
    batch.n_tokens++;
}

extern "C" {

// Package: com.bata.localllm  Class: LlmBridge
JNIEXPORT jlong JNICALL
Java_com_bata_localllm_LlmBridge_loadModel(
        JNIEnv* env, jclass,
        jstring jpath, jint n_ctx) {

    llama_backend_init();

    auto mparams     = llama_model_default_params();
    mparams.n_gpu_layers = 0;

    const char* path = env->GetStringUTFChars(jpath, nullptr);
    LOGI("Loading model: %s", path);
    llama_model* model = llama_model_load_from_file(path, mparams);
    env->ReleaseStringUTFChars(jpath, path);

    if (!model) { LOGE("Failed to load model"); return 0L; }

    auto cparams       = llama_context_default_params();
    cparams.n_ctx      = (uint32_t)n_ctx;
    cparams.n_batch    = 512;
    cparams.n_threads  = 4;
    cparams.n_threads_batch = 4;

    llama_context* ctx = llama_init_from_model(model, cparams);
    if (!ctx) {
        LOGE("Failed to create context");
        llama_model_free(model);
        return 0L;
    }

    const llama_vocab* vocab = llama_model_get_vocab(model);

    auto* state = new ModelState{model, ctx, vocab};
    LOGI("Model loaded OK");
    return reinterpret_cast<jlong>(state);
}

JNIEXPORT void JNICALL
Java_com_bata_localllm_LlmBridge_generate(
        JNIEnv* env, jclass,
        jlong handle, jstring jprompt, jobject callback) {

    if (!handle) { LOGE("Null handle"); return; }
    auto* state = reinterpret_cast<ModelState*>(handle);
    g_stop.store(false);

    const char* p = env->GetStringUTFChars(jprompt, nullptr);
    std::string prompt(p);
    env->ReleaseStringUTFChars(jprompt, p);

    jclass    cbCls = env->GetObjectClass(callback);
    jmethodID cbFn  = env->GetMethodID(cbCls, "onToken", "(Ljava/lang/String;Z)V");

    const int max_tok = llama_n_ctx(state->ctx);
    std::vector<llama_token> tokens(max_tok);
    int n = llama_tokenize(state->vocab,
                           prompt.c_str(), (int32_t)prompt.size(),
                           tokens.data(), max_tok,
                           true, false);
    if (n < 0) { LOGE("Tokenize error"); return; }
    tokens.resize(n);

    // Decode prompt in chunks
    llama_batch batch = llama_batch_init(512, 0, 1);
    for (int i = 0; i < n; i++) {
        batch_add(batch, tokens[i], i, i == n - 1);
        if (batch.n_tokens == 512 || i == n - 1) {
            if (llama_decode(state->ctx, batch) != 0) {
                LOGE("Decode failed (prompt)");
                llama_batch_free(batch);
                return;
            }
            batch.n_tokens = 0;
        }
    }
    llama_batch_free(batch);
    int kv_pos = n;

    // Sampler chain
    auto sparams = llama_sampler_chain_default_params();
    llama_sampler* smpl = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(smpl, llama_sampler_init_top_k(40));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_p(0.95f, 1));
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.7f));
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(42));

    // Generation loop
    llama_batch gen_batch = llama_batch_init(1, 0, 1);
    for (int i = 0; i < 2048 && !g_stop.load(); i++) {
        llama_token tok = llama_sampler_sample(smpl, state->ctx, -1);

        if (llama_vocab_is_eog(state->vocab, tok)) {
            jstring empty = env->NewStringUTF("");
            env->CallVoidMethod(callback, cbFn, empty, (jboolean)true);
            env->DeleteLocalRef(empty);
            break;
        }

        char piece[256];
        int plen = llama_token_to_piece(state->vocab, tok, piece, sizeof(piece)-1, 0, true);
        if (plen > 0) {
            piece[plen] = '\0';
            jstring js = env->NewStringUTF(piece);
            env->CallVoidMethod(callback, cbFn, js, (jboolean)false);
            env->DeleteLocalRef(js);
        }

        gen_batch.n_tokens = 0;
        batch_add(gen_batch, tok, kv_pos++, true);
        if (llama_decode(state->ctx, gen_batch) != 0) {
            LOGE("Decode failed (gen)");
            break;
        }
    }

    llama_batch_free(gen_batch);
    llama_sampler_free(smpl);
}

JNIEXPORT void JNICALL
Java_com_bata_localllm_LlmBridge_stopGeneration(JNIEnv*, jclass) {
    g_stop.store(true);
}

JNIEXPORT void JNICALL
Java_com_bata_localllm_LlmBridge_freeModel(JNIEnv*, jclass, jlong handle) {
    if (!handle) return;
    auto* state = reinterpret_cast<ModelState*>(handle);
    if (state->ctx)   llama_free(state->ctx);
    if (state->model) llama_model_free(state->model);
    delete state;
    llama_backend_free();
}

} // extern "C"

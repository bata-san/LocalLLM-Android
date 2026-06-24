# LocalLLM — Android

ローカルでGGUFモデルを動かし、Firecrawlでウェブ検索もできるAndroidアプリ。

## 特徴

- **完全オフラインLLM推論** — llama.cpp (JNI) でGGUFモデルをオンデバイス実行
- **Firecrawl Web Search** — 質問前にウェブ検索してコンテキストを注入 (RAG)
- **ストリーミング出力** — トークンをリアルタイムで表示
- **モデル管理** — 任意のGGUFファイルをストレージから読み込み/削除
- **Jetpack Compose UI** — Material3 ダークテーマ対応

## 推奨モデル

Gemma 4 E2B uncensored を使う場合:

```bash
# TrevorJS/gemma-4-E2B-it-uncensored (safetensors) → GGUF変換
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp && pip install -r requirements.txt
python convert_hf_to_gguf.py TrevorJS/gemma-4-E2B-it-uncensored --outtype q4_k_m
```

または [unsloth/gemma-4-E2B-it-qat-mobile-GGUF](https://huggingface.co/unsloth/gemma-4-E2B-it-qat-mobile-GGUF) の `UD-Q2_K_XL` (2.19 GB, モバイル最適化) を直接使用可。

## セットアップ

### 必要環境
- Android Studio Ladybug 以降
- NDK 27+
- CMake 3.22+
- Android API 26+ デバイス / エミュレータ (RAM 6GB 以上推奨)

### ビルド

```bash
git clone https://github.com/bata-san/LocalLLM-Android
cd LocalLLM-Android
# Android Studio で開く → Build → Run
```

> **初回ビルド時** CMakeがllama.cppをGitHubから自動ダウンロード (数分かかります)

### 設定

1. アプリ起動 → ⚙ → Settings
2. **Firecrawl API Key** を入力 ([firecrawl.dev](https://firecrawl.dev) で取得)
3. Models 画面で GGUF ファイルを読み込む

## アーキテクチャ

```
UI (Jetpack Compose)
  └── ViewModel (StateFlow / coroutines)
        ├── LlmManager
        │     └── LlmBridge (JNI → llama.cpp C++)
        ├── FirecrawlClient (OkHttp REST)
        ├── Room Database (チャット履歴)
        └── DataStore (設定)
```

## チャットフロー

```
ユーザー入力
  │
  ├─ [🔍 検索ON] → Firecrawl /v2/search → Markdown取得
  │                    ↓ プロンプトに注入
  └─ llama.cpp ローカル推論 → トークンストリーミング → UI
```

## プロンプト形式

Gemma 4 IT フォーマット準拠:

```
<start_of_turn>system
{system_prompt}<end_of_turn>
<start_of_turn>user
{message}<end_of_turn>
<start_of_turn>model
```

## ライセンス

MIT

package com.bata.localllm.data.model

import java.io.File

data class GgufModel(
    val file: File,
    val sizeBytes: Long = file.length(),
) {
    val name: String get() = file.nameWithoutExtension
    val displaySize: String get() = when {
        sizeBytes >= 1_073_741_824L -> "%.1f GB".format(sizeBytes / 1_073_741_824.0)
        sizeBytes >= 1_048_576L     -> "%.0f MB".format(sizeBytes / 1_048_576.0)
        else                        -> "${sizeBytes / 1024} KB"
    }
}

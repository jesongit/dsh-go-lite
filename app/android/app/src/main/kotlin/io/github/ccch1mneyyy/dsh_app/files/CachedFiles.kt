package io.github.ccch1mneyyy.dsh_app.files

import java.io.File

/** Client previews and exports read cache files; old private runtime data stays inaccessible. */
internal object CachedFiles {
    fun resolve(cache: File, path: String): File? {
        if (path.isBlank()) return null
        val root = cache.canonicalFile.toPath()
        val file = File(path).canonicalFile
        return file.takeIf { it.toPath().startsWith(root) && it.toPath() != root }
    }
}

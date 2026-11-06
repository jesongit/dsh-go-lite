package io.github.ccch1mneyyy.dsh_app.files

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.file.Files

class CachedFilesTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun cachePreviewsAndExportsRemainReadableButOldRuntimePathsAreRejected() {
        val cache = temporary.newFolder("cache")
        val preview = File(cache, "artifacts/remote/report.pdf")
        assertEquals(preview.canonicalFile, CachedFiles.resolve(cache, preview.path))
        val export = File(cache, "exports/save-1/session.zip")
        assertEquals(export.canonicalFile, CachedFiles.resolve(cache, export.path))
        assertNull(CachedFiles.resolve(cache, File(temporary.root, "files/runtime/rootfs/root/private.txt").path))
        assertNull(CachedFiles.resolve(cache, File(cache, "../cache-other/report.pdf").path))
        assertNull(CachedFiles.resolve(cache, cache.path))
        assertNull(CachedFiles.resolve(cache, ""))
    }

    @Test fun symlinkInsideCacheCannotExposePrivateFiles() {
        val cache = temporary.newFolder("cache")
        val privateFile = temporary.newFile("private.txt")
        val link = File(cache, "report.txt").toPath()
        // Windows may not grant symlink creation to this test process.
        try {
            Files.createSymbolicLink(link, privateFile.toPath())
        } catch (error: Exception) {
            org.junit.Assume.assumeNoException(error)
        }
        assertNull(CachedFiles.resolve(cache, link.toString()))
    }
}

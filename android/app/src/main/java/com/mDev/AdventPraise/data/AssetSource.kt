package com.mDev.AdventPraise.data

import android.content.res.AssetManager
import java.io.File
import java.io.FileNotFoundException
import java.io.InputStream

/**
 * The bundled files, flat as in the iOS bundle: the APK's assets in the
 * app, the iOS app's Resources folders in JVM tests.
 */
interface AssetSource {
    /** Opens `name`; throws when it isn't there. */
    fun open(name: String): InputStream
    /** Every file name at the root. */
    fun list(): Set<String>

    fun readText(name: String): String? = runCatching { open(name).bufferedReader().use { it.readText() } }.getOrNull()
    fun readJson(name: String): Any? = readText(name)?.let(Json::parseOrNull)

    /**
     * `length` bytes from `offset` of `name` (a pack). Null when the file
     * is shorter or can't be read.
     */
    fun readRange(name: String, offset: Long, length: Int): ByteArray? = runCatching {
        open(name).use { input ->
            var toSkip = offset
            while (toSkip > 0) {
                val skipped = input.skip(toSkip)
                if (skipped <= 0) {
                    if (input.read() < 0) return null
                    toSkip -= 1
                } else {
                    toSkip -= skipped
                }
            }
            val bytes = ByteArray(length)
            var read = 0
            while (read < length) {
                val n = input.read(bytes, read, length - read)
                if (n < 0) return null
                read += n
            }
            bytes
        }
    }.getOrNull()
}

/** The APK's assets. */
class AndroidAssets(private val assets: AssetManager) : AssetSource {
    private val names: Set<String> by lazy { assets.list("")?.toSet().orEmpty() }
    override fun open(name: String): InputStream = assets.open(name)
    override fun list(): Set<String> = names
}

/** Folders on disk, searched in order (tests read the iOS app's Resources). */
class DirectoryAssets(private val folders: List<File>) : AssetSource {
    constructor(vararg folders: File) : this(folders.toList())

    override fun open(name: String): InputStream =
        folders.map { File(it, name) }.firstOrNull { it.isFile }?.inputStream() ?: throw FileNotFoundException(name)

    override fun list(): Set<String> = folders.flatMap { it.list()?.toList().orEmpty() }.toSet()

    override fun readRange(name: String, offset: Long, length: Int): ByteArray? {
        val file = folders.map { File(it, name) }.firstOrNull { it.isFile } ?: return null
        return runCatching {
            java.io.RandomAccessFile(file, "r").use { raf ->
                if (offset + length > raf.length()) return null
                raf.seek(offset)
                ByteArray(length).also { raf.readFully(it) }
            }
        }.getOrNull()
    }

    companion object {
        /**
         * The iOS app's resource folders, as Gradle adds them to the APK, found
         * from the working directory (android/app when Gradle runs the tests).
         */
        fun iosResources(): DirectoryAssets {
            val candidates = listOf("../../AdventPraise/Resources", "../AdventPraise/Resources", "AdventPraise/Resources")
            val root = candidates.map(::File).firstOrNull { it.isDirectory } ?: File(candidates.first())
            return DirectoryAssets(listOf("Hymnals", "Midi", "Extras", "SheetMusic").map { File(root, it) })
        }
    }
}

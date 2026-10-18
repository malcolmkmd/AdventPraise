package com.mDev.AdventPraise.church.display

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.LruCache
import java.io.File
import java.util.UUID
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Church mode's pictures (ChurchImageStore on iOS): a picked picture is
 * saved downscaled (at most 1920 px on its long side) as a JPEG in the app's
 * own storage, newest first, six kept. [ChurchState.image] holds the id; the
 * worship display and the presenter's recents load it from here.
 */
class ChurchImages(context: Context) {
    data class Entry(val id: String, val thumbnail: Bitmap)

    private val folder = File(context.filesDir, "church-images").apply { mkdirs() }
    private val resolver = context.contentResolver
    private val cache = LruCache<String, Bitmap>(2)

    private fun files(): List<File> =
        folder.listFiles { f -> f.extension == "jpg" }.orEmpty().sortedByDescending { it.lastModified() }

    fun recents(): List<Entry> = files().mapNotNull { file ->
        decode(file, THUMBNAIL)?.let { Entry(file.nameWithoutExtension, it) }
    }

    /** The full picture for the TV, marked as just used. */
    fun image(id: String): Bitmap? {
        cache.get(id)?.let { return it }
        val file = File(folder, "$id.jpg")
        if (!file.exists()) return null
        file.setLastModified(System.currentTimeMillis())
        return BitmapFactory.decodeFile(file.path)?.also { cache.put(id, it) }
    }

    /** Saves a picture from the photo picker; null when it can't be read. */
    fun add(uri: Uri): Entry? = runCatching {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        val longSide = max(bounds.outWidth, bounds.outHeight)
        if (longSide <= 0) return null
        var sample = 1
        while (longSide / (sample * 2) >= MAX_SIDE) sample *= 2
        val decoded = resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: return null
        val scale = min(1f, MAX_SIDE.toFloat() / max(decoded.width, decoded.height))
        val image = if (scale < 1f) {
            Bitmap.createScaledBitmap(decoded, (decoded.width * scale).roundToInt(), (decoded.height * scale).roundToInt(), true)
        } else decoded
        val id = UUID.randomUUID().toString().uppercase()
        File(folder, "$id.jpg").outputStream().use { image.compress(Bitmap.CompressFormat.JPEG, 85, it) }
        files().drop(KEEP).forEach { it.delete() }
        cache.put(id, image)
        Entry(id, thumbnail(image))
    }.getOrNull()

    private fun decode(file: File, size: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        var sample = 1
        while (min(bounds.outWidth, bounds.outHeight) / (sample * 2) >= size) sample *= 2
        return BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample })
    }

    private fun thumbnail(image: Bitmap): Bitmap {
        val scale = THUMBNAIL.toFloat() / min(image.width, image.height)
        if (scale >= 1f) return image
        return Bitmap.createScaledBitmap(image, (image.width * scale).roundToInt(), (image.height * scale).roundToInt(), true)
    }

    private companion object {
        const val KEEP = 6
        const val MAX_SIDE = 1920
        const val THUMBNAIL = 240
    }
}

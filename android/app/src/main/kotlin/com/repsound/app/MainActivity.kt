package com.repsound.app

import android.content.ContentUris
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Ponte nativa com o MediaStore.
 *
 * A biblioteca é lida por volume externo (armazenamento interno + cartão SD),
 * o que garante suporte real a microSD. O Flutter recebe apenas metadados
 * leves; as capas são carregadas sob demanda, uma por vez.
 */
class MainActivity : AudioServiceActivity() {

    private val channelName = "com.repsound/media"
    private val executor = Executors.newSingleThreadExecutor()
    private val deleteRequestCode = 4711
    private var pendingDeleteResult: MethodChannel.Result? = null
    private var pendingDeleteCount = 0
    private var openPlayerRequested = false

    private fun isNotificationClick(intent: Intent?): Boolean =
        intent?.action == "com.ryanheise.audioservice.NOTIFICATION_CLICK"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        if (isNotificationClick(intent)) openPlayerRequested = true
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isNotificationClick(intent)) openPlayerRequested = true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(true)
                    "querySongs" -> runAsync(result) { querySongs() }
                    "queryArtwork" -> {
                        val volume = call.argument<String>("volume")
                        val mediaId = call.argument<Number>("mediaId")?.toLong()
                        val size = call.argument<Number>("size")?.toInt() ?: 320
                        if (volume == null || mediaId == null) {
                            result.error("bad_args", "volume e mediaId são obrigatórios", null)
                        } else {
                            runAsync(result) { queryArtwork(volume, mediaId, size) }
                        }
                    }
                    "deleteSongs" -> deleteSongs(call, result)
                    "consumeOpenPlayer" -> {
                        val value = openPlayerRequested
                        openPlayerRequested = false
                        result.success(value)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun deleteSongs(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val raw = call.argument<List<*>>("items")
        if (raw.isNullOrEmpty()) {
            result.success(0)
            return
        }
        val uris = ArrayList<Uri>()
        for (entry in raw) {
            val item = entry as? Map<*, *> ?: continue
            val volume = item["volume"] as? String ?: continue
            val mediaId = (item["mediaId"] as? Number)?.toLong() ?: continue
            uris.add(ContentUris.withAppendedId(collectionFor(volume), mediaId))
        }
        if (uris.isEmpty()) {
            result.success(0)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val pendingIntent = MediaStore.createDeleteRequest(contentResolver, uris)
                pendingDeleteResult = result
                pendingDeleteCount = uris.size
                startIntentSenderForResult(
                    pendingIntent.intentSender,
                    deleteRequestCode,
                    null,
                    0,
                    0,
                    0,
                )
            } catch (t: Throwable) {
                result.error("delete_failed", t.message ?: t.toString(), null)
            }
        } else {
            executor.execute {
                var deleted = 0
                var error: String? = null
                for (uri in uris) {
                    try {
                        deleted += contentResolver.delete(uri, null, null)
                    } catch (t: Throwable) {
                        error = t.message
                    }
                }
                runOnUiThread {
                    if (deleted > 0) {
                        result.success(deleted)
                    } else {
                        result.error(
                            "delete_failed",
                            error ?: "O sistema não permitiu excluir os arquivos.",
                            null,
                        )
                    }
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == deleteRequestCode) {
            val pending = pendingDeleteResult
            pendingDeleteResult = null
            if (resultCode == RESULT_OK) {
                pending?.success(pendingDeleteCount)
            } else {
                pending?.error("delete_cancelled", "Exclusão cancelada.", null)
            }
        }
    }

    private fun <T> runAsync(result: MethodChannel.Result, block: () -> T) {
        executor.execute {
            try {
                val value = block()
                runOnUiThread { result.success(value) }
            } catch (t: Throwable) {
                runOnUiThread {
                    result.error("native_error", t.message ?: t.toString(), null)
                }
            }
        }
    }

    // ---------------------------------------------------------------- library

    private fun querySongs(): List<Map<String, Any?>> {
        val songs = ArrayList<Map<String, Any?>>()
        val volumes: Set<String> =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    MediaStore.getExternalVolumeNames(this)
                } catch (t: Throwable) {
                    setOf(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                }
            } else {
                setOf("external")
            }

        for (volume in volumes) {
            try {
                queryVolume(volume, songs)
            } catch (t: Throwable) {
                // Um volume pode estar indisponível (SD removido). Segue para o próximo.
            }
        }
        return songs
    }

    private fun collectionFor(volume: String): Uri =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(volume)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

    private fun queryVolume(volume: String, out: MutableList<Map<String, Any?>>) {
        val isQ = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
        val projection = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.YEAR,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.DISPLAY_NAME,
        )
        if (isQ) {
            projection.add(MediaStore.Audio.Media.RELATIVE_PATH)
        } else {
            projection.add(MediaStore.Audio.Media.DATA)
        }

        val collection = collectionFor(volume)
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val order = "${MediaStore.Audio.Media.DATE_ADDED} DESC"

        contentResolver.query(
            collection,
            projection.toTypedArray(),
            selection,
            null,
            order,
        )?.use { cursor ->
            val idCol = cursor.getColumnIndex(MediaStore.Audio.Media._ID)
            val titleCol = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
            val artistCol = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
            val albumCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)
            val albumIdCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)
            val durationCol = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
            val sizeCol = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
            val dateCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_ADDED)
            val trackCol = cursor.getColumnIndex(MediaStore.Audio.Media.TRACK)
            val yearCol = cursor.getColumnIndex(MediaStore.Audio.Media.YEAR)
            val mimeCol = cursor.getColumnIndex(MediaStore.Audio.Media.MIME_TYPE)
            val nameCol = cursor.getColumnIndex(MediaStore.Audio.Media.DISPLAY_NAME)
            val relCol = if (isQ) cursor.getColumnIndex(MediaStore.Audio.Media.RELATIVE_PATH) else -1
            val dataCol = if (isQ) -1 else cursor.getColumnIndex(MediaStore.Audio.Media.DATA)

            while (cursor.moveToNext()) {
                val id = if (idCol >= 0) cursor.getLong(idCol) else continue
                val displayName = if (nameCol >= 0) cursor.getString(nameCol) else null
                val title = (if (titleCol >= 0) cursor.getString(titleCol) else null)
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() && it != "<unknown>" }
                    ?: displayName?.substringBeforeLast('.')
                    ?: "Faixa $id"

                val artist = (if (artistCol >= 0) cursor.getString(artistCol) else null)
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() && it != "<unknown>" }
                    ?: "Artista desconhecido"

                val album = (if (albumCol >= 0) cursor.getString(albumCol) else null)
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() && it != "<unknown>" }
                    ?: "Álbum desconhecido"

                val relativePath =
                    if (relCol >= 0) cursor.getString(relCol)?.trim().orEmpty() else ""
                val dataPath = if (dataCol >= 0) cursor.getString(dataCol) else null
                val folder = folderFrom(relativePath, dataPath)

                val duration = if (durationCol >= 0) cursor.getLong(durationCol) else 0L
                val size = if (sizeCol >= 0) cursor.getLong(sizeCol) else 0L
                val dateAdded = if (dateCol >= 0) cursor.getLong(dateCol) * 1000L else 0L
                val track = if (trackCol >= 0) cursor.getInt(trackCol) % 1000 else 0
                val year = if (yearCol >= 0) cursor.getInt(yearCol) else 0
                val mime = if (mimeCol >= 0) cursor.getString(mimeCol) else null
                val albumId = if (albumIdCol >= 0) cursor.getLong(albumIdCol) else 0L

                out.add(
                    mapOf(
                        "id" to "$volume:$id",
                        "volume" to volume,
                        "mediaId" to id,
                        "albumId" to albumId,
                        "title" to title,
                        "artist" to artist,
                        "album" to album,
                        "durationMs" to duration,
                        "sizeBytes" to size,
                        "dateAddedMs" to dateAdded,
                        "track" to track,
                        "year" to year,
                        "mimeType" to mime,
                        "format" to formatOf(mime, displayName),
                        "path" to dataPath,
                        "relativePath" to relativePath,
                        "folder" to folder,
                        "contentUri" to ContentUris.withAppendedId(collection, id).toString(),
                    )
                )
            }
        }
    }

    private fun folderFrom(relativePath: String, dataPath: String?): String {
        val cleaned = relativePath.trim().trim('/')
        if (cleaned.isNotEmpty()) {
            return cleaned.substringAfterLast('/').ifBlank { "Armazenamento interno" }
        }
        if (!dataPath.isNullOrBlank()) {
            val parent = dataPath.substringBeforeLast('/', "")
            return parent.substringAfterLast('/').ifBlank { "Armazenamento interno" }
        }
        return "Armazenamento interno"
    }

    private fun formatOf(mime: String?, displayName: String?): String {
        val value = mime?.lowercase().orEmpty()
        if (value.isNotEmpty()) {
            return when {
                value.contains("mpeg") -> "MP3"
                value.contains("mp4a") || value.contains("aac") -> "AAC"
                value.contains("flac") -> "FLAC"
                value.contains("wav") || value.contains("x-wav") -> "WAV"
                value.contains("opus") -> "OPUS"
                value.contains("ogg") || value.contains("vorbis") -> "OGG"
                value.contains("x-ms-wma") -> "WMA"
                value.contains("amr") -> "AMR"
                value.contains("midi") -> "MIDI"
                value.contains("alac") -> "ALAC"
                else -> value.substringAfter('/').uppercase().take(6)
            }
        }
        return displayName
            ?.substringAfterLast('.', "")
            ?.uppercase()
            ?.takeIf { it.isNotBlank() }
            ?: "AUDIO"
    }

    // ---------------------------------------------------------------- artwork

    private fun queryArtwork(volume: String, mediaId: Long, size: Int): ByteArray? {
        val collection = collectionFor(volume)
        val uri = ContentUris.withAppendedId(collection, mediaId)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val bitmap = contentResolver.loadThumbnail(uri, Size(size, size), null)
                compress(bitmap)?.let { return it }
            } catch (t: Throwable) {
                // Tenta o retriever abaixo.
            }
        }

        var retriever: MediaMetadataRetriever? = null
        return try {
            val mmr = MediaMetadataRetriever()
            retriever = mmr
            mmr.setDataSource(this, uri)
            mmr.embeddedPicture
        } catch (t: Throwable) {
            null
        } finally {
            try {
                retriever?.release()
            } catch (t: Throwable) {
                // ignore
            }
        }
    }

    private fun compress(bitmap: Bitmap): ByteArray? {
        return try {
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 88, stream)
            stream.toByteArray()
        } catch (t: Throwable) {
            null
        }
    }
}

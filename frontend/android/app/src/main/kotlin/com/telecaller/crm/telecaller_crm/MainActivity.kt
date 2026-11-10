package com.telecaller.crm.telecaller_crm

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.telecaller.crm/call_recorder"
    private val PERMISSION_REQ_CODE = 9011

    private var mediaRecorder: MediaRecorder? = null
    private var activeOutputFile: File? = null
    private var callStartTimeMs: Long = 0L
    private var activePhoneNumber: String = ""
    private var isRecordingActive: Boolean = false
    private var isRecordingPaused: Boolean = false

    private var mediaPlayer: MediaPlayer? = null
    private var currentPlayingUrl: String? = null
    private var isPlayerPrepared: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensurePermissions" -> {
                        val granted = checkAndRequestPermissions()
                        result.success(granted)
                    }
                    "startCallRecording" -> {
                        val phone = call.argument<String>("phoneNumber") ?: ""
                        checkAndRequestPermissions()
                        val started = startRecordingInternal(phone)
                        result.success(started)
                    }
                    "pauseCallRecording" -> {
                        pauseRecordingInternal()
                        result.success(true)
                    }
                    "resumeCallRecording" -> {
                        resumeRecordingInternal()
                        result.success(true)
                    }
                    "stopCallRecording" -> {
                        val phone = call.argument<String>("phoneNumber") ?: activePhoneNumber
                        val info = stopAndResolveRecording(phone)
                        result.success(info)
                    }
                    "discardCallRecording" -> {
                        discardRecordingInternal()
                        result.success(true)
                    }
                    "playAudio" -> {
                        val url = call.argument<String>("url") ?: ""
                        playAudioInternal(url, result)
                    }
                    "pauseAudio" -> {
                        try {
                            if (mediaPlayer?.isPlaying == true) {
                                mediaPlayer?.pause()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "stopAudio" -> {
                        stopAudioInternal()
                        result.success(true)
                    }
                    "seekAudio" -> {
                        val positionSeconds = call.argument<Double>("positionSeconds") ?: 0.0
                        try {
                            if (isPlayerPrepared) {
                                mediaPlayer?.seekTo((positionSeconds * 1000).toInt())
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "getAudioStatus" -> {
                        try {
                            val playing = mediaPlayer?.isPlaying ?: false
                            val posMs = if (isPlayerPrepared) (mediaPlayer?.currentPosition ?: 0) else 0
                            val durMs = if (isPlayerPrepared) (mediaPlayer?.duration ?: 0) else 0
                            result.success(
                                mapOf(
                                    "isPlaying" to playing,
                                    "positionSeconds" to (posMs.toDouble() / 1000.0),
                                    "durationSeconds" to if (durMs > 0) (durMs.toDouble() / 1000.0) else 0.0,
                                    "url" to (currentPlayingUrl ?: "")
                                )
                            )
                        } catch (e: Exception) {
                            result.success(
                                mapOf(
                                    "isPlaying" to false,
                                    "positionSeconds" to 0.0,
                                    "durationSeconds" to 0.0,
                                    "url" to ""
                                )
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun checkAndRequestPermissions(): Boolean {
        val needed = mutableListOf(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.READ_PHONE_STATE
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            needed.add(Manifest.permission.READ_MEDIA_AUDIO)
        } else {
            needed.add(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

        val missing = needed.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), PERMISSION_REQ_CODE)
            return false
        }
        return true
    }

    private fun startRecordingInternal(phoneNumber: String): Boolean {
        stopRecorderSafely()
        callStartTimeMs = System.currentTimeMillis()
        activePhoneNumber = phoneNumber.replace(Regex("[^0-9+]"), "")

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            // Still record callStartTimeMs so system call recorder sync works even if mic permission was just prompted
            isRecordingActive = true
            isRecordingPaused = false
            return true
        }

        val outDir = File(cacheDir, "call_recordings")
        if (!outDir.exists()) outDir.mkdirs()
        val outFile = File(outDir, "call_${callStartTimeMs}.m4a")
        activeOutputFile = outFile

        // Try audio sources in order that best captures voice + headset communication
        val sourcesToTry = intArrayOf(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.MIC
        )

        for (source in sourcesToTry) {
            try {
                val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    MediaRecorder(this)
                } else {
                    @Suppress("DEPRECATION")
                    MediaRecorder()
                }

                val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                try {
                    if (audioManager != null && audioManager.isBluetoothScoAvailableOffCall) {
                        audioManager.startBluetoothSco()
                        audioManager.isBluetoothScoOn = true
                    }
                } catch (_: Exception) {}

                recorder.setAudioSource(source)
                recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                recorder.setAudioEncodingBitRate(128000)
                recorder.setAudioSamplingRate(44100)
                recorder.setOutputFile(outFile.absolutePath)
                recorder.prepare()
                recorder.start()

                mediaRecorder = recorder
                isRecordingActive = true
                isRecordingPaused = false
                return true
            } catch (e: Exception) {
                try {
                    mediaRecorder?.release()
                } catch (_: Exception) {}
                mediaRecorder = null
            }
        }

        isRecordingActive = true
        isRecordingPaused = false
        return false
    }

    private fun pauseRecordingInternal() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isRecordingActive && !isRecordingPaused) {
                mediaRecorder?.pause()
                isRecordingPaused = true
            }
        } catch (_: Exception) {}
    }

    private fun resumeRecordingInternal() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isRecordingActive && isRecordingPaused) {
                mediaRecorder?.resume()
                isRecordingPaused = false
            }
        } catch (_: Exception) {}
    }

    private fun stopRecorderSafely() {
        try {
            mediaRecorder?.stop()
        } catch (_: Exception) {}
        try {
            mediaRecorder?.reset()
            mediaRecorder?.release()
        } catch (_: Exception) {}
        mediaRecorder = null
        isRecordingActive = false
        isRecordingPaused = false
    }

    private fun discardRecordingInternal() {
        stopRecorderSafely()
        try {
            activeOutputFile?.delete()
        } catch (_: Exception) {}
        activeOutputFile = null
        callStartTimeMs = 0L
        activePhoneNumber = ""
    }

    private fun stopAndResolveRecording(phoneNumber: String): Map<String, Any?> {
        stopRecorderSafely()
        val searchSinceMs = if (callStartTimeMs > 0) callStartTimeMs - 15000L else (System.currentTimeMillis() - 300000L)
        val cleanPhone = phoneNumber.replace(Regex("[^0-9]"), "").takeLast(10)

        // 1. First check if the phone's built-in 2-Way System Call Recorder saved a file during this call.
        // System Call Recorder captures BOTH Employee Headset Mic + Client Downlink Audio!
        val systemFile = findRecentSystemCallRecording(searchSinceMs, cleanPhone)
        if (systemFile != null && systemFile.exists() && systemFile.length() > 512) {
            val destDir = File(cacheDir, "call_recordings")
            if (!destDir.exists()) destDir.mkdirs()
            val ext = systemFile.extension.ifEmpty { "m4a" }
            val copiedFile = File(destDir, "sys_call_${System.currentTimeMillis()}.$ext")
            return try {
                systemFile.copyTo(copiedFile, overwrite = true)
                val dur = extractDurationSeconds(copiedFile)
                val bytes = if (copiedFile.length() <= 30 * 1024 * 1024) copiedFile.readBytes() else null
                mapOf(
                    "filePath" to copiedFile.absolutePath,
                    "fileName" to copiedFile.name,
                    "durationSeconds" to dur,
                    "fileSize" to copiedFile.length(),
                    "source" to "SYSTEM_CALL_RECORDER",
                    "fileBytes" to bytes
                )
            } catch (e: Exception) {
                val dur = extractDurationSeconds(systemFile)
                val bytes = try { if (systemFile.length() <= 30 * 1024 * 1024) systemFile.readBytes() else null } catch (_: Exception) { null }
                mapOf(
                    "filePath" to systemFile.absolutePath,
                    "fileName" to systemFile.name,
                    "durationSeconds" to dur,
                    "fileSize" to systemFile.length(),
                    "source" to "SYSTEM_CALL_RECORDER",
                    "fileBytes" to bytes
                )
            }
        }

        // 2. Fallback to the live in-app MediaRecorder audio file
        val fallbackFile = activeOutputFile
        if (fallbackFile != null && fallbackFile.exists() && fallbackFile.length() > 256) {
            val dur = extractDurationSeconds(fallbackFile)
            val bytes = try { if (fallbackFile.length() <= 30 * 1024 * 1024) fallbackFile.readBytes() else null } catch (_: Exception) { null }
            return mapOf(
                "filePath" to fallbackFile.absolutePath,
                "fileName" to fallbackFile.name,
                "durationSeconds" to dur,
                "fileSize" to fallbackFile.length(),
                "source" to "MIC_RECORDING",
                "fileBytes" to bytes
            )
        }

        return mapOf(
            "filePath" to null,
            "fileName" to null,
            "durationSeconds" to 0,
            "fileSize" to 0L,
            "source" to "MIC_RECORDING"
        )
    }

    private fun findRecentSystemCallRecording(sinceMs: Long, last10Digits: String): File? {
        val candidates = mutableListOf<File>()

        // A. Query MediaStore.Audio.Media for any new audio recording since call started
        try {
            val projection = arrayOf(
                MediaStore.Audio.Media.DATA,
                MediaStore.Audio.Media.DATE_ADDED,
                MediaStore.Audio.Media.DATE_MODIFIED
            )
            val sinceSec = (sinceMs / 1000L)
            val selection = "${MediaStore.Audio.Media.DATE_MODIFIED} >= ? OR ${MediaStore.Audio.Media.DATE_ADDED} >= ?"
            val selectionArgs = arrayOf(sinceSec.toString(), sinceSec.toString())
            val sortOrder = "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"

            contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                sortOrder
            )?.use { cursor ->
                val dataIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
                while (cursor.moveToNext()) {
                    val path = cursor.getString(dataIdx) ?: continue
                    val file = File(path)
                    if (file.exists() && file.length() > 512 && !file.absolutePath.contains(cacheDir.absolutePath)) {
                        candidates.add(file)
                    }
                }
            }
        } catch (_: Exception) {}

        // B. Scan known OEM Call Recorder directories (Samsung, Xiaomi/MIUI, OnePlus, Oppo, Vivo, Realme, Google)
        val extRoot = Environment.getExternalStorageDirectory()
        val knownRelativeDirs = listOf(
            "Recordings/Call",
            "Recordings/Call Recordings",
            "Recordings/Voice Recorder",
            "Recordings",
            "MIUI/sound_recorder/call_rec",
            "Music/Recordings/Call Recordings",
            "Music/Recordings",
            "Record/Call",
            "Record",
            "Call",
            "CallRecordings",
            "PhoneRecord",
            "Recorder/Call"
        )

        for (rel in knownRelativeDirs) {
            try {
                val dir = File(extRoot, rel)
                if (dir.exists() && dir.isDirectory) {
                    dir.listFiles()?.forEach { f ->
                        if (f.isFile && f.lastModified() >= sinceMs && f.length() > 512) {
                            candidates.add(f)
                        } else if (f.isDirectory) {
                            f.listFiles()?.forEach { sub ->
                                if (sub.isFile && sub.lastModified() >= sinceMs && sub.length() > 512) {
                                    candidates.add(sub)
                                }
                            }
                        }
                    }
                }
            } catch (_: Exception) {}
        }

        if (candidates.isEmpty()) return null

        // Prioritize files whose name contains the dialed phone number, otherwise pick most recently modified
        if (last10Digits.length >= 6) {
            val phoneMatch = candidates
                .filter { it.name.replace(Regex("[^0-9]"), "").contains(last10Digits) }
                .maxByOrNull { it.lastModified() }
            if (phoneMatch != null) return phoneMatch
        }

        return candidates.maxByOrNull { it.lastModified() }
    }

    private fun extractDurationSeconds(file: File): Int {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.absolutePath)
            val durStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val durMs = durStr?.toLongOrNull() ?: 0L
            ((durMs + 500L) / 1000L).toInt().coerceAtLeast(1)
        } catch (e: Exception) {
            0
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {}
        }
    }

    private fun playAudioInternal(url: String, result: MethodChannel.Result) {
        if (url.isBlank()) {
            result.success(false)
            return
        }
        try {
            if (currentPlayingUrl == url && mediaPlayer != null && isPlayerPrepared) {
                if (mediaPlayer?.isPlaying == false) {
                    mediaPlayer?.start()
                }
                result.success(true)
                return
            }

            stopAudioInternal()
            val mp = MediaPlayer()
            currentPlayingUrl = url
            isPlayerPrepared = false

            mp.setDataSource(url)
            mp.setOnPreparedListener { player ->
                isPlayerPrepared = true
                player.start()
            }
            mp.setOnCompletionListener { player ->
                player.seekTo(0)
            }
            mp.setOnErrorListener { _, _, _ ->
                isPlayerPrepared = false
                true
            }
            mediaPlayer = mp
            mp.prepareAsync()
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun stopAudioInternal() {
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {}
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {}
        mediaPlayer = null
        currentPlayingUrl = null
        isPlayerPrepared = false
    }

    override fun onDestroy() {
        stopRecorderSafely()
        stopAudioInternal()
        super.onDestroy()
    }
}

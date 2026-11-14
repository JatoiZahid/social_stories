package com.socialstories.social_stories

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodChannel
import android.media.AudioAttributes
import android.media.SoundPool

class MainActivity : FlutterActivity() {
    private var previewSounds: SoundPool? = null
    private val ids = mutableMapOf<String, Int>()
    private val loaded = mutableSetOf<Int>()
    private val streams = mutableListOf<Int>()
    private var pending: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lazy, isolated preview earcons. Normal Story Book never invokes this.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "social_stories/tyre_preview_sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "stop" -> { stopPreviewSounds(); result.success(null) }
                    "play" -> {
                        val name = call.arguments as? String
                        if (name !in setOf("soft", "metal", "jack", "snap", "chime")) {
                            result.error("sound", "Unknown preview sound", null)
                        } else {
                            try {
                                val pool = previewSounds ?: SoundPool.Builder().setMaxStreams(3)
                                    .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                                    .build().also { soundPool ->
                                        previewSounds = soundPool
                                        soundPool.setOnLoadCompleteListener { p, id, status ->
                                            if (status == 0) {
                                                loaded.add(id)
                                                if (pending == id) { streams.add(p.play(id, .3f, .3f, 1, 0, 1f)); pending = null }
                                            }
                                        }
                                    }
                                val id = ids.getOrPut(name!!) {
                                    val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/audio/tyre_preview/$name.wav")
                                    assets.openFd(key).use { pool.load(it, 1) }
                                }
                                if (loaded.contains(id)) { streams.add(pool.play(id, .3f, .3f, 1, 0, 1f)) } else { pending = id }
                                result.success(null)
                            } catch (error: Exception) { result.error("sound", error.message, null) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
    private fun stopPreviewSounds() {
        pending = null
        streams.forEach { previewSounds?.stop(it) }; streams.clear()
    }
    override fun onPause() { stopPreviewSounds(); super.onPause() }
    override fun onDestroy() {
        stopPreviewSounds(); previewSounds?.release(); previewSounds = null
        super.onDestroy()
    }
}

package com.aquiset.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var bridge: AquisetBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = AquisetBridge(this, flutterEngine.dartExecutor.binaryMessenger).also {
            it.captureLaunch(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        bridge?.deliver(intent)
    }

    override fun onResume() {
        super.onResume()
        bridge?.onResume()
    }
}

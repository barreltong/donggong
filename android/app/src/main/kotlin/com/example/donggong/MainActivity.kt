package com.example.donggong

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val dpiChannel = "com.donggong/dpi"
    private val otaChannel = "com.donggong/ota"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            dpiChannel,
        ).setMethodCallHandler(DpiBypassModule())
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            otaChannel,
        ).setMethodCallHandler(OtaUpdateModule(this))
    }
}

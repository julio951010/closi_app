package com.jchd.closi_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Registrar el PlatformView del mapa VTM
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "closi_app/vtm_map",
            VtmMapFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
    }
}

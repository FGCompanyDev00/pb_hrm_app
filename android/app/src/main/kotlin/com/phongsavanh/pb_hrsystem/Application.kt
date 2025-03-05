package com.phongsavanh.pb_hrsystem

import io.flutter.embedding.android.FlutterActivity
import io.flutter.app.FlutterApplication
import androidx.work.Configuration
import androidx.work.WorkManager

class Application : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        
        // Initialize WorkManager with custom configuration
        val config = Configuration.Builder()
            .setMinimumLoggingLevel(android.util.Log.INFO)
            .build()
            
        WorkManager.initialize(this, config)
    }
} 
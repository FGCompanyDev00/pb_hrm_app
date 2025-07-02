package com.example.pb_hrsystem

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "device_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> {
                    val deviceInfo = getDeviceInfo()
                    result.success(deviceInfo)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getDeviceInfo(): Map<String, Any> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        
        // Get total RAM in MB
        val totalMemoryMB = memoryInfo.totalMem / (1024 * 1024)
        
        // Get available RAM in MB
        val availableMemoryMB = memoryInfo.availMem / (1024 * 1024)
        
        // Get device information
        val deviceInfo = mapOf(
            "totalMemoryMB" to totalMemoryMB,
            "availableMemoryMB" to availableMemoryMB,
            "isLowMemory" to memoryInfo.lowMemory,
            "deviceModel" to Build.MODEL,
            "deviceBrand" to Build.BRAND,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkVersion" to Build.VERSION.SDK_INT,
            "cpuAbi" to Build.SUPPORTED_ABIS[0],
            "hardware" to Build.HARDWARE
        )
        
        return deviceInfo
    }
} 
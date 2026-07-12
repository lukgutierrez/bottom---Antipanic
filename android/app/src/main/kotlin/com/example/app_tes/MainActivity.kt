package com.example.app_tes

import android.content.Intent
import android.net.Uri
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.panico.app/canales"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            
            // 1. FUNCIÓN NATIVA PARA ENVIAR SMS EN SEGUNDO PLANO
            if (call.method == "sendBackgroundSms") {
                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")
                
                if (phone != null && message != null) {
                    try {
                        val smsManager: SmsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                            context.getSystemService(SmsManager::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            SmsManager.getDefault()
                        }
                        
                        val parts = smsManager.divideMessage(message)
                        if (parts.size > 1) {
                            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                        } else {
                            smsManager.sendTextMessage(phone, null, message, null, null)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR_SMS", e.message, null)
                    }
                } else {
                    result.error("DATOS_VACIOS", "El número o mensaje están vacíos", null)
                }
            } 
            
            // 2. FUNCIÓN NATIVA PARA ABRIR WHATSAPP O ENLACES
            else if (call.method == "abrirEnlace") {
                val url = call.argument<String>("url")
                if (url != null) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR_URL", "No se pudo abrir WhatsApp o la URL", null)
                    }
                } else {
                    result.error("URL_VACIA", "La URL está vacía", null)
                }
            } 
            
            else {
                result.notImplemented()
            }
        }
    }
}
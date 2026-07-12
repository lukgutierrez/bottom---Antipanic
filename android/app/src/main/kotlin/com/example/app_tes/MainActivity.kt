package com.example.app_tes

import android.content.Context
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
            
            // 1. ENVÍO DE SMS NATIVO EN SEGUNDO PLANO
            if (call.method == "sendBackgroundSms") {
                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")
                
                if (!phone.isNullOrBlank() && !message.isNullOrBlank()) {
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
                    result.error("DATOS_VACIOS", "Número o mensaje vacío", null)
                }
            } 
            
            // 2. LLAMADA DIRECTA (911)
            else if (call.method == "llamarEmergencia") {
                val numero = call.argument<String>("numero") ?: "911"
                try {
                    val intent = Intent(Intent.ACTION_CALL)
                    intent.data = Uri.parse("tel:$numero")
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR_CALL", e.message, null)
                }
            }

            // 3. ABRIR WHATSAPP NATIVAMENTE
            else if (call.method == "abrirEnlace") {
                val url = call.argument<String>("url")
                if (!url.isNullOrBlank()) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR_URL", e.message, null)
                    }
                } else {
                    result.error("URL_VACIA", "La URL está vacía", null)
                }
            } 
            
            // 4. GUARDADO NATIVO ULTRA SEGURO (Usando separador ||)
            else if (call.method == "guardarContactos") {
                val lista = call.argument<List<String>>("contactos")
                if (lista != null) {
                    val prefs = context.getSharedPreferences("panico_memoria", Context.MODE_PRIVATE)
                    val stringGuardar = lista.joinToString("||")
                    prefs.edit().putString("mis_numeros", stringGuardar).apply()
                    result.success(true)
                } else {
                    result.error("ERROR", "Lista nula", null)
                }
            }

            // 5. CARGA NATIVA
            else if (call.method == "cargarContactos") {
                val prefs = context.getSharedPreferences("panico_memoria", Context.MODE_PRIVATE)
                val guardado = prefs.getString("mis_numeros", "") ?: ""
                val lista = if (guardado.isEmpty()) emptyList<String>() else guardado.split("||")
                result.success(lista)
            }
            
            else {
                result.notImplemented()
            }
        }
    }
}
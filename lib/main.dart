import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para conectar con Kotlin (MethodChannel)
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Botón Antipánico',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.red),
      home: const PanicButtonScreen(),
    );
  }
}

class PanicButtonScreen extends StatefulWidget {
  const PanicButtonScreen({Key? key}) : super(key: key);

  @override
  State<PanicButtonScreen> createState() => _PanicButtonScreenState();
}

class _PanicButtonScreenState extends State<PanicButtonScreen> {
  // Canal de comunicación que conecta exacto con nuestro código en Kotlin
  static const platform = MethodChannel('com.panico.app/canales');
  bool _enviando = false;

  // Pon aquí tus números de emergencia con el formato internacional (ej: +549...)
  final List<String> contactosEmergencia = [
     
    "+543876102482",
  ];

  @override
  void initState() {
    super.initState();
    _solicitarPermisos();
  }

  Future<void> _solicitarPermisos() async {
    await [Permission.location, Permission.sms].request();
  }

  // 1. ENVÍO DE SMS NATIVO EN SEGUNDO PLANO
  Future<bool> _enviarSmsNativo(String telefono, String mensaje) async {
    try {
      final bool exito = await platform.invokeMethod('sendBackgroundSms', {
        'phone': telefono,
        'message': mensaje,
      });
      return exito;
    } on PlatformException catch (e) {
      debugPrint("Fallo al enviar SMS: '${e.message}'.");
      return false;
    }
  }

  // 2. ABRIR WHATSAPP NATIVAMENTE
  Future<void> _enviarPorWhatsApp(String numero) async {
    try {
      Position posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String linkMaps = "https://maps.google.com/?q=${posicion.latitude},${posicion.longitude}";
      String mensajeAlerta = "¡ALERTA DE EMERGENCIA! Necesito ayuda urgente. Mi ubicación actual: $linkMaps";

      String numeroLimpio = numero.replaceAll(RegExp(r'[^0-9]'), '');
      String urlCompleta = "https://wa.me/$numeroLimpio?text=${Uri.encodeComponent(mensajeAlerta)}";

      // Llamada al MethodChannel de Kotlin para abrir la URL
      await platform.invokeMethod('abrirEnlace', {'url': urlCompleta});
      
    } on PlatformException catch (e) {
      _mostrarAlerta("No se pudo abrir WhatsApp: ${e.message}");
    } catch (e) {
      _mostrarAlerta("Error al obtener ubicación para WhatsApp.");
    }
  }

  // 3. ACCIÓN DEL BOTÓN PRIMARIO (SMS AUTOMÁTICO)
  Future<void> _activarAlertaSms() async {
    setState(() => _enviando = true);
    try {
      Position posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String linkMaps = "https://maps.google.com/?q=${posicion.latitude},${posicion.longitude}";
      String mensajeAlerta = "¡ALERTA DE EMERGENCIA! Necesito ayuda urgente. Mi ubicación actual: $linkMaps";

      int enviados = 0;
      for (String numero in contactosEmergencia) {
        if (await _enviarSmsNativo(numero, mensajeAlerta)) enviados++;
      }
      _mostrarAlerta("Alerta enviada automáticamente por SMS a $enviados contacto(s).");
    } catch (e) {
      _mostrarAlerta("Error al procesar la ubicación o el envío: $e");
    } finally {
      setState(() => _enviando = false);
    }
  }

  void _mostrarAlerta(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Botón Antipánico", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red[800],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Presiona el botón para enviar tu ubicación nativamente en segundo plano.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 40),
              
              // BOTÓN DE ALERTA (Mantener presionado)
              GestureDetector(
                onLongPress: _enviando ? null : _activarAlertaSms,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: _enviando ? Colors.grey : Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Center(
                    child: _enviando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 60),
                              SizedBox(height: 10),
                              Text(
                                "MANTENER\nPRESIONADO",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
              const Divider(),
              const SizedBox(height: 10),
              
              // BOTÓN SECUNDARIO: WHATSAPP
              const Text("Opcional: Envío asistido por internet"),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _enviarPorWhatsApp(contactosEmergencia.first),
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text("Enviar por WhatsApp", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
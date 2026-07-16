import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antipánico 911',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.red[700],
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const PanicHomeScreen(),
    );
  }
}

class PanicHomeScreen extends StatefulWidget {
  const PanicHomeScreen({Key? key}) : super(key: key);

  @override
  State<PanicHomeScreen> createState() => _PanicHomeScreenState();
}

class _PanicHomeScreenState extends State<PanicHomeScreen> {
  static const platform = MethodChannel('com.panico.app/canales');
  
  List<String> _contactos = [];
  bool _enviando = false;
  bool _alarmaSonando = false;
  final _nombreController = TextEditingController();
  final _numeroController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await [Permission.location, Permission.sms, Permission.phone].request();
    await _cargarContactosNativos();
  }

  Future<void> _cargarContactosNativos() async {
    try {
      final List<dynamic>? listaNativa = await platform.invokeMethod('cargarContactos');
      setState(() {
        _contactos = listaNativa?.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() ?? [];
      });
    } catch (e) {
      debugPrint("Error al cargar: $e");
    }
  }

  Future<void> _guardarContactosNativos(List<String> nuevaLista) async {
    try {
      await platform.invokeMethod('guardarContactos', {'contactos': nuevaLista});
      setState(() {
        _contactos = List.from(nuevaLista);
      });
    } catch (e) {
      debugPrint("Error al guardar: $e");
    }
  }

  // AGREGAR CON NOMBRE Y NÚMERO (Ejemplo de guardado: "Mamá - +549387...")
  void _agregarContacto(Function setDialogState) {
    String nombre = _nombreController.text.trim();
    String numero = _numeroController.text.trim();

    if (nombre.isEmpty || numero.isEmpty) {
      _mostrarSnack("⚠️ Por favor ingresa el Nombre y el Número", isError: true);
      return;
    }
    
    if (!numero.startsWith("+")) {
      if (numero.startsWith("0")) {
        numero = "+549${numero.substring(1)}";
      } else if (numero.startsWith("15")) {
        numero = "+549${numero.substring(2)}";
      } else if (numero.startsWith("3") || numero.startsWith("1") || numero.startsWith("2")) {
        numero = "+549$numero";
      } else {
        numero = "+$numero";
      }
    }

    if (_contactos.length >= 3) {
      _mostrarSnack("⚠️ Máximo 3 contactos permitidos.", isError: true);
      return;
    }
    
    String contactoCompleto = "$nombre - $numero";
    List<String> actualizada = List.from(_contactos)..add(contactoCompleto);
    
    _guardarContactosNativos(actualizada);
    _nombreController.clear();
    _numeroController.clear();
    setDialogState(() {});
    setState(() {});
    _mostrarSnack("✅ Guardado: $contactoCompleto");
  }

  void _eliminarContacto(int index, Function setDialogState) {
    List<String> actualizada = List.from(_contactos)..removeAt(index);
    _guardarContactosNativos(actualizada);
    setDialogState(() {});
    setState(() {});
    _mostrarSnack("🗑️ Contacto eliminado.");
  }

  // Extrae solo los números para que el SMS o WhatsApp puedan enviarse sin error
  String _extraerNumero(String contactoGuardado) {
    if (contactoGuardado.contains(" - ")) {
      return contactoGuardado.split(" - ").last.trim();
    }
    return contactoGuardado.trim();
  }

  String _extraerNombre(String contactoGuardado) {
    if (contactoGuardado.contains(" - ")) {
      return contactoGuardado.split(" - ").first.trim();
    }
    return "Contacto de Emergencia";
  }

  Future<Position?> _obtenerUbicacionSegura() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _mostrarSnack("⚠️ EL GPS ESTÁ APAGADO. Actívalo en tu teléfono.", isError: true);
      await Geolocator.openLocationSettings();
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _mostrarSnack("⚠️ Permiso de GPS denegado.", isError: true);
        return null;
      }
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7),
      );
    } catch (e) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  Future<void> _activarAlertaSms() async {
    if (_contactos.isEmpty) {
      _mostrarSnack("⚠️ AGREGA UN CONTACTO PRIMERO", isError: true);
      _abrirGestorContactosCentro();
      return;
    }

    setState(() => _enviando = true);
    Position? posicion = await _obtenerUbicacionSegura();

    if (posicion == null) {
      setState(() => _enviando = false);
      _mostrarSnack("❌ No se pudo obtener la ubicación GPS.", isError: true);
      return;
    }

    String linkMaps = "https://maps.google.com/?q=${posicion.latitude},${posicion.longitude}";
    String mensajeAlerta = "¡ALERTA DE EMERGENCIA! Necesito ayuda urgente. Mi ubicación actual: $linkMaps";

    int enviados = 0;
    for (String item in _contactos) {
      String numeroLimpio = _extraerNumero(item);
      try {
        final bool exito = await platform.invokeMethod('sendBackgroundSms', {
          'phone': numeroLimpio,
          'message': mensajeAlerta,
        });
        if (exito) enviados++;
      } catch (e) {
        debugPrint("Fallo al enviar a $numeroLimpio: $e");
      }
    }

    setState(() => _enviando = false);

    if (enviados > 0) {
      _mostrarSnack("✅ Alerta enviada automáticamente por SMS a $enviados contacto(s).");
    } else {
      _mostrarAlertaFalloSaldo();
    }
  }

  Future<void> _llamar911() async {
    try {
      await platform.invokeMethod('llamarEmergencia', {'numero': '911'});
    } on PlatformException catch (e) {
      _mostrarSnack("Error en llamada: ${e.message}", isError: true);
    }
  }

  void _alternarAlarma() async {
    try {
      if (_alarmaSonando) {
        await platform.invokeMethod('detenerAlarma');
        setState(() => _alarmaSonando = false);
        _mostrarSnack("🔇 Sirena silenciada.");
      } else {
        await platform.invokeMethod('iniciarAlarma');
        setState(() => _alarmaSonando = true);
        _mostrarSnack("🚨 SIRENA DE EMERGENCIA AL MÁXIMO VOLUMEN");
      }
    } catch (e) {
      _mostrarSnack("Error en sirena: $e", isError: true);
    }
  }

  Future<void> _enviarPorWhatsAppA(String itemContacto) async {
    Position? posicion = await _obtenerUbicacionSegura();
    if (posicion == null) return;

    String linkMaps = "https://maps.google.com/?q=${posicion.latitude},${posicion.longitude}";
    String mensajeAlerta = "¡ALERTA DE EMERGENCIA! Necesito ayuda urgente. Mi ubicación actual: $linkMaps";

    String numero = _extraerNumero(itemContacto);
    String numeroLimpio = numero.replaceAll(RegExp(r'[^0-9]'), '');
    String urlCompleta = "https://wa.me/$numeroLimpio?text=${Uri.encodeComponent(mensajeAlerta)}";

    await platform.invokeMethod('abrirEnlace', {'url': urlCompleta});
  }

  void _mostrarSelectorWhatsApp() {
    if (_contactos.isEmpty) {
      _mostrarSnack("⚠️ Configura un contacto primero.", isError: true);
      _abrirGestorContactosCentro();
      return;
    }

    if (_contactos.length == 1) {
      _enviarPorWhatsAppA(_contactos.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.send, color: Color(0xFF128C7E), size: 24),
                SizedBox(width: 10),
                Text("Enviar ubicación por WhatsApp", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 6),
            const Text("Elige el contacto al que deseas avisar en este momento:", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _contactos.length,
              itemBuilder: (ctx, i) {
                String nombre = _extraerNombre(_contactos[i]);
                String numero = _extraerNumero(_contactos[i]);
                return Card(
                  color: const Color(0xFF2C2C2C),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: const CircleAvatar(backgroundColor: Color(0xFF128C7E), child: Icon(Icons.person, color: Colors.white)),
                    title: Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(numero, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                    onTap: () {
                      Navigator.pop(ctx);
                      _enviarPorWhatsAppA(_contactos[i]);
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _mostrarAlertaFalloSaldo() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text("Falló el SMS", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          "Es posible que no tengas saldo o señal celular para enviar SMS.\n\n¿Qué deseas hacer?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () { Navigator.pop(ctx); _alternarAlarma(); },
            icon: const Icon(Icons.volume_up, color: Colors.white, size: 16),
            label: const Text("Sirena", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF128C7E)),
            onPressed: () { Navigator.pop(ctx); _mostrarSelectorWhatsApp(); },
            icon: const Icon(Icons.send, color: Colors.white, size: 16),
            label: const Text("WhatsApp", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _abrirGestorContactosCentro() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
            insetPadding: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Mis Contactos (Máx. 3)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        )
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Text("Agrega el nombre y el número de tu contacto de confianza.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 20),

                    _contactos.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                            child: const Text("No hay contactos aún.\nAgrega el primero abajo 👇", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _contactos.length,
                            itemBuilder: (ctx, i) {
                              String nombre = _extraerNombre(_contactos[i]);
                              String numero = _extraerNumero(_contactos[i]);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const CircleAvatar(backgroundColor: Colors.green, radius: 18, child: Icon(Icons.person, color: Colors.white, size: 20)),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                            Text(numero, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      tooltip: "Eliminar",
                                      onPressed: () => _eliminarContacto(i, setDialogState),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                    const SizedBox(height: 20),

                    if (_contactos.length < 3) ...[
                      TextField(
                        controller: _nombreController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: "Nombre (Ej: Mamá, Hermano)",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF2C2C2C),
                          prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _numeroController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: "Número (Ej: 387696...)",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF2C2C2C),
                          prefixIcon: const Icon(Icons.phone, color: Colors.white54),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _agregarContacto(setDialogState),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text("AGREGAR CONTACTO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _mostrarSnack(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red[900] : Colors.green[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  final Color colorFondo = _alarmaSonando
      ? Colors.red[900]!.withOpacity(0.35)
      : const Color(0xFF121212);

  return Scaffold(
    backgroundColor: colorFondo,
    appBar: AppBar(
      title: const Text(
        "BOTÓN ANTIPÁNICO",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      backgroundColor:
          _alarmaSonando ? Colors.red[900] : const Color(0xFF1E1E1E),
    ),
    body: SafeArea(
      child: Column(
        children: [
          // BARRA SUPERIOR PARA GESTIONAR CONTACTOS
          GestureDetector(
            onTap: _abrirGestorContactosCentro,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: _contactos.isEmpty
                    ? Colors.orange[900]
                    : const Color(0xFF252525),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _contactos.isEmpty
                      ? Colors.orange
                      : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _contactos.isEmpty
                            ? Icons.warning
                            : Icons.group,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _contactos.isEmpty
                                ? "⚠️ FALTA AGREGAR CONTACTOS"
                                : "CONTACTOS GUARDADOS (${_contactos.length}/3)",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            "Toca aquí para ver, agregar o eliminar",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.edit,
                    size: 20,
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            ),
          ),

          // CUERPO CENTRAL
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _alarmaSonando
                          ? "🚨 ¡SIRENA ACTIVADA! TOCA EL BOTÓN PARA APAGAR 🚨"
                          : "MANTÉN PRESIONADO PARA ENVIAR ALERTA",
                      style: TextStyle(
                        color: _alarmaSonando
                            ? Colors.redAccent
                            : Colors.grey,
                        fontSize: 13,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // BOTÓN SOS
                    GestureDetector(
                      onLongPress:
                          _enviando ? null : _activarAlertaSms,
                      onTap:
                          _alarmaSonando ? _alternarAlarma : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          color: _alarmaSonando
                              ? Colors.orange[700]
                              : (_enviando
                                  ? Colors.grey[800]
                                  : Colors.red[600]),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_alarmaSonando
                                      ? Colors.orange
                                      : (_enviando
                                          ? Colors.grey
                                          : Colors.red))
                                  .withOpacity(0.5),
                              blurRadius:
                                  _alarmaSonando ? 50 : 30,
                              spreadRadius:
                                  _alarmaSonando ? 15 : 8,
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white24,
                            width: 4,
                          ),
                        ),
                        child: Center(
                          child: _enviando
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 4,
                                )
                              : Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _alarmaSonando
                                          ? Icons.volume_off
                                          : Icons.touch_app_rounded,
                                      color: Colors.white,
                                      size: 55,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _alarmaSonando
                                          ? "APAGAR"
                                          : "SOS",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 38,
                                        fontWeight:
                                            FontWeight.w900,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    Text(
                                      _alarmaSonando
                                          ? "TOCA UNA VEZ"
                                          : "2 SEGUNDOS",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 15),

                    const Text(
                      "ACCIONES RÁPIDAS DE EMERGENCIA",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // BOTONES INFERIORES
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.red[900],
                              foregroundColor:
                                  Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),
                            onPressed: _llamar911,
                            icon: const Icon(
                              Icons.call,
                              size: 18,
                            ),
                            label: const Text(
                              "911",
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF128C7E),
                              foregroundColor:
                                  Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),
                            onPressed:
                                _mostrarSelectorWhatsApp,
                            icon: const Icon(
                              Icons.send,
                              size: 18,
                            ),
                            label: const Text(
                              "WHATSAPP",
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _alarmaSonando
                                      ? Colors.redAccent
                                      : Colors.orange[800],
                              foregroundColor:
                                  Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),
                            onPressed: _alternarAlarma,
                            icon: Icon(
                              _alarmaSonando
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              size: 18,
                            ),
                            label: Text(
                              _alarmaSonando
                                  ? "PARAR"
                                  : "SIRENA",
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // MARCA DE AGUA
          Padding(
            padding: const EdgeInsets.only(
              bottom: 16,
              top: 8,
            ),
            child: Text(
              "Created by @lukgtz",
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}}
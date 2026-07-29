import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../services/panic_service.dart';
import '../widgets/sos_button.dart';
import '../widgets/contact_manager_dialog.dart';
import '../widgets/whatsapp_selector.dart';
import '../widgets/message_editor_dialog.dart';

class PanicHomeScreen extends StatefulWidget {
  const PanicHomeScreen({super.key});

  @override
  State<PanicHomeScreen> createState() => _PanicHomeScreenState();
}

class _PanicHomeScreenState extends State<PanicHomeScreen> {
  final _panicService = PanicService();

  List<String> _contacts = [];
  bool _isSending = false;
  bool _isAlarmActive = false;
  String _customMessage = '';

  String get _effectiveMessage =>
      _customMessage.isNotEmpty ? _customMessage : AppConstants.messageTemplates[0];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _panicService.requestPermissions();
    final contacts = await _panicService.loadContacts();
    final msg = await _panicService.loadCustomMessage();
    setState(() {
      _contacts = contacts;
      _customMessage = msg;
    });
  }

  Future<void> _sendSmsAlert() async {
    if (_contacts.isEmpty) {
      _showSnack("⚠️ AGREGA UN CONTACTO PRIMERO", isError: true);
      _openContactManager();
      return;
    }

    setState(() => _isSending = true);

    final position = await _panicService.getLocation();
    if (position == null) {
      setState(() => _isSending = false);
      _showSnack("❌ No se pudo obtener la ubicación GPS.", isError: true);
      return;
    }

    final locationUrl = _panicService.buildLocationUrl(position);
    final message = _panicService.buildFinalMessage(_effectiveMessage, locationUrl);

    int sent = 0;
    for (final item in _contacts) {
      final phone = _panicService.extractNumber(item);
      final ok = await _panicService.sendSms(phone, message);
      if (ok) sent++;
    }

    setState(() => _isSending = false);

    if (sent > 0) {
      _showSnack("✅ Alerta enviada por SMS a $sent contacto(s).");
    } else {
      _showSmsFailDialog();
    }
  }

  Future<void> _toggleAlarm() async {
    if (_isAlarmActive) {
      await _panicService.stopAlarm();
      setState(() => _isAlarmActive = false);
      _showSnack("🔇 Sirena silenciada.");
    } else {
      await _panicService.startAlarm();
      setState(() => _isAlarmActive = true);
      _showSnack("🚨 SIRENA DE EMERGENCIA AL MÁXIMO VOLUMEN");
    }
  }

  void _showWhatsAppSelector() {
    if (_contacts.isEmpty) {
      _showSnack("⚠️ Configura un contacto primero.", isError: true);
      _openContactManager();
      return;
    }

    if (_contacts.length == 1) {
      _sendWhatsApp(_contacts.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkAppBar,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => WhatsAppSelector(
        contacts: _contacts,
        panicService: _panicService,
        messageTemplate: _effectiveMessage,
      ),
    );
  }

  Future<void> _sendWhatsApp(String contact) async {
    final position = await _panicService.getLocation();
    if (position == null) return;

    final locationUrl = _panicService.buildLocationUrl(position);
    final message = _panicService.buildFinalMessage(_effectiveMessage, locationUrl);
    final phone = _panicService.extractNumber(contact);

    await _panicService.openWhatsApp(phone, message);
  }

  void _showSmsFailDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () {
              Navigator.pop(ctx);
              _toggleAlarm();
            },
            icon: const Icon(Icons.volume_up, color: Colors.white, size: 16),
            label: const Text("Sirena", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF128C7E)),
            onPressed: () {
              Navigator.pop(ctx);
              _showWhatsAppSelector();
            },
            icon: const Icon(Icons.send, color: Colors.white, size: 16),
            label: const Text("WhatsApp", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openContactManager() {
    showDialog(
      context: context,
      builder: (_) => ContactManagerDialog(
        contacts: _contacts,
        panicService: _panicService,
        onChanged: () async {
          final updated = await _panicService.loadContacts();
          setState(() => _contacts = updated);
        },
      ),
    );
  }

  void _openMessageEditor() {
    showDialog(
      context: context,
      builder: (_) => MessageEditorDialog(
        panicService: _panicService,
        currentMessage: _customMessage.isNotEmpty
            ? _customMessage
            : AppConstants.messageTemplates[0],
        onSaved: () async {
          final msg = await _panicService.loadCustomMessage();
          setState(() => _customMessage = msg);
        },
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red[900] : Colors.green[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isAlarmActive
        ? Colors.red[900]!.withValues(alpha: 0.35)
        : AppTheme.darkBackground;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "BOTÓN ANTIPÁNICO",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: _isAlarmActive ? Colors.red[900] : AppTheme.darkAppBar,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Contact bar
            GestureDetector(
              onTap: _openContactManager,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: _contacts.isEmpty ? Colors.orange[900] : AppTheme.darkContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _contacts.isEmpty ? Colors.orange : Colors.white12,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _contacts.isEmpty ? Icons.warning : Icons.group,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _contacts.isEmpty
                                  ? "⚠️ FALTA AGREGAR CONTACTOS"
                                  : "CONTACTOS GUARDADOS (${_contacts.length}/3)",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              "Toca aquí para ver, agregar o eliminar",
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Icon(Icons.edit, size: 20, color: Colors.blueAccent),
                  ],
                ),
              ),
            ),

            // Main body
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isAlarmActive
                            ? "🚨 ¡SIRENA ACTIVADA! TOCA EL BOTÓN PARA APAGAR 🚨"
                            : "MANTÉN PRESIONADO PARA ENVIAR ALERTA",
                        style: TextStyle(
                          color: _isAlarmActive ? Colors.redAccent : Colors.grey,
                          fontSize: 13,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 25),

                      SosButton(
                        isSending: _isSending,
                        isAlarmActive: _isAlarmActive,
                        onLongPress: _sendSmsAlert,
                        onTap: _toggleAlarm,
                      ),

                      const SizedBox(height: 35),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 15),

                      const Text(
                        "ACCIONES RÁPIDAS DE EMERGENCIA",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 15),

                      // Bottom buttons
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[900],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _panicService.callEmergency(),
                              icon: const Icon(Icons.call, size: 18),
                              label: const Text(
                                "911",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF128C7E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _showWhatsAppSelector,
                              icon: const Icon(Icons.send, size: 18),
                              label: const Text(
                                "WHATSAPP",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isAlarmActive
                                    ? Colors.redAccent
                                    : Colors.orange[800],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _toggleAlarm,
                              icon: Icon(
                                _isAlarmActive ? Icons.volume_off : Icons.volume_up,
                                size: 18,
                              ),
                              label: Text(
                                _isAlarmActive ? "PARAR" : "SIRENA",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Edit message button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[400],
                            side: const BorderSide(color: Colors.white12),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _openMessageEditor,
                          icon: const Icon(Icons.edit_note, size: 20),
                          label: const Text(
                            "PERSONALIZAR MENSAJE DE ALERTA",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Watermark
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
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
  }
}
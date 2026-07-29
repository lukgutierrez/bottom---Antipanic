import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants/app_constants.dart';

class PanicService {
  static const _channel = MethodChannel(AppConstants.platformChannel);

  // ─── Contactos ───────────────────────────────────────────────
  Future<List<String>> loadContacts() async {
    try {
      final list = await _channel.invokeMethod<List<dynamic>>('cargarContactos');
      return list?.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() ?? [];
    } catch (e) {
      debugPrint("Error al cargar contactos: $e");
      return [];
    }
  }

  Future<void> saveContacts(List<String> contacts) async {
    try {
      await _channel.invokeMethod('guardarContactos', {'contactos': contacts});
    } catch (e) {
      debugPrint("Error al guardar contactos: $e");
    }
  }

  // ─── Permisos ────────────────────────────────────────────────
  Future<void> requestPermissions() async {
    await [Permission.location, Permission.sms, Permission.phone].request();
  }

  // ─── Ubicación ───────────────────────────────────────────────
  Future<Position?> getLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
      return null;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final req = await Geolocator.requestPermission();
      if (req == LocationPermission.denied) return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: AppConstants.locationTimeoutSeconds),
        ),
      );
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  String buildLocationUrl(Position pos) =>
      '${AppConstants.mapsUrlPrefix}${pos.latitude},${pos.longitude}';

  String buildEmergencyMessage(String locationUrl) =>
      '${AppConstants.emergencyMessagePrefix} $locationUrl';

  // ─── SMS ─────────────────────────────────────────────────────
  Future<bool> sendSms(String phone, String message) async {
    try {
      return await _channel.invokeMethod('sendBackgroundSms', {
        'phone': phone,
        'message': message,
      });
    } catch (e) {
      debugPrint("Error SMS a $phone: $e");
      return false;
    }
  }

  // ─── Llamada ─────────────────────────────────────────────────
  Future<void> callEmergency() async {
    try {
      await _channel.invokeMethod('llamarEmergencia', {
        'numero': AppConstants.emergencyNumber,
      });
    } on PlatformException catch (e) {
      debugPrint("Error llamada: ${e.message}");
    }
  }

  // ─── Alarma ──────────────────────────────────────────────────
  Future<void> startAlarm() async {
    await _channel.invokeMethod('iniciarAlarma');
  }

  Future<void> stopAlarm() async {
    await _channel.invokeMethod('detenerAlarma');
  }

  // ─── Mensaje personalizado ──────────────────────────────────
  Future<String> loadCustomMessage() async {
    try {
      final msg = await _channel.invokeMethod<String>('cargarMensaje');
      return msg ?? '';
    } catch (e) {
      debugPrint("Error al cargar mensaje: $e");
      return '';
    }
  }

  Future<void> saveCustomMessage(String message) async {
    try {
      await _channel.invokeMethod('guardarMensaje', {'mensaje': message});
    } catch (e) {
      debugPrint("Error al guardar mensaje: $e");
    }
  }

  String buildFinalMessage(String template, String locationUrl) {
    return template.replaceAll(AppConstants.locationPlaceholder, locationUrl);
  }

  // ─── WhatsApp ────────────────────────────────────────────────
  Future<void> openWhatsApp(String phone, String message) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = '${AppConstants.whatsappUrlPrefix}$clean?text=${Uri.encodeComponent(message)}';
    await _channel.invokeMethod('abrirEnlace', {'url': url});
  }

  // ─── Helpers ─────────────────────────────────────────────────
  String extractNumber(String contact) {
    return contact.contains(' - ') ? contact.split(' - ').last.trim() : contact.trim();
  }

  String extractName(String contact) {
    return contact.contains(' - ') ? contact.split(' - ').first.trim() : 'Contacto de Emergencia';
  }

  String formatNumber(String raw) {
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('0')) return '+549${raw.substring(1)}';
    if (raw.startsWith('15')) return '+549${raw.substring(2)}';
    if (RegExp(r'^[123]').hasMatch(raw)) return '+549$raw';
    return '+$raw';
  }
}
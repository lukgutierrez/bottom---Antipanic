class AppConstants {
  // App info
  static const String appName = 'Antipánico 911';
  static const String appVersion = '1.0.0+1';

  // Platform channel
  static const String platformChannel = 'com.panico.app/canales';

  // Contact limits
  static const int maxContacts = 3;

  // Location settings
  static const int locationTimeoutSeconds = 7;

  // Emergency message
  static const String emergencyMessagePrefix = '¡ALERTA DE EMERGENCIA! Necesito ayuda urgente. Mi ubicación actual:';

  // Maps URL
  static const String mapsUrlPrefix = 'https://maps.google.com/?q=';

  // WhatsApp URL
  static const String whatsappUrlPrefix = 'https://wa.me/';

  // Emergency number
  static const String emergencyNumber = '911';

  // Argentine phone prefixes
  static const String argentinaCountryCode = '+549';

  // Placeholder for location URL in messages
  static const String locationPlaceholder = '{ubicacion}';

  // Pre-defined emergency message templates
  static const List<String> messageTemplates = [
    '¡ALERTA DE EMERGENCIA! Necesito ayuda urgente. Mi ubicación actual: {ubicacion}',
    '¡AYUDA! Estoy en peligro. Por favor ven a mi ubicación: {ubicacion}',
    'EMERGENCIA. Necesito auxilio inmediato. Estoy aquí: {ubicacion}',
    '¡URGENTE! Estoy en una situación de riesgo. Mi ubicación: {ubicacion}',
    'Necesito ayuda por favor. Esta es mi ubicación exacta: {ubicacion}',
  ];
}

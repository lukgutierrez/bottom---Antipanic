import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/panic_service.dart';

class WhatsAppSelector extends StatelessWidget {
  final List<String> contacts;
  final PanicService panicService;
  final String messageTemplate;

  const WhatsAppSelector({
    super.key,
    required this.contacts,
    required this.panicService,
    required this.messageTemplate,
  });

  Future<void> _sendWithLocation(BuildContext context, String contact) async {
    final position = await panicService.getLocation();
    if (position == null) return;

    final locationUrl = panicService.buildLocationUrl(position);
    final message = panicService.buildFinalMessage(messageTemplate, locationUrl);
    final phone = panicService.extractNumber(contact);

    if (context.mounted) {
      Navigator.pop(context);
      await panicService.openWhatsApp(phone, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.send, color: Color(0xFF128C7E), size: 24),
              SizedBox(width: 10),
              Text(
                "Enviar ubicación por WhatsApp",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Elige el contacto al que deseas avisar en este momento:",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: contacts.length,
            itemBuilder: (ctx, i) {
              final name = panicService.extractName(contacts[i]);
              final phone = panicService.extractNumber(contacts[i]);
              return Card(
                color: AppTheme.darkCard,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF128C7E),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    phone,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white54,
                    size: 16,
                  ),
                  onTap: () => _sendWithLocation(context, contacts[i]),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

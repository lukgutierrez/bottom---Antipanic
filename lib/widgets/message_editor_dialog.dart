import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../services/panic_service.dart';

class MessageEditorDialog extends StatefulWidget {
  final PanicService panicService;
  final String currentMessage;
  final VoidCallback onSaved;

  const MessageEditorDialog({
    super.key,
    required this.panicService,
    required this.currentMessage,
    required this.onSaved,
  });

  @override
  State<MessageEditorDialog> createState() => _MessageEditorDialogState();
}

class _MessageEditorDialogState extends State<MessageEditorDialog> {
  late TextEditingController _controller;
  int? _selectedTemplateIndex;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentMessage);
    _detectTemplate();
  }

  void _detectTemplate() {
    for (int i = 0; i < AppConstants.messageTemplates.length; i++) {
      if (_controller.text == AppConstants.messageTemplates[i]) {
        _selectedTemplateIndex = i;
        return;
      }
    }
    _selectedTemplateIndex = null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectTemplate(int index) {
    setState(() {
      _selectedTemplateIndex = index;
      _controller.text = AppConstants.messageTemplates[index];
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _snack("⚠️ El mensaje no puede estar vacío", isError: true);
      return;
    }
    if (!text.contains(AppConstants.locationPlaceholder)) {
      _snack(
        "⚠️ El mensaje debe contener {ubicacion} para que se agregue el link de Maps",
        isError: true,
      );
      return;
    }
    await widget.panicService.saveCustomMessage(text);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
    _snack("✅ Mensaje guardado");
  }

  void _snack(String msg, {bool isError = false}) {
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
    return Dialog(
      backgroundColor: AppTheme.darkAppBar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
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
                  const Text(
                    "Mensaje de Alerta",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                "Elegí un mensaje o escribí el tuyo propio.\n{ubicacion} se reemplazará automáticamente con el link de Google Maps.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // Templates
              const Text(
                "Mensajes predefinidos:",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(AppConstants.messageTemplates.length, (i) {
                final isSelected = _selectedTemplateIndex == i;
                final preview = AppConstants.messageTemplates[i]
                    .replaceAll(AppConstants.locationPlaceholder, "maps.google.com/?q=...");
                return GestureDetector(
                  onTap: () => _selectTemplate(i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withValues(alpha: 0.2) : AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.blueAccent : Colors.white12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? Colors.blueAccent : Colors.white38,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            preview,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 15),

              // Custom editor
              const Text(
                "O escribí tu propio mensaje:",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Ej: ¡AYUDA! Estoy en {ubicacion}",
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.darkCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (_) {
                  setState(() => _selectedTemplateIndex = null);
                },
              ),
              const SizedBox(height: 5),
              const Text(
                "Usá {ubicacion} donde quieras que aparezca el link de Maps",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _save,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text(
                    "GUARDAR MENSAJE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../services/panic_service.dart';

class ContactManagerDialog extends StatefulWidget {
  final List<String> contacts;
  final PanicService panicService;
  final VoidCallback onChanged;

  const ContactManagerDialog({
    super.key,
    required this.contacts,
    required this.panicService,
    required this.onChanged,
  });

  @override
  State<ContactManagerDialog> createState() => _ContactManagerDialogState();
}

class _ContactManagerDialogState extends State<ContactManagerDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _addContact(StateSetter setDialogState) {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _snack("⚠️ Ingresa Nombre y Número", isError: true);
      return;
    }

    if (widget.contacts.length >= AppConstants.maxContacts) {
      _snack("⚠️ Máximo ${AppConstants.maxContacts} contactos", isError: true);
      return;
    }

    final formatted = widget.panicService.formatNumber(phone);
    final contact = "$name - $formatted";
    final updated = [...widget.contacts, contact];

    widget.panicService.saveContacts(updated);
    _nameCtrl.clear();
    _phoneCtrl.clear();
    setDialogState(() {});
    widget.onChanged();
    _snack("✅ Guardado: $contact");
  }

  void _deleteContact(int index, StateSetter setDialogState) {
    final updated = List<String>.from(widget.contacts)..removeAt(index);
    widget.panicService.saveContacts(updated);
    widget.onChanged();
    setDialogState(() {});
    _snack("🗑️ Contacto eliminado.");
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
    return StatefulBuilder(
      builder: (context, setDialogState) {
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
                      Text(
                        "Mis Contactos (Máx. ${AppConstants.maxContacts})",
                        style: const TextStyle(
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
                    "Agrega el nombre y el número de tu contacto de confianza.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),

                  if (widget.contacts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "No hay contactos aún.\nAgrega el primero abajo 👇",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.contacts.length,
                      itemBuilder: (ctx, i) {
                        final name = widget.panicService.extractName(widget.contacts[i]);
                        final phone = widget.panicService.extractNumber(widget.contacts[i]);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Colors.green,
                                    radius: 18,
                                    child: Icon(Icons.person, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: AppTheme.contactNameStyle),
                                      Text(phone, style: AppTheme.contactNumberStyle),
                                    ],
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                tooltip: "Eliminar",
                                onPressed: () => _deleteContact(i, setDialogState),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 20),

                  if (widget.contacts.length < AppConstants.maxContacts) ...[
                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: "Nombre (Ej: Mamá, Hermano)",
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: AppTheme.darkCard,
                        prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: "Número (Ej: 387696...)",
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: AppTheme.darkCard,
                        prefixIcon: const Icon(Icons.phone, color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _addContact(setDialogState),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          "AGREGAR CONTACTO",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
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
    );
  }
}
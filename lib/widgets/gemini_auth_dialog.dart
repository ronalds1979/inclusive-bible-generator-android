import 'package:flutter/material.dart';
import '../generator.dart';

class GeminiAuthDialog extends StatefulWidget {
  final String lang;
  final Generator generator;
  final String? initialApiKey;
  final Future<void> Function(String apiKey) onSave;
  final Future<void> Function() onDisconnect;

  const GeminiAuthDialog({
    super.key,
    required this.lang,
    required this.generator,
    required this.initialApiKey,
    required this.onSave,
    required this.onDisconnect,
  });

  @override
  State<GeminiAuthDialog> createState() => _GeminiAuthDialogState();
}

class _GeminiAuthDialogState extends State<GeminiAuthDialog> {
  late final TextEditingController _keyController;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.initialApiKey ?? "");
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String lang = widget.lang;
    final Generator generator = widget.generator;
    final bool hasExistingKey =
        widget.initialApiKey != null && widget.initialApiKey!.isNotEmpty;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_awesome),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              generator.getLocaleString(lang, "gemini_dialog_title"),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(generator.getLocaleString(lang, "gemini_dialog_hint")),
            const SizedBox(height: 12),
            TextField(
              controller: _keyController,
              obscureText: _obscure,
              maxLength: 256,
              decoration: InputDecoration(
                labelText: generator.getLocaleString(
                  lang,
                  "gemini_api_key_label",
                ),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: generator.getLocaleString(
                    lang,
                    _obscure
                        ? "gemini_show_key_tooltip"
                        : "gemini_hide_key_tooltip",
                  ),
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscure = !(_obscure);
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (hasExistingKey)
          TextButton(
            onPressed: () async {
              await widget.onDisconnect();
              if (context.mounted) {
                Navigator.of(context).pop(false);
              }
            },
            child: Text(
              generator.getLocaleString(lang, "gemini_disconnect_btn"),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(generator.getLocaleString(lang, "gemini_cancel_btn")),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: Text(generator.getLocaleString(lang, "gemini_save_btn")),
          onPressed: () async {
            final String entered = _keyController.text.trim();
            await widget.onSave(entered);
            if (context.mounted) {
              Navigator.of(context).pop(entered.isNotEmpty);
            }
          },
        ),
      ],
    );
  }
}

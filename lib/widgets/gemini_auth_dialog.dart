import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../gemini_service.dart';
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
  bool _detectedFromClipboard = false;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.initialApiKey ?? "");
    if (_keyController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkClipboardForKey(autoConnectIfFound: false);
      });
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _checkClipboardForKey({required bool autoConnectIfFound}) async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      final String? detectedKey = GeminiService.extractApiKeyFromText(
        data?.text,
      );
      if (detectedKey != null && mounted) {
        setState(() {
          _keyController.text = detectedKey;
          _detectedFromClipboard = true;
        });
        if (autoConnectIfFound) {
          await widget.onSave(detectedKey);
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _openGoogleAiStudio() async {
    final Uri uri = Uri.parse(GeminiService.aiStudioUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
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
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _openGoogleAiStudio,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  generator.getLocaleString(lang, "gemini_open_aistudio_btn"),
                ),
              ),
            ),
            if (_detectedFromClipboard) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        generator.getLocaleString(
                          lang,
                          "gemini_clipboard_detected_msg",
                        ),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _keyController,
              obscureText: _obscure,
              maxLength: 256,
              decoration: InputDecoration(
                counterText: "",
                labelText: generator.getLocaleString(
                  lang,
                  "gemini_api_key_label",
                ),
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.content_paste),
                      tooltip: generator.getLocaleString(
                        lang,
                        "gemini_paste_clipboard_btn",
                      ),
                      onPressed: () =>
                          _checkClipboardForKey(autoConnectIfFound: false),
                    ),
                    IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscure = !_obscure;
                        });
                      },
                    ),
                  ],
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
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _keyController,
          builder: (context, value, child) {
            final bool canSave = value.text.trim().isNotEmpty;
            return ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: Text(generator.getLocaleString(lang, "gemini_save_btn")),
              onPressed: canSave
                  ? () async {
                      final String entered = _keyController.text.trim();
                      await widget.onSave(entered);
                      if (context.mounted) {
                        Navigator.of(context).pop(entered.isNotEmpty);
                      }
                    }
                  : null,
            );
          },
        ),
      ],
    );
  }
}

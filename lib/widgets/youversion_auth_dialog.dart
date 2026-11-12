import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../getbible_api.dart';
import '../generator.dart';

class YouVersionAuthDialog extends StatefulWidget {
  final String lang;
  final Generator generator;
  final String? initialApiKey;
  final Future<void> Function(String apiKey) onSave;
  final Future<void> Function() onDisconnect;

  const YouVersionAuthDialog({
    super.key,
    required this.lang,
    required this.generator,
    required this.initialApiKey,
    required this.onSave,
    required this.onDisconnect,
  });

  @override
  State<YouVersionAuthDialog> createState() => _YouVersionAuthDialogState();
}

class _YouVersionAuthDialogState extends State<YouVersionAuthDialog> {
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

  Future<void> _pasteFromClipboard() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      final String? text = data?.text?.trim();
      if (text != null && text.isNotEmpty && mounted) {
        setState(() {
          _keyController.text = text;
        });
      }
    } catch (_) {}
  }

  Future<void> _openYouVersionPortal() async {
    final Uri uri = Uri.parse(GetBibleAPI.youVersionPortalUrl);
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
          const Icon(Icons.menu_book),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              generator.getLocaleString(lang, "yv_dialog_title"),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(generator.getLocaleString(lang, "yv_dialog_hint")),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _openYouVersionPortal,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  generator.getLocaleString(lang, "yv_open_portal_btn"),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.content_paste, size: 18),
                label: Text(
                  generator.getLocaleString(lang, "gemini_paste_clipboard_btn"),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyController,
              obscureText: _obscure,
              maxLength: 256,
              decoration: InputDecoration(
                labelText: generator.getLocaleString(
                  lang,
                  "yv_api_key_label",
                ),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscure = !_obscure;
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

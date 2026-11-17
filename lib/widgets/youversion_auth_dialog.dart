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
  bool _pastedFromClipboard = false;
  bool _clipboardEmpty = false;

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
      final String? normalized = GetBibleAPI.normalizeYouVersionApiKey(data?.text);
      if (!mounted) return;
      if (normalized != null) {
        setState(() {
          _keyController.text = normalized;
          _pastedFromClipboard = true;
          _clipboardEmpty = false;
        });
      } else {
        setState(() {
          _pastedFromClipboard = false;
          _clipboardEmpty = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pastedFromClipboard = false;
          _clipboardEmpty = true;
        });
      }
    }
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
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
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
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.content_paste, size: 18),
                label: Text(
                  generator.getLocaleString(lang, "gemini_paste_clipboard_btn"),
                ),
              ),
            ),
            if (_pastedFromClipboard || _clipboardEmpty) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _pastedFromClipboard
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _pastedFromClipboard
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _pastedFromClipboard
                            ? Icons.check_circle
                            : Icons.info_outline,
                        color: _pastedFromClipboard
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onErrorContainer,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          generator.getLocaleString(
                            lang,
                            _pastedFromClipboard
                                ? "yv_clipboard_detected_msg"
                                : "yv_clipboard_empty_msg",
                          ),
                          style: TextStyle(
                            color: _pastedFromClipboard
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  "yv_api_key_label",
                ),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  tooltip: generator.getLocaleString(
                    lang,
                    _obscure ? "show_api_key_tooltip" : "hide_api_key_tooltip",
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
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
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
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(generator.getLocaleString(lang, "gemini_cancel_btn")),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _keyController,
          builder: (context, value, child) {
            final bool canSave =
                GetBibleAPI.normalizeYouVersionApiKey(value.text) != null;
            return ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.check),
              label: Text(generator.getLocaleString(lang, "gemini_save_btn")),
              onPressed: canSave
                  ? () async {
                      final String? normalized =
                          GetBibleAPI.normalizeYouVersionApiKey(
                            _keyController.text,
                          );
                      if (normalized == null) return;
                      await widget.onSave(normalized);
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
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

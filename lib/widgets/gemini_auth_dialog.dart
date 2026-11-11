import 'package:flutter/material.dart';
import '../generator.dart';

class GeminiAuthDialog extends StatefulWidget {
  final String lang;
  final Generator generator;
  final String? userEmail;
  final bool isSignedIn;
  final Future<bool> Function() onSignIn;
  final Future<void> Function() onSignOut;

  const GeminiAuthDialog({
    super.key,
    required this.lang,
    required this.generator,
    required this.userEmail,
    required this.isSignedIn,
    required this.onSignIn,
    required this.onSignOut,
  });

  @override
  State<GeminiAuthDialog> createState() => _GeminiAuthDialogState();
}

class _GeminiAuthDialogState extends State<GeminiAuthDialog> {
  bool _isAuthenticating = false;

  @override
  Widget build(BuildContext context) {
    final String lang = widget.lang;
    final Generator generator = widget.generator;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.account_circle),
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
            if (widget.isSignedIn &&
                widget.userEmail != null &&
                widget.userEmail!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.verified_user, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      generator.getLocaleString(
                        lang,
                        "gemini_signed_in_as",
                        kwargs: {"email": widget.userEmail!},
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.isSignedIn)
          TextButton.icon(
            icon: const Icon(Icons.logout),
            onPressed: _isAuthenticating
                ? null
                : () async {
                    await widget.onSignOut();
                    if (context.mounted) {
                      Navigator.of(context).pop(false);
                    }
                  },
            label: Text(
              generator.getLocaleString(lang, "gemini_disconnect_btn"),
            ),
          ),
        TextButton(
          onPressed: _isAuthenticating
              ? null
              : () => Navigator.of(context).pop(widget.isSignedIn),
          child: Text(generator.getLocaleString(lang, "gemini_cancel_btn")),
        ),
        if (!widget.isSignedIn)
          ElevatedButton.icon(
            icon: _isAuthenticating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(generator.getLocaleString(lang, "gemini_sign_in_btn")),
            onPressed: _isAuthenticating
                ? null
                : () async {
                    setState(() {
                      _isAuthenticating = true;
                    });
                    final bool success = await widget.onSignIn();
                    if (!context.mounted) return;
                    setState(() {
                      _isAuthenticating = false;
                    });
                    if (success) {
                      Navigator.of(context).pop(true);
                    }
                  },
          ),
      ],
    );
  }
}

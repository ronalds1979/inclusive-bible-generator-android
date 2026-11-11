import 'package:flutter/material.dart';
import '../gemini_service.dart';
import '../generator.dart';

class GeminiBackgroundCard extends StatelessWidget {
  final String lang;
  final Generator generator;
  final bool isConnected;
  final String selectedStyle;
  final ValueChanged<String> onStyleChanged;
  final TextEditingController promptController;
  final TextEditingController verseController;
  final bool isGenerating;
  final VoidCallback onConnectPressed;
  final VoidCallback onGeneratePressed;

  const GeminiBackgroundCard({
    super.key,
    required this.lang,
    required this.generator,
    required this.isConnected,
    required this.selectedStyle,
    required this.onStyleChanged,
    required this.promptController,
    required this.verseController,
    required this.isGenerating,
    required this.onConnectPressed,
    required this.onGeneratePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Icon(Icons.auto_awesome, size: 20),
                Text(
                  generator.getLocaleString(lang, "gemini_section_title"),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                OutlinedButton.icon(
                  onPressed: onConnectPressed,
                  icon: Icon(
                    isConnected ? Icons.verified_user : Icons.key,
                    size: 16,
                  ),
                  label: Text(
                    generator.getLocaleString(
                      lang,
                      isConnected
                          ? "gemini_connected_btn"
                          : "gemini_connect_btn",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                Text(generator.getLocaleString(lang, "gemini_style_label")),
                DropdownButton<String>(
                  value: selectedStyle,
                  items: GeminiService.styleKeys.map((styleKey) {
                    return DropdownMenuItem<String>(
                      value: styleKey,
                      child: Text(generator.getLocaleString(lang, styleKey)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) onStyleChanged(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: promptController,
              builder: (context, value, child) {
                return TextField(
                  controller: promptController,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: generator.getLocaleString(
                      lang,
                      "gemini_prompt_label",
                    ),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: generator.getLocaleString(
                              lang,
                              "clear_btn",
                            ),
                            onPressed: promptController.clear,
                          )
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: verseController,
              builder: (context, verseValue, child) {
                return ElevatedButton.icon(
                  onPressed: isGenerating || verseValue.text.trim().isEmpty
                      ? null
                      : onGeneratePressed,
                  icon: isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    generator.getLocaleString(lang, "gemini_generate_bg_btn"),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

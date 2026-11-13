import 'package:flutter/material.dart';
import '../gemini_service.dart';
import '../generator.dart';

class GeminiBackgroundCard extends StatefulWidget {
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
  State<GeminiBackgroundCard> createState() => _GeminiBackgroundCardState();
}

class _GeminiBackgroundCardState extends State<GeminiBackgroundCard> {
  late bool _showExtraDetails;

  @override
  void initState() {
    super.initState();
    _showExtraDetails = widget.promptController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final String lang = widget.lang;
    final Generator generator = widget.generator;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    generator.getLocaleString(lang, "gemini_section_title"),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onConnectPressed,
                  icon: Icon(
                    widget.isConnected ? Icons.verified_user : Icons.key,
                    size: 16,
                    color: widget.isConnected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  label: Text(
                    generator.getLocaleString(
                      lang,
                      widget.isConnected
                          ? "gemini_connected_btn"
                          : "gemini_connect_btn",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              generator.getLocaleString(lang, "gemini_style_label"),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GeminiService.styleKeys.map((styleKey) {
                final bool isSelected = widget.selectedStyle == styleKey;
                return ChoiceChip(
                  label: Text(generator.getLocaleString(lang, styleKey)),
                  selected: isSelected,
                  onSelected: (_) => widget.onStyleChanged(styleKey),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topLeft,
              child: !_showExtraDetails
                  ? TextButton.icon(
                      onPressed: () => setState(() => _showExtraDetails = true),
                      icon: const Icon(Icons.tune, size: 16),
                      label: Text(
                        generator.getLocaleString(
                          lang,
                          "gemini_add_details_btn",
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.promptController,
                        builder: (context, value, child) {
                          return TextField(
                            controller: widget.promptController,
                            maxLength: 200,
                            decoration: InputDecoration(
                              isDense: true,
                              counterText: "",
                              labelText: generator.getLocaleString(
                                lang,
                                "gemini_prompt_label",
                              ),
                              border: const OutlineInputBorder(),
                              suffixIcon: value.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      tooltip: generator.getLocaleString(
                                        lang,
                                        "clear_btn",
                                      ),
                                      onPressed: widget.promptController.clear,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.verseController,
              builder: (context, verseValue, child) {
                final bool isVerseEmpty = verseValue.text.trim().isEmpty;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: widget.isGenerating || isVerseEmpty
                          ? null
                          : widget.onGeneratePressed,
                      icon: widget.isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        generator.getLocaleString(
                          lang,
                          "gemini_generate_bg_btn",
                        ),
                      ),
                    ),
                    if (isVerseEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          generator.getLocaleString(
                            lang,
                            "gemini_verse_required_hint",
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:app/generator.dart';

void main() {
  group('Generator generateTexts tests', () {
    late Generator generator;

    setUp(() {
      generator = Generator();
      generator.locales = {
        "en": {
          "default_description": "Default English Description",
          "alt_text_template": "{description}. Verse: {verse}. Ref: {reference}",
          "caption_template": "Caption: {verse} - {reference}"
        },
        "pt-BR": {
          "default_description": "Descrição Padrão",
          "alt_text_template": "{description}. Verso: {verse}. Ref: {reference}",
          "caption_template": "Legenda: {verse} - {reference}"
        },
      };
    });

    test('generateTexts English (en) happy path', () async {
      final result = await generator.generateTexts("en", "Jesus wept.", "John 11:35");
      expect(result["altText"], "Default English Description. Verse: Jesus wept.. Ref: John 11:35");
      expect(result["caption"], "Caption: Jesus wept. - John 11:35");
    });

    test('generateTexts Portuguese (pt-BR) happy path', () async {
      final result = await generator.generateTexts("pt-BR", "Jesus chorou.", "João 11:35");
      expect(result["altText"], "Descrição Padrão. Verso: Jesus chorou.. Ref: João 11:35");
      expect(result["caption"], "Legenda: Jesus chorou. - João 11:35");
    });

    test('generateTexts fallback to pt-BR for unknown language', () async {
      // The generator falls back to "pt-BR" if the language is not in the map
      final result = await generator.generateTexts("fr", "Jesus chorou.", "João 11:35");
      expect(result["altText"], "Descrição Padrão. Verso: Jesus chorou.. Ref: João 11:35");
      expect(result["caption"], "Legenda: Jesus chorou. - João 11:35");
    });

    test('generateTexts language normalization', () async {
      // The generator normalizes "English (US/UK)" to "en"
      final result = await generator.generateTexts("English (US/UK)", "Jesus wept.", "John 11:35");
      expect(result["altText"], "Default English Description. Verse: Jesus wept.. Ref: John 11:35");
      expect(result["caption"], "Caption: Jesus wept. - John 11:35");
    });
  });
}

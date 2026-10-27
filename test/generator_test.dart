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

    test('generateTexts missing locale keys', () async {
      generator.locales = {
        "en": {
          "other_key": "some value"
        }
      };
      final result = await generator.generateTexts("en", "verse", "ref");
      expect(result["altText"], "");
      expect(result["caption"], "");
    });

    test('generateTexts with empty verse and reference', () async {
      final result = await generator.generateTexts("en", "", "");
      expect(result["altText"], "Default English Description. Verse: . Ref: ");
      expect(result["caption"], "Caption:  - ");
    });

    test('generateTexts with empty locales map', () async {
      generator.locales = {};
      final result = await generator.generateTexts("en", "verse", "ref");
      expect(result["altText"], "");
      expect(result["caption"], "");
    });
  });

  group('Generator getLocaleString tests', () {
    late Generator generator;

    setUp(() {
      generator = Generator();
      generator.locales = {
        "en": {
          "greeting": "Hello",
          "greeting_name": "Hello, {name}!"
        },
        "pt-BR": {
          "greeting": "Olá",
          "greeting_name": "Olá, {name}!"
        },
      };
    });

    test('getLocaleString direct translation extraction without kwargs', () {
      final result = generator.getLocaleString("en", "greeting");
      expect(result, "Hello");
    });

    test('getLocaleString string interpolation using kwargs', () {
      final result = generator.getLocaleString("en", "greeting_name", kwargs: {"name": "World"});
      expect(result, "Hello, World!");
    });

    test('getLocaleString fallback when key does not exist', () {
      final result = generator.getLocaleString("en", "missing_key");
      expect(result, "");
    });

    test('getLocaleString language normalization and fallback to pt-BR', () {
      // Normalizes "Português" to "pt-BR"
      final result1 = generator.getLocaleString("Português", "greeting");
      expect(result1, "Olá");

      // Normalizes "English (US/UK)" to "en"
      final result2 = generator.getLocaleString("English (US/UK)", "greeting");
      expect(result2, "Hello");

      // Normalizes "Español (España)" to "es", which is missing, so it falls back to "pt-BR"
      final result3 = generator.getLocaleString("Español (España)", "greeting");
      expect(result3, "Olá");

      // Unknown language falls back to "pt-BR"
      final result4 = generator.getLocaleString("fr", "greeting");
      expect(result4, "Olá");
    });
  });
}

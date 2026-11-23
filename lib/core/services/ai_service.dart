import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// AI provider abstraction. The user configures any OpenAI-compatible
/// endpoint (base URL, API key, model) inside the app. No API keys are
/// hardcoded or shipped with the app. When unconfigured, the app shows an
/// honest configuration screen instead of pretending AI works.
class AiConfig {
  final String baseUrl;
  final String apiKey;
  final String model;
  const AiConfig(
      {required this.baseUrl, required this.apiKey, required this.model});
  bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty && model.isNotEmpty;
}

class AiService {
  static const _kBase = 'ai_base_url';
  static const _kKey = 'ai_api_key';
  static const _kModel = 'ai_model';

  Future<AiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AiConfig(
      baseUrl: prefs.getString(_kBase) ?? '',
      apiKey: prefs.getString(_kKey) ?? '',
      model: prefs.getString(_kModel) ?? '',
    );
  }

  Future<void> save(AiConfig c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBase, c.baseUrl);
    await prefs.setString(_kKey, c.apiKey);
    await prefs.setString(_kModel, c.model);
  }

  static const styles = <String, String>{
    'quick': 'Quick summary',
    'detailed': 'Detailed summary',
    'key_ideas': 'Key ideas',
    'lessons': 'Actionable lessons',
    'study_notes': 'Study notes',
    'qa': 'Questions & answers',
  };

  String _prompt(String style, String lang) {
    final ar = lang == 'ar';
    final task = switch (style) {
      'quick' => ar ? 'لخّص النص التالي باختصار شديد.' : 'Summarize the following text very briefly.',
      'detailed' => ar ? 'لخّص النص التالي بتفصيل مع الحفاظ على ترتيب الأفكار.' : 'Summarize the following text in detail, preserving the order of ideas.',
      'key_ideas' => ar ? 'استخرج الأفكار الرئيسية من النص التالي كنقاط.' : 'Extract the key ideas from the following text as bullet points.',
      'lessons' => ar ? 'استخرج دروساً عملية قابلة للتطبيق من النص التالي.' : 'Extract actionable lessons from the following text.',
      'study_notes' => ar ? 'حوّل النص التالي إلى ملاحظات دراسية منظمة بعناوين.' : 'Turn the following text into structured study notes with headings.',
      'qa' => ar ? 'أنشئ أسئلة وإجابات للمراجعة من النص التالي.' : 'Create review questions and answers from the following text.',
      _ => ar ? 'لخّص النص التالي.' : 'Summarize the following text.',
    };
    final guard = ar
        ? 'اعتمد فقط على النص المقدم، ولا تخترع محتوى غير موجود فيه.'
        : 'Rely only on the provided text; do not invent content that is not in it.';
    return '$task $guard';
  }

  /// Generates a summary of [text]. Throws with a readable message on
  /// network/provider errors — never fabricates a result.
  Future<String> summarize({
    required String text,
    required String style,
    required String lang,
  }) async {
    final config = await load();
    if (!config.isConfigured) {
      throw StateError('AI provider is not configured');
    }
    final trimmed = text.length > 12000 ? text.substring(0, 12000) : text;
    final uri = Uri.parse(
        '${config.baseUrl.replaceAll(RegExp(r'/$'), '')}/chat/completions');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.apiKey}',
          },
          body: jsonEncode({
            'model': config.model,
            'messages': [
              {'role': 'system', 'content': _prompt(style, lang)},
              {'role': 'user', 'content': trimmed},
            ],
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw StateError('Provider error ${res.statusCode}: ${res.body}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final content =
        (((decoded['choices'] as List).first as Map)['message'] as Map)['content']
            as String;
    return content.trim();
  }
}

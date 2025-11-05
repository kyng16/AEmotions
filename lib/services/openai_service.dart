import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class OpenAIService {
  OpenAIService({
    String? apiKey,
    String? chatModel,
    String? sttModel,
    String? ttsModel,
  })  : apiKey = apiKey ?? (const String.fromEnvironment('OPENAI_API_KEY').isNotEmpty
            ? const String.fromEnvironment('OPENAI_API_KEY')
            : (Platform.environment['OPENAI_API_KEY'] ?? '')),
        chatModel = chatModel ?? const String.fromEnvironment('OPENAI_MODEL', defaultValue: 'gpt-4.1'),
        sttModel = sttModel ?? const String.fromEnvironment('OPENAI_STT_MODEL', defaultValue: 'whisper-1'),
        ttsModel = ttsModel ?? const String.fromEnvironment('OPENAI_TTS_MODEL', defaultValue: 'tts-1'),
        backendUrl = const String.fromEnvironment('BACKEND_URL', defaultValue: '')
            .isNotEmpty
            ? const String.fromEnvironment('BACKEND_URL')
            : (Platform.environment['BACKEND_URL'] ?? '');

  final String apiKey;
  final String chatModel;
  final String sttModel;
  final String ttsModel;
  final String backendUrl;

  static const _baseUrl = 'https://api.openai.com/v1';

  Map<String, String> get _headers => {
        HttpHeaders.authorizationHeader: 'Bearer $apiKey',
      };

  void _ensureApiKey() {
    if (apiKey.isEmpty) {
      throw StateError('Brak OPENAI_API_KEY. Uruchom z --dart-define=OPENAI_API_KEY=...');
    }
  }

  /// Send a chat completion request. `messages` is a list of maps with roles: 'system'|'user'|'assistant'.
  Future<String> chat(List<Map<String, String>> messages, {double temperature = 0.7}) async {
    if (backendUrl.isNotEmpty) {
      final res = await http.post(
        Uri.parse('$backendUrl/chat'),
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode({
          'messages': messages,
          'model': chatModel,
          'temperature': temperature,
        }),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['content'] ?? '').toString();
      }
      throw HttpException('Backend chat error: ${res.statusCode} ${res.body}');
    }

    _ensureApiKey();

    final uri = Uri.parse('$_baseUrl/chat/completions');
    final payload = {
      'model': chatModel,
      'messages': messages,
      'temperature': temperature,
    };

    final res = await http.post(
      uri,
      headers: {
        ..._headers,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final first = choices.first as Map<String, dynamic>;
        final message = first['message'] as Map<String, dynamic>?;
        final content = message?['content']?.toString() ?? '';
        return content;
      }
      return '';
    }

    throw HttpException('OpenAI chat error: ${res.statusCode} ${res.body}');
  }

  /// Transcribe an audio file using Whisper/STT.
  Future<String> transcribeAudio(File audioFile, {String? language}) async {
    if (backendUrl.isNotEmpty) {
      final req = http.MultipartRequest('POST', Uri.parse('$backendUrl/stt'))
        ..fields['language'] = language ?? '';
      final fileStream = http.ByteStream(audioFile.openRead());
      final fileLength = await audioFile.length();
      req.files.add(http.MultipartFile('file', fileStream, fileLength,
          filename: audioFile.path.split(Platform.pathSeparator).last));
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['text'] ?? '').toString();
      }
      throw HttpException('Backend STT error: ${res.statusCode} ${res.body}');
    }

    _ensureApiKey();

    final uri = Uri.parse('$_baseUrl/audio/transcriptions');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers)
      ..fields['model'] = sttModel;

    if (language != null && language.isNotEmpty) {
      req.fields['language'] = language;
    }

    final fileStream = http.ByteStream(audioFile.openRead());
    final fileLength = await audioFile.length();
    req.files.add(http.MultipartFile(
      'file',
      fileStream,
      fileLength,
      filename: audioFile.path.split(Platform.pathSeparator).last,
    ));

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      // Whisper returns { text: '...' }
      return (data['text'] ?? '').toString();
    }

    throw HttpException('OpenAI STT error: ${res.statusCode} ${res.body}');
  }

  /// Text-to-speech via OpenAI, returns MP3 bytes.
  Future<Uint8List> synthesizeSpeech(String text, {String voice = 'alloy', String format = 'mp3'}) async {
    if (backendUrl.isNotEmpty) {
      final res = await http.post(
        Uri.parse('$backendUrl/tts'),
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode({'text': text, 'voice': voice, 'format': format}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res.bodyBytes;
      }
      throw HttpException('Backend TTS error: ${res.statusCode} ${res.body}');
    }

    _ensureApiKey();

    final uri = Uri.parse('$_baseUrl/audio/speech');
    final payload = {
      'model': ttsModel,
      'voice': voice,
      'input': text,
      'format': format,
    };

    final res = await http.post(
      uri,
      headers: {
        ..._headers,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }

    throw HttpException('OpenAI TTS error: ${res.statusCode} ${res.body}');
  }
}

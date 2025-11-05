import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/openai_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  ChatMessage(this.role, this.content);
}

class _ChatPageState extends State<ChatPage> {
  final _service = OpenAIService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  bool _recording = false;
  bool _loading = false;

  final List<ChatMessage> _messages = [
    ChatMessage('assistant', 'Cześć! Jestem Twoim asystentem. Jak mogę pomóc?'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendText(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage('user', text.trim()));
      _loading = true;
    });
    _controller.clear();
    await _scrollToBottom();

    try {
      final msgs = _messages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      final reply = await _service.chat(msgs);

      setState(() {
        _messages.add(ChatMessage('assistant', reply.isEmpty ? '(brak odpowiedzi)' : reply));
      });
      await _scrollToBottom();

      // Auto TTS of assistant reply
      if (reply.isNotEmpty) {
        final bytes = await _service.synthesizeSpeech(reply);
        await _player.play(BytesSource(bytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      // Stop and transcribe
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path == null) return;
      try {
        final file = File(path);
        final text = await _service.transcribeAudio(file, language: 'pl');
        if (text.trim().isEmpty) return;
        // Auto send the transcribed text
        await _sendText(text);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd transkrypcji: $e')),
          );
        }
      }
      return;
    }

    // Start recording
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brak uprawnień do mikrofonu')),
        );
      }
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
    setState(() => _recording = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat (OpenAI)')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isUser = m.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m.content),
                  ),
                );
              },
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _toggleRecord,
                    icon: Icon(_recording ? Icons.stop_circle : Icons.mic),
                    color: _recording ? Colors.red : null,
                    tooltip: _recording ? 'Zatrzymaj nagrywanie' : 'Nagraj i wyślij',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendText,
                      decoration: const InputDecoration(
                        hintText: 'Napisz wiadomość... (lub użyj mikrofonu)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _sendText(_controller.text),
                    icon: const Icon(Icons.send),
                    tooltip: 'Wyślij',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

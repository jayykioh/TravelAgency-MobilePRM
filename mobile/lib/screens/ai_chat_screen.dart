import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';

/// Chat UI calls only the existing Next.js API; no AI key is stored in Flutter.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final input = TextEditingController();
  final messages = <Map<String, String>>[];
  bool busy = false;
  String? error;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> send([String? suggestion]) async {
    final text = (suggestion ?? input.text).trim();
    if (text.isEmpty || busy) return;
    setState(() {
      messages.add({'role': 'user', 'content': text});
      input.clear();
      busy = true;
      error = null;
    });
    try {
      final answer = await context.read<HotelState>().service.sendChat(
        messages,
      );
      if (mounted) {
        setState(
          () => messages.add({
            'role': 'assistant',
            'content': answer.isEmpty
                ? 'Không nhận được nội dung trả lời.'
                : answer,
          }),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TripC AI Assistant')),
    body: Column(
      children: [
        if (messages.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF5E1F), Color(0xFFF59E0B)],
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'How can I help your journey?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children:
                          [
                                'Find hotels nearby',
                                'Suggest a hotel in Đà Nẵng',
                                'Explain my booking',
                              ]
                              .map(
                                (value) => ActionChip(
                                  label: Text(value),
                                  onPressed: () => send(value),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final item = messages[index];
                final mine = item['role'] == 'user';
                return Align(
                  alignment: mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    constraints: const BoxConstraints(maxWidth: 560),
                    decoration: BoxDecoration(
                      color: mine ? const Color(0xFFFF5E1F) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item['content']!,
                      style: TextStyle(color: mine ? Colors.white : null),
                    ),
                  ),
                );
              },
            ),
          ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    onSubmitted: (_) => send(),
                    decoration: InputDecoration(
                      hintText: 'Ask TripC AI…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: busy ? null : send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

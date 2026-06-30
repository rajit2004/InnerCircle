import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/persona.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final Persona persona;
  const ChatScreen({super.key, required this.persona});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;
  String? _conversationId;

  void _sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: content));
      _isTyping = true;
    });

    try {
      final stream = await ChatService.sendMessage(
        widget.persona.id,
        content,
        conversationId: _conversationId,
      );

      String fullReply = '';
      bool firstChunk = true;

      await for (String chunk in stream) {
        try {
          final json = Map<String, dynamic>.from(jsonDecode(chunk));
          if (json['content'] != null) {
            fullReply += json['content'];
            if (firstChunk) {
              setState(() {
                _messages.add(ChatMessage(role: 'assistant', content: ''));
                firstChunk = false;
              });
            }
            setState(() {
              _messages.last = ChatMessage(role: 'assistant', content: fullReply);
            });
          }
          if (json['done'] == true) {
            if (json['conversationId'] != null) {
              _conversationId = json['conversationId'];
            }
            setState(() => _isTyping = false);
            break;
          }
        } catch (e) {
          // ignore parse errors
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _isTyping = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.persona.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              // Option to clear conversation
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final msg = _messages[index];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Align(
                    alignment: msg.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: msg.role == 'user' ? Colors.blue[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg.content),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/persona.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final Persona persona;
  const ChatScreen({super.key, required this.persona});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    final greeting = widget.persona.greeting?.trim();
    if (greeting != null && greeting.isNotEmpty) {
      _messages.add(ChatMessage(role: 'assistant', content: greeting));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isTyping) return;

    final content = _controller.text.trim();
    if (content.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: content));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await ChatService.sendMessage(
        widget.persona.id,
        content,
        conversationId: _conversationId,
      );

      final reply = (response['reply'] as String? ?? '').trim();
      final conversationId = response['conversationId'] as String?;

      if (!mounted) return;
      setState(() {
        if (conversationId != null && conversationId.isNotEmpty) {
          _conversationId = conversationId;
        }
        if (reply.isNotEmpty) {
          _messages.add(ChatMessage(role: 'assistant', content: reply));
        }
        _isTyping = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTyping = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      final greeting = widget.persona.greeting?.trim();
      if (greeting != null && greeting.isNotEmpty) {
        _messages.add(ChatMessage(role: 'assistant', content: greeting));
      }
      _conversationId = null;
      _isTyping = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.contains('No static resource api/chat/sync')) {
      return 'The app was still calling the old chat endpoint. I changed it to /api/chat.';
    }
    return text.isEmpty
        ? 'Something went wrong while sending the message.'
        : text;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.persona.name),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_outline),
            onPressed: _messages.isEmpty && _conversationId == null
                ? null
                : _clearConversation,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isTyping && index == _messages.length) {
                    return _TypingBubble(
                      color: colorScheme.surfaceContainerHighest,
                    );
                  }

                  return _MessageBubble(message: _messages[index]);
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    icon: const Icon(Icons.send),
                    onPressed: _isTyping ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final colorScheme = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: isUser
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  final Color color;

  const _TypingBubble({required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

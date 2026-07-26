import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/persona.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/persona_avatar.dart';

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
  bool _loadingHistory = true;
  String? _conversationId;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    // BUG FIX (chat history, 2026-07-02): initState used to just add the
    // persona's greeting and stop there -- every screen open/close cycle
    // started completely fresh with no memory of past messages, and no
    // conversationId either, which meant the backend created a brand new
    // Conversation on the very next message. That's also why in-chat style
    // instructions (e.g. "reply shorter") appeared to reset on reopen: they
    // weren't forgotten, they were sitting in an orphaned conversation this
    // new session never loaded. See bugs.md and ChatService.getHistory() for
    // the full story. Now we fetch the most recent conversation for this
    // persona first, and only fall back to greeting-only if there isn't one.
    _loadHistory();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ChatService.getHistory(widget.persona.id);
      final conversationId = history['conversationId'] as String?;
      final rawMessages = (history['messages'] as List<dynamic>? ?? []);

      if (!mounted) return;

      if (conversationId == null || rawMessages.isEmpty) {
        _showGreetingOnly();
        return;
      }

      setState(() {
        _conversationId = conversationId;
        _messages.addAll(
          rawMessages.map(
                (m) => ChatMessage(
              role: m['role'] as String,
              content: m['content'] as String,
            ),
          ),
        );
        _loadingHistory = false;
      });
      _scrollToBottom();
    } catch (e) {
      // History fetch failing shouldn't block the chat from being usable --
      // fall back to a fresh conversation with just the greeting, same as
      // the old behavior.
      if (!mounted) return;
      _showGreetingOnly();
    }
  }

  void _showGreetingOnly() {
    final greeting = widget.persona.greeting?.trim();
    setState(() {
      _messages.clear();
      if (greeting != null && greeting.isNotEmpty) {
        _messages.add(ChatMessage(role: 'assistant', content: greeting));
      }
      _conversationId = null;
      _loadingHistory = false;
    });
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
      _hasText = false;
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
    final gradient = AppColors.personaGradient(widget.persona.name);

    return Scaffold(
      appBar: AppBar(
        // UX FIX (2026-07-03): appbar now carries the persona's own color +
        // a small avatar instead of just their name as plain text -- makes
        // it immediately obvious which companion you're talking to even at
        // a glance, and the color continuity from the persona list card
        // makes navigating in feel like a single continuous place rather
        // than a context switch.
        titleSpacing: 8,
        title: Row(
          children: [
            PersonaAvatar(personaName: widget.persona.name, size: 36),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.persona.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _messages.isEmpty && _conversationId == null
                ? null
                : _clearConversation,
          ),
        ],
      ),
      body: SafeArea(
        child: _loadingHistory
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isTyping && index == _messages.length) {
                    return _TypingBubble(gradient: gradient);
                  }

                  return _MessageBubble(
                    message: _messages[index],
                    gradient: gradient,
                  );
                },
              ),
            ),
            // FEATURE (dark mode, 2026-07-06): dropped `const` here -- both
            // colors now come from Theme.of(context), a runtime lookup, not a
            // compile-time constant. Without this the input bar would stay a
            // light-mode white strip even with dark mode on.
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: (_hasText && !_isTyping)
                          ? LinearGradient(colors: gradient)
                          : null,
                      color: (_hasText && !_isTyping)
                          ? null
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: IconButton(
                      tooltip: 'Send',
                      icon: Icon(
                        Icons.arrow_upward_rounded,
                        color: (_hasText && !_isTyping)
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _isTyping ? null : _sendMessage,
                    ),
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
  final List<Color> gradient;

  const _MessageBubble({required this.message, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            // UX FIX (2026-07-03): assistant bubbles now use the persona's
            // own accent color (softened) instead of a neutral gray -- the
            // same color continuity as the avatar/appbar, reinforced on
            // every single message instead of just at the top of the
            // screen. User bubbles use the brand primary so they read as
            // distinctly "you" regardless of which persona you're talking
            // to.
            gradient: isUser
                ? const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            )
                : null,
            color: isUser ? null : gradient.first.withValues(alpha: 0.16),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  final List<Color> gradient;

  const _TypingBubble({required this.gradient});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

// UX FIX (2026-07-03): replaced the small CircularProgressIndicator spinner
// with three dots that pulse in sequence -- the classic "someone is typing"
// pattern people already recognize from every messaging app they've used.
// A spinner reads as "the app is doing something," a typing indicator reads
// as "a person is composing a reply" -- much closer to the actual feeling
// this app is going for.
class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: widget.gradient.first.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i * 0.2;
                final t = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
                final bounce = (t < 0.5)
                    ? Curves.easeOut.transform(t * 2)
                    : Curves.easeIn.transform((1 - t) * 2);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.translate(
                    offset: Offset(0, -4 * bounce),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.gradient.last,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
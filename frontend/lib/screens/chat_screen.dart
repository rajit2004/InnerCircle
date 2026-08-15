import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  int _animationKey = 0;

  @override
  void initState() {
    super.initState();
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
              id: m['id'] as String?,
              role: m['role'] as String,
              content: m['content'] as String,
              reaction: m['reaction'] as String?,
            ),
          ),
        );
        _loadingHistory = false;
      });
      _scrollToBottom();
    } catch (e) {
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

    HapticFeedback.lightImpact();
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: content));
      _isTyping = true;
      _hasText = false;
      _animationKey++;
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
      final messageId = response['messageId'] as String?;

      if (!mounted) return;
      setState(() {
        if (conversationId != null && conversationId.isNotEmpty) {
          _conversationId = conversationId;
        }
        if (reply.isNotEmpty) {
          _messages.add(
            ChatMessage(id: messageId, role: 'assistant', content: reply),
          );
        }
        _isTyping = false;
        _animationKey++;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _isTyping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear chat?'),
        content: Text(
          'This permanently deletes your conversation with '
          '${widget.persona.name}. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ChatService.deleteConversation(widget.persona.id);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear chat: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
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

  static const List<String> _reactionOptions = ['❤️', '😂', '😮', '😢', '👍', '🔥'];

  Future<void> _showReactionPicker(ChatMessage message) async {
    if (message.id == null) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _reactionOptions.map((emoji) {
            return GestureDetector(
              onTap: () => Navigator.pop(sheetContext, emoji),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            );
          }).toList(),
        ),
      ),
    );

    if (selected == null) return;
    HapticFeedback.selectionClick();
    final newReaction = (message.reaction == selected) ? null : selected;
    final previousReaction = message.reaction;

    setState(() => message.reaction = newReaction);

    try {
      await ChatService.setReaction(message.id!, newReaction);
    } catch (e) {
      if (!mounted) return;
      setState(() => message.reaction = previousReaction);
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save reaction'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty
        ? 'Something went wrong while sending the message.'
        : text;
  }

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.personaGradient(widget.persona.name);

    return Scaffold(
      appBar: AppBar(
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
            ? Center(
                child: CircularProgressIndicator(
                  color: gradient.first,
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isTyping && index == _messages.length) {
                          return _TypingBubble(
                            gradient: gradient,
                            key: ValueKey('typing-$_animationKey'),
                          );
                        }

                        final message = _messages[index];
                        return _AnimatedMessageBubble(
                          key: ValueKey('msg-${message.content.length}-$index'),
                          message: message,
                          gradient: gradient,
                          onLongPress: () => _showReactionPicker(message),
                          index: index,
                        );
                      },
                    ),
                  ),
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
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
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
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: (_hasText && !_isTyping)
                                ? LinearGradient(colors: gradient)
                                : null,
                            color: (_hasText && !_isTyping)
                                ? null
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            boxShadow: (_hasText && !_isTyping)
                                ? [
                                    BoxShadow(
                                      color: gradient.first
                                          .withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: IconButton(
                            tooltip: 'Send',
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: Icon(
                                _isTyping
                                    ? Icons.hourglass_top_rounded
                                    : Icons.arrow_upward_rounded,
                                key: ValueKey(_isTyping),
                                color: (_hasText && !_isTyping)
                                    ? Colors.white
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ),
                            onPressed: (_hasText && !_isTyping)
                                ? _sendMessage
                                : null,
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

class _AnimatedMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final List<Color> gradient;
  final VoidCallback? onLongPress;
  final int index;

  const _AnimatedMessageBubble({
    super.key,
    required this.message,
    required this.gradient,
    this.onLongPress,
    required this.index,
  });

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    final isUser = widget.message.role == 'user';
    final beginOffset = isUser
        ? const Offset(0.3, 0.0)
        : const Offset(-0.3, 0.0);

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == 'user';
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: GestureDetector(
              onLongPress: widget.onLongPress,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? LinearGradient(
                              colors: widget.gradient,
                            )
                          : null,
                      color: isUser
                          ? null
                          : widget.gradient.first.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      boxShadow: isUser
                          ? [
                              BoxShadow(
                                color: widget.gradient.first.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      widget.message.content,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (widget.message.reaction != null)
                    Positioned(
                      bottom: -6,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Text(
                          widget.message.reaction!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  final List<Color> gradient;

  const _TypingBubble({super.key, required this.gradient});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-0.3, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOutCubic),
      )),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.gradient.first.withValues(alpha: 0.2),
                  widget.gradient.first.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i * 0.15;
                    final t = ((_controller.value - delay) % 1.0)
                        .clamp(0.0, 1.0);
                    final bounce = (t < 0.5)
                        ? Curves.easeOut.transform(t * 2)
                        : Curves.easeIn.transform((1 - t) * 2);
                    final scale = 0.6 + 0.4 * bounce;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Transform.translate(
                        offset: Offset(0, -5 * bounce),
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  widget.gradient.first.withValues(
                                    alpha: 0.4 + 0.6 * bounce,
                                  ),
                                  widget.gradient.last.withValues(
                                    alpha: 0.4 + 0.6 * bounce,
                                  ),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.gradient.last
                                      .withValues(alpha: 0.3 * bounce),
                                  blurRadius: 4 * bounce,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

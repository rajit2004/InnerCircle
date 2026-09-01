import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/chat_message.dart';
import '../models/persona.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../services/sound_service.dart';
import '../widgets/persona_avatar.dart';
import '../widgets/shared_widgets.dart';

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
  bool _showScrollToBottom = false;
  int _animationKey = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80;
    if (atBottom != _showScrollToBottom) {
      setState(() => _showScrollToBottom = !atBottom);
    }
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
        _messages.addAll(rawMessages.map((m) => ChatMessage(
              id: m['id'] as String?,
              role: m['role'] as String,
              content: m['content'] as String,
              reaction: m['reaction'] as String?,
              timestamp: m['createdAt'] != null
                  ? DateTime.tryParse(m['createdAt'] as String)
                  : null,
            )));
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
        _messages.add(ChatMessage(role: 'assistant', content: greeting, timestamp: DateTime.now()));
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

    AppSound.lightImpact();
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: content, timestamp: DateTime.now()));
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
              ChatMessage(id: messageId, role: 'assistant', content: reply, timestamp: DateTime.now()));
        }
        _isTyping = false;
        _animationKey++;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      AppSound.lightImpact();
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
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat?'),
        content: Text(
          'This permanently deletes your conversation with ${widget.persona.name}. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ChatService.deleteConversation(widget.persona.id);
    } catch (e) {
      if (!mounted) return;
      AppSound.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear chat: $e'),
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
        _messages.add(ChatMessage(role: 'assistant', content: greeting, timestamp: DateTime.now()));
      }
      _conversationId = null;
      _isTyping = false;
    });
  }

  static const List<String> _reactionOptions = [
    '❤️', '😂', '😮', '😢', '👍', '🔥'
  ];

  Future<void> _showReactionPicker(ChatMessage message) async {
    if (message.id == null) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ReactionSheet(
        options: _reactionOptions,
        currentReaction: message.reaction,
      ),
    );

    if (selected == null) return;
    AppSound.mediumImpact();
    final newReaction = (message.reaction == selected) ? null : selected;
    final previousReaction = message.reaction;
    setState(() => message.reaction = newReaction);

    try {
      await ChatService.setReaction(message.id!, newReaction);
    } catch (e) {
      if (!mounted) return;
      setState(() => message.reaction = previousReaction);
      AppSound.lightImpact();
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

  void _showMessageActions(ChatMessage message) {
    if (message.role != 'assistant') return;
    AppSound.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _ActionTile(
              icon: Icons.copy_rounded,
              label: 'Copy',
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            _ActionTile(
              icon: Icons.refresh_rounded,
              label: 'Regenerate',
              onTap: () {
                Navigator.pop(ctx);
                _regenerateMessage();
              },
            ),
            _ActionTile(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: () {
                Navigator.pop(ctx);
                SharePlus.instance.share(ShareParams(text: message.content));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _regenerateMessage() async {
    if (_isTyping || _conversationId == null) return;
    AppSound.lightImpact();
    setState(() => _isTyping = true);

    try {
      final response = await ChatService.regenerate(
        widget.persona.id,
        _conversationId!,
      );
      final reply = (response['reply'] as String? ?? '').trim();
      final messageId = response['messageId'] as String?;
      if (!mounted) return;

      setState(() {
        // Remove last assistant message and add new one
        if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
          _messages.removeLast();
        }
        if (reply.isNotEmpty) {
          _messages.add(
            ChatMessage(id: messageId, role: 'assistant', content: reply, timestamp: DateTime.now()),
          );
        }
        _isTyping = false;
        _animationKey++;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      AppSound.lightImpact();
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

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty
        ? 'Something went wrong while sending the message.'
        : text;
  }

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.personaGradient(widget.persona.name);
    final personaBg = gradient.first.withValues(alpha: 0.04);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            _BreathingAvatar(
              personaName: widget.persona.name,
              size: 36,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.persona.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                  _isTyping ? 'typing...' : 'online',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isTyping ? gradient.first : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: _isTyping ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed:
                _messages.isEmpty && _conversationId == null ? null : _clearConversation,
          ),
        ],
      ),
      body: SafeArea(
        child: _loadingHistory
            ? const ChatShimmer()
            : Container(
                color: personaBg,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount:
                                _messages.length + (_isTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isTyping && index == _messages.length) {
                                return _TypingBubble(
                                  gradient: gradient,
                                  key: ValueKey('typing-$_animationKey'),
                                );
                              }
                              final message = _messages[index];
                              return _AnimatedMessageBubble(
                                key: ValueKey(
                                    'msg-${message.content.hashCode}-$index'),
                                message: message,
                                gradient: gradient,
                                personaName: widget.persona.name,
                                onLongPress: () =>
                                    _showReactionPicker(message),
                                onTap: message.role == 'assistant'
                                    ? () => _showMessageActions(message)
                                    : null,
                              );
                            },
                          ),
                        ),
                        if (!_isTyping && _messages.isNotEmpty &&
                            _messages.last.role == 'assistant')
                          _SuggestionChips(
                            personaName: widget.persona.name,
                            lastMessage: _messages.last.content,
                            gradient: gradient,
                            onSelected: (text) {
                              _controller.text = text;
                              setState(() => _hasText = true);
                            },
                          ),
                        _ChatInputBar(
                          controller: _controller,
                          hasText: _hasText,
                          isTyping: _isTyping,
                          gradient: gradient,
                          onSend: _sendMessage,
                          personaName: widget.persona.name,
                        ),
                      ],
                    ),
                    // Scroll-to-bottom FAB
                    Positioned(
                      bottom: 80,
                      right: 16,
                      child: AnimatedOpacity(
                        duration: AppMotion.micro,
                        opacity: _showScrollToBottom ? 1.0 : 0.0,
                        child: FloatingActionButton.small(
                          heroTag: 'scroll-to-bottom',
                          onPressed: () {
                            AppSound.selectionClick();
                            _scrollToBottom();
                          },
                          backgroundColor: gradient.first,
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Breathing Avatar ─────────────────────────────────────────────────────

class _BreathingAvatar extends StatefulWidget {
  final String personaName;
  final double size;

  const _BreathingAvatar({required this.personaName, this.size = 36});

  @override
  State<_BreathingAvatar> createState() => _BreathingAvatarState();
}

class _BreathingAvatarState extends State<_BreathingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: PersonaAvatar(personaName: widget.personaName, size: widget.size),
    );
  }
}

// ── Animated Message Bubble ──────────────────────────────────────────────

class _AnimatedMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final List<Color> gradient;
  final String personaName;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const _AnimatedMessageBubble({
    super.key,
    required this.message,
    required this.gradient,
    required this.personaName,
    this.onLongPress,
    this.onTap,
  });

  @override
  State<_AnimatedMessageBubble> createState() =>
      _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final isUser = widget.message.role == 'user';
    final beginOffset =
        isUser ? const Offset(0.2, 0.0) : const Offset(-0.2, 0.0);

    _slideAnim = Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppMotion.easeOutCubic,
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (msgDate == today) return time;
    final yesterday = today.subtract(const Duration(days: 1));
    if (msgDate == yesterday) return 'Yesterday $time';
    return '${dt.day}/${dt.month} $time';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == 'user';
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final gradient = widget.gradient;

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: GestureDetector(
                onLongPress: widget.onLongPress,
                onTap: widget.onTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isUser) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: gradient.first.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            AppColors.personaIcon(widget.personaName),
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Column(
                        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isUser)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 3),
                              child: Text(
                                widget.personaName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: gradient.first,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: isUser
                                  ? LinearGradient(
                                      colors: gradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isUser
                                  ? null
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(isUser ? 20 : 4),
                                bottomRight: Radius.circular(isUser ? 4 : 20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isUser
                                      ? gradient.first.withValues(alpha: 0.25)
                                      : Colors.black.withValues(alpha: 0.06),
                                  blurRadius: isUser ? 10 : 8,
                                  offset: Offset(0, isUser ? 3 : 2),
                                ),
                              ],
                              border: isUser
                                  ? null
                                  : Border.all(
                                      color: Theme.of(context).dividerColor,
                                      width: 0.5,
                                    ),
                            ),
                            child: Text(
                              widget.message.content,
                              style: TextStyle(
                                color: isUser
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                          ),
                          if (widget.message.reaction != null)
                            Positioned(
                              bottom: -8,
                              right: -4,
                              child: _ReactionBadge(
                                reaction: widget.message.reaction!,
                                gradient: gradient,
                              ),
                            ),
                          ],
                          ),
                          if (widget.message.timestamp != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                              child: Text(
                                _formatTime(widget.message.timestamp!),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isUser) const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reaction Badge (animated landing) ────────────────────────────────────

class _ReactionBadge extends StatefulWidget {
  final String reaction;
  final List<Color> gradient;

  const _ReactionBadge({required this.reaction, required this.gradient});

  @override
  State<_ReactionBadge> createState() => _ReactionBadgeState();
}

class _ReactionBadgeState extends State<_ReactionBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
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
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: widget.gradient.first.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(widget.reaction, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

// ── Typing Bubble (enhanced with glow) ───────────────────────────────────

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
        begin: const Offset(-0.15, 0.0),
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
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.gradient.first.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
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
                    final scale = 0.5 + 0.5 * bounce;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Transform.translate(
                        offset: Offset(0, -4 * bounce),
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  widget.gradient.first
                                      .withValues(alpha: 0.5 + 0.5 * bounce),
                                  widget.gradient.last
                                      .withValues(alpha: 0.5 + 0.5 * bounce),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.gradient.last
                                      .withValues(alpha: 0.25 * bounce),
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

// ── Reaction Picker Bottom Sheet ─────────────────────────────────────────

class _ReactionSheet extends StatefulWidget {
  final List<String> options;
  final String? currentReaction;

  const _ReactionSheet({required this.options, this.currentReaction});

  @override
  State<_ReactionSheet> createState() => _ReactionSheetState();
}

class _ReactionSheetState extends State<_ReactionSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.options.length, (i) {
          final emoji = widget.options[i];
          final delay = i * 0.06;
          final scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _controller,
              curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
                  curve: Curves.elasticOut),
            ),
          );
          final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _controller,
              curve: Interval(delay, (delay + 0.3).clamp(0.0, 1.0),
                  curve: Curves.easeOut),
            ),
          );
          final isSelected = widget.currentReaction == emoji;

          return ScaleTransition(
            scale: scaleAnim,
            child: FadeTransition(
              opacity: fadeAnim,
              child: GestureDetector(
                onTap: () => Navigator.pop(context, emoji),
                child: AnimatedContainer(
                  duration: AppMotion.micro,
                  padding: const EdgeInsets.all(6),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Text(emoji,
                      style: const TextStyle(fontSize: 28)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Chat Input Bar ───────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final bool isTyping;
  final List<Color> gradient;
  final VoidCallback onSend;
  final String? personaName;

  const _ChatInputBar({
    required this.controller,
    required this.hasText,
    required this.isTyping,
    required this.gradient,
    required this.onSend,
    this.personaName,
  });

  @override
  Widget build(BuildContext context) {
    final active = hasText && !isTyping;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.micro,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: active
                      ? gradient.first.withValues(alpha: 0.4)
                      : Theme.of(context).dividerColor,
                  width: active ? 1.2 : 0.8,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: gradient.first.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Message ${personaName ?? ''}...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  filled: false,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: AppMotion.micro,
            curve: Curves.easeOutCubic,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active
                  ? LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: active ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: gradient.first.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: IconButton(
              tooltip: 'Send',
              icon: AnimatedSwitcher(
                duration: AppMotion.micro,
                child: Icon(
                  isTyping ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded,
                  key: ValueKey(isTyping),
                  color: active
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              onPressed: active ? onSend : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Tile (for message action bottom sheet) ─────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 14),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Suggested Follow-up Chips ─────────────────────────────────────────────

class _SuggestionChips extends StatelessWidget {
  final String personaName;
  final String lastMessage;
  final List<Color> gradient;
  final ValueChanged<String> onSelected;

  const _SuggestionChips({
    required this.personaName,
    required this.lastMessage,
    required this.gradient,
    required this.onSelected,
  });

  List<String> _generateSuggestions() {
    final lower = lastMessage.toLowerCase();
    if (lower.contains('?')) {
      return [
        'Tell me more',
        'What do you think?',
        'I agree',
      ];
    }
    if (lower.contains('love') || lower.contains('miss') || lower.contains('cute')) {
      return [
        'Aww thanks',
        'You\'re sweet',
        'Same here',
      ];
    }
    if (lower.contains('sorry') || lower.contains('sad') || lower.contains('bad')) {
      return [
        'It\'s okay',
        'Thanks for listening',
        'I appreciate you',
      ];
    }
    if (lower.contains('haha') || lower.contains('lol') || lower.contains('funny')) {
      return [
        'Right??',
        'I know',
        'So true',
      ];
    }
    if (lower.contains('food') || lower.contains('eat') || lower.contains('hungry')) {
      return [
        'I\'m starving',
        'What should I get?',
        'Good idea',
      ];
    }
    return [
      'Tell me more',
      'That\'s interesting',
      'What do you think?',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _generateSuggestions();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: suggestions.map((s) {
          return GestureDetector(
            onTap: () {
              AppSound.selectionClick();
              onSelected(s);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: gradient.first.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                s,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: gradient.first,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

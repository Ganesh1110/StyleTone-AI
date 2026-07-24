import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/llm_service.dart';
import '../services/tts_service.dart';
import '../widgets/glass_card.dart';

class StyleCoachScreen extends StatefulWidget {
  const StyleCoachScreen({super.key});

  @override
  State<StyleCoachScreen> createState() => _StyleCoachScreenState();
}

class _StyleCoachScreenState extends State<StyleCoachScreen> {
  final _messages = <_ChatMessage>[];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _llm = LlmService.instance;
  final _tts = TtsService();

  bool _isProcessing = false;
  bool _isInitialized = false;
  String? _statusMessage;

  static const _suggestedPrompts = [
    'Rate my outfit idea: navy blazer, white shirt, grey chinos',
    'What colours should I avoid with my skin tone?',
    'Suggest a casual weekend outfit from my wardrobe',
    'Does this blue shirt go with khaki chinos?',
    'What accessories work for a formal office look?',
    'I have a wedding next week, what should I wear?',
  ];

  @override
  void initState() {
    super.initState();
    _tts.init();
    _checkModel();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _checkModel() async {
    final downloaded = _llm.isModelDownloaded;
    if (mounted) {
      setState(() {
        _isInitialized = downloaded;
        _statusMessage = downloaded ? null : 'Model not downloaded';
      });
    }
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: isUser));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isProcessing) return;

    _addMessage(text.trim(), true);
    _textController.clear();

    setState(() => _isProcessing = true);

    try {
      final response = await _llm.ask(text.trim());
      _addMessage(response, false);
      _tts.speak(response);
    } catch (e) {
      _addMessage(
        'Sorry, I encountered an issue: ${e.toString().replaceAll("Exception: ", "")}',
        false,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _statusMessage = 'Downloading model (2.3GB)...';
      _isInitialized = false;
    });

    try {
      await _llm.downloadModelFuture(
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _statusMessage =
                  'Downloading... ${(progress * 100).toStringAsFixed(0)}%';
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _statusMessage = null;
        });
        _addMessage(
          'Model ready! I\'m your personal Style Coach. '
              'Ask me anything about fashion, outfits, or style.',
          false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Download failed: ${e.toString().replaceAll("Exception: ", "")}';
          _isInitialized = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _isInitialized ? Colors.green : Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Style Coach'),
          ],
        ),
        actions: [
          if (_isInitialized) ...[
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh context & clear history',
              onPressed: () {
                _llm.refreshContext();
                _llm.clearHistory();
                setState(() => _messages.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Context refreshed, conversation reset'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            if (_messages.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Clear conversation',
                onPressed: () {
                  _llm.clearHistory();
                  setState(() => _messages.clear());
                },
              ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (_statusMessage != null)
            _buildStatusBanner(theme),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(theme)
                : _buildChatList(theme),
          ),
          _buildInputBar(theme),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.orange.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage!,
              style: const TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
          if (!_isInitialized)
            TextButton(
              onPressed: _isProcessing ? null : _downloadModel,
              child: const Text('Download'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Style Coach',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your personal AI fashion stylist.\nAsk anything about style & outfits.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          if (!_isInitialized) ...[
            GlassCard(
              margin: const EdgeInsets.only(bottom: 24),
              color: Colors.amber.withValues(alpha: 0.06),
              padding: const EdgeInsets.all(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              child: Column(
                children: [
                  const Icon(Icons.download_rounded,
                      color: Colors.amber, size: 28),
                  const SizedBox(height: 8),
                    const Text(
                    'Download the fashion AI model to get started.\n'
                    '~2.3 GB • One-time download • Runs 100% offline',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _downloadModel,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download Model'),
                  ),
                ],
              ),
            ),
          ],
          const Text(
            'Try asking:',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
          const SizedBox(height: 12),
          ..._suggestedPrompts.map(
            (prompt) => _SuggestionChip(
              label: prompt,
              onTap: _isInitialized ? () => _sendMessage(prompt) : null,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildChatList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isProcessing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildTypingIndicator(theme);
        }
        return _buildMessageBubble(_messages[index], theme);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, ThemeData theme) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft:
                      Radius.circular(isUser ? 18 : 4),
                  bottomRight:
                      Radius.circular(isUser ? 4 : 18),
                ),
                border: Border.all(
                  color: (isUser
                          ? theme.colorScheme.primary
                          : Colors.white)
                      .withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person, size: 18, color: theme.colorScheme.primary),
            ),
          ],
          if (!isUser)
            IconButton(
              icon: const Icon(Icons.volume_up, size: 16),
              color: Colors.white38,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => _tts.speak(msg.text),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(theme),
                const SizedBox(width: 4),
                _dot(theme),
                const SizedBox(width: 4),
                _dot(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(ThemeData theme) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    ).animate().shake(duration: 600.ms);
  }

  Widget _buildInputBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: _isInitialized && !_isProcessing,
              textInputAction: TextInputAction.send,
              onSubmitted: _isInitialized ? (v) => _sendMessage(v) : null,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: _isInitialized
                    ? 'Ask about outfits, colours, style...'
                    : 'Download model to start...',
                filled: true,
                fillColor: theme.colorScheme.surface.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: 200.ms,
            child: Material(
              color: _isInitialized && !_isProcessing
                  ? theme.colorScheme.primary
                  : Colors.grey,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _isInitialized && !_isProcessing
                    ? () => _sendMessage(_textController.text)
                    : null,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: _isProcessing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Icon(
                          Icons.arrow_upward_rounded,
                          color: theme.colorScheme.onPrimary,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  const _ChatMessage({required this.text, required this.isUser});
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SuggestionChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0);
  }
}

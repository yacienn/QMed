import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz/core/model/chat_message.dart';
import 'package:quiz/core/theme/app_theme.dart';
import 'package:quiz/feature/home/controller/webSocket_vm.dart';

/// Opens the room chat as a modal bottom sheet. Purely in-memory on the
/// server — there's no chat history once the room itself is gone.
Future<void> showChatPanel(BuildContext context, {required String? myUserName}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<WebsocketVm>(),
      child: _ChatSheet(myUserName: myUserName),
    ),
  );
}

/// A small icon button that opens the chat sheet, for use in an AppBar.
class ChatButton extends StatelessWidget {
  final String? myUserName;
  const ChatButton({super.key, required this.myUserName});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.chat_bubble_outline,
        color: AppTheme.neoBlack,
        size: 26,
      ),
      tooltip: 'Room chat',
      onPressed: () => showChatPanel(context, myUserName: myUserName),
    );
  }
}

class _ChatSheet extends StatefulWidget {
  final String? myUserName;
  const _ChatSheet({required this.myUserName});

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    context.read<WebsocketVm>().sendChatMessage(text);
    _controller.clear();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final websocket = context.watch<WebsocketVm>();
    final messages = websocket.chatMessages;
    _scrollToBottom();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.paperBeige,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.mediumGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'ROOM CHAT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppTheme.neoBlack,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.accentTeal,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '${messages.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.neoBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                color: AppTheme.neoBlack,
                thickness: 2,
                height: 16,
              ),
              // Messages list
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: AppTheme.mediumGrey,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'NO MESSAGES YET',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.mediumGrey,
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Say hi to the room! 👋',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.darkGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.userName == widget.myUserName;
                          return _ChatBubble(message: msg, isMe: isMe);
                        },
                      ),
              ),
              const Divider(
                color: AppTheme.neoBlack,
                thickness: 2,
                height: 1,
              ),
              // Input field
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.neoBlack,
                            width: AppTheme.borderWidth,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppTheme.neoBlack,
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          maxLength: 300,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.neoBlack,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.mediumGrey,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            counterText: '',
                            prefixIcon: const Icon(
                              Icons.message_outlined,
                              color: AppTheme.neoBlack,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send button
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.neoBlack,
                            width: AppTheme.borderWidth,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppTheme.neoBlack,
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.send,
                          color: AppTheme.neoBlack,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.accentTeal : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.neoBlack,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.neoBlack,
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.userName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.neoBlack,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            Text(
              message.message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.neoBlack,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
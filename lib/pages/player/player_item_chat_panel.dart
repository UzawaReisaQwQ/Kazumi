import 'package:kazumi/bbcode/bbcode_widget.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/utils/utils.dart';

class SyncPlayChatItem {
  final String name;
  final String message;
  final DateTime time;

  SyncPlayChatItem({
    required this.name,
    required this.message,
    required this.time,
  });
}

class SyncPlayChatPanel extends StatefulWidget {
  const SyncPlayChatPanel({super.key});

  @override
  State<SyncPlayChatPanel> createState() => _SyncPlayChatPanelState();
}

class _SyncPlayChatPanelState extends State<SyncPlayChatPanel> {
  final PlayerController playerController = Modular.get<PlayerController>();
  final VideoPageController videoPageController = Modular.get<VideoPageController>();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 本地维护的聊天历史（打开面板时尝试从 controller 取历史）
  final List<SyncPlayChatItem> _messages = [];

  @override
  void initState() {
    super.initState();

    // 尝试从 playerController 读取历史（如果你的 controller 有字段请替换字段名）
    // TODO: 若你的 PlayerController 中历史字段名不是 `syncplayChatHistory`，把下面逻辑替换为正确字段
    try {
      final dynamic maybeHistory = (playerController as dynamic).syncplayChatHistory;
      if (maybeHistory is List) {
        for (final item in maybeHistory) {
          // 假设每个 item 有 name, message, time（若你存储格式不同，请替换）
          if (item is Map) {
            _messages.add(SyncPlayChatItem(
              name: item['name']?.toString() ?? '用户',
              message: item['message']?.toString() ?? '',
              time: item['time'] is DateTime ? item['time'] : DateTime.now(),
            ));
          }
        }
      }
    } catch (_) {
      // 没有历史字段就从空开始
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 调用 PlayerController 提供的发送接口
    try {
      await playerController.sendSyncPlayChatMessage(text);
    } catch (e) {
      // 若你需要错误提示可以在这里 showToast/弹窗
    }

    // 尝试取当前用户名（如果 controller 有字段请替换）
    String name = '我';
    try {
      final dynamic maybeName = (playerController as dynamic).syncplayUserName;
      if (maybeName is String && maybeName.isNotEmpty) name = maybeName;
    } catch (_) {}

    final newItem = SyncPlayChatItem(
      name: name,
      message: text,
      time: DateTime.now(),
    );

    setState(() {
      _messages.add(newItem);
      _textController.clear();
    });

    // 可选：同时也可以把它推回 controller 的历史里（若你希望共享历史）
    try {
      final dynamic history = (playerController as dynamic).syncplayChatHistory;
      if (history is List) {
        history.add({
          'name': newItem.name,
          'message': newItem.message,
          'time': newItem.time,
        });
      }
    } catch (_) {}

    _scrollToBottom();
  }

  Widget _buildMessageItem(SyncPlayChatItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名字 - 时间 行
          Text(
            '${item.name} - ${Utils.dateFormat(item.time)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          // 内容（使用 BBCodeWidget 以与评论样式一致）
          BBCodeWidget(bbcode: item.message),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: FractionallySizedBox(
        heightFactor: (Utils.isDesktop() || Utils.isTablet()) ? 0.9 : 0.85,
        widthFactor: 1.0,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                // 顶部标题栏
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '聊天室',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // 消息列表
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                            '聊天室为空，赶快说点什么吧～',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageItem(_messages[index]);
                          },
                        ),
                ),
                // 输入框 + 发送
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: '在一起看里发言（点"发送"按钮来发送评论）',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _handleSend,
                        child: const Text('发送'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

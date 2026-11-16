import 'package:llamadart/llamadart.dart';

class ChatMessage {
  ChatMessage(this.text, this.isUser, {this.imagePath});
  String text;
  final bool isUser;
  final String? imagePath;
  Map<String, Object?> toJson() => {
    'text': text,
    'user': isUser,
    'image': imagePath,
  };
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    json['text'] as String? ?? '',
    json['user'] as bool? ?? false,
    imagePath: json['image'] as String?,
  );
}

class ChatThread {
  ChatThread(this.title) : messages = [];
  String title;
  final List<ChatMessage> messages;
  ChatSession? session;
  Map<String, Object?> toJson() => {
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
  };
  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final thread = ChatThread(json['title'] as String? ?? 'Chat');
    thread.messages.addAll(
      (json['messages'] as List<dynamic>? ?? []).whereType<Map>().map(
        (m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)),
      ),
    );
    return thread;
  }
}


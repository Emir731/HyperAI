import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai/models/chat_thread.dart';

void main() {
  test('chat threads preserve text and image messages across serialization', () {
    final original = ChatThread('Physics');
    original.messages
      ..add(
        ChatMessage(
          'Explain this diagram.',
          true,
          imagePath: '/local/images/diagram.png',
        ),
      )
      ..add(ChatMessage('The diagram shows a force vector.', false));

    final restored = ChatThread.fromJson(original.toJson());

    expect(restored.title, 'Physics');
    expect(restored.messages, hasLength(2));
    expect(restored.messages[0].text, 'Explain this diagram.');
    expect(restored.messages[0].isUser, isTrue);
    expect(restored.messages[0].imagePath, '/local/images/diagram.png');
    expect(restored.messages[1].text, 'The diagram shows a force vector.');
    expect(restored.messages[1].isUser, isFalse);
    expect(restored.session, isNull);
  });

  test('chat threads tolerate missing optional fields', () {
    final restored = ChatThread.fromJson({
      'messages': [
        {'text': 'Hello', 'user': true},
        'invalid entry',
      ],
    });

    expect(restored.title, 'Chat');
    expect(restored.messages, hasLength(1));
    expect(restored.messages.single.text, 'Hello');
  });
}

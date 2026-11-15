import 'package:flutter/material.dart';

void main() => runApp(const OfflineAIApp());

const _background = Color(0xFF111313);
const _surface = Color(0xFF1B1E1D);
const _line = Color(0xFF303533);
const _accent = Color(0xFFD14CF4);
const _radius = 12.0;

class OfflineAIApp extends StatelessWidget {
  const OfflineAIApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Hyper AI',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _background,
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: _surface,
          ),
          useMaterial3: true,
          fontFamily: 'Arial',
          textTheme: const TextTheme(
            headlineMedium: TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w600),
            titleMedium: TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w600),
            bodyLarge: TextStyle(fontSize: 16, height: 1.55),
            bodyMedium: TextStyle(fontSize: 14, height: 1.5),
            labelSmall: TextStyle(fontSize: 12, height: 1.4),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: _line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: _line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: _accent)),
          ),
        ),
        home: const ChatScreen(),
      );
}

class _Message {
  _Message(this.text, this.isUser);
  final String text;
  final bool isUser;
}

class _Conversation {
  _Conversation(this.title) : messages = [];
  final String title;
  final List<_Message> messages;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _conversations = <_Conversation>[];
  _Conversation? _active;
  bool _historyOpen = true;

  void _newChat() => setState(() => _active = null);

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      final conversation = _active ?? _Conversation(text.length > 32 ? '${text.substring(0, 32)}…' : text);
      if (_active == null) {
        _conversations.insert(0, conversation);
        _active = conversation;
      }
      conversation.messages.add(_Message(text, true));
      _controller.clear();
    });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    return Scaffold(
      drawer: wide ? null : Drawer(child: _history()),
      body: SafeArea(
        child: Row(children: [
          if (wide && _historyOpen) SizedBox(width: 260, child: _history()),
          Expanded(child: Column(children: [
            _topBar(wide),
            Expanded(child: _active == null || _active!.messages.isEmpty ? _welcome() : _conversation()),
            _composer(),
          ])),
        ]),
      ),
    );
  }

  Widget _topBar(bool wide) => Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
        child: Row(children: [
          IconButton(
            onPressed: () {
              if (wide) {
                setState(() => _historyOpen = !_historyOpen);
              } else {
                Scaffold.of(context).openDrawer();
              }
            },
            tooltip: 'Geçmiş panelini aç veya kapat',
            icon: const Icon(Icons.menu),
          ),
          Image.asset('assets/images/logo.png', width: 30, height: 30, fit: BoxFit.contain),
          const SizedBox(width: 10),
          Text('Hyper AI', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          TextButton.icon(onPressed: _newChat, icon: const Icon(Icons.add, size: 18), label: const Text('Yeni sohbet')),
        ]),
      );

  Widget _history() => Container(
        color: const Color(0xFF151817),
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Image.asset('assets/images/logo.png', width: 28, height: 28), const SizedBox(width: 10), const Text('Hyper AI', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 28),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _newChat, icon: const Icon(Icons.add), label: const Text('Yeni sohbet'), style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius))))),
          const SizedBox(height: 28),
          const Text('SON SOHBETLER', style: TextStyle(fontSize: 11, color: Colors.white54, letterSpacing: 1)),
          const SizedBox(height: 10),
          Expanded(child: _conversations.isEmpty
              ? const Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.only(top: 8), child: Text('Sohbet geçmişi burada görünür.', style: TextStyle(color: Colors.white54, fontSize: 13))))
              : ListView.builder(itemCount: _conversations.length, itemBuilder: (context, index) {
                  final item = _conversations[index];
                  return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.chat_bubble_outline, size: 18), title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis), selected: item == _active, selectedTileColor: _surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)), onTap: () => setState(() => _active = item));
                })),
        ]),
      );

  Widget _welcome() => Align(alignment: const Alignment(0, -0.15), child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Image.asset('assets/images/logo.png', width: 48, height: 48),
    const SizedBox(height: 24),
    Text('Merhaba, ben Hyper AI.', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 8),
    const Text('Bugün ne üzerinde çalışalım?', style: TextStyle(fontSize: 16, color: Colors.white70)),
    const SizedBox(height: 28),
    const Text('Bir mesaj yazarak sohbeti başlatın.', style: TextStyle(color: Colors.white54)),
  ]))));


  Widget _conversation() => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: _active!.messages.length,
        itemBuilder: (context, index) {
          final message = _active!.messages[index];
          return Align(alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: message.isUser ? _surface : Colors.transparent, border: message.isUser ? null : const Border(left: BorderSide(color: _accent, width: 2)), borderRadius: BorderRadius.circular(_radius)),
            child: Text(message.text, style: Theme.of(context).textTheme.bodyLarge),
          ));
        },
      );

  Widget _composer() => Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 10), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: Column(children: [
    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: TextField(controller: _controller, minLines: 1, maxLines: 6, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Hyper AI’ye mesaj gönderin', filled: true, fillColor: _surface, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
      const SizedBox(width: 8),
      IconButton.filled(onPressed: _send, icon: const Icon(Icons.arrow_upward), tooltip: 'Gönder'),
    ]),
    const SizedBox(height: 9),
    const Text('Hyper AI şu anda çevrimdışı arayüz önizlemesidir.', style: TextStyle(fontSize: 12, color: Colors.white54)),
  ]))));
}

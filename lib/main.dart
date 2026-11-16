import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:llamadart/llamadart.dart';

void main() => runApp(const HyperAIApp());

const _bg = Color(0xFF101413);
const _panel = Color(0xFF171D1B);
const _panel2 = Color(0xFF202825);
const _line = Color(0xFF2B3531);
const _accent = Color(0xFF70D6A5);
const _text = Color(0xFFEAF1ED);
const _muted = Color(0xFF9AA8A0);
const _radius = 14.0;

class HyperAIApp extends StatelessWidget {
  const HyperAIApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hyper AI',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(primary: _accent, surface: _panel),
      useMaterial3: true,
      fontFamily: 'Arial',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 29, height: 1.2, fontWeight: FontWeight.w650, color: _text),
        titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: _text),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _text),
        bodyLarge: TextStyle(fontSize: 15, height: 1.55, color: _text),
        bodyMedium: TextStyle(fontSize: 13, height: 1.5, color: _muted),
        labelSmall: TextStyle(fontSize: 11, color: _muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: _panel,
        hintStyle: const TextStyle(color: _muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: _line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: _line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: _accent)),
      ),
    ),
    home: const ChatPage(),
  );
}

class ChatMessage {
  ChatMessage(this.text, this.isUser, {this.imagePath});
  final String text;
  final bool isUser;
  final String? imagePath;
}

class ChatThread {
  ChatThread(this.title) : messages = [];
  final String title;
  final List<ChatMessage> messages = [];
  ChatSession? session;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final List<ChatThread> _threads = [];
  ChatThread? _active;
  LlamaEngine? _engine;
  String? _modelPath;
  String? _projectorPath;
  XFile? _image;
  bool _loadingModel = false;
  bool _sending = false;
  bool _sidebarOpen = true;
  String? _error;
  String _status = 'Model not loaded';

  Future<void> _chooseModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['gguf'], allowMultiple: false,
      dialogTitle: 'Select Qwen3.5 GGUF model',
    );
    if (result == null || result.files.single.path == null) return;
    setState(() { _modelPath = result.files.single.path; _error = null; });
  }

  Future<void> _chooseProjector() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['gguf'], allowMultiple: false,
      dialogTitle: 'Select multimodal projector',
    );
    if (result == null || result.files.single.path == null) return;
    setState(() { _projectorPath = result.files.single.path; _error = null; });
  }

  Future<void> _loadModel() async {
    if (_modelPath == null || _projectorPath == null) {
      setState(() => _error = 'Select both the main GGUF model and its mmproj file.');
      return;
    }
    setState(() { _loadingModel = true; _error = null; _status = 'Loading model…'; });
    try {
      final old = _engine;
      final loaded = await LlamaEngine.load(
        LlamaModel(
          ModelSource.path(_modelPath!),
          projector: ModelSource.path(_projectorPath!),
        ),
        params: const ModelParams(contextSize: 4096),
      );
      await old?.dispose();
      if (!mounted) { await loaded.dispose(); return; }
      setState(() {
        _engine = loaded;
        _active?.session = ChatSession(loaded)..systemPrompt =
          'You are Hyper AI, a helpful offline study assistant. Help with school subjects including mathematics, physics, chemistry and geometry. Reply in the language the user uses (Turkish, English or Russian). Explain clearly and accurately.';
        _status = 'Ready · offline';
      });
    } catch (e) {
      if (mounted) setState(() { _status = 'Model load failed'; _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _loadingModel = false);
    }
  }

  Future<void> _unloadModel() async {
    final engine = _engine;
    setState(() { _engine = null; _status = 'Unloading…'; });
    await engine?.dispose();
    if (mounted) setState(() { _status = 'Model not loaded'; for (final t in _threads) { t.session = null; } });
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 85);
    if (file != null && mounted) setState(() => _image = file);
  }

  void _newChat() => setState(() { _active = null; _image = null; _error = null; });

  Future<void> _send() async {
    final prompt = _input.text.trim();
    if ((prompt.isEmpty && _image == null) || _sending) return;
    final engine = _engine;
    if (engine == null) {
      setState(() => _error = 'Load your local GGUF model before starting a chat.');
      return;
    }
    final thread = _active ?? ChatThread(prompt.isEmpty ? 'Image question' : (prompt.length > 34 ? '${prompt.substring(0, 34)}…' : prompt));
    if (_active == null) { _threads.insert(0, thread); _active = thread; }
    final image = _image;
    final userText = prompt.isEmpty ? 'Please explain this image.' : prompt;
    setState(() {
      thread.messages.add(ChatMessage(userText, true, imagePath: image?.path));
      _input.clear(); _image = null; _sending = true; _error = null;
    });
    thread.session ??= ChatSession(engine)..systemPrompt =
      'You are Hyper AI, a helpful offline study assistant. Help with school subjects including mathematics, physics, chemistry and geometry. Reply in the language the user uses (Turkish, English or Russian). Explain clearly and accurately.';
    final answer = StringBuffer();
    thread.messages.add(ChatMessage('', false));
    try {
      final parts = <LlamaContent>[
        if (image != null) LlamaImageContent(path: image.path),
        LlamaTextContent(userText),
      ];
      await for (final chunk in thread.session!.create(parts, params: const GenerationParams(maxTokens: 512, temp: 0.7))) {
        answer.write(chunk.text);
        if (!mounted) return;
        setState(() => thread.messages.last = ChatMessage(answer.toString(), false));
        _scrollToEnd();
      }
    } catch (e) {
      if (mounted) setState(() {
        thread.messages.removeLast();
        _error = 'Generation failed: $e';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _input.dispose(); _scroll.dispose(); unawaited(_engine?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    return Scaffold(
      drawer: wide ? null : Drawer(backgroundColor: _panel, child: _sidebar()),
      body: SafeArea(child: Row(children: [
        if (wide && _sidebarOpen) SizedBox(width: 270, child: _sidebar()),
        Expanded(child: Column(children: [
          _header(wide),
          Expanded(child: _active == null || _active!.messages.isEmpty ? _welcome() : _chat()),
          _composer(),
        ])),
      ])),
    );
  }

  Widget _header(bool wide) => Container(
    height: 62, padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
    child: Row(children: [
      IconButton(onPressed: () {
        if (wide) { setState(() => _sidebarOpen = !_sidebarOpen); }
        else { Scaffold.of(context).openDrawer(); }
      }, icon: const Icon(Icons.menu, color: _muted)),
      const Text('HYPER', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: _text)),
      const SizedBox(width: 6),
      const Text('AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _accent)),
      const Spacer(),
      _statusDot(),
      const SizedBox(width: 7),
      Text(_engine == null ? 'Offline model' : 'Ready offline', style: const TextStyle(fontSize: 12, color: _muted)),
      const SizedBox(width: 10),
      IconButton(tooltip: 'Model settings', onPressed: _showSettings, icon: const Icon(Icons.tune, color: _muted)),
      IconButton(tooltip: 'New chat', onPressed: _newChat, icon: const Icon(Icons.add, color: _accent)),
    ]),
  );

  Widget _statusDot() => Container(width: 7, height: 7, decoration: BoxDecoration(
    color: _engine == null ? const Color(0xFFCFAB65) : _accent, shape: BoxShape.circle));

  Widget _sidebar() => Container(
    color: const Color(0xFF131917), padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('HYPER AI', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      const SizedBox(height: 22),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: _newChat, icon: const Icon(Icons.add, size: 18), label: const Text('New chat'),
        style: OutlinedButton.styleFrom(foregroundColor: _text, side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)), alignment: Alignment.centerLeft))),
      const SizedBox(height: 26),
      const Text('RECENT CHATS', style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: _muted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Expanded(child: _threads.isEmpty
        ? const Text('Your conversations will appear here.', style: TextStyle(fontSize: 12, color: _muted))
        : ListView.builder(itemCount: _threads.length, itemBuilder: (context, i) {
          final t = _threads[i];
          return ListTile(dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.chat_bubble_outline, size: 17, color: _muted),
            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            selected: t == _active, selectedTileColor: _panel2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onTap: () => setState(() { _active = t; if (_engine != null && t.session == null) { t.session = ChatSession(_engine!); } }));
        })),
      const Divider(color: _line),
      ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.memory, color: _accent),
        title: const Text('Local model', style: TextStyle(fontSize: 13)),
        subtitle: Text(_engine == null ? 'Not loaded' : 'Loaded in memory', style: const TextStyle(fontSize: 11, color: _muted)),
        onTap: _showSettings),
    ]),
  );

  Widget _welcome() => Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.auto_awesome, color: _accent, size: 24)),
        const SizedBox(height: 26),
        const Text('Your AI.\nCompletely offline.', style: TextStyle(fontSize: 34, height: 1.15, fontWeight: FontWeight.w700, color: _text)),
        const SizedBox(height: 14),
        const Text('Ask questions, study concepts, or share an image. Your prompts stay on your device.', style: TextStyle(fontSize: 15, height: 1.6, color: _muted)),
        const SizedBox(height: 28),
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _panel, border: Border.all(color: _line), borderRadius: BorderRadius.circular(_radius)),
          child: Row(children: [
            const Icon(Icons.memory, color: _accent),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Load your local model', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Choose the Qwen GGUF file and its mmproj companion.', style: TextStyle(fontSize: 12, color: _muted)),
            ])),
            TextButton(onPressed: _showSettings, child: const Text('Set up')),
          ])),
        const SizedBox(height: 24),
        const Text('BUILT FOR LEARNING', style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: _muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: ['Mathematics', 'Physics', 'Chemistry', 'Geometry', 'Languages'].map((s) =>
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _panel, border: Border.all(color: _line), borderRadius: BorderRadius.circular(30)),
            child: Text(s, style: const TextStyle(fontSize: 12, color: _muted)))).toList()),
      ]),
    ),
  ));

  Widget _chat() => ListView.builder(
    controller: _scroll, padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
    itemCount: _active!.messages.length,
    itemBuilder: (context, index) {
      final m = _active!.messages[index];
      return Align(alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(constraints: const BoxConstraints(maxWidth: 720),
          margin: const EdgeInsets.only(bottom: 18),
          padding: EdgeInsets.symmetric(horizontal: m.isUser ? 15 : 4, vertical: 11),
          decoration: BoxDecoration(
            color: m.isUser ? _panel2 : Colors.transparent,
            border: m.isUser ? Border.all(color: _line) : const Border(left: BorderSide(color: _accent, width: 2)),
            borderRadius: BorderRadius.circular(_radius)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (m.imagePath != null) ...[
              ClipRRect(borderRadius: BorderRadius.circular(9),
                child: Image.file(File(m.imagePath!), height: 170, fit: BoxFit.cover)),
              const SizedBox(height: 9),
            ],
            if (m.text.isEmpty && !m.isUser)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _accent))
            else Text(m.text, style: Theme.of(context).textTheme.bodyLarge),
          ]),
        ),
      );
    },
  );

  Widget _composer() => Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
    child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760),
      child: Column(children: [
        if (_image != null) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 8),
          child: InputChip(label: Text(_image!.name), avatar: const Icon(Icons.image, size: 17),
            onDeleted: () => setState(() => _image = null)))),
        if (_error != null) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Text(_error!, style: const TextStyle(color: Color(0xFFE7A2A2), fontSize: 12)))),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          IconButton(tooltip: 'Add image', onPressed: _sending ? null : _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined, color: _muted)),
          Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 6,
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(hintText: 'Message Hyper AI', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(backgroundColor: _accent, foregroundColor: _bg),
            icon: _sending ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: _bg)) : const Icon(Icons.arrow_upward)),
        ]),
        const SizedBox(height: 8),
        const Text('Runs on your device. No cloud requests.', style: TextStyle(fontSize: 11, color: _muted)),
      ]),
    )),
  );

  void _showSettings() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: _panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) => StatefulBuilder(builder: (context, refresh) => Padding(
        padding: EdgeInsets.fromLTRB(22, 22, 22, MediaQuery.viewInsetsOf(context).bottom + 26),
        child: SafeArea(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('Model settings', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Select the two local Qwen3.5 files stored on this device.', style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 22),
          _fileRow('Main model', _modelPath, 'Qwen3.5-4B-Q4_K_M.gguf', _chooseModel),
          const SizedBox(height: 12),
          _fileRow('Vision projector', _projectorPath, 'mmproj-qwen3.5-4b-f16.gguf', _chooseProjector),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _engine == null || _loadingModel ? null : () async {
              Navigator.pop(sheetContext); await _unloadModel();
            }, child: const Text('Unload'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: _loadingModel ? null : () async {
              refresh(() {}); await _loadModel(); refresh(() {});
            }, style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: _bg),
              child: _loadingModel ? const Text('Loading…') : const Text('Load model'))),
          ]),
          const SizedBox(height: 12),
          Text(_status, style: const TextStyle(fontSize: 12, color: _muted)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFE7A2A2), fontSize: 12))),
        ]))),
      )),
    );
  }

  Widget _fileRow(String label, String? path, String expected, VoidCallback onPick) => Container(
    padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _bg, border: Border.all(color: _line), borderRadius: BorderRadius.circular(_radius)),
    child: Row(children: [
      const Icon(Icons.insert_drive_file_outlined, color: _accent),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        Text(path == null ? expected : path.split(Platform.pathSeparator).last,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 11)),
      ])),
      TextButton(onPressed: onPick, child: Text(path == null ? 'Choose' : 'Change')),
    ]),
  );
}

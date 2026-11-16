import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:llamadart/llamadart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'models/chat_thread.dart';
import 'repositories/chat_repository.dart';
import 'l10n/app_strings.dart';
import 'services/local_inference_service.dart';

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
        headlineMedium: TextStyle(
          fontSize: 29,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: _text,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: _text,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _text,
        ),
        bodyLarge: TextStyle(fontSize: 15, height: 1.55, color: _text),
        bodyMedium: TextStyle(fontSize: 13, height: 1.5, color: _muted),
        labelSmall: TextStyle(fontSize: 11, color: _muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _panel,
        hintStyle: const TextStyle(color: _muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: _accent),
        ),
      ),
    ),
    home: const ChatPage(),
  );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _chatRepository = ChatRepository();
  final _inferenceService = LocalInferenceService();
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
  String _language = 'en';
  int _contextLength = 4096;
  int _maxTokens = 512;
  int _threadsCount = 4;
  double _temperature = 0.7;
  StreamIterator<dynamic>? _generation;
  bool _stopRequested = false;

  String tr(String key) => AppStrings(_language)[key];

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('language') ?? 'en';
    _modelPath = prefs.getString('modelPath');
    _projectorPath = prefs.getString('projectorPath');
    _contextLength = prefs.getInt('context') ?? 4096;
    _maxTokens = prefs.getInt('maxTokens') ?? 512;
    _temperature = prefs.getDouble('temperature') ?? 0.7;
    _threadsCount = prefs.getInt('threads') ?? 4;
    _threads.addAll(await _chatRepository.loadThreads());
    if (mounted) setState(() {});
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _language);
    if (_modelPath != null) await prefs.setString('modelPath', _modelPath!);
    if (_projectorPath != null)
      await prefs.setString('projectorPath', _projectorPath!);
    await prefs.setInt('context', _contextLength);
    await prefs.setInt('maxTokens', _maxTokens);
    await prefs.setDouble('temperature', _temperature);
    await prefs.setInt('threads', _threadsCount);
    await _chatRepository.saveThreads(_threads);
  }

  Future<void> _chooseModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gguf'],
      allowMultiple: false,
      dialogTitle: tr('selectModel'),
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _modelPath = result.files.single.path;
      _error = null;
    });
    await _persist();
  }

  Future<void> _chooseProjector() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gguf'],
      allowMultiple: false,
      dialogTitle: tr('selectProjector'),
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _projectorPath = result.files.single.path;
      _error = null;
    });
    await _persist();
  }

  Future<void> _loadModel() async {
    if (_modelPath == null || _projectorPath == null) {
      setState(() => _error = tr('modelError'));
      return;
    }
    if (!await File(_modelPath!).exists() ||
        !await File(_projectorPath!).exists()) {
      setState(() => _error = tr('fileMissing'));
      return;
    }
    setState(() {
      _loadingModel = true;
      _error = null;
      _status = tr('loading');
    });
    try {
      final loaded = await _inferenceService.load(
        modelPath: _modelPath!,
        projectorPath: _projectorPath!,
        contextLength: _contextLength,
        cpuThreads: _threadsCount,
      );
      if (!mounted) {
        await loaded.dispose();
        return;
      }
      setState(() {
        _engine = loaded;
        for (final thread in _threads) {
          thread.session = null;
        }
        _active?.session = ChatSession(loaded)..systemPrompt = 'You are Hyper AI, a helpful offline study assistant. Help with school subjects including mathematics, physics, chemistry and geometry. Reply in the language the user uses (Turkish, English or Russian). Explain clearly and accurately.';
        _status = tr('ready');
      });
      await _persist();
    } catch (e) {
      if (mounted && !_stopRequested)
        setState(() {
          _status = tr('loadFailed');
          _error = e.toString();
        });
    } finally {
      if (mounted) setState(() => _loadingModel = false);
    }
  }

  Future<void> _unloadModel() async {
    if (_sending) await _stop();
    setState(() {
      _engine = null;
      _status = tr('unloading');
    });
    await _inferenceService.unload();
    if (mounted)
      setState(() {
        _status = tr('noModel');
        for (final t in _threads) {
          t.session = null;
        }
      });
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (file != null && mounted) setState(() => _image = file);
  }

  void _newChat() => setState(() {
    _active = null;
    _image = null;
    _error = null;
  });

  Future<void> _send() async {
    final prompt = _input.text.trim();
    if ((prompt.isEmpty && _image == null) || _sending) return;
    final engine = _engine;
    if (engine == null) {
      setState(() => _error = tr('notLoaded'));
      return;
    }
    final thread =
        _active ??
        ChatThread(
          prompt.isEmpty
              ? tr('imageQuestion')
              : (prompt.length > 34 ? '${prompt.substring(0, 34)}…' : prompt),
        );
    _threads.remove(thread);
    _threads.insert(0, thread);
    if (_active == null) _active = thread;
    final image = _image;
    final userText = prompt.isEmpty ? tr('explainImage') : prompt;
    setState(() {
      thread.messages.add(ChatMessage(userText, true, imagePath: image?.path));
      _input.clear();
      _image = null;
      _sending = true;
      _error = null;
    });
    thread.session ??= ChatSession(engine)..systemPrompt = 'You are Hyper AI, a helpful offline study assistant. Help with school subjects including mathematics, physics, chemistry and geometry. Reply in the language the user uses (Turkish, English or Russian). Explain clearly and accurately.';
    final answer = StringBuffer();
    thread.messages.add(ChatMessage('', false));
    try {
      final parts = <LlamaContentPart>[
        if (image != null) LlamaImageContent(path: image.path),
        LlamaTextContent(userText),
      ];
      _stopRequested = false;
      final iterator = StreamIterator<dynamic>(
        _inferenceService.generate(
          thread.session!,
          parts,
          maxTokens: _maxTokens,
          temperature: _temperature,
        ),
      );
      _generation = iterator;
      while (!_stopRequested && await iterator.moveNext()) {
        final chunk = iterator.current;
        answer.write(chunk.text);
        if (!mounted) return;
        setState(
          () => thread.messages.last = ChatMessage(answer.toString(), false),
        );
        _scrollToEnd();
      }
      await iterator.cancel();
    } catch (e) {
      if (mounted)
        setState(() {
          thread.messages.removeLast();
          _error = '${tr('failure')}: $e';
        });
    } finally {
      _generation = null;
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
      unawaited(_persist());
    }
  }

  Future<void> _stop() async {
    _stopRequested = true;
    await _generation?.cancel();
  }

  Future<void> _deleteThread(ChatThread thread) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('delete')),
        content: Text(tr('deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (yes != true) return;
    setState(() {
      _threads.remove(thread);
      if (_active == thread) _active = null;
    });
    await _persist();
  }

  Future<void> _renameThread(ChatThread thread) async {
    final controller = TextEditingController(text: thread.title);
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('rename')),
        content: TextField(controller: controller, maxLength: 70),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: Text(tr('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.isNotEmpty) {
      setState(() => thread.title = value);
      await _persist();
    }
  }

  Future<void> _messageAction(ChatMessage message, String action) async {
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text));
      return;
    }
    if (action == 'delete') {
      setState(() => _active!.messages.remove(message));
      await _persist();
      return;
    }
    final controller = TextEditingController(text: message.text);
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('edit')),
        content: TextField(controller: controller, maxLines: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: Text(tr('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      setState(() {
        message.text = result;
        final idx = _active!.messages.indexOf(message);
        if (idx + 1 < _active!.messages.length &&
            !_active!.messages[idx + 1].isUser)
          _active!.messages.removeRange(idx + 1, _active!.messages.length);
      });
      await _persist();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients)
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    unawaited(_engine?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    return Scaffold(
      drawer: wide ? null : Drawer(backgroundColor: _panel, child: _sidebar()),
      body: SafeArea(
        child: Row(
          children: [
            if (wide && _sidebarOpen) SizedBox(width: 270, child: _sidebar()),
            Expanded(
              child: Column(
                children: [
                  _header(wide),
                  Expanded(
                    child: _active == null || _active!.messages.isEmpty
                        ? _welcome()
                        : _chat(),
                  ),
                  _composer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(bool wide) => Container(
    height: 62,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: () {
            if (wide) {
              setState(() => _sidebarOpen = !_sidebarOpen);
            } else {
              Scaffold.of(context).openDrawer();
            }
          },
          icon: const Icon(PhosphorIconsRegular.list, color: _muted),
        ),
        const Text(
          'HYPER',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: _text,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'AI',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _accent,
          ),
        ),
        const Spacer(),
        _statusDot(),
        const SizedBox(width: 7),
        Text(
          _engine == null ? tr('noModel') : tr('ready'),
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: tr('model'),
          onPressed: _showSettings,
          icon: Icon(
            PhosphorIconsRegular.slidersHorizontal,
            color: _muted,
          ),
        ),
        IconButton(
          tooltip: tr('new'),
          onPressed: _newChat,
          icon: const Icon(PhosphorIconsRegular.plus, color: _accent),
        ),
      ],
    ),
  );

  Widget _statusDot() => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      color: _engine == null ? const Color(0xFFCFAB65) : _accent,
      shape: BoxShape.circle,
    ),
  );

  Widget _sidebar() => Container(
    color: const Color(0xFF131917),
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HYPER AI',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _newChat,
            icon: const Icon(PhosphorIconsRegular.plus, size: 18),
            label: Text(tr('new')),
            style: OutlinedButton.styleFrom(
              foregroundColor: _text,
              side: const BorderSide(color: _line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radius),
              ),
              alignment: Alignment.centerLeft,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          tr('history').toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: _muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _threads.isEmpty
              ? Text(
                  tr('empty'),
                  style: const TextStyle(fontSize: 12, color: _muted),
                )
              : ListView.builder(
                  itemCount: _threads.length,
                  itemBuilder: (context, i) {
                    final t = _threads[i];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(
                        PhosphorIconsRegular.chatCircle,
                        size: 17,
                        color: _muted,
                      ),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      selected: t == _active,
                      selectedTileColor: _panel2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_radius),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'rename') _renameThread(t);
                          if (v == 'delete') _deleteThread(t);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text(tr('rename')),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(tr('delete')),
                          ),
                        ],
                      ),
                      onTap: () => setState(() {
                        _active = t;
                        if (_engine != null && t.session == null) {
                          t.session = ChatSession(_engine!);
                        }
                      }),
                    );
                  },
                ),
        ),
        const Divider(color: _line),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(PhosphorIconsRegular.brain, color: _accent),
          title: Text(tr('mainModel'), style: const TextStyle(fontSize: 13)),
          subtitle: Text(
            _engine == null ? tr('noModel') : tr('ready'),
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
          onTap: _showSettings,
        ),
      ],
    ),
  );

  Widget _welcome() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _panel2,
                borderRadius: BorderRadius.circular(_radius),
              ),
              child: const Icon(PhosphorIconsRegular.sparkle, color: _accent, size: 24),
            ),
            const SizedBox(height: 26),
            Text(
              tr('welcome'),
              style: const TextStyle(
                fontSize: 34,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tr('offlinePrompt'),
              style: const TextStyle(fontSize: 15, height: 1.6, color: _muted),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _panel,
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(_radius),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.brain, color: _accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('setup'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          tr('choosePair'),
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _showSettings,
                    child: Text(tr('setupAction')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr('learning').toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
                        'mathematics',
                        'physics',
                        'chemistry',
                        'geometry',
                        'languages',
                      ]
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _panel,
                            border: Border.all(color: _line),
                            borderRadius: BorderRadius.circular(_radius),
                          ),
                          child: Text(
                            tr(s),
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _chat() => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
    itemCount: _active!.messages.length,
    itemBuilder: (context, index) {
      final m = _active!.messages[index];
      return Align(
        alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          margin: const EdgeInsets.only(bottom: 18),
          padding: EdgeInsets.symmetric(
            horizontal: m.isUser ? 15 : 4,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: m.isUser ? _panel2 : Colors.transparent,
            border: m.isUser
                ? Border.all(color: _line)
                : const Border(left: BorderSide(color: _accent, width: 2)),
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.imagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(_radius),
                  child: Image.file(
                    File(m.imagePath!),
                    height: 170,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 9),
              ],
              if (m.text.isEmpty && !m.isUser)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accent,
                  ),
                )
              else
                Text(m.text, style: Theme.of(context).textTheme.bodyLarge),
              if (!_sending)
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<String>(
                    tooltip: tr('messageActions'),
                    onSelected: (action) => _messageAction(m, action),
                    itemBuilder: (_) => [
                      if (m.isUser)
                        PopupMenuItem(value: 'edit', child: Text(tr('edit'))),
                      PopupMenuItem(value: 'copy', child: Text(tr('copy'))),
                      PopupMenuItem(value: 'delete', child: Text(tr('delete'))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _composer() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            if (_image != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InputChip(
                    label: Text(_image!.name),
                    avatar: const Icon(PhosphorIconsRegular.image, size: 17),
                    onDeleted: () => setState(() => _image = null),
                  ),
                ),
              ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFE7A2A2),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: tr('addImage'),
                  onPressed: _sending ? null : _pickImage,
                  icon: const Icon(
                    PhosphorIconsRegular.imagePlus,
                    color: _muted,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 6,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: tr('send'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? _stop : _send,
                  style: IconButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _bg,
                  ),
                  tooltip: _sending ? tr('stop') : tr('send'),
                  icon: _sending
                      ? const Icon(PhosphorIconsRegular.stop)
                      : const Icon(PhosphorIconsRegular.arrowUp),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr('offline'),
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ],
        ),
      ),
    ),
  );

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_radius)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            22,
            22,
            MediaQuery.viewInsetsOf(context).bottom + 26,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('model'),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('selectPair'),
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  _fileRow(
                    tr('mainModel'),
                    _modelPath,
                    'Qwen3.5-4B-Q4_K_M.gguf',
                    _chooseModel,
                  ),
                  const SizedBox(height: 12),
                  _fileRow(
                    tr('projector'),
                    _projectorPath,
                    'mmproj-qwen3.5-4b-f16.gguf',
                    _chooseProjector,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    tr('language'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  DropdownButton<String>(
                    value: _language,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                      DropdownMenuItem(value: 'ru', child: Text('Русский')),
                    ],
                    onChanged: (v) async {
                      if (v != null) {
                        setState(() => _language = v);
                        await _persist();
                        refresh(() {});
                      }
                    },
                  ),
                  Text('${tr('context')}: $_contextLength'),
                  Slider(
                    value: _contextLength.toDouble(),
                    min: 2048,
                    max: 8192,
                    divisions: 3,
                    label: '$_contextLength',
                    onChanged: (v) {
                      refresh(() => _contextLength = v.round());
                      unawaited(_persist());
                    },
                  ),
                  Text(
                    '${tr('temperature')}: ${_temperature.toStringAsFixed(1)}',
                  ),
                  Slider(
                    value: _temperature,
                    min: 0,
                    max: 1.5,
                    divisions: 15,
                    onChanged: (v) {
                      refresh(() => _temperature = v);
                      unawaited(_persist());
                    },
                  ),
                  Text('${tr('maxTokens')}: $_maxTokens'),
                  Slider(
                    value: _maxTokens.toDouble(),
                    min: 128,
                    max: 1024,
                    divisions: 7,
                    onChanged: (v) {
                      refresh(() => _maxTokens = v.round());
                      unawaited(_persist());
                    },
                  ),
                  Text('${tr('cpuThreads')}: $_threadsCount'),
                  Slider(
                    value: _threadsCount.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    onChanged: (v) {
                      refresh(() => _threadsCount = v.round());
                      unawaited(_persist());
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _engine == null || _loadingModel
                              ? null
                              : () async {
                                  Navigator.pop(sheetContext);
                                  await _unloadModel();
                                },
                          child: Text(tr('unload')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _loadingModel
                              ? null
                              : () async {
                                  refresh(() {});
                                  await _loadModel();
                                  refresh(() {});
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: _bg,
                          ),
                          child: _loadingModel
                              ? Text(tr('loading'))
                              : Text(tr('load')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFE7A2A2),
                          fontSize: 12,
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

  Widget _fileRow(
    String label,
    String? path,
    String expected,
    VoidCallback onPick,
  ) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _bg,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(_radius),
    ),
    child: Row(
      children: [
        const Icon(PhosphorIconsRegular.file, color: _accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                path == null
                    ? expected
                    : path.split(Platform.pathSeparator).last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onPick,
          child: Text(path == null ? tr('choose') : tr('change')),
        ),
      ],
    ),
  );
}


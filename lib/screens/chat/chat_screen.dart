import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../core/session.dart';
import '../../data/chat_repository.dart';
import '../../data/repository.dart';
import '../../i18n/chat_strings.dart';
import '../../i18n/strings.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// The encrypted doctor–patient chat for one appointment — the same thread the
/// website's ChatPanel reads and writes.
///
/// Opening it does what the website's "Open chat" button does: it asks the
/// server to start the session first (which is where the join window is
/// enforced and where the patient is told the doctor has opened it early),
/// then fetches the thread key and subscribes to the messages.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.appointment, this.asHost = false});

  final Appointment appointment;

  /// True for the doctor (or admin): may open the session before its time,
  /// and sees the patient's name in the header.
  final bool asHost;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum _Phase { starting, ready, closed, failed }

class _ChatScreenState extends State<ChatScreen> {
  late final ChatRepository _chat = ChatRepository(threadId: widget.appointment.id);
  final Repository _repo = Repository();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  StreamSubscription<List<ChatMessage>>? _sub;
  late Appointment _appointment = widget.appointment;

  _Phase _phase = _Phase.starting;
  Object? _error;
  String? _closedReason;
  List<ChatMessage> _messages = const [];
  bool _loadedOnce = false;
  bool _sending = false;
  bool _showJump = false;

  /// How far from the newest message still counts as "reading the latest".
  static const _stickThreshold = 120.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    _chat.close();
    _repo.close();
    super.dispose();
  }

  bool get _nearLatest => !_scroll.hasClients || _scroll.offset <= _stickThreshold;

  void _onScroll() {
    if (_showJump && _nearLatest) setState(() => _showJump = false);
  }

  Future<void> _start() async {
    await _sub?.cancel();
    _sub = null;
    if (!mounted) return;
    setState(() {
      _phase = _Phase.starting;
      _error = null;
      _closedReason = null;
    });

    final reason = ChatAccess.closedReason(_appointment, asHost: widget.asHost);
    if (reason != null) {
      setState(() {
        _phase = _Phase.closed;
        _closedReason = reason;
      });
      return;
    }

    try {
      // The website opens the panel only after this succeeds. It marks the
      // session live, and the server refuses a patient who is too early.
      final result = await _repo.startSession(_appointment.id);
      if (!mounted) return;
      _appointment = result.appointment;
      await _chat.key();
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = e;
      });
      return;
    }

    _sub = _chat.messages().listen(
      _onMessages,
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.failed;
          _error = e;
        });
      },
    );
    setState(() => _phase = _Phase.ready);
  }

  void _onMessages(List<ChatMessage> list) {
    if (!mounted) return;
    final previousLatest = _messages.isEmpty ? null : _messages.last.id;
    final latest = list.isEmpty ? null : list.last;
    final isNew = latest != null && latest.id != previousLatest;
    final mine = latest != null && latest.senderId == _chat.viewerUid;
    final stick = _nearLatest;

    setState(() {
      _messages = list;
      // The first snapshot is the history: it lands at the bottom without a
      // "latest" nudge.
      if (_loadedOnce && isNew && !mine && !stick) _showJump = true;
      _loadedOnce = true;
    });

    if (isNew && (mine || stick)) _jumpToLatest();
  }

  void _jumpToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
    if (_showJump) setState(() => _showJump = false);
  }

  String _viewerRole() {
    final uid = _chat.viewerUid;
    switch (context.read<Session>().role) {
      case Role.patient:
        return 'patient';
      case Role.doctor:
        return 'doctor';
      case Role.admin:
        return 'admin';
      case Role.unknown:
        if (uid != null && uid == _appointment.patientId) return 'patient';
        if (uid != null && uid == _appointment.doctorId) return 'doctor';
        return widget.asHost ? 'doctor' : 'patient';
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || _phase != _Phase.ready) return;
    setState(() => _sending = true);
    try {
      await _chat.send(text, senderRole: _viewerRole());
      if (!mounted) return;
      _input.clear();
      _jumpToLatest();
    } catch (_) {
      if (mounted) showToast(context, ChatStrings.t('chat.sendError'), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _senderName(ChatMessage m) {
    if (m.senderId == _chat.viewerUid) return ChatStrings.t('chat.you');
    switch (m.senderRole) {
      case 'patient':
        return _appointment.patientName.isNotEmpty
            ? _appointment.patientName
            : ChatStrings.t('chat.patient');
      case 'doctor':
        final name = _appointment.doctorName;
        return name != null && name.isNotEmpty ? name : ChatStrings.t('chat.doctor');
      default:
        return ChatStrings.t('chat.clinic');
    }
  }

  String _timeLabel(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final now = DateTime.now();
    final today = local.year == now.year && local.month == now.month && local.day == now.day;
    if (today) {
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return Fmt.time('$hh:$mm');
    }
    return Fmt.stamp(local.toUtc().toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds on a language switch; ChatStrings reads the static locale.
    context.watch<LocaleController>();
    final a = _appointment;
    final title = widget.asHost
        ? (a.patientName.isNotEmpty ? a.patientName : ChatStrings.t('chat.title'))
        : ((a.doctorName ?? '').isNotEmpty ? a.doctorName! : ChatStrings.t('chat.title'));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              a.service,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const _EncryptedNotice(),
            Expanded(child: _body()),
            if (_phase == _Phase.ready) _composer(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.starting:
        return _centered(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(
                ChatStrings.t('chat.unlocking'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
              ),
            ],
          ),
        );
      case _Phase.closed:
        return _centered(
          EmptyState(
            icon: Icons.lock_clock_outlined,
            title: _closedReason ?? ChatStrings.t('chat.closed.notYet'),
          ),
        );
      case _Phase.failed:
        return _centered(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: Palette.inkSoft),
              const SizedBox(height: 14),
              Text(
                ChatStrings.t('chat.loadError'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  errorText(_error!),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _start,
                child: Text(ChatStrings.t('chat.retry')),
              ),
            ],
          ),
        );
      case _Phase.ready:
        if (!_loadedOnce) {
          return _centered(const CircularProgressIndicator());
        }
        if (_messages.isEmpty) {
          return _centered(
            EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: ChatStrings.t('chat.empty'),
              message: ChatStrings.t('chat.emptySub'),
            ),
          );
        }
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Palette.paperDim,
                child: ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    // Reversed: index 0 is the newest, at the bottom.
                    final m = _messages[_messages.length - 1 - i];
                    return _Bubble(
                      key: ValueKey(m.id),
                      text: m.text,
                      sender: _senderName(m),
                      time: _timeLabel(m.sentAt),
                      mine: m.senderId == _chat.viewerUid,
                      pending: m.pending,
                    );
                  },
                ),
              ),
            ),
            if (_showJump)
              PositionedDirectional(
                end: 12,
                bottom: 12,
                child: FilledButton.icon(
                  onPressed: _jumpToLatest,
                  icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                  label: Text(ChatStrings.t('chat.jumpToLatest')),
                ),
              ),
          ],
        );
    }
  }

  Widget _centered(Widget child) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: child,
        ),
      );

  Widget _composer() {
    return Container(
      decoration: const BoxDecoration(
        color: Palette.paper,
        border: Border(top: BorderSide(color: Palette.line)),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focus,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: ChatStrings.t('chat.placeholder'),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _input,
            builder: (context, value, _) {
              final canSend = value.text.trim().isNotEmpty && !_sending;
              return IconButton.filled(
                tooltip: ChatStrings.t(_sending ? 'chat.sending' : 'chat.send'),
                onPressed: canSend ? _send : null,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Palette.paper),
                      )
                    // Mirrors itself in Urdu, so the arrow points the way the
                    // text runs.
                    : const Icon(Icons.send_rounded, size: 20),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EncryptedNotice extends StatelessWidget {
  const _EncryptedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Palette.warningSoft,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 16, color: Palette.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ChatStrings.t('chat.encrypted'),
              style: const TextStyle(fontSize: 12, height: 1.45, color: Palette.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.text,
    required this.sender,
    required this.time,
    required this.mine,
    required this.pending,
  });

  final String text;
  final String sender;
  final String time;
  final bool mine;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Palette.paper : Palette.ink;
    final meta = mine ? Palette.paper.withValues(alpha: 0.78) : Palette.inkSoft;
    const r = Radius.circular(16);
    const tail = Radius.circular(4);

    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsetsDirectional.only(bottom: 8),
          padding: const EdgeInsetsDirectional.fromSTEB(13, 8, 13, 7),
          decoration: BoxDecoration(
            color: mine ? Palette.indigo : Palette.paper,
            border: mine ? null : Border.all(color: Palette.line),
            borderRadius: BorderRadiusDirectional.only(
              topStart: r,
              topEnd: r,
              bottomStart: mine ? r : tail,
              bottomEnd: mine ? tail : r,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sender,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: meta),
              ),
              const SizedBox(height: 2),
              SelectableText(
                text,
                style: TextStyle(fontSize: 14.5, height: 1.45, color: fg),
              ),
              const SizedBox(height: 3),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                widthFactor: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(time, style: TextStyle(fontSize: 10.5, color: meta)),
                    if (mine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        pending ? Icons.schedule_rounded : Icons.done_rounded,
                        size: 12,
                        color: meta,
                      ),
                    ],
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

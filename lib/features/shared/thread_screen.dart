// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/input_rules.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../data/app_store.dart';
import '../../data/models/models.dart';
import '../../services/app_services.dart';
import '../../widgets/common.dart';

/// A private conversation between a student and their class educator.
/// Access is checked here as well as in the router: a student may only
/// message their own educator, and an educator only their own students.
class ThreadScreen extends StatefulWidget {
  const ThreadScreen({super.key, required this.peerId});
  final String peerId;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.services;
      final u = s.auth.user;
      if (u != null && _peerName(s.store, u) != null) {
        unawaited(s.store.markThreadRead(u.id, widget.peerId));
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String? _peerName(AppStore store, SessionUser u) {
    if (u.role == Role.student) {
      final edu = store.educatorFor(u.classCode ?? '');
      return edu != null && edu.id == widget.peerId ? edu.name : null;
    }
    if (u.role == Role.educator) {
      final st = store.studentById(widget.peerId);
      return st != null && st.classCode == u.classCode ? st.name : null;
    }
    return null;
  }

  Future<void> _send(SessionUser u, String peerName) async {
    final body = InputRules.clean(_input.text);
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await context.services.store.sendMessage(from: u, toId: widget.peerId, toName: peerName, body: body);
      _input.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
              duration: context.motion(AqMotion.medium) == Duration.zero ? const Duration(milliseconds: 1) : AqMotion.medium,
              curve: Curves.easeOut);
        }
      });
    } on ActionRefused catch (e) {
      if (mounted) context.toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final u = s.auth.user;
    final peerName = u == null ? null : _peerName(s.store, u);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(peerName ?? 'Conversation'),
      ),
      body: u == null || peerName == null
          ? const EmptyState(
              icon: Icons.lock_outline,
              title: 'Conversation not available',
              message: 'You can only message people in your own group.',
            )
          : Column(
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: s.store,
                    builder: (context, _) {
                      final msgs = s.store.thread(u.id, widget.peerId);
                      if (msgs.isEmpty) {
                        return EmptyState(
                          icon: Icons.forum_outlined,
                          title: 'Start the conversation',
                          message: u.role == Role.student
                              ? 'Ask $peerName a question about a lesson, a task or a pickup.'
                              : 'Send $peerName a note. They will see it on their home screen.',
                        );
                      }
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: msgs.length,
                            itemBuilder: (context, i) => _Bubble(message: msgs[i], mine: msgs[i].fromId == u.id),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: InputRules.maxMessage,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(hintText: 'Write a message', counterText: ''),
                            onSubmitted: (_) => _send(u, peerName),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          tooltip: 'Send',
                          onPressed: _sending ? null : () => _send(u, peerName),
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final DirectMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bg = mine ? scheme.primary : scheme.surface;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      label: '${mine ? 'You' : message.fromName}, ${Fmt.relative(message.sentAt)}: ${message.body}',
      child: ExcludeSemantics(
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: bg,
                border: mine ? null : Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.body, style: text.bodyLarge?.copyWith(color: fg)),
                  const SizedBox(height: 4),
                  Text(Fmt.relative(message.sentAt), style: text.labelSmall?.copyWith(color: fg.withValues(alpha: 0.75))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

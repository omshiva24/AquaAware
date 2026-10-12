import 'package:flutter/material.dart';

import '../core/security/input_rules.dart';
import 'common.dart';

class ComposeResult {
  const ComposeResult({required this.text, this.urgent = false, this.audience});
  final String text;
  final bool urgent;
  final String? audience;
}

/// One composer for announcements, broadcasts and direct messages.
/// Input is cleaned and length-limited before it leaves this sheet.
Future<ComposeResult?> showComposer(
  BuildContext context, {
  required String title,
  required String hint,
  required String submitLabel,
  String initial = '',
  bool allowUrgent = false,
  List<(String, String)> audiences = const [],
  String? note,
}) {
  return showModalBottomSheet<ComposeResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ComposerSheet(
      title: title,
      hint: hint,
      submitLabel: submitLabel,
      initial: initial,
      allowUrgent: allowUrgent,
      audiences: audiences,
      note: note,
    ),
  );
}

class _ComposerSheet extends StatefulWidget {
  const _ComposerSheet({
    required this.title,
    required this.hint,
    required this.submitLabel,
    required this.initial,
    required this.allowUrgent,
    required this.audiences,
    this.note,
  });
  final String title;
  final String hint;
  final String submitLabel;
  final String initial;
  final bool allowUrgent;
  final List<(String, String)> audiences;
  final String? note;

  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _text = TextEditingController(text: widget.initial);
  bool _urgent = false;
  late String? _audience = widget.audiences.isEmpty ? null : widget.audiences.first.$1;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(ComposeResult(
      text: InputRules.clean(_text.text),
      urgent: _urgent,
      audience: _audience,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(header: true, child: Text(widget.title, style: text.titleLarge)),
              if (widget.note != null) ...[
                const SizedBox(height: 6),
                Text(widget.note!, style: text.bodySmall),
              ],
              const SizedBox(height: 16),
              if (widget.audiences.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: _audience,
                  decoration: const InputDecoration(labelText: 'Send to', prefixIcon: Icon(Icons.groups_outlined)),
                  items: [
                    for (final a in widget.audiences) DropdownMenuItem(value: a.$1, child: Text(a.$2)),
                  ],
                  onChanged: (v) => setState(() => _audience = v),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _text,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                maxLength: InputRules.maxMessage,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: widget.hint, alignLabelWithHint: true),
                validator: (v) => InputRules.validateRequired(v, 'a message'),
              ),
              if (widget.allowUrgent) ...[
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _urgent,
                  onChanged: (v) => setState(() => _urgent = v),
                  title: const Text('Urgent'),
                  subtitle: const Text(
                    'Urgent notices alert students straight away. Others are held quietly during class hours (8 am – 3 pm).',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              BusyButton(label: widget.submitLabel, icon: Icons.send_rounded, onPressed: () async => _submit()),
            ],
          ),
        ),
      ),
    );
  }
}

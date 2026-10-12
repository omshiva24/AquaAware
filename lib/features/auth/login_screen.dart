import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/security/input_rules.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/seed/community_seed.dart';
import '../../services/app_services.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/reservoir.dart';

/// Demo credentials are shown so the pilot can be evaluated. Build with
/// `--dart-define=AQUA_HIDE_DEMO=true` to remove the panel.
const bool kShowDemoAccounts = !bool.fromEnvironment('AQUA_HIDE_DEMO');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _pin = TextEditingController();
  final _email = TextEditingController();
  final _secret = TextEditingController();
  Role _role = Role.student;
  String? _ngoId;
  String? _error;
  bool _showSecret = false;
  QuickUnlockInfo? _quick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuick());
  }

  Future<void> _loadQuick() async {
    final info = await context.services.auth.quickUnlockInfo();
    if (mounted) setState(() => _quick = info);
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _pin, _email, _secret]) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  void _setRole(Role r) {
    if (r == _role) return;
    setState(() {
      _role = r;
      _error = null;
      _secret.clear();
      _pin.clear();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _error = null);
    final auth = context.services.auth;
    final AuthResult r;
    switch (_role) {
      case Role.student:
        r = await auth.signInStudent(name: _name.text, classCode: _code.text, pin: _pin.text);
      case Role.ngo:
        r = await auth.signInWithSecret(role: Role.ngo, loginId: _ngoId ?? '', secret: _secret.text);
      case Role.educator:
      case Role.manager:
        r = await auth.signInWithSecret(role: _role, loginId: _email.text, secret: _secret.text);
    }
    if (!mounted) return;
    if (!r.ok) {
      _secret.clear();
      _pin.clear();
      setState(() => _error = r.message);
      context.announce(r.message ?? 'Sign-in failed');
      return;
    }
    TextInput.finishAutofillContext();
    if (r.newProfile) {
      context.toast('Welcome to AquaAware! Remember your PIN — you will need it next time.');
    }
  }

  Future<void> _quickUnlock() async {
    final r = await context.services.auth.quickUnlock();
    if (!mounted || r.ok) return;
    setState(() => _error = r.message);
  }

  void _useDemo(Role role, {String? email, String? secret, String? ngoId, String? name, String? code}) {
    _setRole(role);
    setState(() {
      if (email != null) _email.text = email;
      if (secret != null) _secret.text = secret;
      if (ngoId != null) _ngoId = ngoId;
      if (name != null) _name.text = name;
      if (code != null) _code.text = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final reason = context.services.auth.signedOutReason;
    final form = _buildForm(context, reason);

    if (wide) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 5, child: _SeaPanel(tall: true)),
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: form),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _SeaPanel(tall: false)),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), child: form),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, String? reason) {
    final text = Theme.of(context).textTheme;
    return RiseIn(
      delay: const Duration(milliseconds: 250),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reason != null) ...[
                InfoNote(reason, tone: Tone.warning, icon: Icons.lock_clock_outlined),
                const SizedBox(height: 16),
              ],
              Semantics(header: true, child: Text('Sign in', style: text.headlineMedium)),
              const SizedBox(height: 4),
              Text('Choose who you are, then enter your details.', style: text.bodyMedium),
              const SizedBox(height: 16),
              _RolePicker(selected: _role, onChanged: _setRole),
              const SizedBox(height: 20),
              ..._fieldsFor(context),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: InfoNote(_error!, tone: Tone.danger)),
              ],
              const SizedBox(height: 20),
              BusyButton(
                label: _role == Role.student ? 'Join my class' : 'Sign in',
                busyLabel: 'Checking securely…',
                icon: _role == Role.student ? Icons.school_outlined : Icons.login,
                onPressed: _submit,
              ),
              if (_quick != null && _role != Role.student) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _quickUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: Text('Unlock as ${_quick!.name}'),
                ),
              ],
              if (_role == Role.educator) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _openRegister(context),
                  child: const Text('New educator? Register your class'),
                ),
              ],
              if (kShowDemoAccounts) ...[
                const SizedBox(height: 16),
                _DemoAccounts(onUse: _useDemo),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fieldsFor(BuildContext context) {
    const gap = SizedBox(height: 14);
    final secretField = TextFormField(
      controller: _secret,
      obscureText: !_showSecret,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: _role == Role.ngo ? 'Access code' : 'Password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _showSecret ? 'Hide' : 'Show',
          icon: Icon(_showSecret ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _showSecret = !_showSecret),
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Enter your ${_role == Role.ngo ? 'access code' : 'password'}.' : null,
    );

    switch (_role) {
      case Role.student:
        return [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
            validator: InputRules.validatePersonName,
          ),
          gap,
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
              LengthLimitingTextInputFormatter(16),
            ],
            decoration: const InputDecoration(
              labelText: 'Class code',
              hintText: 'AWA-2024-GHS',
              prefixIcon: Icon(Icons.qr_code_2),
            ),
            validator: InputRules.validateClassCode,
          ),
          gap,
          TextFormField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: const InputDecoration(
              labelText: '4-digit PIN',
              prefixIcon: Icon(Icons.password),
              helperText: 'First time here? The PIN you choose now becomes yours.',
              helperMaxLines: 2,
            ),
            validator: InputRules.validatePin,
          ),
        ];
      case Role.ngo:
        return [
          DropdownButtonFormField<String>(
            // initialValue is read once; the key rebuilds the field when the
            // demo panel fills in a different organisation.
            key: ValueKey('ngo-${_ngoId ?? 'none'}'),
            initialValue: _ngoId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Organisation', prefixIcon: Icon(Icons.volunteer_activism_outlined)),
            items: [
              for (final n in CommunitySeed.ngos)
                DropdownMenuItem(value: n.id, child: Text(n.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _ngoId = v),
            validator: (v) => v == null ? 'Choose your organisation.' : null,
          ),
          gap,
          secretField,
        ];
      case Role.educator:
      case Role.manager:
        return [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _role == Role.manager ? 'Admin email' : 'School email',
              prefixIcon: const Icon(Icons.alternate_email),
            ),
            validator: InputRules.validateEmail,
          ),
          gap,
          secretField,
        ];
    }
  }

  Future<void> _openRegister(BuildContext context) async {
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _RegisterSheet(),
    );
    if (email != null && mounted) {
      setState(() {
        _email.text = email;
        _secret.clear();
      });
    }
  }
}

/// The deep-water header with the letter-by-letter wordmark (kept from the
/// first version) rising out of the sea.
class _SeaPanel extends StatelessWidget {
  const _SeaPanel({required this.tall});
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final text = Theme.of(context).textTheme;
    final word = 'AquaAware'.split('');
    final content = Padding(
      padding: EdgeInsets.fromLTRB(28, tall ? 0 : MediaQuery.paddingOf(context).top + 36, 28, tall ? 0 : 18),
      child: Column(
        mainAxisAlignment: tall ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.water_drop, color: AqColors.shallows, size: 40),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            label: 'AquaAware',
            child: ExcludeSemantics(
              child: Wrap(
                children: [
                  for (var i = 0; i < word.length; i++)
                    RiseIn(
                      delay: Duration(milliseconds: 60 * i),
                      offset: 22,
                      child: Text(
                        word[i],
                        style: (tall ? text.displayLarge : text.displayMedium)?.copyWith(color: Colors.white, height: 1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          RiseIn(
            delay: const Duration(milliseconds: 600),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                'Learn about water, act on waste, and watch your school’s reservoir rise.',
                style: text.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.88), fontWeight: FontWeight.w500),
              ),
            ),
          ),
          if (tall) ...[
            const SizedBox(height: 28),
            Text(
              'A Pondicherry schools programme with partner NGOs.',
              style: text.bodyMedium?.copyWith(color: AqColors.shallows),
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B2230), AqColors.tideDeep, AqColors.tide],
        ),
      ),
      child: Column(
        mainAxisSize: tall ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (tall) Expanded(child: content) else content,
          WaveHorizon(color: bg, height: tall ? 64 : 40),
        ],
      ),
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.selected, required this.onChanged});
  final Role selected;
  final ValueChanged<Role> onChanged;

  static const _info = <Role, (IconData, String, String)>{
    Role.student: (Icons.school_outlined, 'Student', 'Join with your class code'),
    Role.educator: (Icons.co_present_outlined, 'Educator', 'Run your class'),
    Role.ngo: (Icons.volunteer_activism_outlined, 'NGO desk', 'Broadcast and hand out rewards'),
    Role.manager: (Icons.admin_panel_settings_outlined, 'Manager', 'Oversee the programme'),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 520 ? 4 : 2;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final r in Role.values)
            SizedBox(
              width: w,
              child: Semantics(
                selected: r == selected,
                button: true,
                inMutuallyExclusiveGroup: true,
                label: '${_info[r]!.$2}. ${_info[r]!.$3}',
                // ExcludeSemantics below hides the InkWell's own tap action,
                // so the tap must be exposed here or screen-reader users
                // (TalkBack, VoiceOver) cannot choose a role.
                onTap: () => onChanged(r),
                child: ExcludeSemantics(
                  child: Material(
                    color: r == selected ? scheme.primaryContainer : scheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AqRadius.card),
                      side: BorderSide(
                        color: r == selected ? scheme.primary : scheme.outlineVariant,
                        width: r == selected ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AqRadius.card),
                      onTap: () => onChanged(r),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_info[r]!.$1, color: r == selected ? scheme.primary : scheme.onSurfaceVariant),
                                const Spacer(),
                                if (r == selected) Icon(Icons.check_circle, size: 18, color: scheme.primary),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(_info[r]!.$2, style: text.titleSmall),
                            const SizedBox(height: 2),
                            Text(_info[r]!.$3, style: text.bodySmall, maxLines: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

typedef _DemoUse = void Function(Role role, {String? email, String? secret, String? ngoId, String? name, String? code});

class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts({required this.onUse});
  final _DemoUse onUse;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget row(String who, String detail, VoidCallback use) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(who),
          subtitle: Text(detail),
          trailing: TextButton(onPressed: use, child: const Text('Fill in')),
        );
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.science_outlined),
        title: const Text('Try a demo account'),
        subtitle: Text('For evaluating the pilot only', style: text.bodySmall),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          row('Student · Priya', 'Class AWA-2024-GHS · choose any 4-digit PIN the first time',
              () => onUse(Role.student, name: 'Priya', code: 'AWA-2024-GHS')),
          row('Educator · Mrs. Kavitha', 'kavitha@aquaaware.org · Kavitha#2026',
              () => onUse(Role.educator, email: 'kavitha@aquaaware.org', secret: 'Kavitha#2026')),
          row('Educator · Mr. Rajan', 'rajan@aquaaware.org · Rajan#2026',
              () => onUse(Role.educator, email: 'rajan@aquaaware.org', secret: 'Rajan#2026')),
          row('NGO desk · Pondicherry Science Forum', 'Access code PSF-GREEN-2026',
              () => onUse(Role.ngo, ngoId: 'NGO001', secret: 'PSF-GREEN-2026')),
          row('Manager', 'admin@aquaaware.org · Manager#2026!',
              () => onUse(Role.manager, email: 'admin@aquaaware.org', secret: 'Manager#2026!')),
        ],
      ),
    );
  }
}

class _RegisterSheet extends StatefulWidget {
  const _RegisterSheet();

  @override
  State<_RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<_RegisterSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _school = TextEditingController();
  final _city = TextEditingController(text: 'Pondicherry');
  String _title = 'Mrs.';
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _school, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final r = await context.services.auth.registerEducator(
      name: '$_title ${_name.text.trim()}',
      email: _email.text,
      password: _password.text,
      school: _school.text,
      city: _city.text,
    );
    if (!mounted) return;
    if (!r.ok) {
      setState(() => _error = r.message);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline),
        title: const Text('Your class is ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this class code with your students. They join with it and a PIN they choose.'),
            const SizedBox(height: 16),
            SelectableText(r.classCode ?? '', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: r.classCode ?? '')),
            child: const Text('Copy code'),
          ),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(_email.text.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final score = InputRules.passwordScore(_password.text);
    final scheme = Theme.of(context).colorScheme;
    final strengthLabels = ['Too weak', 'Weak', 'Fair', 'Strong', 'Very strong'];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text('Register your class', style: text.titleLarge)),
                const SizedBox(height: 4),
                Text('A class code is created for your school. Manager and NGO accounts are set up by the programme team.',
                    style: text.bodySmall),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in const ['Mr.', 'Mrs.', 'Ms.', 'Dr.'])
                      ChoiceChip(label: Text(t), selected: _title == t, onSelected: (_) => setState(() => _title = t)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)),
                  validator: InputRules.validatePersonName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'School email', prefixIcon: Icon(Icons.alternate_email)),
                  validator: InputRules.validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'Create a password',
                    helperText: 'At least 10 characters. A short sentence works well.',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: InputRules.validateNewPassword,
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Password strength: ${strengthLabels[score]}',
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        for (var i = 0; i < 4; i++)
                          Expanded(
                            child: AnimatedContainer(
                              duration: context.motion(AqMotion.fast),
                              height: 6,
                              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                              decoration: BoxDecoration(
                                color: i < score
                                    ? (score >= 3 ? scheme.tertiary : scheme.secondary)
                                    : scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Text(_password.text.isEmpty ? '' : strengthLabels[score], style: text.labelMedium),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _school,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'School name', prefixIcon: Icon(Icons.apartment_outlined)),
                  validator: (v) => InputRules.validateRequired(v, 'the school name', max: InputRules.maxTitle),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city_outlined)),
                  validator: (v) => InputRules.validateRequired(v, 'the city', max: 40),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  InfoNote(_error!, tone: Tone.danger),
                ],
                const SizedBox(height: 18),
                BusyButton(label: 'Create class', busyLabel: 'Securing your account…', icon: Icons.add_home_work_outlined, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

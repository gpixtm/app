import 'localization.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import '../application/app_controller.dart';
import 'app.dart';
import 'design.dart';

/// A fresh Navigator on every account transition removes every protected route.
class AuthShell extends StatefulWidget {
  const AuthShell({
    required this.auth,
    required this.openLibrary,
    required this.closeLibrary,
    this.decideLegacyImport,
    this.localeController,
    this.initialIdentifier = '',
    this.initialPassword = '',
    super.key,
  });
  final AuthController auth;
  final Future<AppController> Function(AuthSession) openLibrary;
  final Future<void> Function() closeLibrary;
  final Future<void> Function(AuthSession, bool)? decideLegacyImport;
  final LocaleController? localeController;
  final String initialIdentifier, initialPassword;
  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  StreamSubscription<void>? subscription;
  AppController? library;
  String? account;
  Object? failure;
  AuthSession? legacyDecision;
  bool decidingLegacy = false;
  int generation = 0;
  Future<void> transition = Future.value();
  @override
  void initState() {
    super.initState();
    subscription = widget.auth.changes.stream.listen((_) => changed());
    changed();
  }

  void changed() {
    final session = widget.auth.session;
    final next = session?.user.id;
    if (next == account) {
      if (mounted) setState(() {});
      return;
    }
    account = next;
    final current = ++generation;
    library = null;
    failure = null;
    legacyDecision = null;
    if (mounted) setState(() {});
    transition = transition.catchError((Object _) {}).then((_) async {
      try {
        await widget.closeLibrary();
        if (!mounted || current != generation || session == null) return;
        final opened = await widget.openLibrary(session);
        if (mounted && current == generation) setState(() => library = opened);
      } on LegacyLibraryConsentRequired {
        if (mounted && current == generation) {
          setState(() => legacyDecision = session);
        }
      } catch (_) {
        if (mounted && current == generation) {
          setState(() => failure = AppMessage.libraryOpenFailed);
        }
      }
    });
  }

  Future<void> decideLegacy(bool adopt) async {
    final session = legacyDecision;
    final decide = widget.decideLegacyImport;
    if (session == null || decide == null || decidingLegacy) return;
    final current = generation;
    setState(() {
      decidingLegacy = true;
      failure = null;
    });
    try {
      await decide(session, adopt);
      if (!mounted || generation != current) return;
      final opened = await widget.openLibrary(session);
      if (mounted && generation == current) {
        setState(() {
          library = opened;
          legacyDecision = null;
        });
      }
    } catch (_) {
      if (mounted && generation == current) {
        setState(() => failure = AppMessage.libraryAdoptFailed);
      }
    } finally {
      if (mounted) setState(() => decidingLegacy = false);
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    generation++;
    unawaited(
      transition.then((_) => widget.closeLibrary()).catchError((Object _) {}),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LocalizedApp(
    controller: widget.localeController,
    key: ValueKey(account ?? 'signed-out'),
    theme: appTheme(),
    homeBuilder: (context) => widget.auth.restoring
        ? const _Waiting()
        : account == null
        ? AuthScreen(
            auth: widget.auth,
            initialIdentifier: widget.initialIdentifier,
            initialPassword: widget.initialPassword,
          )
        : library != null
        ? Home(library!, auth: widget.auth)
        : legacyDecision != null
        ? Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.folder_copy_outlined,
                          size: 56,
                          color: forest,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.l10n.previousLibrary,
                          style: appTheme().textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Text(context.l10n.previousLibraryInfo),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.adoptLibraryQuestion(
                            legacyDecision!.user.username,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(widget.auth.environment.normalizedUrl),
                        const SizedBox(height: 16),
                        Text(context.l10n.adoptLibraryInfo),
                        const SizedBox(height: 24),
                        if (failure != null) _Notice(failure!, error: true),
                        FilledButton(
                          onPressed:
                              decidingLegacy ||
                                  widget.decideLegacyImport == null
                              ? null
                              : () => decideLegacy(true),
                          child: Text(context.l10n.importExistingLibrary),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed:
                              decidingLegacy ||
                                  widget.decideLegacyImport == null
                              ? null
                              : () => decideLegacy(false),
                          child: Text(context.l10n.useSeparateLibrary),
                        ),
                        if (decidingLegacy)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: LinearProgressIndicator(),
                          ),
                        TextButton(
                          onPressed: decidingLegacy ? null : widget.auth.logout,
                          child: Text(context.l10n.signOut),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        : failure == null
        ? const _Waiting()
        : Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.message(failure!)),
                      TextButton(
                        onPressed: widget.auth.logout,
                        child: Text(context.l10n.signOut),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
}

class _Waiting extends StatelessWidget {
  const _Waiting();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(context.l10n.openingLibrary),
        ],
      ),
    ),
  );
}

enum AuthPage { login, register, forgot, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.auth,
    this.localeController,
    this.initialIdentifier = '',
    this.initialPassword = '',
    super.key,
  });
  final AuthController auth;
  final LocaleController? localeController;
  final String initialIdentifier, initialPassword;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final identifier = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController(),
      token = TextEditingController();
  AuthPage page = AuthPage.login;
  Object? notice;
  @override
  void initState() {
    super.initState();
    identifier.text = widget.initialIdentifier;
    password.text = widget.initialPassword;
  }

  @override
  void dispose() {
    for (final field in [identifier, email, password, confirmation, token]) {
      field.dispose();
    }
    super.dispose();
  }

  void navigate(AuthPage next) => setState(() {
    form.currentState?.reset();
    page = next;
    notice = null;
    password.clear();
    confirmation.clear();
    if (next == AuthPage.register) identifier.clear();
  });
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => notice = null);
    final auth = widget.auth;
    final ok = switch (page) {
      AuthPage.login => await auth.login(identifier.text.trim(), password.text),
      AuthPage.register => await auth.register(
        identifier.text.trim(),
        email.text.trim(),
        password.text,
      ),
      AuthPage.forgot => await auth.forgotPassword(email.text.trim()),
      AuthPage.reset => await auth.resetPassword(
        token.text.trim(),
        password.text,
      ),
    };
    if (!mounted) return;
    setState(() {
      if (ok && page == AuthPage.forgot) notice = AppMessage.resetEmailSent;
      if (ok && page == AuthPage.reset) {
        page = AuthPage.login;
        password.clear();
        confirmation.clear();
        token.clear();
        notice = AppMessage.passwordSaved;
      }
    });
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: widget.auth.changes.stream,
    builder: (context, _) {
      final auth = widget.auth;
      final title = switch (page) {
        AuthPage.login => context.l10n.loginHeading,
        AuthPage.register => context.l10n.registerHeading,
        AuthPage.forgot => context.l10n.forgotHeading,
        AuthPage.reset => context.l10n.resetHeading,
      };
      final action = switch (page) {
        AuthPage.login => context.l10n.signIn,
        AuthPage.register => context.l10n.createMyAccount,
        AuthPage.forgot => context.l10n.sendInstructions,
        AuthPage.reset => context.l10n.savePassword,
      };
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AutofillGroup(
                  child: Form(
                    key: form,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const LanguageSelector(),
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Icon(Icons.terrain, color: forest, size: 40),
                            SizedBox(width: 10),
                            Text(
                              'gpix',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: forest,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(context.l10n.authIntro),
                        const SizedBox(height: 24),
                        if (auth.environment.problem
                            case final AppMessage problem)
                          _Notice(problem, error: true),
                        if (notice != null) _Notice(notice!),
                        if (auth.message != null)
                          _Notice(auth.message!, error: true),
                        if (page == AuthPage.login || page == AuthPage.register)
                          _Field(
                            controller: identifier,
                            label: page == AuthPage.login
                                ? context.l10n.identifier
                                : context.l10n.username,
                            autofill: const [AutofillHints.username],
                            validator: page == AuthPage.register
                                ? (value) => context.validation(
                                    AuthValidation.username(value),
                                  )
                                : (value) => _required(context, value),
                          ),
                        if (page == AuthPage.register ||
                            page == AuthPage.forgot)
                          _Field(
                            controller: email,
                            label: context.l10n.email,
                            keyboard: TextInputType.emailAddress,
                            autofill: const [AutofillHints.email],
                            validator: (value) =>
                                context.validation(AuthValidation.email(value)),
                          ),
                        if (page == AuthPage.reset)
                          _Field(
                            controller: token,
                            label: context.l10n.resetCode,
                            validator: (value) => _required(context, value),
                            helper: context.l10n.resetCodeHint,
                          ),
                        if (page != AuthPage.forgot)
                          PasswordField(
                            controller: password,
                            label: page == AuthPage.reset
                                ? context.l10n.newPassword
                                : context.l10n.password,
                            newPassword: page != AuthPage.login,
                            validator: page == AuthPage.login
                                ? (value) => _required(context, value)
                                : (value) => context.validation(
                                    AuthValidation.password(value),
                                  ),
                          ),
                        if (page == AuthPage.register || page == AuthPage.reset)
                          PasswordField(
                            controller: confirmation,
                            label: context.l10n.confirmPassword,
                            newPassword: true,
                            validator: (v) =>
                                v == password.text && v!.isNotEmpty
                                ? null
                                : context.l10n.passwordMismatch,
                          ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: auth.busy ? null : submit,
                          child: auth.busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(action),
                        ),
                        if (page == AuthPage.login) ...[
                          TextButton(
                            onPressed: auth.busy
                                ? null
                                : () => navigate(AuthPage.forgot),
                            child: Text(context.l10n.forgotPassword),
                          ),
                          OutlinedButton(
                            onPressed: auth.busy
                                ? null
                                : () => navigate(AuthPage.register),
                            child: Text(context.l10n.createAccount),
                          ),
                        ] else
                          TextButton(
                            onPressed: auth.busy
                                ? null
                                : () => navigate(AuthPage.login),
                            child: Text(context.l10n.backToLogin),
                          ),
                        if (page == AuthPage.forgot || page == AuthPage.login)
                          TextButton(
                            onPressed: auth.busy
                                ? null
                                : () => navigate(AuthPage.reset),
                            child: Text(context.l10n.haveResetCode),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          context.l10n.serverLabel(auth.environment.label),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          auth.environment.normalizedUrl.isEmpty
                              ? context.l10n.configureServer
                              : auth.environment.normalizedUrl,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    required this.auth,
    required this.resolveConflicts,
    super.key,
  });
  final AuthController auth;
  final Future<void> Function() resolveConflicts;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  Object? notice;
  @override
  void dispose() {
    current.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: widget.auth.changes.stream,
    builder: (context, _) {
      final auth = widget.auth;
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.myAccount)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  size: 56,
                  color: forest,
                ),
                const SizedBox(height: 12),
                Text(
                  auth.session?.user.username ?? '',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(auth.session?.user.email ?? ''),
                const SizedBox(height: 24),
                Text(context.l10n.offlineSessionInfo),
                const SizedBox(height: 24),
                Text(
                  context.l10n.password,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (notice != null) _Notice(notice!),
                if (auth.message != null) _Notice(auth.message!, error: true),
                Form(
                  key: form,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      PasswordField(
                        controller: current,
                        label: context.l10n.currentPassword,
                        validator: (value) => _required(context, value),
                      ),
                      PasswordField(
                        controller: password,
                        label: context.l10n.newPassword,
                        newPassword: true,
                        validator: (value) =>
                            context.validation(AuthValidation.password(value)),
                      ),
                      PasswordField(
                        controller: confirmation,
                        label: context.l10n.confirmNewPassword,
                        newPassword: true,
                        validator: (v) => v == password.text && v!.isNotEmpty
                            ? null
                            : context.l10n.passwordMismatch,
                      ),
                      FilledButton(
                        onPressed: auth.busy
                            ? null
                            : () async {
                                if (!form.currentState!.validate()) return;
                                final ok = await auth.changePassword(
                                  current.text,
                                  password.text,
                                );
                                if (!mounted || !ok) return;
                                setState(() {
                                  notice = context.l10n.passwordChanged;
                                  current.clear();
                                  password.clear();
                                  confirmation.clear();
                                });
                              },
                        child: Text(context.l10n.changePassword),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  context.l10n.serverLabel(auth.environment.label),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SelectableText(auth.environment.normalizedUrl),
                const SizedBox(height: 8),
                Text(context.l10n.apiConfigurationInfo),
                if (auth.environment.problem case final AppMessage problem)
                  _Notice(problem, error: true),
                TextButton(
                  onPressed: auth.busy ? null : widget.resolveConflicts,
                  child: Text(context.l10n.resolveConflicts),
                ),
                const Divider(height: 40),
                OutlinedButton.icon(
                  onPressed: auth.busy ? null : auth.logout,
                  icon: const Icon(Icons.logout),
                  label: Text(context.l10n.signOut),
                ),
                const SizedBox(height: 8),
                Text(context.l10n.signOutInfo),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String? _required(BuildContext context, String? value) =>
    value == null || value.trim().isEmpty ? context.l10n.requiredField : null;

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.error = false});
  final Object text;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? const Color(0xffffedcd) : const Color(0xffe0eddd),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(context.message(text)),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.validator,
    this.keyboard,
    this.autofill,
    this.helper,
  });
  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? Function(String?) validator;
  final TextInputType? keyboard;
  final List<String>? autofill;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboard,
      autofillHints: autofill,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
      ),
    ),
  );
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.label,
    required this.validator,
    this.newPassword = false,
    super.key,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final bool newPassword;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      obscureText: hidden,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: hidden
              ? context.l10n.showPassword
              : context.l10n.hidePassword,
          onPressed: () => setState(() => hidden = !hidden),
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    ),
  );
}

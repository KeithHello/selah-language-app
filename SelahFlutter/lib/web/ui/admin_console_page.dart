import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../admin/admin_controller.dart';
import '../data/learning_gateway.dart';
import '../domain/learning_models.dart';
import 'admin_dashboard_page.dart';

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({
    required this.controller,
    this.uiLocale = defaultUiLocale,
    super.key,
  });

  final AdminController controller;
  final String uiLocale;

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    if (widget.controller.signedIn && !widget.controller.checked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    if (!widget.controller.signedIn) return;
    await widget.controller.load();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _loginError = null;
    });
    try {
      await widget.controller.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      await widget.controller.load();
    } on LearningFailure catch (failure) {
      if (mounted) _loginError = failure.message;
    } catch (_) {
      if (mounted) _loginError = '登录失败，请稍后重试。';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _loginError = null;
    });
    try {
      await widget.controller.signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (!widget.controller.signedIn) return _buildLogin(context);
        return Scaffold(
          backgroundColor: const Color(0xfffbf8f4),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '管理台 · ${widget.controller.email ?? '已登录'}',
                          style: SelahTypography.labelLarge(
                            color: SelahColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _signOut,
                        child: const Text('退出管理台'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SelahSpacing.xs),
                if (widget.controller.controlsError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.controller.controlsError!,
                        style: SelahTypography.bodySmall(
                          color: SelahColors.danger,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: AdminDashboardPage(
                    controller: widget.controller,
                    uiLocale: widget.uiLocale,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogin(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffbf8f4),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SelahSpacing.page),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(SelahSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Selah 管理台', style: SelahTypography.headlineLarge()),
                    const SizedBox(height: SelahSpacing.sm),
                    Text(
                      '请使用管理员账号登录。',
                      style: SelahTypography.bodyMedium(
                        color: SelahColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: SelahSpacing.xl),
                    TextField(
                      controller: _emailController,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: '管理员邮箱',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: SelahSpacing.md),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      enabled: !_busy,
                      onSubmitted: (_) => _signIn(),
                      decoration: const InputDecoration(
                        labelText: '密码',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_loginError != null) ...[
                      const SizedBox(height: SelahSpacing.md),
                      Text(
                        _loginError!,
                        style: SelahTypography.bodySmall(
                          color: SelahColors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: SelahSpacing.xl),
                    FilledButton(
                      onPressed: _busy ? null : _signIn,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('登录管理台'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

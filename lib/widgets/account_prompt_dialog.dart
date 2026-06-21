import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/device_service.dart';
import '../theme/app_theme.dart';
import 'military_button.dart';

class AccountPromptDialog extends ConsumerStatefulWidget {
  const AccountPromptDialog({super.key});

  @override
  ConsumerState<AccountPromptDialog> createState() =>
      _AccountPromptDialogState();
}

class _AccountPromptDialogState extends ConsumerState<AccountPromptDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _showForm = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryCyan.withAlpha(128)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryCyan.withAlpha(51),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SECURE YOUR COMMAND',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryCyan,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create an account to save your achievements, stats, '
              'and progress across devices.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            if (!_showForm) ...[
              MilitaryButton(
                label: 'CREATE ACCOUNT',
                color: AppTheme.primaryCyan,
                onPressed: () => setState(() => _showForm = true),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await DeviceService.resetPromptCounter();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text(
                  'REMIND ME LATER',
                  style: TextStyle(color: Colors.white54, letterSpacing: 1),
                ),
              ),
            ],
            if (_showForm) ...[
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'DISPLAY NAME',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryCyan),
                  ),
                  prefixIcon:
                      Icon(Icons.military_tech, color: AppTheme.primaryCyan),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'EMAIL',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryCyan),
                  ),
                  prefixIcon: Icon(Icons.email, color: AppTheme.primaryCyan),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'PASSWORD',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryCyan),
                  ),
                  prefixIcon: Icon(Icons.lock, color: AppTheme.primaryCyan),
                ),
              ),
              const SizedBox(height: 16),
              if (authState.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    authState.error!,
                    style:
                        const TextStyle(color: AppTheme.primaryRed, fontSize: 12),
                  ),
                ),
              MilitaryButton(
                label: authState.isLoading ? 'DEPLOYING...' : 'DEPLOY ACCOUNT',
                color: AppTheme.primaryCyan,
                onPressed: authState.isLoading
                    ? null
                    : () async {
                        final email = _emailController.text.trim();
                        final password = _passwordController.text.trim();
                        final name = _nameController.text.trim();
                        if (email.isEmpty || password.isEmpty) return;

                        await ref
                            .read(authProvider.notifier)
                            .upgradeAnonymousAccount(email, password, name);

                        if (context.mounted &&
                            ref.read(authProvider).error == null) {
                          Navigator.of(context).pop(true);
                        }
                      },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await DeviceService.resetPromptCounter();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

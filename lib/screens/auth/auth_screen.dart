import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/military_button.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/images/backgrounds/dark_login.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.darkBg),
          ),
          // Light overlay for form readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
          // Content
          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Spacer to push form below the background title
                      const SizedBox(height: 120),

                      // Auth form
                      SizedBox(
                        width: 320,
                        child: Column(
                          children: [
                            if (_isSignUp) ...[
                              _buildTextField(
                                controller: _nameController,
                                hint: 'COMMANDER NAME',
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _buildTextField(
                              controller: _emailController,
                              hint: 'COMMANDER ID',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _passwordController,
                              hint: 'ACCESS CODE',
                              icon: Icons.lock_outline,
                              obscureText: true,
                            ),
                            const SizedBox(height: 24),
                            MilitaryButton(
                              label: 'DEPLOY',
                              isLoading: authState.isLoading,
                              onPressed: _handleEmailAuth,
                              width: double.infinity,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() => _isSignUp = !_isSignUp);
                              },
                              child: Text(
                                _isSignUp
                                    ? 'EXISTING COMMANDER? SIGN IN'
                                    : 'NEW RECRUIT? SIGN UP',
                                style: TextStyle(
                                  fontFamily: 'RobotoCondensed',
                                  fontSize: 12,
                                  color:
                                      AppTheme.metalGray.withValues(alpha: 0.7),
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppTheme.metalGray
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      fontFamily: 'RobotoCondensed',
                                      fontSize: 12,
                                      color: AppTheme.metalGray
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppTheme.metalGray
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            MilitaryButton(
                              label: 'DEPLOY AS GUEST',
                              isLoading: authState.isLoading,
                              color: AppTheme.primaryCyan,
                              onPressed: () {
                                ref
                                    .read(authProvider.notifier)
                                    .signInAnonymously();
                              },
                              width: double.infinity,
                            ),
                          ],
                        ),
                      ),

                      if (authState.error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          authState.error!,
                          style: const TextStyle(
                            color: AppTheme.warRed,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: 'RobotoCondensed',
        color: AppTheme.metalLight,
        letterSpacing: 1,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.metalGray.withValues(alpha: 0.5)),
      ),
    );
  }

  void _handleEmailAuth() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    if (_isSignUp) {
      ref
          .read(authProvider.notifier)
          .signUpWithEmail(email, password, _nameController.text.trim());
    } else {
      ref.read(authProvider.notifier).signInWithEmail(email, password);
    }
  }
}

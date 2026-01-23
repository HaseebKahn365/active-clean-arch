import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primary.withAlpha(150)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // App Branding
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimary.withAlpha(50),
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.onPrimary.withAlpha(70)),
                    ),
                    child: Icon(Icons.timer_outlined, size: 64, color: colorScheme.onPrimary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onPrimary,
                      letterSpacing: -1.5,
                    ),
                  ),
                  Text(
                    'Track what matters, effortlessly.',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onPrimary.withAlpha(180),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Sign In Card
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 40, offset: const Offset(0, 20)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Welcome Back',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue your progress',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 32),

                        _GoogleSignInButton(),

                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            // Link to terms or privacy
                          },
                          child: Text(
                            'Privacy Policy & Terms',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleSignInButton extends StatefulWidget {
  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ElevatedButton(
      onPressed: _isLoading ? null : _handleSignIn,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                  height: 24,
                ),
                const SizedBox(width: 12),
                const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
    );
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await context.read<AppAuthProvider>().signInWithGoogle();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

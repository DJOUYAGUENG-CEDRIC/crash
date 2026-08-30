import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/error_messages.dart';
import '../../providers/activation_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/service_providers.dart';

/// Sign-in only — CrashX never exposes a public signup form (spec §45).
/// New accounts are created exclusively through an invitation, via
/// [ActivationScreen] reached from the link below.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // signInWithPassword has completed, but Riverpod's auth stream can
      // still contain the previous signed-out event for one frame. Clear
      // every derived auth gate before entering the splash verification so
      // a successful login cannot be bounced straight back to this page.
      ref.invalidate(authStateChangesProvider);
      ref.invalidate(currentUserIdProvider);
      ref.invalidate(activationProvider);
      await Future<void>.delayed(Duration.zero);

      if (mounted) context.go('/');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = friendlyLoginErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: AppTextStyles.displayLarge.copyWith(
                          color: AppColors.primaryVariant,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const SizedBox(height: AppSpacing.xxl),
                  Text('Connexion', style: AppTextStyles.heading1),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) =>
                        (value == null || !value.contains('@'))
                        ? 'Adresse e-mail invalide.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Mot de passe requis.'
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _errorText!,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : const Text('SE CONNECTER'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: () => context.push('/activate'),
                    child: const Text("J'ai un code d'invitation"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

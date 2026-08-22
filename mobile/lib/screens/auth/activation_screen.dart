import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/error_messages.dart';
import '../../providers/service_providers.dart';

/// Account creation ONLY happens here, by redeeming an invitation token
/// (spec §45 — there is no public signup form). Success signs the new
/// account in automatically (see AuthService.activateInvitation).
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _tokenController.dispose();
    _displayNameController.dispose();
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
      await ref.read(authServiceProvider).activateInvitation(
            // Invitation tokens are always generated lowercase hex
            // (see create_invitation() in 0005_admin_functions.sql) —
            // normalize defensively in case a keyboard capitalized a
            // character despite the field's own autocapitalize=off.
            token: _tokenController.text.trim().toLowerCase(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _displayNameController.text.trim(),
          );
      if (mounted) context.go('/');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = friendlyActivationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Activer mon compte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Saisissez le code d'invitation reçu ainsi que vos informations pour créer votre accès CRASHX.",
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _tokenController,
                  style: AppTextStyles.body,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    labelText: "Code d'invitation",
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? "Code d'invitation requis." : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _displayNameController,
                  style: AppTextStyles.body,
                  decoration: const InputDecoration(
                    labelText: "Nom d'affichage",
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Nom requis.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTextStyles.body,
                  decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (value) =>
                      (value == null || !value.contains('@')) ? 'Adresse e-mail invalide.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    helperText: 'Au moins 8 caractères.',
                  ),
                  validator: (value) {
                    if (value == null || value.length < 8) return 'Minimum 8 caractères.';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_errorText!, style: AppTextStyles.body.copyWith(color: AppColors.danger)),
                ],
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                        )
                      : const Text('ACTIVER MON COMPTE'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

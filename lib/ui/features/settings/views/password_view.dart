import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../view_models/password_view_model.dart';

class PasswordView extends StatelessWidget {
  const PasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          PasswordViewModel(authRepository: context.read<AuthRepository>()),
      child: const _PasswordForm(),
    );
  }
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm();

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<PasswordViewModel>();

    if (viewModel.saved) {
      viewModel.consumeSaved();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
        _currentController.clear();
        _newController.clear();
        _confirmController.clear();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.changePasswordTitle),
        leading: BackButton(onPressed: () => context.go('/settings')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (viewModel.errorMessage != null) ...[
                Text(
                  viewModel.errorMessage!,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _currentController,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.currentPasswordLabel,
                  errorText: viewModel.fieldError('current_password'),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? l10n.passwordRequired
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newController,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.newPasswordLabel,
                  errorText: viewModel.fieldError('password'),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? l10n.passwordRequired
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.confirmPasswordLabel,
                ),
                validator: (value) => value != _newController.text
                    ? l10n.passwordMismatch
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: viewModel.submitting
                    ? null
                    : () {
                        if (!_formKey.currentState!.validate()) return;
                        viewModel.submit(
                          currentPassword: _currentController.text,
                          password: _newController.text,
                          passwordConfirmation: _confirmController.text,
                        );
                      },
                child: viewModel.submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

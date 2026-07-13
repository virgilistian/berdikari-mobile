import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../view_models/profile_view_model.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ProfileViewModel(authRepository: context.read<AuthRepository>()),
      child: const _ProfileForm(),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm();

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthRepository>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<ProfileViewModel>();

    if (viewModel.saved) {
      viewModel.consumeSaved();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
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
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.nameLabel,
                  errorText: viewModel.fieldError('name'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.nameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.emailLabel,
                  errorText: viewModel.fieldError('email'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.emailRequired
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: viewModel.submitting
                    ? null
                    : () {
                        if (!_formKey.currentState!.validate()) return;
                        viewModel.submit(
                          name: _nameController.text,
                          email: _emailController.text,
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

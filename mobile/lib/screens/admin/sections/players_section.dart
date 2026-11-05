import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/player_login.dart';
import '../../../models/admin_models.dart';
import '../../../providers/admin_providers.dart';
import '../admin_widgets.dart';

final _playersProvider = FutureProvider.autoDispose<List<AdminPlayer>>(
  (ref) => ref.watch(adminServiceProvider).fetchPlayers(),
);

final _transactionsProvider = FutureProvider.autoDispose
    .family<List<AdminTransaction>, String>(
      (ref, userId) =>
          ref.watch(adminServiceProvider).fetchPlayerTransactions(userId),
    );

class PlayersSection extends ConsumerStatefulWidget {
  const PlayersSection({super.key, required this.account});

  final AdminAccount account;

  @override
  ConsumerState<PlayersSection> createState() => _PlayersSectionState();
}

class _PlayersSectionState extends ConsumerState<PlayersSection> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(_playersProvider);
    final query = _search.trim().toLowerCase();

    return AdminSectionList(
      value: players,
      onRefresh: () => ref.refresh(_playersProvider.future),
      header: [
        if (widget.account.can(AdminPermissions.createInvitations))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: FilledButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('CRÉER UN JOUEUR'),
              onPressed: _createPlayer,
            ),
          ),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Rechercher un joueur',
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      builder: () {
        final filtered = players.requireValue
            .where(
              (p) =>
                  query.isEmpty ||
                  p.email.toLowerCase().contains(query) ||
                  (p.displayName ?? '').toLowerCase().contains(query),
            )
            .toList();
        if (filtered.isEmpty) {
          return const [AdminEmptyState('Aucun joueur.')];
        }
        return [
          for (final player in filtered)
            AdminCard(
              onTap: () => _openPlayer(player),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(player.label, style: AppTextStyles.body),
                        Text(
                          PlayerLogin.display(player.email),
                          style: AppTextStyles.caption,
                        ),
                        Text(
                          '${Formatters.amount(player.balance)} '
                          '${AppConstants.currencyLabel}',
                          style: AppTextStyles.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                  AdminStatusChip(
                    player.isBlocked ? 'BLOQUÉ' : 'ACTIF',
                    color: adminStatusColor(player.status),
                  ),
                ],
              ),
            ),
        ];
      },
    );
  }

  Future<void> _createPlayer() async {
    final input = await showDialog<_NewPlayer>(
      context: context,
      builder: (_) => const _NewPlayerDialog(),
    );
    if (input == null || !mounted) return;
    final login = PlayerLogin.display(PlayerLogin.toEmail(input.login));
    final done = await runAdminAction(
      context,
      () => ref
          .read(adminServiceProvider)
          .createPlayer(
            login: input.login,
            password: input.password,
            displayName: input.displayName,
            maxDevices: input.maxDevices,
          ),
      success: 'Joueur créé. Identifiant : $login',
    );
    if (done) ref.invalidate(_playersProvider);
  }

  Future<void> _openPlayer(AdminPlayer player) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlayerSheet(player: player, account: widget.account),
    ).then((_) => ref.invalidate(_playersProvider));
  }
}

class _PlayerSheet extends ConsumerWidget {
  const _PlayerSheet({required this.player, required this.account});

  final AdminPlayer player;
  final AdminAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(adminServiceProvider);
    final canBlock = account.can(AdminPermissions.blockUsers);
    final canManage = account.can(AdminPermissions.manageUsers);
    final transactions = ref.watch(_transactionsProvider(player.id));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Text(player.label, style: AppTextStyles.heading1),
          Text(
            'Identifiant : ${PlayerLogin.display(player.email)}',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Solde : ${Formatters.amount(player.balance)} '
            '${AppConstants.currencyLabel}',
            style: AppTextStyles.body,
          ),
          Text(
            'Dernière activité : '
            '${player.lastDeviceActivity == null ? '—' : Formatters.dateTime(player.lastDeviceActivity!)}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (canBlock)
                OutlinedButton.icon(
                  icon: Icon(
                    player.isBlocked ? Icons.lock_open : Icons.block,
                    color: player.isBlocked
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                  label: Text(player.isBlocked ? 'DÉBLOQUER' : 'BLOQUER'),
                  onPressed: () async {
                    final ok = await confirmAdminAction(
                      context,
                      title: player.isBlocked
                          ? 'Débloquer ce joueur ?'
                          : 'Bloquer ce joueur ?',
                      message: player.isBlocked
                          ? "Le joueur pourra de nouveau accéder à l'application."
                          : "Le joueur perdra l'accès à la prochaine vérification serveur.",
                      destructive: !player.isBlocked,
                    );
                    if (!ok || !context.mounted) return;
                    final done = await runAdminAction(
                      context,
                      () => player.isBlocked
                          ? service.unblockPlayer(player.id)
                          : service.blockPlayer(player.id),
                      success: player.isBlocked
                          ? 'Joueur débloqué.'
                          : 'Joueur bloqué.',
                    );
                    if (done && context.mounted) Navigator.of(context).pop();
                  },
                ),
              if (canManage)
                OutlinedButton.icon(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('AJUSTER LE SOLDE'),
                  onPressed: () => _adjustBalance(context, ref),
                ),
              if (canManage)
                OutlinedButton.icon(
                  icon: const Icon(Icons.password),
                  label: const Text('NOUVEAU MOT DE PASSE'),
                  onPressed: () => _resetPassword(context, ref),
                ),
              if (account.can(AdminPermissions.manageDevices))
                OutlinedButton.icon(
                  icon: const Icon(Icons.devices_other),
                  label: Text('APPAREILS MAX : ${player.maxDevices}'),
                  onPressed: () => _setMaxDevices(context, ref),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Transactions récentes', style: AppTextStyles.heading2),
          const SizedBox(height: AppSpacing.sm),
          ...transactions.when(
            loading: () => const [
              Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ],
            error: (error, _) => [
              Text(adminErrorMessage(error), style: AppTextStyles.bodyMuted),
            ],
            data: (rows) => rows.isEmpty
                ? const [AdminEmptyState('Aucune transaction.')]
                : [
                    for (final t in rows)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.type),
                        subtitle: Text(Formatters.dateTime(t.createdAt)),
                        trailing: Text(
                          '${t.amount >= 0 ? '+' : ''}${Formatters.amount(t.amount)}',
                          style: AppTextStyles.body.copyWith(
                            color: t.amount >= 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      ),
                  ],
          ),
        ],
      ),
    );
  }

  Future<String?> _askValue(
    BuildContext context, {
    required String title,
    required String label,
    String initial = '',
    TextInputType? keyboardType,
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('ANNULER'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('VALIDER'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref) async {
    final password = await _askValue(
      context,
      title: 'Nouveau mot de passe',
      label: 'Mot de passe (8 caractères min.)',
    );
    if (password == null || !context.mounted) return;
    if (password.length < 8) {
      showAdminSnack(context, '8 caractères minimum.', error: true);
      return;
    }
    await runAdminAction(
      context,
      () =>
          ref.read(adminServiceProvider).setPlayerPassword(player.id, password),
      success: 'Mot de passe modifié. Communiquez-le au joueur.',
    );
  }

  Future<void> _setMaxDevices(BuildContext context, WidgetRef ref) async {
    final value = await _askValue(
      context,
      title: "Nombre max. d'appareils",
      label: 'Appareils autorisés',
      initial: '${player.maxDevices}',
      keyboardType: TextInputType.number,
    );
    if (value == null || !context.mounted) return;
    final maxDevices = int.tryParse(value);
    if (maxDevices == null || maxDevices < 1) {
      showAdminSnack(context, 'Nombre invalide.', error: true);
      return;
    }
    final done = await runAdminAction(
      context,
      () => ref
          .read(adminServiceProvider)
          .setPlayerMaxDevices(player.id, maxDevices),
      success: 'Limite mise à jour.',
    );
    if (done && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _adjustBalance(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajuster le solde'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Montant (négatif pour retirer)',
              ),
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Motif'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ANNULER'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('VALIDER'),
          ),
        ],
      ),
    );
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    final motive = reason.text.trim();
    amount.dispose();
    reason.dispose();
    if (submitted != true || !context.mounted) return;
    if (value == null || value == 0 || motive.isEmpty) {
      showAdminSnack(context, 'Montant et motif obligatoires.', error: true);
      return;
    }
    final done = await runAdminAction(
      context,
      () => ref
          .read(adminServiceProvider)
          .adjustBalance(player.id, value, motive),
      success: 'Solde ajusté.',
    );
    if (done && context.mounted) Navigator.of(context).pop();
  }
}

class _NewPlayer {
  const _NewPlayer({
    required this.login,
    required this.password,
    required this.displayName,
    required this.maxDevices,
  });

  final String login;
  final String password;
  final String displayName;
  final int maxDevices;
}

class _NewPlayerDialog extends StatefulWidget {
  const _NewPlayerDialog();

  @override
  State<_NewPlayerDialog> createState() => _NewPlayerDialogState();
}

class _NewPlayerDialogState extends State<_NewPlayerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _devices = TextEditingController(text: '1');

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
    _password.dispose();
    _devices.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _NewPlayer(
        login: _login.text.trim(),
        password: _password.text,
        displayName: _name.text.trim(),
        maxDevices: int.parse(_devices.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau joueur'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom affiché'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis.' : null,
              ),
              TextFormField(
                controller: _login,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Identifiant',
                  helperText: 'ex. moussa.k (3-30 caractères) ou un e-mail',
                ),
                validator: (v) => (v == null || !PlayerLogin.isValid(v))
                    ? 'Lettres, chiffres, . _ - uniquement.'
                    : null,
              ),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                validator: (v) => (v == null || v.length < 8)
                    ? '8 caractères minimum.'
                    : null,
              ),
              TextFormField(
                controller: _devices,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Nombre max. d'appareils",
                ),
                validator: (v) =>
                    ((int.tryParse(v ?? '') ?? 0) < 1) ? 'Au moins 1.' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ANNULER'),
        ),
        FilledButton(onPressed: _submit, child: const Text('CRÉER')),
      ],
    );
  }
}

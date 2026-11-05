import 'package:crashx/models/admin_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a super admin holds every permission', () {
    const account = AdminAccount(
      id: 'a',
      role: 'SUPER_ADMIN',
      displayName: null,
      permissions: {},
    );
    expect(AdminPermissions.all.every(account.can), isTrue);
  });

  test('a sub-admin only holds the granted permissions', () {
    const account = AdminAccount(
      id: 'b',
      role: 'SOUS_ADMIN',
      displayName: null,
      permissions: {AdminPermissions.viewGame},
    );
    expect(account.can(AdminPermissions.viewGame), isTrue);
    expect(account.can(AdminPermissions.controlGame), isFalse);
    expect(account.isSuperAdmin, isFalse);
    expect(
      account.canAny(const [
        AdminPermissions.viewLogs,
        AdminPermissions.viewGame,
      ]),
      isTrue,
    );
  });
}

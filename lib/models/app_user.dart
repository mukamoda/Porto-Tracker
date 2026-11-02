import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.nome,
    required this.email,
    required this.papel,
    this.empresa,
    this.empresaCnpj,
    this.criadoEm,
  });

  final String id;
  final String nome;
  final String email;
  final UserRole papel;

  /// Para transportadores: empresa vinculada (define quais cargas enxerga).
  final String? empresa;
  final String? empresaCnpj;
  final DateTime? criadoEm;

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as String,
        nome: (m['nome'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        papel: UserRole.fromCodigo(m['papel'] as String?),
        empresa: m['empresa'] as String?,
        empresaCnpj: m['empresa_cnpj'] as String?,
        criadoEm: m['criado_em'] == null
            ? null
            : DateTime.parse(m['criado_em'] as String).toLocal(),
      );

  AppUser copyWith({UserRole? papel}) => AppUser(
        id: id,
        nome: nome,
        email: email,
        papel: papel ?? this.papel,
        empresa: empresa,
        empresaCnpj: empresaCnpj,
        criadoEm: criadoEm,
      );
}

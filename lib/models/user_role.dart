/// Perfis de acesso, em ordem hierárquica.
///
/// Quanto maior o [nivel], mais informações e ações o usuário enxerga.
/// O nível é a base de todas as regras de permissão (app e banco/RLS).
enum UserRole {
  transportador(1, 'transportador', 'Transportador',
      'Acompanha apenas as cargas da sua transportadora e envia documentos.'),
  gate(2, 'gate', 'Equipe de Gate',
      'Registra entrada (gate in) e saída (gate out) de veículos e contêineres.'),
  conferente(3, 'conferente', 'Conferente',
      'Armazena, movimenta, envia para inspeção e registra ocorrências.'),
  operador(4, 'operador', 'Operador Portuário',
      'Cadastra e edita cargas, resolve ocorrências e acessa o dashboard.'),
  supervisor(5, 'supervisor', 'Supervisor Operacional',
      'Libera cargas, exclui documentos e vê a produtividade da equipe.'),
  admin(6, 'admin', 'Administrador',
      'Acesso total, incluindo gestão de usuários e perfis.');

  const UserRole(this.nivel, this.codigo, this.label, this.descricao);

  final int nivel;
  final String codigo;
  final String label;
  final String descricao;

  bool atLeast(UserRole outro) => nivel >= outro.nivel;

  static UserRole fromCodigo(String? codigo) => UserRole.values.firstWhere(
        (r) => r.codigo == codigo,
        orElse: () => UserRole.transportador,
      );
}

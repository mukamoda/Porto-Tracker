import '../models/user_role.dart';

/// Ações e visualizações controladas por perfil.
enum Permissao {
  verDashboard('Visualizar dashboard da operação'),
  verDesempenhoEquipe('Ver produtividade da equipe no dashboard'),
  verTodasCargas('Ver cargas de todas as transportadoras'),
  verResponsavelEventos('Ver quem registrou cada evento'),
  registrarGate('Registrar gate in / gate out'),
  registrarArmazenagem('Armazenar, movimentar e enviar à inspeção'),
  registrarOcorrencia('Registrar ocorrências (avaria, lacre...)'),
  resolverOcorrencia('Resolver ocorrências'),
  liberarCarga('Liberar carga para retirada'),
  cadastrarCarga('Cadastrar cargas previstas'),
  editarCarga('Editar dados da carga'),
  excluirCarga('Excluir cargas'),
  enviarDocumento('Enviar documentos (NF, DANFE, DI...)'),
  excluirDocumento('Excluir documentos'),
  gerenciarUsuarios('Gerenciar usuários e perfis');

  const Permissao(this.descricao);
  final String descricao;
}

class Permissoes {
  Permissoes._();

  /// Perfil mínimo exigido para cada permissão (hierarquia cumulativa).
  static const Map<Permissao, UserRole> _minimo = {
    Permissao.enviarDocumento: UserRole.transportador,
    Permissao.verTodasCargas: UserRole.gate,
    Permissao.registrarGate: UserRole.gate,
    Permissao.verResponsavelEventos: UserRole.conferente,
    Permissao.registrarArmazenagem: UserRole.conferente,
    Permissao.registrarOcorrencia: UserRole.conferente,
    Permissao.verDashboard: UserRole.operador,
    Permissao.resolverOcorrencia: UserRole.operador,
    Permissao.cadastrarCarga: UserRole.operador,
    Permissao.editarCarga: UserRole.operador,
    Permissao.verDesempenhoEquipe: UserRole.supervisor,
    Permissao.liberarCarga: UserRole.supervisor,
    Permissao.excluirDocumento: UserRole.supervisor,
    Permissao.excluirCarga: UserRole.admin,
    Permissao.gerenciarUsuarios: UserRole.admin,
  };

  static UserRole minimo(Permissao p) => _minimo[p] ?? UserRole.admin;

  static bool pode(UserRole papel, Permissao p) => papel.atLeast(minimo(p));
}

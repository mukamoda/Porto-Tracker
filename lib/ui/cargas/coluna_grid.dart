import '../../models/carga.dart';
import '../../models/user_role.dart';
import '../../services/business_rules.dart';

/// Colunas do GRID principal. Cada coluna declara o perfil mínimo que a
/// enxerga — quanto maior o nível do usuário, mais colunas aparecem.
enum ColunaGrid {
  status('Status', UserRole.transportador),
  conteiner('Contêiner', UserRole.transportador),
  pendencias('Pendências', UserRole.transportador),
  proximaEtapa('Próxima etapa', UserRole.transportador),
  previsao('Previsão', UserRole.transportador),
  placa('Placa', UserRole.transportador),
  motorista('Motorista', UserRole.transportador),
  transportadora('Transportadora', UserRole.gate),
  entrada('Entrada', UserRole.gate),
  peso('Peso bruto', UserRole.gate, numerica: true),
  posicao('Posição', UserRole.conferente),
  booking('Booking', UserRole.conferente),
  navio('Navio', UserRole.conferente),
  viagem('Viagem', UserRole.conferente),
  documentos('Docs', UserRole.conferente, numerica: true),
  permanencia('Permanência', UserRole.operador, numerica: true),
  ultimoEvento('Último evento', UserRole.operador),
  responsavel('Responsável', UserRole.supervisor);

  const ColunaGrid(this.rotulo, this.minimo, {this.numerica = false});

  final String rotulo;
  final UserRole minimo;
  final bool numerica;

  static List<ColunaGrid> permitidas(UserRole papel) =>
      ColunaGrid.values.where((c) => papel.atLeast(c.minimo)).toList();

  Object? _chave(Carga c) => switch (this) {
        ColunaGrid.status => c.status.ordem,
        ColunaGrid.conteiner => c.conteiner,
        ColunaGrid.pendencias => BusinessRules.pendencias(c).length,
        ColunaGrid.proximaEtapa => BusinessRules.proximaEtapa(c),
        ColunaGrid.previsao => c.dataPrevista,
        ColunaGrid.placa => c.placa,
        ColunaGrid.motorista => c.motorista,
        ColunaGrid.transportadora => c.transportadora,
        ColunaGrid.entrada => c.dataEntrada,
        ColunaGrid.peso => c.pesoKg,
        ColunaGrid.posicao => c.posicao,
        ColunaGrid.booking => c.booking,
        ColunaGrid.navio => c.navio,
        ColunaGrid.viagem => c.viagem,
        ColunaGrid.documentos => c.documentos.length,
        ColunaGrid.permanencia => c.permanencia()?.inMinutes,
        ColunaGrid.ultimoEvento => c.ultimoEvento?.dataHora,
        ColunaGrid.responsavel => c.ultimoEvento?.usuarioNome,
      };

  /// Comparador com valores vazios sempre ao final.
  int comparar(Carga a, Carga b) {
    final ka = _chave(a);
    final kb = _chave(b);
    if (ka == null && kb == null) return 0;
    if (ka == null) return 1;
    if (kb == null) return -1;
    return (ka as Comparable<Object>).compareTo(kb);
  }
}

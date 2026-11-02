import 'status_carga.dart';

enum TipoEvento {
  criacao('criacao', 'Cadastro da carga'),
  status('status', 'Mudança de etapa'),
  movimentacao('movimentacao', 'Movimentação no pátio'),
  ocorrencia('ocorrencia', 'Ocorrência'),
  resolucao('resolucao', 'Resolução de ocorrência');

  const TipoEvento(this.codigo, this.label);

  final String codigo;
  final String label;

  static TipoEvento fromCodigo(String? c) => TipoEvento.values
      .firstWhere((t) => t.codigo == c, orElse: () => TipoEvento.status);
}

enum TipoOcorrencia {
  avaria('avaria', 'Avaria'),
  lacre('lacre', 'Lacre violado/divergente'),
  divergenciaPeso('divergencia_peso', 'Divergência de peso'),
  documental('documental', 'Pendência documental'),
  outra('outra', 'Outra');

  const TipoOcorrencia(this.codigo, this.label);

  final String codigo;
  final String label;

  static TipoOcorrencia fromCodigo(String? c) => TipoOcorrencia.values
      .firstWhere((t) => t.codigo == c, orElse: () => TipoOcorrencia.outra);
}

enum OrgaoInspecao {
  receita('receita_federal', 'Receita Federal'),
  mapa('mapa', 'MAPA / Vigiagro'),
  anvisa('anvisa', 'ANVISA'),
  policiaFederal('policia_federal', 'Polícia Federal');

  const OrgaoInspecao(this.codigo, this.label);

  final String codigo;
  final String label;

  static String labelDe(String? codigo) => OrgaoInspecao.values
      .firstWhere((o) => o.codigo == codigo,
          orElse: () => OrgaoInspecao.receita)
      .label;
}

/// Chaves do mapa `dados` dos eventos (informações adicionais por tipo/status).
class CampoEvento {
  CampoEvento._();
  static const placa = 'placa';
  static const motorista = 'motorista';
  static const peso = 'peso';
  static const posicao = 'posicao';
  static const posicaoAnterior = 'posicao_anterior';
  static const orgao = 'orgao';
  static const motivo = 'motivo';
  static const documentoLiberacao = 'documento_liberacao';
  static const tipoOcorrencia = 'tipo_ocorrencia';
  static const descricao = 'descricao';
  static const ocorrenciaId = 'ocorrencia_id';
}

/// Evento operacional já registrado (histórico imutável).
class EventoOperacional {
  const EventoOperacional({
    required this.id,
    required this.cargaId,
    required this.tipo,
    required this.dataHora,
    required this.usuarioNome,
    this.statusAnterior,
    this.statusNovo,
    this.usuarioId,
    this.dados = const {},
    this.observacao,
    this.registradoEm,
  });

  final String id;
  final String cargaId;
  final TipoEvento tipo;
  final StatusCarga? statusAnterior;
  final StatusCarga? statusNovo;

  /// Data/hora em que o evento ocorreu (informada pelo operador).
  final DateTime dataHora;

  /// Data/hora em que foi gravado no sistema (auditoria).
  final DateTime? registradoEm;
  final String? usuarioId;
  final String usuarioNome;
  final Map<String, dynamic> dados;
  final String? observacao;

  String? dado(String chave) {
    final v = dados[chave];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  String get titulo => switch (tipo) {
        TipoEvento.criacao => 'Carga cadastrada (Previsto)',
        TipoEvento.status => statusNovo?.label ?? 'Mudança de etapa',
        TipoEvento.movimentacao => 'Movimentação no pátio',
        TipoEvento.ocorrencia =>
          'Ocorrência: ${TipoOcorrencia.fromCodigo(dado(CampoEvento.tipoOcorrencia)).label}',
        TipoEvento.resolucao => 'Ocorrência resolvida',
      };

  /// Resumo das informações adicionais para exibição na linha do tempo.
  String get resumo {
    final partes = <String>[];
    void add(String rotulo, String? valor) {
      if (valor != null) partes.add('$rotulo: $valor');
    }

    switch (tipo) {
      case TipoEvento.status:
        add('Placa', dado(CampoEvento.placa));
        add('Motorista', dado(CampoEvento.motorista));
        final peso = dado(CampoEvento.peso);
        if (peso != null) partes.add('Peso: $peso kg');
        add('Posição', dado(CampoEvento.posicao));
        final orgao = dado(CampoEvento.orgao);
        if (orgao != null) partes.add('Órgão: ${OrgaoInspecao.labelDe(orgao)}');
        add('Motivo', dado(CampoEvento.motivo));
        add('Doc. liberação', dado(CampoEvento.documentoLiberacao));
      case TipoEvento.movimentacao:
        partes.add(
            '${dado(CampoEvento.posicaoAnterior) ?? '—'} → ${dado(CampoEvento.posicao) ?? '—'}');
      case TipoEvento.ocorrencia:
      case TipoEvento.resolucao:
        add('Descrição', dado(CampoEvento.descricao));
      case TipoEvento.criacao:
        break;
    }
    return partes.join(' · ');
  }

  factory EventoOperacional.fromMap(Map<String, dynamic> m) {
    final dadosBrutos = m['dados'];
    return EventoOperacional(
      id: m['id'] as String,
      cargaId: m['carga_id'] as String,
      tipo: TipoEvento.fromCodigo(m['tipo'] as String?),
      statusAnterior: StatusCarga.tryCodigo(m['status_anterior'] as String?),
      statusNovo: StatusCarga.tryCodigo(m['status_novo'] as String?),
      dataHora: DateTime.parse(m['data_hora'] as String).toLocal(),
      registradoEm: m['registrado_em'] == null
          ? null
          : DateTime.parse(m['registrado_em'] as String).toLocal(),
      usuarioId: m['usuario_id'] as String?,
      usuarioNome: (m['usuario_nome'] as String?) ?? 'Sistema',
      dados: dadosBrutos is Map
          ? Map<String, dynamic>.from(dadosBrutos)
          : const <String, dynamic>{},
      observacao: m['observacao'] as String?,
    );
  }
}

/// Evento a ser registrado (entrada do formulário).
class NovoEvento {
  const NovoEvento({
    required this.tipo,
    required this.dataHora,
    this.statusNovo,
    this.dados = const {},
    this.observacao,
  });

  final TipoEvento tipo;
  final StatusCarga? statusNovo;
  final DateTime dataHora;
  final Map<String, String> dados;
  final String? observacao;

  String? dado(String chave) {
    final v = dados[chave]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  Map<String, dynamic> toRpcParams(String cargaId) => {
        'p_carga_id': cargaId,
        'p_tipo': tipo.codigo,
        'p_status_novo': statusNovo?.codigo,
        'p_data_hora': dataHora.toUtc().toIso8601String(),
        'p_dados': dados,
        'p_observacao':
            (observacao == null || observacao!.trim().isEmpty) ? null : observacao,
      };
}

import 'documento.dart';
import 'evento.dart';
import 'status_carga.dart';

export 'status_carga.dart';

class Carga {
  const Carga({
    required this.id,
    required this.conteiner,
    required this.booking,
    required this.navio,
    required this.viagem,
    required this.transportadora,
    required this.dataPrevista,
    required this.status,
    required this.criadoEm,
    required this.atualizadoEm,
    this.transportadoraCnpj,
    this.placa,
    this.motorista,
    this.pesoKg,
    this.dataEntrada,
    this.dataSaida,
    this.posicao,
    this.eventos = const [],
    this.documentos = const [],
  });

  final String id;
  final String conteiner;
  final String booking;
  final String navio;
  final String viagem;
  final String transportadora;
  final String? transportadoraCnpj;
  final String? placa;
  final String? motorista;
  final double? pesoKg;
  final DateTime dataPrevista;
  final DateTime? dataEntrada;
  final DateTime? dataSaida;
  final String? posicao;
  final StatusCarga status;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  /// Histórico ordenado do mais antigo para o mais recente.
  final List<EventoOperacional> eventos;
  final List<Documento> documentos;

  EventoOperacional? get ultimoEvento => eventos.isEmpty ? null : eventos.last;

  /// Ocorrências registradas que ainda não possuem resolução.
  List<EventoOperacional> get ocorrenciasAbertas {
    final resolvidas = eventos
        .where((e) => e.tipo == TipoEvento.resolucao)
        .map((e) => e.dado(CampoEvento.ocorrenciaId))
        .whereType<String>()
        .toSet();
    return eventos
        .where((e) =>
            e.tipo == TipoEvento.ocorrencia && !resolvidas.contains(e.id))
        .toList();
  }

  /// Momento em que a carga entrou no status atual.
  DateTime get statusDesde {
    for (final e in eventos.reversed) {
      if ((e.tipo == TipoEvento.status || e.tipo == TipoEvento.criacao) &&
          e.statusNovo == status) {
        return e.dataHora;
      }
    }
    return atualizadoEm;
  }

  /// Tempo de permanência no terminal (entrada → saída/agora).
  Duration? permanencia({DateTime? agora}) {
    if (dataEntrada == null) return null;
    return (dataSaida ?? agora ?? DateTime.now()).difference(dataEntrada!);
  }

  bool possuiDocumento(Set<TipoDocumento> tipos) =>
      documentos.any((d) => tipos.contains(d.tipo));

  factory Carga.fromMap(Map<String, dynamic> m) {
    DateTime? data(String k) =>
        m[k] == null ? null : DateTime.parse(m[k] as String).toLocal();

    final eventos = ((m['eventos'] as List?) ?? const [])
        .map((e) => EventoOperacional.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort(_ordenarEventos);
    final docs = ((m['documentos'] as List?) ?? const [])
        .map((d) => Documento.fromMap(Map<String, dynamic>.from(d as Map)))
        .toList()
      ..sort((a, b) => b.enviadoEm.compareTo(a.enviadoEm));

    return Carga(
      id: m['id'] as String,
      conteiner: m['conteiner'] as String,
      booking: (m['booking'] as String?) ?? '',
      navio: (m['navio'] as String?) ?? '',
      viagem: (m['viagem'] as String?) ?? '',
      transportadora: (m['transportadora'] as String?) ?? '',
      transportadoraCnpj: m['transportadora_cnpj'] as String?,
      placa: m['placa'] as String?,
      motorista: m['motorista'] as String?,
      pesoKg: (m['peso_kg'] as num?)?.toDouble(),
      dataPrevista: data('data_prevista')!,
      dataEntrada: data('data_entrada'),
      dataSaida: data('data_saida'),
      posicao: m['posicao'] as String?,
      status: StatusCarga.fromCodigo(m['status'] as String?),
      criadoEm: data('criado_em') ?? DateTime.now(),
      atualizadoEm: data('atualizado_em') ?? DateTime.now(),
      eventos: eventos,
      documentos: docs,
    );
  }

  static int _ordenarEventos(EventoOperacional a, EventoOperacional b) {
    final c = a.dataHora.compareTo(b.dataHora);
    if (c != 0) return c;
    final ra = a.registradoEm, rb = b.registradoEm;
    if (ra != null && rb != null) return ra.compareTo(rb);
    return 0;
  }

  /// Campos editáveis diretamente (cadastro/edição). O status nunca é
  /// alterado por aqui: apenas via registro de evento.
  Map<String, dynamic> toEditMap() => {
        'conteiner': conteiner,
        'booking': booking,
        'navio': navio,
        'viagem': viagem,
        'transportadora': transportadora,
        'transportadora_cnpj': transportadoraCnpj,
        'placa': placa,
        'motorista': motorista,
        'peso_kg': pesoKg,
        'data_prevista': dataPrevista.toUtc().toIso8601String(),
      };

  Carga copyWith({
    String? id,
    String? conteiner,
    String? booking,
    String? navio,
    String? viagem,
    String? transportadora,
    String? transportadoraCnpj,
    String? placa,
    String? motorista,
    double? pesoKg,
    DateTime? dataPrevista,
    DateTime? dataEntrada,
    DateTime? dataSaida,
    String? posicao,
    bool limparPosicao = false,
    StatusCarga? status,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
    List<EventoOperacional>? eventos,
    List<Documento>? documentos,
  }) =>
      Carga(
        id: id ?? this.id,
        conteiner: conteiner ?? this.conteiner,
        booking: booking ?? this.booking,
        navio: navio ?? this.navio,
        viagem: viagem ?? this.viagem,
        transportadora: transportadora ?? this.transportadora,
        transportadoraCnpj: transportadoraCnpj ?? this.transportadoraCnpj,
        placa: placa ?? this.placa,
        motorista: motorista ?? this.motorista,
        pesoKg: pesoKg ?? this.pesoKg,
        dataPrevista: dataPrevista ?? this.dataPrevista,
        dataEntrada: dataEntrada ?? this.dataEntrada,
        dataSaida: dataSaida ?? this.dataSaida,
        posicao: limparPosicao ? null : (posicao ?? this.posicao),
        status: status ?? this.status,
        criadoEm: criadoEm ?? this.criadoEm,
        atualizadoEm: atualizadoEm ?? this.atualizadoEm,
        eventos: eventos ?? this.eventos,
        documentos: documentos ?? this.documentos,
      );
}

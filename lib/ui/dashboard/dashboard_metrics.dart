import '../../models/carga.dart';
import '../../models/evento.dart';
import '../../models/pendencia.dart';
import '../../services/business_rules.dart';

class FluxoDia {
  const FluxoDia(this.dia, this.entradas, this.saidas);
  final DateTime dia;
  final int entradas;
  final int saidas;
}

/// Indicadores calculados a partir das cargas visíveis ao usuário.
class DashboardMetrics {
  DashboardMetrics(this.cargas, {DateTime? agora})
      : agora = agora ?? DateTime.now() {
    for (final c in cargas) {
      _pendencias[c.id] = BusinessRules.pendencias(c, agora: this.agora);
    }
  }

  final List<Carga> cargas;
  final DateTime agora;
  final Map<String, List<Pendencia>> _pendencias = {};

  List<Pendencia> pendenciasDe(Carga c) => _pendencias[c.id] ?? const [];

  int get noTerminal => cargas.where((c) => c.status.noTerminal).length;

  int get previstas24h => cargas
      .where((c) =>
          c.status == StatusCarga.previsto &&
          c.dataPrevista.isBefore(agora.add(const Duration(hours: 24))))
      .length;

  int get comPendencias =>
      cargas.where((c) => pendenciasDe(c).isNotEmpty).length;

  int get comPendenciaCritica => cargas
      .where((c) => pendenciasDe(c).any((p) => p.gravidade == Gravidade.alta))
      .length;

  int get emInspecao =>
      cargas.where((c) => c.status == StatusCarga.emInspecao).length;

  int get aguardandoRetirada =>
      cargas.where((c) => c.status == StatusCarga.liberado).length;

  int get retirados7d => cargas
      .where((c) =>
          c.dataSaida != null &&
          agora.difference(c.dataSaida!) <= const Duration(days: 7))
      .length;

  Map<StatusCarga, int> get porStatus => {
        for (final s in StatusCarga.values)
          s: cargas.where((c) => c.status == s).length,
      };

  Iterable<EventoOperacional> get _todosEventos =>
      cargas.expand((c) => c.eventos);

  /// Gate in (recepções) e gate out (retiradas) por dia, últimos 7 dias.
  List<FluxoDia> get fluxo7dias {
    final hoje = DateTime(agora.year, agora.month, agora.day);
    return [
      for (var i = 6; i >= 0; i--)
        () {
          final dia = hoje.subtract(Duration(days: i));
          final fim = dia.add(const Duration(days: 1));
          bool noDia(EventoOperacional e) =>
              !e.dataHora.isBefore(dia) && e.dataHora.isBefore(fim);
          final status =
              _todosEventos.where((e) => e.tipo == TipoEvento.status && noDia(e));
          return FluxoDia(
            dia,
            status.where((e) => e.statusNovo == StatusCarga.recepcionado).length,
            status.where((e) => e.statusNovo == StatusCarga.retirado).length,
          );
        }(),
    ];
  }

  /// Contêineres no pátio por bloco (primeira letra da posição).
  Map<String, int> get ocupacaoPorBloco {
    final mapa = <String, int>{};
    for (final c in cargas) {
      final p = c.posicao;
      if (!c.status.noTerminal || p == null || p.isEmpty) continue;
      final bloco = 'Bloco ${p[0]}';
      mapa[bloco] = (mapa[bloco] ?? 0) + 1;
    }
    final chaves = mapa.keys.toList()..sort();
    return {for (final k in chaves) k: mapa[k]!};
  }

  Duration? _media(Iterable<Duration> valores) {
    final lista = valores.toList();
    if (lista.isEmpty) return null;
    final total = lista.fold<int>(0, (s, d) => s + d.inMinutes);
    return Duration(minutes: total ~/ lista.length);
  }

  /// Permanência média (entrada → saída) das cargas retiradas.
  Duration? get permanenciaMedia => _media(cargas
      .where((c) => c.dataEntrada != null && c.dataSaida != null)
      .map((c) => c.dataSaida!.difference(c.dataEntrada!)));

  /// Tempo médio entre a entrada no terminal e a liberação.
  Duration? get tempoMedioLiberacao => _media(cargas
      .where((c) => c.dataEntrada != null)
      .map((c) {
        for (final e in c.eventos) {
          if (e.tipo == TipoEvento.status &&
              e.statusNovo == StatusCarga.liberado) {
            return e.dataHora.difference(c.dataEntrada!);
          }
        }
        return null;
      })
      .whereType<Duration>());

  /// Pendências de todas as cargas, das mais graves para as mais leves.
  List<(Carga, Pendencia)> get pendenciasOrdenadas {
    final lista = <(Carga, Pendencia)>[
      for (final c in cargas)
        for (final p in pendenciasDe(c)) (c, p),
    ]..sort((a, b) => a.$2.gravidade.index.compareTo(b.$2.gravidade.index));
    return lista;
  }

  /// Eventos registrados por colaborador nos últimos 7 dias.
  Map<String, int> get eventosPorUsuario7d {
    final mapa = <String, int>{};
    for (final e in _todosEventos) {
      if (e.tipo == TipoEvento.criacao) continue;
      if (agora.difference(e.dataHora) > const Duration(days: 7)) continue;
      mapa[e.usuarioNome] = (mapa[e.usuarioNome] ?? 0) + 1;
    }
    final ordenado = mapa.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in ordenado) e.key: e.value};
  }

  Map<TipoOcorrencia, int> get ocorrenciasPorTipo {
    final mapa = <TipoOcorrencia, int>{};
    for (final e in _todosEventos) {
      if (e.tipo != TipoEvento.ocorrencia) continue;
      final t = TipoOcorrencia.fromCodigo(e.dado(CampoEvento.tipoOcorrencia));
      mapa[t] = (mapa[t] ?? 0) + 1;
    }
    return mapa;
  }
}

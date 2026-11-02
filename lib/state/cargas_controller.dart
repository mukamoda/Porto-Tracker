import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/exceptions.dart';
import '../core/validators.dart';
import '../data/porto_repository.dart';
import '../models/carga.dart';
import '../models/documento.dart';
import '../models/evento.dart';
import '../models/pendencia.dart';
import '../services/business_rules.dart';

/// Estado central das cargas: lista, filtros, eventos e documentos.
class CargasController extends ChangeNotifier {
  CargasController(this._repo);

  final PortoRepository _repo;

  List<Carga> _cargas = const [];
  bool _carregando = false;
  String? _erro;
  DateTime? _ultimaAtualizacao;

  // Filtros do GRID
  String _busca = '';
  final Set<StatusCarga> _filtroStatus = {};
  bool _somentePendencias = false;

  List<Carga> get cargas => _cargas;
  bool get carregando => _carregando;
  String? get erro => _erro;
  DateTime? get ultimaAtualizacao => _ultimaAtualizacao;
  String get busca => _busca;
  Set<StatusCarga> get filtroStatus => Set.unmodifiable(_filtroStatus);
  bool get somentePendencias => _somentePendencias;
  bool get possuiFiltros =>
      _busca.isNotEmpty || _filtroStatus.isNotEmpty || _somentePendencias;

  /// Assinatura dos filtros (usada para reiniciar a paginação do GRID).
  String get assinaturaFiltros =>
      '$_busca|${_filtroStatus.map((s) => s.codigo).join(',')}|$_somentePendencias';

  List<Pendencia> pendenciasDe(Carga c) => BusinessRules.pendencias(c);

  List<Carga> get cargasFiltradas {
    final termo = _busca.trim().toUpperCase();
    final termoPlaca = Validators.normalizarPlaca(termo);
    return _cargas.where((c) {
      if (_filtroStatus.isNotEmpty && !_filtroStatus.contains(c.status)) {
        return false;
      }
      if (_somentePendencias && pendenciasDe(c).isEmpty) return false;
      if (termo.isEmpty) return true;
      return c.conteiner.contains(Iso6346.normalizar(termo)) ||
          c.booking.toUpperCase().contains(termo) ||
          c.navio.toUpperCase().contains(termo) ||
          c.transportadora.toUpperCase().contains(termo) ||
          (termoPlaca.isNotEmpty && (c.placa ?? '').contains(termoPlaca)) ||
          (c.posicao ?? '').contains(termo);
    }).toList();
  }

  int contarPorStatus(StatusCarga s) =>
      _cargas.where((c) => c.status == s).length;

  int get totalComPendencias =>
      _cargas.where((c) => pendenciasDe(c).isNotEmpty).length;

  Carga? porId(String id) {
    for (final c in _cargas) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ---------------------------------------------------------------- filtros

  void definirBusca(String termo) {
    _busca = termo;
    notifyListeners();
  }

  void alternarStatus(StatusCarga s) {
    if (!_filtroStatus.remove(s)) _filtroStatus.add(s);
    notifyListeners();
  }

  void definirSomentePendencias(bool v) {
    _somentePendencias = v;
    notifyListeners();
  }

  void limparFiltros() {
    _busca = '';
    _filtroStatus.clear();
    _somentePendencias = false;
    notifyListeners();
  }

  // ------------------------------------------------------------- operações

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      _cargas = await _repo.listarCargas();
      _ultimaAtualizacao = DateTime.now();
    } catch (e) {
      _erro = mensagemDeErro(e);
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> recarregarCarga(String id) async {
    final atualizada = await _repo.obterCarga(id);
    final idx = _cargas.indexWhere((c) => c.id == id);
    final nova = [..._cargas];
    if (idx >= 0) {
      nova[idx] = atualizada;
    } else {
      nova.insert(0, atualizada);
    }
    _cargas = nova;
    notifyListeners();
  }

  Future<Carga> criarCarga(Carga carga) async {
    final criada = await _repo.criarCarga(carga);
    _cargas = [criada, ..._cargas];
    notifyListeners();
    return criada;
  }

  Future<void> atualizarCarga(Carga carga) async {
    await _repo.atualizarCarga(carga);
    await recarregarCarga(carga.id);
  }

  Future<void> excluirCarga(String id) async {
    await _repo.excluirCarga(id);
    _cargas = _cargas.where((c) => c.id != id).toList();
    notifyListeners();
  }

  Future<void> registrarEvento(String cargaId, NovoEvento evento) async {
    await _repo.registrarEvento(cargaId, evento);
    await recarregarCarga(cargaId);
  }

  Future<void> enviarDocumento({
    required String cargaId,
    required TipoDocumento tipo,
    required String nomeArquivo,
    required Uint8List bytes,
    String? numero,
  }) async {
    await _repo.enviarDocumento(
      cargaId: cargaId,
      tipo: tipo,
      nomeArquivo: nomeArquivo,
      bytes: bytes,
      numero: numero,
    );
    await recarregarCarga(cargaId);
  }

  Future<Uri?> urlDocumento(Documento d) => _repo.urlDocumento(d);

  Future<void> excluirDocumento(Documento d) async {
    await _repo.excluirDocumento(d);
    await recarregarCarga(d.cargaId);
  }

  /// Limpa o estado ao sair (evita vazar dados entre perfis).
  void limpar() {
    _cargas = const [];
    _erro = null;
    _ultimaAtualizacao = null;
    _busca = '';
    _filtroStatus.clear();
    _somentePendencias = false;
    notifyListeners();
  }
}

import 'dart:math';
import 'dart:typed_data';

import '../core/config.dart';
import '../core/exceptions.dart';
import '../models/app_user.dart';
import '../models/carga.dart';
import '../models/documento.dart';
import '../models/evento.dart';
import '../models/user_role.dart';
import '../services/business_rules.dart';
import '../services/permissions.dart';
import 'demo_seed.dart';
import 'porto_repository.dart';

/// Repositório em memória para demonstração sem backend.
///
/// Reproduz as mesmas restrições que o Supabase aplica via RLS e pela função
/// `registrar_evento`: visibilidade por perfil, permissões e regras de negócio.
class DemoRepository implements PortoRepository {
  DemoRepository() {
    final seed = DemoSeed.gerar(DateTime.now());
    for (final u in seed.usuarios) {
      _usuarios[u.email] = _ContaDemo(u, senhaDemo);
    }
    for (final c in seed.cargas) {
      _cargas[c.id] = c;
    }
  }

  static const String senhaDemo = 'porto123';

  final Map<String, _ContaDemo> _usuarios = {};
  final Map<String, Carga> _cargas = {};
  final Random _random = Random();
  AppUser? _atual;

  @override
  bool get modoDemonstracao => true;

  // ---------------------------------------------------------------- helpers

  Future<void> _latencia() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  String _novoId(String prefixo) =>
      '${prefixo}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 20)}';

  AppUser get _usuario =>
      _atual ?? (throw const AppException('Sessão expirada. Entre novamente.'));

  void _exigir(Permissao p) {
    if (!Permissoes.pode(_usuario.papel, p)) {
      throw PermissionException(
          'Seu perfil (${_usuario.papel.label}) não permite: '
          '${p.descricao.toLowerCase()}.');
    }
  }

  bool _visivel(Carga c) =>
      Permissoes.pode(_usuario.papel, Permissao.verTodasCargas) ||
      (c.transportadoraCnpj != null &&
          c.transportadoraCnpj == _usuario.empresaCnpj);

  Carga _cargaVisivel(String id) {
    final c = _cargas[id];
    if (c == null || !_visivel(c)) {
      throw const AppException('Carga não encontrada ou sem acesso.');
    }
    return c;
  }

  /// Aplica o efeito de um evento sobre a carga (status, posição, datas...).
  static Carga aplicarEvento(Carga c, EventoOperacional e) {
    var nova = c.copyWith(
      eventos: [...c.eventos, e],
      atualizadoEm: e.registradoEm ?? e.dataHora,
    );
    switch (e.tipo) {
      case TipoEvento.status:
        final s = e.statusNovo!;
        nova = nova.copyWith(status: s);
        if (s == StatusCarga.recepcionado) {
          nova = nova.copyWith(
            placa: e.dado(CampoEvento.placa),
            motorista: e.dado(CampoEvento.motorista),
            pesoKg: double.tryParse(e.dado(CampoEvento.peso) ?? ''),
            dataEntrada: e.dataHora,
          );
        } else if (s == StatusCarga.armazenado) {
          nova = nova.copyWith(posicao: e.dado(CampoEvento.posicao));
        } else if (s == StatusCarga.retirado) {
          nova = nova.copyWith(
            placa: e.dado(CampoEvento.placa),
            motorista: e.dado(CampoEvento.motorista),
            dataSaida: e.dataHora,
            limparPosicao: true,
          );
        }
      case TipoEvento.movimentacao:
        nova = nova.copyWith(posicao: e.dado(CampoEvento.posicao));
      case TipoEvento.criacao:
      case TipoEvento.ocorrencia:
      case TipoEvento.resolucao:
        break;
    }
    return nova;
  }

  // ----------------------------------------------------------- autenticação

  @override
  Future<AppUser?> usuarioAtual() async => _atual;

  @override
  Future<AppUser> entrar(String email, String senha) async {
    await _latencia();
    final conta = _usuarios[email.trim().toLowerCase()];
    if (conta == null || conta.senha != senha) {
      throw const AppException('E-mail ou senha inválidos.');
    }
    _atual = conta.usuario;
    return conta.usuario;
  }

  @override
  Future<void> cadastrar({
    required String nome,
    required String email,
    required String senha,
    String? empresa,
    String? empresaCnpj,
  }) async {
    await _latencia();
    final chave = email.trim().toLowerCase();
    if (_usuarios.containsKey(chave)) {
      throw const AppException('Este e-mail já está cadastrado.');
    }
    final usuario = AppUser(
      id: _novoId('usr'),
      nome: nome.trim(),
      email: chave,
      papel: UserRole.transportador, // todo cadastro inicia no menor nível
      empresa: empresa,
      empresaCnpj: empresaCnpj,
      criadoEm: DateTime.now(),
    );
    _usuarios[chave] = _ContaDemo(usuario, senha);
  }

  @override
  Future<void> sair() async {
    _atual = null;
  }

  // ----------------------------------------------------------------- cargas

  @override
  Future<List<Carga>> listarCargas() async {
    await _latencia();
    final lista = _cargas.values.where(_visivel).toList()
      ..sort((a, b) => b.atualizadoEm.compareTo(a.atualizadoEm));
    return lista;
  }

  @override
  Future<Carga> obterCarga(String id) async {
    await _latencia();
    return _cargaVisivel(id);
  }

  @override
  Future<Carga> criarCarga(Carga nova) async {
    await _latencia();
    _exigir(Permissao.cadastrarCarga);
    if (_cargas.values.any((c) => c.conteiner == nova.conteiner)) {
      throw AppException(
          'Já existe uma carga com o contêiner ${nova.conteiner}.');
    }
    final agora = DateTime.now();
    final id = _novoId('cg');
    final evento = EventoOperacional(
      id: _novoId('ev'),
      cargaId: id,
      tipo: TipoEvento.criacao,
      statusNovo: StatusCarga.previsto,
      dataHora: agora,
      registradoEm: agora,
      usuarioId: _usuario.id,
      usuarioNome: _usuario.nome,
    );
    final carga = nova.copyWith(
      id: id,
      status: StatusCarga.previsto,
      criadoEm: agora,
      atualizadoEm: agora,
      eventos: [evento],
      documentos: const [],
    );
    _cargas[id] = carga;
    return carga;
  }

  @override
  Future<Carga> atualizarCarga(Carga carga) async {
    await _latencia();
    _exigir(Permissao.editarCarga);
    final existente = _cargaVisivel(carga.id);
    if (carga.conteiner != existente.conteiner &&
        _cargas.values.any((c) => c.conteiner == carga.conteiner)) {
      throw AppException('Já existe uma carga com o contêiner ${carga.conteiner}.');
    }
    // Status, datas operacionais, posição e histórico não mudam por edição.
    final atualizada = Carga(
      id: existente.id,
      conteiner: carga.conteiner,
      booking: carga.booking,
      navio: carga.navio,
      viagem: carga.viagem,
      transportadora: carga.transportadora,
      transportadoraCnpj: carga.transportadoraCnpj,
      placa: carga.placa,
      motorista: carga.motorista,
      pesoKg: carga.pesoKg,
      dataPrevista: carga.dataPrevista,
      dataEntrada: existente.dataEntrada,
      dataSaida: existente.dataSaida,
      posicao: existente.posicao,
      status: existente.status,
      criadoEm: existente.criadoEm,
      atualizadoEm: DateTime.now(),
      eventos: existente.eventos,
      documentos: existente.documentos,
    );
    _cargas[atualizada.id] = atualizada;
    return atualizada;
  }

  @override
  Future<void> excluirCarga(String id) async {
    await _latencia();
    _exigir(Permissao.excluirCarga);
    _cargaVisivel(id);
    _cargas.remove(id);
  }

  // ---------------------------------------------------------------- eventos

  @override
  Future<void> registrarEvento(String cargaId, NovoEvento evento) async {
    await _latencia();
    final carga = _cargaVisivel(cargaId);
    final erros = BusinessRules.validarEvento(
        carga: carga, evento: evento, papel: _usuario.papel);
    if (erros.isNotEmpty) throw BusinessRuleException(erros.join('\n'));

    final dados = <String, dynamic>{...evento.dados};
    if (evento.tipo == TipoEvento.movimentacao) {
      dados[CampoEvento.posicaoAnterior] = carga.posicao;
    }
    final registro = EventoOperacional(
      id: _novoId('ev'),
      cargaId: cargaId,
      tipo: evento.tipo,
      statusAnterior:
          evento.tipo == TipoEvento.status ? carga.status : null,
      statusNovo: evento.statusNovo,
      dataHora: evento.dataHora,
      registradoEm: DateTime.now(),
      usuarioId: _usuario.id,
      usuarioNome: _usuario.nome,
      dados: dados,
      observacao: (evento.observacao?.trim().isEmpty ?? true)
          ? null
          : evento.observacao!.trim(),
    );
    _cargas[cargaId] = aplicarEvento(carga, registro);
  }

  // ------------------------------------------------------------- documentos

  @override
  Future<Documento> enviarDocumento({
    required String cargaId,
    required TipoDocumento tipo,
    required String nomeArquivo,
    required Uint8List bytes,
    String? numero,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _exigir(Permissao.enviarDocumento);
    final carga = _cargaVisivel(cargaId);
    if (bytes.length > AppConfig.tamanhoMaximoArquivo) {
      throw const AppException('Arquivo maior que 10 MB.');
    }
    final doc = Documento(
      id: _novoId('doc'),
      cargaId: cargaId,
      tipo: tipo,
      nomeArquivo: nomeArquivo,
      caminho: '$cargaId/$nomeArquivo',
      tamanhoBytes: bytes.length,
      mimeType: Documento.mimePorExtensao(nomeArquivo),
      numero: numero,
      enviadoPorNome: _usuario.nome,
      enviadoEm: DateTime.now(),
      bytes: bytes,
    );
    _cargas[cargaId] = carga.copyWith(
      documentos: [doc, ...carga.documentos],
      atualizadoEm: DateTime.now(),
    );
    return doc;
  }

  @override
  Future<Uri?> urlDocumento(Documento documento) async => null;

  @override
  Future<void> excluirDocumento(Documento documento) async {
    await _latencia();
    _exigir(Permissao.excluirDocumento);
    final carga = _cargaVisivel(documento.cargaId);
    _cargas[carga.id] = carga.copyWith(
      documentos: carga.documentos.where((d) => d.id != documento.id).toList(),
      atualizadoEm: DateTime.now(),
    );
  }

  // --------------------------------------------------------------- usuários

  @override
  Future<List<AppUser>> listarUsuarios() async {
    await _latencia();
    _exigir(Permissao.gerenciarUsuarios);
    return _usuarios.values.map((c) => c.usuario).toList()
      ..sort((a, b) => b.papel.nivel != a.papel.nivel
          ? b.papel.nivel.compareTo(a.papel.nivel)
          : a.nome.compareTo(b.nome));
  }

  @override
  Future<void> alterarPapel(String usuarioId, UserRole papel) async {
    await _latencia();
    _exigir(Permissao.gerenciarUsuarios);
    if (usuarioId == _usuario.id) {
      throw const AppException('Você não pode alterar o próprio perfil.');
    }
    final entrada = _usuarios.entries.firstWhere(
      (e) => e.value.usuario.id == usuarioId,
      orElse: () => throw const AppException('Usuário não encontrado.'),
    );
    _usuarios[entrada.key] =
        _ContaDemo(entrada.value.usuario.copyWith(papel: papel), entrada.value.senha);
  }
}

class _ContaDemo {
  const _ContaDemo(this.usuario, this.senha);
  final AppUser usuario;
  final String senha;
}

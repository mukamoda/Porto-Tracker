import 'package:flutter/foundation.dart';

import '../data/porto_repository.dart';
import '../models/app_user.dart';
import '../services/permissions.dart';

/// Estado de autenticação e do usuário logado.
class AuthController extends ChangeNotifier {
  AuthController(this._repo);

  final PortoRepository _repo;

  AppUser? _usuario;
  bool _inicializado = false;
  bool _carregando = false;

  AppUser? get usuario => _usuario;
  bool get inicializado => _inicializado;
  bool get carregando => _carregando;
  bool get autenticado => _usuario != null;
  bool get modoDemonstracao => _repo.modoDemonstracao;

  bool pode(Permissao p) =>
      _usuario != null && Permissoes.pode(_usuario!.papel, p);

  Future<void> inicializar() async {
    try {
      _usuario = await _repo.usuarioAtual();
    } catch (_) {
      _usuario = null;
    }
    _inicializado = true;
    notifyListeners();
  }

  /// Erros são propagados para a tela exibir o feedback adequado.
  Future<void> entrar(String email, String senha) async {
    _carregando = true;
    notifyListeners();
    try {
      _usuario = await _repo.entrar(email, senha);
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> cadastrar({
    required String nome,
    required String email,
    required String senha,
    String? empresa,
    String? empresaCnpj,
  }) async {
    _carregando = true;
    notifyListeners();
    try {
      await _repo.cadastrar(
        nome: nome,
        email: email,
        senha: senha,
        empresa: empresa,
        empresaCnpj: empresaCnpj,
      );
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> sair() async {
    try {
      await _repo.sair();
    } finally {
      _usuario = null;
      notifyListeners();
    }
  }
}

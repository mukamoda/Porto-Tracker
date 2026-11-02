import 'package:flutter/foundation.dart';

import '../core/exceptions.dart';
import '../data/porto_repository.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';

/// Gestão de usuários (somente Administrador).
class UsuariosController extends ChangeNotifier {
  UsuariosController(this._repo);

  final PortoRepository _repo;

  List<AppUser> _usuarios = const [];
  bool _carregando = false;
  String? _erro;

  List<AppUser> get usuarios => _usuarios;
  bool get carregando => _carregando;
  String? get erro => _erro;

  Map<UserRole, int> get totalPorPerfil {
    final mapa = {for (final r in UserRole.values) r: 0};
    for (final u in _usuarios) {
      mapa[u.papel] = mapa[u.papel]! + 1;
    }
    return mapa;
  }

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      _usuarios = await _repo.listarUsuarios();
    } catch (e) {
      _erro = mensagemDeErro(e);
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> alterarPapel(AppUser usuario, UserRole papel) async {
    await _repo.alterarPapel(usuario.id, papel);
    _usuarios = [
      for (final u in _usuarios) u.id == usuario.id ? u.copyWith(papel: papel) : u
    ];
    notifyListeners();
  }

  void limpar() {
    _usuarios = const [];
    _erro = null;
    notifyListeners();
  }
}

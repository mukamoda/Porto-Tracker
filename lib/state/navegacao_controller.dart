import 'package:flutter/foundation.dart';

/// Abas (módulos) da área logada.
enum Aba { cargas, dashboard, documentos, usuarios, perfil }

/// Permite que um módulo direcione o usuário para outro
/// (ex.: um indicador do dashboard abre o GRID já filtrado).
class NavegacaoController extends ChangeNotifier {
  Aba _aba = Aba.cargas;

  Aba get aba => _aba;

  void ir(Aba aba) {
    if (_aba == aba) return;
    _aba = aba;
    notifyListeners();
  }

  void reiniciar() {
    _aba = Aba.cargas;
  }
}

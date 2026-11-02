import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../services/permissions.dart';
import '../../state/auth_controller.dart';
import '../../state/cargas_controller.dart';
import '../../state/navegacao_controller.dart';
import '../admin/usuarios_page.dart';
import '../cargas/cargas_grid_page.dart';
import '../dashboard/dashboard_page.dart';
import '../documentos/documentos_page.dart';
import '../perfil/perfil_page.dart';
import '../theme.dart';

class _Destino {
  const _Destino(
      this.aba, this.rotulo, this.icone, this.iconeSelecionado, this.pagina);

  final Aba aba;
  final String rotulo;
  final IconData icone;
  final IconData iconeSelecionado;
  final Widget pagina;
}

/// Estrutura principal após o login. Os módulos exibidos dependem do perfil:
/// GRID de cargas e Documentos (todos), Dashboard (Operador+),
/// Usuários (Admin) e Perfil (todos).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CargasController>().carregar();
    });
  }

  List<_Destino> _destinos(AppUser u) => [
        const _Destino(Aba.cargas, 'Cargas', Icons.view_list_outlined,
            Icons.view_list, CargasGridPage()),
        if (Permissoes.pode(u.papel, Permissao.verDashboard))
          const _Destino(Aba.dashboard, 'Dashboard', Icons.insights_outlined,
              Icons.insights, DashboardPage()),
        const _Destino(Aba.documentos, 'Documentos', Icons.folder_open_outlined,
            Icons.folder, DocumentosPage()),
        if (Permissoes.pode(u.papel, Permissao.gerenciarUsuarios))
          const _Destino(Aba.usuarios, 'Usuários', Icons.group_outlined,
              Icons.group, UsuariosPage()),
        const _Destino(Aba.perfil, 'Perfil', Icons.person_outline,
            Icons.person, PerfilPage()),
      ];

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthController>().usuario;
    final nav = context.watch<NavegacaoController>();
    if (usuario == null) return const SizedBox.shrink();

    final destinos = _destinos(usuario);
    var indice = destinos.indexWhere((d) => d.aba == nav.aba);
    if (indice < 0) indice = 0; // aba sem permissão → volta ao GRID
    void selecionar(int i) => nav.ir(destinos[i].aba);

    final corpo = IndexedStack(
      index: indice,
      children: [for (final d in destinos) d.pagina],
    );

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 900) {
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: indice,
                onDestinationSelected: selecionar,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.white,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Icon(Icons.directions_boat_filled,
                      color: AppTheme.laranjaConteiner, size: 32),
                ),
                destinations: [
                  for (final d in destinos)
                    NavigationRailDestination(
                      icon: Icon(d.icone),
                      selectedIcon: Icon(d.iconeSelecionado),
                      label: Text(d.rotulo),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: corpo),
            ],
          ),
        );
      }
      return Scaffold(
        body: corpo,
        bottomNavigationBar: NavigationBar(
          selectedIndex: indice,
          onDestinationSelected: selecionar,
          destinations: [
            for (final d in destinos)
              NavigationDestination(
                icon: Icon(d.icone),
                selectedIcon: Icon(d.iconeSelecionado),
                label: d.rotulo,
              ),
          ],
        ),
      );
    });
  }
}

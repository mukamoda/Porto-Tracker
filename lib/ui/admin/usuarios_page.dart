import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../services/permissions.dart';
import '../../state/auth_controller.dart';
import '../../state/usuarios_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';

/// Gestão de usuários e perfis de acesso (somente Administrador).
class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  String _busca = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UsuariosController>().carregar();
    });
  }

  Future<void> _alterar(AppUser u, UserRole novo) async {
    if (novo == u.papel) return;
    final ok = await AppFeedback.confirmar(
      context,
      titulo: 'Alterar perfil?',
      mensagem: '${u.nome} passará de ${u.papel.label} (nível '
          '${u.papel.nivel}) para ${novo.label} (nível ${novo.nivel}).',
    );
    if (!ok || !mounted) return;
    try {
      await context.read<UsuariosController>().alterarPapel(u, novo);
      if (mounted) {
        AppFeedback.sucesso(context, 'Perfil de ${u.nome} atualizado.');
      }
    } catch (e) {
      if (mounted) AppFeedback.erro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eu = context.watch<AuthController>().usuario!;
    final ctrl = context.watch<UsuariosController>();
    final termo = _busca.trim().toLowerCase();
    final lista = ctrl.usuarios
        .where((u) =>
            termo.isEmpty ||
            u.nome.toLowerCase().contains(termo) ||
            u.email.toLowerCase().contains(termo) ||
            (u.empresa ?? '').toLowerCase().contains(termo))
        .toList();

    return PermissionGuard(
      permitido: (u) => Permissoes.pode(u.papel, Permissao.gerenciarUsuarios),
      requisito: UserRole.admin,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Usuários e perfis'),
          actions: [
            IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh),
              onPressed: ctrl.carregando ? null : ctrl.carregar,
            ),
            const RoleBadge(),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: ctrl.carregar,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const _Hierarquia(),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _busca = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nome, e-mail ou empresa',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              if (ctrl.carregando && ctrl.usuarios.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (ctrl.erro != null)
                ErrorView(mensagem: ctrl.erro!, onRetry: ctrl.carregar)
              else if (lista.isEmpty)
                const EmptyState(
                    icone: Icons.person_search, titulo: 'Nenhum usuário')
              else
                for (final u in lista)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.azulPorto,
                        child: Text(Fmt.iniciais(u.nome),
                            style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(u.id == eu.id ? '${u.nome} (você)' : u.nome),
                      subtitle: Text([
                        u.email,
                        if (u.empresa != null) u.empresa!,
                      ].join(' · ')),
                      trailing: DropdownButton<UserRole>(
                        value: u.papel,
                        underline: const SizedBox.shrink(),
                        onChanged: u.id == eu.id
                            ? null
                            : (novo) {
                                if (novo != null) _alterar(u, novo);
                              },
                        items: [
                          for (final r in UserRole.values.reversed)
                            DropdownMenuItem(
                              value: r,
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(r.icone, size: 16),
                                const SizedBox(width: 6),
                                Text(r.label),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hierarquia extends StatelessWidget {
  const _Hierarquia();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      titulo: 'Hierarquia de acesso',
      icone: Icons.account_tree_outlined,
      child: Column(
        children: [
          for (final r in UserRole.values.reversed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.azulPorto.withAlpha(20 + r.nivel * 25),
                child: Text('${r.nivel}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              title: Row(children: [
                Icon(r.icone, size: 16),
                const SizedBox(width: 6),
                Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              subtitle: Text(r.descricao),
            ),
          const Text(
            'Cada nível herda tudo o que os níveis abaixo podem fazer.',
            style: TextStyle(fontSize: 12, color: AppTheme.textoSecundario),
          ),
        ],
      ),
    );
  }
}

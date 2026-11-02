import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../services/permissions.dart';
import '../../state/auth_controller.dart';
import '../../state/cargas_controller.dart';
import '../../state/navegacao_controller.dart';
import '../../state/usuarios_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';

/// Perfil do usuário: dados, nível de acesso e permissões efetivas.
class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  Future<void> _sair(BuildContext context) async {
    final ok = await AppFeedback.confirmar(context,
        titulo: 'Sair', mensagem: 'Deseja encerrar a sessão?', confirmar: 'Sair');
    if (!ok || !context.mounted) return;
    // Limpa o estado para não vazar dados entre perfis.
    context.read<CargasController>().limpar();
    context.read<UsuariosController>().limpar();
    context.read<NavegacaoController>().reiniciar();
    await context.read<AuthController>().sair();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final u = auth.usuario!;
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SectionCard(
            titulo: 'Dados do usuário',
            icone: Icons.person_outline,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.azulPorto,
                  child: Text(Fmt.iniciais(u.nome),
                      style: const TextStyle(color: Colors.white, fontSize: 20)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.nome,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(u.email,
                          style: const TextStyle(color: AppTheme.textoSecundario)),
                      if (u.empresa != null)
                        Text('${u.empresa} · ${Fmt.cnpj(u.empresaCnpj)}',
                            style: const TextStyle(
                                color: AppTheme.textoSecundario)),
                      const SizedBox(height: 6),
                      Chip(
                        avatar: Icon(u.papel.icone, size: 16),
                        label: Text('${u.papel.label} · nível ${u.papel.nivel}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            titulo: 'O que seu perfil pode fazer',
            icone: Icons.verified_user_outlined,
            child: Column(
              children: [
                Text(u.papel.descricao),
                const SizedBox(height: 8),
                for (final p in Permissao.values)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Permissoes.pode(u.papel, p)
                          ? Icons.check_circle
                          : Icons.lock_outline,
                      color: Permissoes.pode(u.papel, p)
                          ? AppTheme.sucesso
                          : AppTheme.textoSecundario,
                    ),
                    title: Text(p.descricao),
                    trailing: Permissoes.pode(u.papel, p)
                        ? null
                        : Text('Requer ${Permissoes.minimo(p).label}',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textoSecundario)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            titulo: 'Ambiente',
            icone: Icons.cloud_outlined,
            child: Text(auth.modoDemonstracao
                ? 'Modo demonstração: dados em memória, reiniciados ao fechar o app.'
                : 'Conectado ao Supabase (Auth, Postgres com RLS e Storage).'),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _sair(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.critico,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

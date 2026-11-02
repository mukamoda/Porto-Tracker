import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/carga.dart';
import '../../models/evento.dart';
import '../../models/user_role.dart';
import '../../services/permissions.dart';
import '../../state/auth_controller.dart';
import '../../state/cargas_controller.dart';
import '../../state/navegacao_controller.dart';
import '../../state/usuarios_controller.dart';
import '../cargas/acoes_carga.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart' show ErrorView;
import 'charts.dart';
import 'dashboard_metrics.dart';

/// Módulo de visão macro da operação (Operador+). Supervisores veem também
/// a produtividade da equipe; administradores, a distribuição de perfis.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthController>().pode(Permissao.gerenciarUsuarios)) {
        context.read<UsuariosController>().carregar();
      }
    });
  }

  void _filtrarGrid(BuildContext context, {StatusCarga? status, bool pendencias = false}) {
    final ctrl = context.read<CargasController>();
    ctrl.limparFiltros();
    if (status != null) ctrl.alternarStatus(status);
    if (pendencias) ctrl.definirSomentePendencias(true);
    context.read<NavegacaoController>().ir(Aba.cargas);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final usuario = auth.usuario!;
    final ctrl = context.watch<CargasController>();

    return PermissionGuard(
      permitido: (u) => Permissoes.pode(u.papel, Permissao.verDashboard),
      requisito: UserRole.operador,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard da operação'),
          actions: [
            IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh),
              onPressed: ctrl.carregando ? null : ctrl.carregar,
            ),
            const RoleBadge(),
          ],
        ),
        body: Builder(builder: (context) {
          if (ctrl.carregando && ctrl.cargas.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ctrl.erro != null && ctrl.cargas.isEmpty) {
            return ErrorView(mensagem: ctrl.erro!, onRetry: ctrl.carregar);
          }
          final m = DashboardMetrics(ctrl.cargas);
          return RefreshIndicator(
            onRefresh: ctrl.carregar,
            child: LayoutBuilder(builder: (context, constraints) {
              final largura = constraints.maxWidth - 24;
              final colunasKpi = largura > 1000 ? 6 : (largura > 560 ? 3 : 2);
              final larguraKpi = (largura - 10 * (colunasKpi - 1)) / colunasKpi;
              final larguraCard = largura > 900 ? (largura - 12) / 2 : largura;

              Widget kpi(Widget w) => SizedBox(width: larguraKpi, child: w);
              Widget card(Widget w) => SizedBox(width: larguraCard, child: w);

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Text(
                    'Atualizado ${ctrl.ultimaAtualizacao == null ? '—' : 'às ${Fmt.hora(ctrl.ultimaAtualizacao)}'}'
                    ' · ${ctrl.cargas.length} cargas no sistema',
                    style: const TextStyle(color: AppTheme.textoSecundario),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    kpi(KpiCard(
                      titulo: 'No terminal',
                      valor: '${m.noTerminal}',
                      icone: Icons.warehouse_outlined,
                      subtitulo: 'Recepcionadas até liberadas',
                    )),
                    kpi(KpiCard(
                      titulo: 'Chegadas em 24h',
                      valor: '${m.previstas24h}',
                      icone: StatusCarga.previsto.icone,
                      subtitulo: 'Previstas (inclui atrasadas)',
                      onTap: () =>
                          _filtrarGrid(context, status: StatusCarga.previsto),
                    )),
                    kpi(KpiCard(
                      titulo: 'Com pendências',
                      valor: '${m.comPendencias}',
                      icone: Icons.warning_amber_rounded,
                      corIcone: AppTheme.alerta,
                      subtitulo: '${m.comPendenciaCritica} crítica(s)',
                      onTap: () => _filtrarGrid(context, pendencias: true),
                    )),
                    kpi(KpiCard(
                      titulo: 'Em inspeção',
                      valor: '${m.emInspecao}',
                      icone: StatusCarga.emInspecao.icone,
                      onTap: () =>
                          _filtrarGrid(context, status: StatusCarga.emInspecao),
                    )),
                    kpi(KpiCard(
                      titulo: 'Aguardando retirada',
                      valor: '${m.aguardandoRetirada}',
                      icone: StatusCarga.liberado.icone,
                      onTap: () =>
                          _filtrarGrid(context, status: StatusCarga.liberado),
                    )),
                    kpi(KpiCard(
                      titulo: 'Retiradas (7 dias)',
                      valor: '${m.retirados7d}',
                      icone: StatusCarga.retirado.icone,
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    card(SectionCard(
                      titulo: 'Cargas por etapa',
                      icone: Icons.stacked_bar_chart,
                      child: BarrasHorizontais(
                        itens: [
                          for (final e in m.porStatus.entries)
                            BarraItem(e.key.label, e.value,
                                cor: e.key.cor,
                                icone: e.key.icone,
                                onTap: () =>
                                    _filtrarGrid(context, status: e.key)),
                        ],
                      ),
                    )),
                    card(SectionCard(
                      titulo: 'Gate in × gate out (7 dias)',
                      icone: Icons.swap_vert,
                      child: Builder(builder: (_) {
                        final fluxo = m.fluxo7dias;
                        return ColunasAgrupadas(
                          rotulos: [for (final f in fluxo) Fmt.dataCurta(f.dia)],
                          series: [
                            SerieColunas('Entradas (gate in)', AppTheme.serie1,
                                [for (final f in fluxo) f.entradas]),
                            SerieColunas('Saídas (gate out)', AppTheme.serie2,
                                [for (final f in fluxo) f.saidas]),
                          ],
                        );
                      }),
                    )),
                    card(SectionCard(
                      titulo: 'Ocupação do pátio por bloco',
                      icone: Icons.grid_view,
                      child: BarrasHorizontais(
                        larguraRotulo: 80,
                        unidade: ' contêiner(es)',
                        itens: [
                          for (final e in m.ocupacaoPorBloco.entries)
                            BarraItem(e.key, e.value),
                        ],
                      ),
                    )),
                    card(SectionCard(
                      titulo: 'Tempos médios',
                      icone: Icons.timer_outlined,
                      child: Wrap(spacing: 24, runSpacing: 12, children: [
                        InfoItem(
                            'Entrada → liberação',
                            m.tempoMedioLiberacao == null
                                ? '—'
                                : Fmt.duracao(m.tempoMedioLiberacao!),
                            largura: 180),
                        InfoItem(
                            'Permanência (retiradas)',
                            m.permanenciaMedia == null
                                ? '—'
                                : Fmt.duracao(m.permanenciaMedia!),
                            largura: 180),
                      ]),
                    )),
                    card(_CardPendencias(metrics: m)),
                    if (Permissoes.pode(
                        usuario.papel, Permissao.verDesempenhoEquipe)) ...[
                      card(SectionCard(
                        titulo: 'Produtividade da equipe (7 dias)',
                        icone: Icons.groups_outlined,
                        trailing: const _SeloRestrito(UserRole.supervisor),
                        child: BarrasHorizontais(
                          larguraRotulo: 140,
                          unidade: ' evento(s)',
                          itens: [
                            for (final e in m.eventosPorUsuario7d.entries)
                              BarraItem(e.key, e.value),
                          ],
                        ),
                      )),
                      card(SectionCard(
                        titulo: 'Ocorrências por tipo',
                        icone: Icons.report_problem_outlined,
                        trailing: const _SeloRestrito(UserRole.supervisor),
                        child: BarrasHorizontais(
                          larguraRotulo: 160,
                          itens: [
                            for (final t in TipoOcorrencia.values)
                              if ((m.ocorrenciasPorTipo[t] ?? 0) > 0)
                                BarraItem(t.label, m.ocorrenciasPorTipo[t]!),
                          ],
                        ),
                      )),
                    ],
                    if (Permissoes.pode(
                        usuario.papel, Permissao.gerenciarUsuarios))
                      card(const _CardUsuarios()),
                  ]),
                ],
              );
            }),
          );
        }),
      ),
    );
  }
}

class _SeloRestrito extends StatelessWidget {
  const _SeloRestrito(this.papel);
  final UserRole papel;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Visível para ${papel.label} ou superior',
      child: Icon(papel.icone, size: 18, color: AppTheme.textoSecundario),
    );
  }
}

class _CardPendencias extends StatelessWidget {
  const _CardPendencias({required this.metrics});

  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final lista = metrics.pendenciasOrdenadas.take(6).toList();
    return SectionCard(
      titulo: 'Pendências prioritárias',
      icone: Icons.priority_high,
      child: lista.isEmpty
          ? const Text('Nenhuma pendência. Operação em dia!',
              style: TextStyle(color: AppTheme.textoSecundario))
          : Column(
              children: [
                for (final (c, p) in lista)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(p.gravidade.icone, color: p.gravidade.cor),
                    title: Text(c.conteiner,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(p.descricao),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => AcoesCarga.abrirDetalhe(context, c.id),
                  ),
              ],
            ),
    );
  }
}

class _CardUsuarios extends StatelessWidget {
  const _CardUsuarios();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<UsuariosController>();
    return SectionCard(
      titulo: 'Usuários por perfil',
      icone: Icons.admin_panel_settings_outlined,
      trailing: const _SeloRestrito(UserRole.admin),
      child: ctrl.carregando && ctrl.usuarios.isEmpty
          ? const LinearProgressIndicator()
          : BarrasHorizontais(
              larguraRotulo: 170,
              unidade: ' usuário(s)',
              itens: [
                for (final e in ctrl.totalPorPerfil.entries.toList().reversed)
                  BarraItem(e.key.label, e.value, icone: e.key.icone),
              ],
            ),
    );
  }
}

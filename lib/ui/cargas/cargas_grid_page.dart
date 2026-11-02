import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../models/app_user.dart';
import '../../models/carga.dart';
import '../../models/evento.dart';
import '../../models/pendencia.dart';
import '../../services/business_rules.dart';
import '../../services/permissions.dart';
import '../../state/auth_controller.dart';
import '../../state/cargas_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart' show EmptyState, ErrorView;
import '../widgets/status_chip.dart';
import 'acoes_carga.dart';
import 'coluna_grid.dart';

/// Módulo principal: GRID operacional de cargas/contêineres.
///
/// * colunas variam conforme o perfil (ver [ColunaGrid]);
/// * busca, filtro por status, filtro de pendências e ordenação por coluna;
/// * células editáveis (ícone de lápis) para preenchimento pelos operadores;
/// * ações rápidas por linha: registrar evento, enviar documento, detalhes.
class CargasGridPage extends StatefulWidget {
  const CargasGridPage({super.key});

  @override
  State<CargasGridPage> createState() => _CargasGridPageState();
}

class _CargasGridPageState extends State<CargasGridPage> {
  final _busca = TextEditingController();
  final Set<ColunaGrid> _ocultas = {};
  ColunaGrid? _ordenarPor;
  bool _crescente = true;
  int _linhasPorPagina = 10;

  @override
  void initState() {
    super.initState();
    _busca.text = context.read<CargasController>().busca;
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _escolherColunas(List<ColunaGrid> permitidas) async {
    final selecao = <ColunaGrid>{..._ocultas};
    final resultado = await showDialog<Set<ColunaGrid>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Colunas visíveis'),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in permitidas)
                  CheckboxListTile(
                    dense: true,
                    value: !selecao.contains(c),
                    title: Text(c.rotulo),
                    // Contêiner e status são sempre exibidos.
                    onChanged: (c == ColunaGrid.conteiner ||
                            c == ColunaGrid.status)
                        ? null
                        : (v) => setLocal(() =>
                            v == true ? selecao.remove(c) : selecao.add(c)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, <ColunaGrid>{}),
                child: const Text('Mostrar todas')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, selecao),
                child: const Text('Aplicar')),
          ],
        ),
      ),
    );
    if (resultado != null) {
      setState(() {
        _ocultas
          ..clear()
          ..addAll(resultado);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthController>().usuario!;
    final ctrl = context.watch<CargasController>();
    final permitidas = ColunaGrid.permitidas(usuario.papel);
    final visiveis = permitidas.where((c) => !_ocultas.contains(c)).toList();
    final podeCadastrar =
        Permissoes.pode(usuario.papel, Permissao.cadastrarCarga);

    // Mantém o campo de busca sincronizado com filtros aplicados por outros
    // módulos (ex.: indicadores do dashboard).
    if (_busca.text != ctrl.busca) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _busca.text != ctrl.busca) _busca.text = ctrl.busca;
      });
    }

    final filtradas = ctrl.cargasFiltradas;
    final ordenar = _ordenarPor;
    if (ordenar != null && visiveis.contains(ordenar)) {
      filtradas.sort((a, b) =>
          _crescente ? ordenar.comparar(a, b) : ordenar.comparar(b, a));
    }

    Widget corpo;
    if (ctrl.carregando && ctrl.cargas.isEmpty) {
      corpo = const Center(child: CircularProgressIndicator());
    } else if (ctrl.erro != null && ctrl.cargas.isEmpty) {
      corpo = ErrorView(mensagem: ctrl.erro!, onRetry: ctrl.carregar);
    } else {
      corpo = RefreshIndicator(
        onRefresh: ctrl.carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            _BarraFiltros(controller: _busca, usuario: usuario),
            const SizedBox(height: 12),
            if (filtradas.isEmpty)
              EmptyState(
                icone: Icons.search_off,
                titulo: ctrl.cargas.isEmpty
                    ? 'Nenhuma carga visível para o seu perfil'
                    : 'Nenhuma carga encontrada com esses filtros',
                acao: ctrl.possuiFiltros
                    ? OutlinedButton(
                        onPressed: () {
                          _busca.clear();
                          ctrl.limparFiltros();
                        },
                        child: const Text('Limpar filtros'))
                    : null,
              )
            else
              PaginatedDataTable(
                key: ValueKey(
                    '${ctrl.assinaturaFiltros}|${visiveis.length}|$_linhasPorPagina'),
                header: Row(
                  children: [
                    Text('${filtradas.length} de ${ctrl.cargas.length} cargas'),
                    const SizedBox(width: 12),
                    if (ctrl.carregando)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                columns: [
                  for (final c in visiveis)
                    DataColumn(
                      label: Text(c.rotulo,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      numeric: c.numerica,
                      onSort: (_, asc) => setState(() {
                        _ordenarPor = c;
                        _crescente = asc;
                      }),
                    ),
                  const DataColumn(
                      label: Text('Ações',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                sortColumnIndex: (ordenar != null && visiveis.contains(ordenar))
                    ? visiveis.indexOf(ordenar)
                    : null,
                sortAscending: _crescente,
                rowsPerPage: _linhasPorPagina,
                availableRowsPerPage: const [10, 20, 50],
                onRowsPerPageChanged: (v) =>
                    setState(() => _linhasPorPagina = v ?? 10),
                showCheckboxColumn: false,
                showFirstLastButtons: true,
                columnSpacing: 20,
                horizontalMargin: 12,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 60,
                source: _CargasDataSource(
                  cargas: filtradas,
                  colunas: visiveis,
                  usuario: usuario,
                  context: context,
                ),
              ),
            const SizedBox(height: 8),
            _LegendaGrid(usuario: usuario, totalColunas: permitidas.length),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cargas e contêineres'),
        actions: [
          IconButton(
            tooltip: 'Colunas',
            icon: const Icon(Icons.view_column_outlined),
            onPressed: () => _escolherColunas(permitidas),
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: ctrl.carregando ? null : ctrl.carregar,
          ),
          const RoleBadge(),
        ],
      ),
      floatingActionButton: podeCadastrar
          ? FloatingActionButton.extended(
              onPressed: () => AcoesCarga.novaCarga(context),
              icon: const Icon(Icons.add),
              label: const Text('Nova carga'),
            )
          : null,
      body: corpo,
    );
  }
}

// ---------------------------------------------------------------- filtros

class _BarraFiltros extends StatelessWidget {
  const _BarraFiltros({required this.controller, required this.usuario});

  final TextEditingController controller;
  final AppUser usuario;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CargasController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: ctrl.definirBusca,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'Buscar por contêiner, booking, placa, navio, posição...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      ctrl.definirBusca('');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                avatar: const Icon(Icons.warning_amber_rounded,
                    size: 18, color: AppTheme.critico),
                label: Text('Com pendências (${ctrl.totalComPendencias})'),
                selected: ctrl.somentePendencias,
                onSelected: ctrl.definirSomentePendencias,
              ),
              const SizedBox(width: 8),
              for (final s in StatusCarga.values) ...[
                FilterChip(
                  avatar: Icon(s.icone, size: 18, color: s.cor),
                  label: Text('${s.label} (${ctrl.contarPorStatus(s)})'),
                  selected: ctrl.filtroStatus.contains(s),
                  onSelected: (_) => ctrl.alternarStatus(s),
                ),
                const SizedBox(width: 8),
              ],
              if (ctrl.possuiFiltros)
                TextButton.icon(
                  onPressed: () {
                    controller.clear();
                    ctrl.limparFiltros();
                  },
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Limpar'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendaGrid extends StatelessWidget {
  const _LegendaGrid({required this.usuario, required this.totalColunas});

  final AppUser usuario;
  final int totalColunas;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Perfil ${usuario.papel.label}: $totalColunas de ${ColunaGrid.values.length} '
      'colunas disponíveis. Toque em uma linha para ver detalhes e histórico; '
      'células com ✎ podem ser preenchidas diretamente.',
      style: const TextStyle(fontSize: 12, color: AppTheme.textoSecundario),
    );
  }
}

// ------------------------------------------------------------ data source

class _CargasDataSource extends DataTableSource {
  _CargasDataSource({
    required this.cargas,
    required this.colunas,
    required this.usuario,
    required this.context,
  });

  final List<Carga> cargas;
  final List<ColunaGrid> colunas;
  final AppUser usuario;
  final BuildContext context;

  bool _pode(Permissao p) => Permissoes.pode(usuario.papel, p);

  @override
  DataRow? getRow(int index) {
    if (index >= cargas.length) return null;
    final c = cargas[index];
    final pendencias = BusinessRules.pendencias(c);
    final critica =
        pendencias.isNotEmpty && pendencias.first.gravidade == Gravidade.alta;
    return DataRow.byIndex(
      index: index,
      color: WidgetStateProperty.resolveWith((estados) {
        if (estados.contains(WidgetState.hovered)) {
          return AppTheme.azulPorto.withAlpha(14);
        }
        return critica ? AppTheme.critico.withAlpha(16) : null;
      }),
      onSelectChanged: (_) => AcoesCarga.abrirDetalhe(context, c.id),
      cells: [
        for (final col in colunas) _celula(col, c, pendencias),
        DataCell(_acoes(c)),
      ],
    );
  }

  DataCell _texto(String? v, {bool negrito = false}) => DataCell(Text(
        v == null || v.isEmpty ? '—' : v,
        overflow: TextOverflow.ellipsis,
        style: negrito
            ? const TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'monospace')
            : null,
      ));

  DataCell _celula(ColunaGrid col, Carga c, List<Pendencia> pendencias) {
    final agendavel =
        c.status == StatusCarga.previsto || c.status == StatusCarga.liberado;
    final podeEditar = _pode(Permissao.editarCarga);

    switch (col) {
      case ColunaGrid.status:
        return DataCell(StatusChip(c.status, compacto: true));
      case ColunaGrid.conteiner:
        return _texto(c.conteiner, negrito: true);
      case ColunaGrid.pendencias:
        return DataCell(PendenciasBadge(pendencias));
      case ColunaGrid.proximaEtapa:
        return _texto(BusinessRules.proximaEtapa(c));
      case ColunaGrid.previsao:
        final editavel = podeEditar && c.status == StatusCarga.previsto;
        return DataCell(
          Text(Fmt.dataHoraCurta(c.dataPrevista)),
          showEditIcon: editavel,
          onTap: editavel ? () => AcoesCarga.editarPrevisao(context, c) : null,
        );
      case ColunaGrid.placa:
        final editavel = podeEditar && agendavel;
        return DataCell(
          Text(c.placa ?? '—'),
          placeholder: c.placa == null,
          showEditIcon: editavel,
          onTap: editavel
              ? () => AcoesCarga.editarCampoTexto(
                    context,
                    carga: c,
                    titulo: 'Placa',
                    valorAtual: c.placa ?? '',
                    validador: Validators.placa,
                    aplicar: (v) =>
                        c.copyWith(placa: Validators.normalizarPlaca(v)),
                  )
              : null,
        );
      case ColunaGrid.motorista:
        final editavel = podeEditar && agendavel;
        return DataCell(
          Text(c.motorista ?? '—', overflow: TextOverflow.ellipsis),
          placeholder: c.motorista == null,
          showEditIcon: editavel,
          onTap: editavel
              ? () => AcoesCarga.editarCampoTexto(
                    context,
                    carga: c,
                    titulo: 'Motorista',
                    valorAtual: c.motorista ?? '',
                    capitalizacao: TextCapitalization.words,
                    validador: (v) => Validators.obrigatorio(v, 'Motorista'),
                    aplicar: (v) => c.copyWith(motorista: v),
                  )
              : null,
        );
      case ColunaGrid.transportadora:
        return DataCell(SizedBox(
            width: 170,
            child: Text(c.transportadora, overflow: TextOverflow.ellipsis)));
      case ColunaGrid.entrada:
        return _texto(c.dataEntrada == null ? null : Fmt.dataHoraCurta(c.dataEntrada));
      case ColunaGrid.peso:
        return _texto(c.pesoKg == null ? null : Fmt.peso(c.pesoKg));
      case ColunaGrid.posicao:
        final editavel = _pode(Permissao.registrarArmazenagem) &&
            BusinessRules.statusMovimentaveis.contains(c.status);
        return DataCell(
          Text(c.posicao ?? '—',
              style: const TextStyle(fontFamily: 'monospace')),
          placeholder: c.posicao == null,
          showEditIcon: editavel,
          onTap: editavel
              ? () => AcoesCarga.registrarEvento(context, c,
                  tipoInicial: c.posicao == null
                      ? TipoEvento.status
                      : TipoEvento.movimentacao)
              : null,
        );
      case ColunaGrid.booking:
        return _texto(c.booking);
      case ColunaGrid.navio:
        return _texto(c.navio);
      case ColunaGrid.viagem:
        return _texto(c.viagem);
      case ColunaGrid.documentos:
        final faltam = (c.status == StatusCarga.armazenado ||
                c.status == StatusCarga.emInspecao) &&
            BusinessRules.documentosFaltantes(c).isNotEmpty;
        return DataCell(Tooltip(
          message: c.documentos.isEmpty
              ? 'Nenhum documento'
              : c.documentos.map((d) => d.tipo.sigla).join(', '),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (faltam)
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppTheme.alerta),
            const SizedBox(width: 2),
            Text('${c.documentos.length}'),
          ]),
        ));
      case ColunaGrid.permanencia:
        final p = c.permanencia();
        return _texto(p == null ? null : Fmt.duracao(p));
      case ColunaGrid.ultimoEvento:
        final e = c.ultimoEvento;
        return _texto(
            e == null ? null : '${e.titulo} · ${Fmt.relativo(e.dataHora)}');
      case ColunaGrid.responsavel:
        return _texto(c.ultimoEvento?.usuarioNome);
    }
  }

  Widget _acoes(Carga c) {
    final podeEvento = BusinessRules.podeRegistrarAlgo(usuario.papel, c);
    final podeDoc = _pode(Permissao.enviarDocumento);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: podeEvento
              ? 'Registrar evento'
              : 'Sem eventos disponíveis para seu perfil',
          icon: const Icon(Icons.add_task),
          color: AppTheme.azulPorto,
          onPressed:
              podeEvento ? () => AcoesCarga.registrarEvento(context, c) : null,
        ),
        if (podeDoc)
          IconButton(
            tooltip: 'Enviar documento',
            icon: const Icon(Icons.upload_file),
            onPressed: () => AcoesCarga.enviarDocumento(context, carga: c),
          ),
        IconButton(
          tooltip: 'Detalhes e histórico',
          icon: const Icon(Icons.open_in_new),
          onPressed: () => AcoesCarga.abrirDetalhe(context, c.id),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => cargas.length;

  @override
  int get selectedRowCount => 0;
}

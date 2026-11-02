import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/app_user.dart';
import '../../models/carga.dart';
import '../../models/documento.dart';
import '../../models/evento.dart';
import '../../models/user_role.dart';
import '../../services/business_rules.dart';
import '../../services/permissions.dart';
import '../../state/auth_controller.dart';
import '../../state/cargas_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';
import '../widgets/status_chip.dart';
import 'acoes_carga.dart';

/// Detalhe da carga: situação atual, pendências, dados, documentos e
/// histórico completo de movimentações.
class CargaDetailPage extends StatefulWidget {
  const CargaDetailPage({super.key, required this.cargaId});

  final String cargaId;

  @override
  State<CargaDetailPage> createState() => _CargaDetailPageState();
}

class _CargaDetailPageState extends State<CargaDetailPage> {
  bool _atualizando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _atualizar());
  }

  Future<void> _atualizar() async {
    setState(() => _atualizando = true);
    try {
      await context.read<CargasController>().recarregarCarga(widget.cargaId);
    } catch (e) {
      if (mounted) AppFeedback.erro(context, e);
    } finally {
      if (mounted) setState(() => _atualizando = false);
    }
  }

  Future<void> _excluir(Carga c) async {
    final ok = await AppFeedback.confirmar(
      context,
      titulo: 'Excluir carga?',
      mensagem: 'A carga ${c.conteiner}, seu histórico e documentos serão '
          'removidos definitivamente.',
      confirmar: 'Excluir',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<CargasController>().excluirCarga(c.id);
      if (!mounted) return;
      AppFeedback.sucesso(context, 'Carga ${c.conteiner} excluída.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) AppFeedback.erro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthController>().usuario!;
    final carga = context.watch<CargasController>().porId(widget.cargaId);

    if (carga == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carga')),
        body: _atualizando
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(
                icone: Icons.search_off,
                titulo: 'Carga não encontrada',
                mensagem: 'Ela pode ter sido excluída ou não estar visível '
                    'para o seu perfil.'),
      );
    }

    bool pode(Permissao p) => Permissoes.pode(usuario.papel, p);
    final podeEvento = BusinessRules.podeRegistrarAlgo(usuario.papel, carga);
    final pendencias = BusinessRules.pendencias(carga);

    return Scaffold(
      appBar: AppBar(
        title: Text(carga.conteiner),
        bottom: _atualizando
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3))
            : null,
        actions: [
          if (pode(Permissao.editarCarga))
            IconButton(
              tooltip: 'Editar dados',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => AcoesCarga.editarCarga(context, carga),
            ),
          if (pode(Permissao.excluirCarga))
            IconButton(
              tooltip: 'Excluir carga',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _excluir(carga),
            ),
          const RoleBadge(),
        ],
      ),
      floatingActionButton: podeEvento
          ? FloatingActionButton.extended(
              onPressed: () => AcoesCarga.registrarEvento(context, carga),
              icon: const Icon(Icons.add_task),
              label: const Text('Registrar evento'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _atualizar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            _CabecalhoSituacao(carga: carga),
            const SizedBox(height: 12),
            if (pendencias.isNotEmpty) ...[
              SectionCard(
                titulo: 'Pendências (${pendencias.length})',
                icone: Icons.warning_amber_rounded,
                child: Column(
                  children: [
                    for (final p in pendencias)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(p.gravidade.icone, color: p.gravidade.cor),
                        title: Text(p.descricao),
                        trailing: Text(p.gravidade.label,
                            style: const TextStyle(
                                color: AppTheme.textoSecundario)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _Informacoes(carga: carga, usuario: usuario),
            const SizedBox(height: 12),
            _Documentos(carga: carga, usuario: usuario),
            const SizedBox(height: 12),
            _Historico(carga: carga, usuario: usuario),
          ],
        ),
      ),
    );
  }
}

class _CabecalhoSituacao extends StatelessWidget {
  const _CabecalhoSituacao({required this.carga});

  final Carga carga;

  @override
  Widget build(BuildContext context) {
    final desde = DateTime.now().difference(carga.statusDesde);
    return SectionCard(
      titulo: 'Situação atual',
      icone: Icons.my_location,
      trailing: StatusChip(carga.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LinhaFluxo(atual: carga.status),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              InfoItem('Próxima etapa', BusinessRules.proximaEtapa(carga),
                  largura: 220),
              InfoItem('Nesta etapa há', Fmt.duracao(desde)),
              InfoItem('Posição no terminal', carga.posicao ?? '—'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Linha do fluxo operacional destacando a etapa atual.
class _LinhaFluxo extends StatelessWidget {
  const _LinhaFluxo({required this.atual});

  final StatusCarga atual;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in StatusCarga.values) ...[
            Column(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: s.ordem < atual.ordem
                      ? s.cor.withAlpha(60)
                      : s == atual
                          ? s.cor
                          : Colors.grey.shade200,
                  child: Icon(
                    s.ordem < atual.ordem ? Icons.check : s.icone,
                    size: 16,
                    color: s == atual ? Colors.white : AppTheme.textoPrimario,
                  ),
                ),
                const SizedBox(height: 4),
                Text(s.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          s == atual ? FontWeight.bold : FontWeight.normal,
                      color: AppTheme.textoPrimario,
                    )),
              ],
            ),
            if (s != StatusCarga.retirado)
              Container(
                width: 28,
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: s.ordem < atual.ordem
                    ? AppTheme.azulPorto
                    : Colors.grey.shade300,
              ),
          ],
        ],
      ),
    );
  }
}

class _Informacoes extends StatelessWidget {
  const _Informacoes({required this.carga, required this.usuario});

  final Carga carga;
  final AppUser usuario;

  @override
  Widget build(BuildContext context) {
    final papel = usuario.papel;
    // Cada informação também respeita a hierarquia de perfis.
    final itens = <(UserRole, String, String)>[
      (UserRole.transportador, 'Contêiner', carga.conteiner),
      (UserRole.transportador, 'Previsão', Fmt.dataHora(carga.dataPrevista)),
      (UserRole.transportador, 'Placa', carga.placa ?? '—'),
      (UserRole.transportador, 'Motorista', carga.motorista ?? '—'),
      (UserRole.transportador, 'Transportadora', carga.transportadora),
      (UserRole.gate, 'CNPJ', Fmt.cnpj(carga.transportadoraCnpj)),
      (UserRole.gate, 'Entrada', Fmt.dataHora(carga.dataEntrada)),
      (UserRole.gate, 'Saída', Fmt.dataHora(carga.dataSaida)),
      (UserRole.gate, 'Peso bruto', Fmt.peso(carga.pesoKg)),
      (UserRole.conferente, 'Booking', carga.booking),
      (UserRole.conferente, 'Navio', carga.navio),
      (UserRole.conferente, 'Viagem', carga.viagem),
      (
        UserRole.operador,
        'Permanência',
        carga.permanencia() == null ? '—' : Fmt.duracao(carga.permanencia()!)
      ),
      (UserRole.operador, 'Cadastrada em', Fmt.dataHora(carga.criadoEm)),
    ];
    final visiveis = itens.where((i) => papel.atLeast(i.$1)).toList();
    final ocultas = itens.length - visiveis.length;
    return SectionCard(
      titulo: 'Informações da carga',
      icone: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final (_, rotulo, valor) in visiveis)
                InfoItem(rotulo, valor,
                    largura: rotulo == 'Transportadora' ? 240 : 160),
            ],
          ),
          if (ocultas > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                const Icon(Icons.lock_outline,
                    size: 14, color: AppTheme.textoSecundario),
                const SizedBox(width: 4),
                Text('$ocultas informações restritas a perfis superiores',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textoSecundario)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _Documentos extends StatelessWidget {
  const _Documentos({required this.carga, required this.usuario});

  final Carga carga;
  final AppUser usuario;

  @override
  Widget build(BuildContext context) {
    final podeEnviar = Permissoes.pode(usuario.papel, Permissao.enviarDocumento);
    final podeExcluir =
        Permissoes.pode(usuario.papel, Permissao.excluirDocumento);
    final faltantes = BusinessRules.documentosFaltantes(carga);
    return SectionCard(
      titulo: 'Documentos (${carga.documentos.length})',
      icone: Icons.folder_open_outlined,
      trailing: podeEnviar
          ? TextButton.icon(
              onPressed: () => AcoesCarga.enviarDocumento(context, carga: carga),
              icon: const Icon(Icons.upload_file),
              label: const Text('Enviar'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (faltantes.isNotEmpty && carga.status != StatusCarga.retirado)
            for (final f in faltantes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppTheme.alerta),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Necessário para liberação: $f')),
                ]),
              ),
          if (carga.documentos.isEmpty)
            const Text('Nenhum documento enviado.',
                style: TextStyle(color: AppTheme.textoSecundario))
          else
            for (final d in carga.documentos)
              _DocumentoTile(documento: d, podeExcluir: podeExcluir),
        ],
      ),
    );
  }
}

class _DocumentoTile extends StatelessWidget {
  const _DocumentoTile({required this.documento, required this.podeExcluir});

  final Documento documento;
  final bool podeExcluir;

  @override
  Widget build(BuildContext context) {
    final d = documento;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.azulPorto.withAlpha(20),
        child: Text(d.tipo.sigla,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.azulPorto)),
      ),
      title: Text(d.tipo.label),
      subtitle: Text(
        '${d.nomeArquivo} · ${Fmt.tamanhoArquivo(d.tamanhoBytes)}\n'
        '${d.enviadoPorNome} · ${Fmt.dataHoraCurta(d.enviadoEm)}',
      ),
      isThreeLine: true,
      onTap: () => AcoesCarga.abrirDocumento(context, d),
      trailing: podeExcluir
          ? IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => AcoesCarga.excluirDocumento(context, d),
            )
          : const Icon(Icons.chevron_right),
    );
  }
}

class _Historico extends StatelessWidget {
  const _Historico({required this.carga, required this.usuario});

  final Carga carga;
  final AppUser usuario;

  IconData _icone(EventoOperacional e) => switch (e.tipo) {
        TipoEvento.criacao => Icons.add_box_outlined,
        TipoEvento.status => e.statusNovo?.icone ?? Icons.swap_horiz,
        TipoEvento.movimentacao => Icons.open_with,
        TipoEvento.ocorrencia => Icons.report_problem_outlined,
        TipoEvento.resolucao => Icons.task_alt,
      };

  Color _cor(EventoOperacional e) => switch (e.tipo) {
        TipoEvento.ocorrencia => AppTheme.critico,
        TipoEvento.resolucao => AppTheme.sucesso,
        TipoEvento.status => e.statusNovo?.cor ?? AppTheme.azulPorto,
        _ => AppTheme.azulPorto,
      };

  @override
  Widget build(BuildContext context) {
    final verResponsavel =
        Permissoes.pode(usuario.papel, Permissao.verResponsavelEventos);
    final eventos = carga.eventos.reversed.toList();
    final abertas = carga.ocorrenciasAbertas.map((o) => o.id).toSet();
    return SectionCard(
      titulo: 'Histórico de movimentações (${eventos.length})',
      icone: Icons.timeline,
      child: Column(
        children: [
          for (var i = 0; i < eventos.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 36,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: _cor(eventos[i]).withAlpha(40),
                          child: Icon(_icone(eventos[i]),
                              size: 16, color: _cor(eventos[i])),
                        ),
                        if (i < eventos.length - 1)
                          Expanded(
                            child: Container(
                                width: 2, color: Colors.grey.shade300),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(eventos[i].titulo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                            if (abertas.contains(eventos[i].id))
                              const Chip(
                                label: Text('Aberta',
                                    style: TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(Icons.error,
                                    size: 14, color: AppTheme.critico),
                              ),
                          ]),
                          Text(
                            Fmt.dataHora(eventos[i].dataHora) +
                                (verResponsavel
                                    ? ' · ${eventos[i].usuarioNome}'
                                    : ''),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textoSecundario),
                          ),
                          if (eventos[i].resumo.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(eventos[i].resumo),
                            ),
                          if (eventos[i].observacao != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('“${eventos[i].observacao}”',
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

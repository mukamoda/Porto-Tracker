import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/carga.dart';
import '../../models/documento.dart';
import '../../services/business_rules.dart';
import '../../services/permissions.dart';
import '../../state/auth_controller.dart';
import '../../state/cargas_controller.dart';
import '../cargas/acoes_carga.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';
import '../widgets/status_chip.dart';

enum _Visao { enviados, pendentes }

/// Módulo de documentos: consulta, upload e pendências documentais.
class DocumentosPage extends StatefulWidget {
  const DocumentosPage({super.key});

  @override
  State<DocumentosPage> createState() => _DocumentosPageState();
}

class _DocumentosPageState extends State<DocumentosPage> {
  _Visao _visao = _Visao.enviados;
  String _busca = '';
  TipoDocumento? _tipo;

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthController>().usuario!;
    final ctrl = context.watch<CargasController>();
    final podeEnviar = Permissoes.pode(usuario.papel, Permissao.enviarDocumento);
    final podeExcluir =
        Permissoes.pode(usuario.papel, Permissao.excluirDocumento);

    final termo = _busca.trim().toUpperCase();
    final docs = <(Carga, Documento)>[
      for (final c in ctrl.cargas)
        for (final d in c.documentos) (c, d),
    ]
        .where((par) {
          final (c, d) = par;
          if (_tipo != null && d.tipo != _tipo) return false;
          if (termo.isEmpty) return true;
          return c.conteiner.contains(termo) ||
              d.nomeArquivo.toUpperCase().contains(termo) ||
              (d.numero ?? '').toUpperCase().contains(termo);
        })
        .toList()
      ..sort((a, b) => b.$2.enviadoEm.compareTo(a.$2.enviadoEm));

    final pendentes = ctrl.cargas
        .where((c) =>
            (c.status == StatusCarga.armazenado ||
                c.status == StatusCarga.emInspecao ||
                c.status == StatusCarga.recepcionado) &&
            BusinessRules.documentosFaltantes(c).isNotEmpty)
        .where((c) => termo.isEmpty || c.conteiner.contains(termo))
        .toList();

    final totalDocs =
        ctrl.cargas.fold<int>(0, (s, c) => s + c.documentos.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: ctrl.carregando ? null : ctrl.carregar,
          ),
          const RoleBadge(),
        ],
      ),
      floatingActionButton: podeEnviar
          ? FloatingActionButton.extended(
              onPressed: () => AcoesCarga.enviarDocumento(context),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Enviar documento'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: ctrl.carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            SegmentedButton<_Visao>(
              segments: [
                ButtonSegment(
                  value: _Visao.enviados,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text('Enviados ($totalDocs)'),
                ),
                ButtonSegment(
                  value: _Visao.pendentes,
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: Text('Pendentes (${pendentes.length})'),
                ),
              ],
              selected: {_visao},
              onSelectionChanged: (s) => setState(() => _visao = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _busca = v),
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Buscar por contêiner, arquivo ou número/chave',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            if (_visao == _Visao.enviados) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _tipo == null,
                    onSelected: (_) => setState(() => _tipo = null),
                  ),
                  for (final t in TipoDocumento.values) ...[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(t.sigla),
                      tooltip: t.label,
                      selected: _tipo == t,
                      onSelected: (_) => setState(() => _tipo = t),
                    ),
                  ],
                ]),
              ),
            ],
            const SizedBox(height: 12),
            if (ctrl.carregando && ctrl.cargas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (ctrl.erro != null && ctrl.cargas.isEmpty)
              ErrorView(mensagem: ctrl.erro!, onRetry: ctrl.carregar)
            else if (_visao == _Visao.enviados)
              ..._listaEnviados(docs, podeExcluir)
            else
              ..._listaPendentes(pendentes, podeEnviar),
          ],
        ),
      ),
    );
  }

  List<Widget> _listaEnviados(List<(Carga, Documento)> docs, bool podeExcluir) {
    if (docs.isEmpty) {
      return const [
        EmptyState(
          icone: Icons.folder_off_outlined,
          titulo: 'Nenhum documento encontrado',
        ),
      ];
    }
    return [
      for (final (c, d) in docs)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.azulPorto.withAlpha(20),
              child: Icon(
                d.ehImagem
                    ? Icons.image_outlined
                    : d.mimeType.contains('xml')
                        ? Icons.code
                        : Icons.picture_as_pdf_outlined,
                color: AppTheme.azulPorto,
              ),
            ),
            title: Text('${d.tipo.sigla} · ${c.conteiner}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${d.nomeArquivo} · ${Fmt.tamanhoArquivo(d.tamanhoBytes)}\n'
              'Enviado por ${d.enviadoPorNome} em ${Fmt.dataHoraCurta(d.enviadoEm)}',
            ),
            isThreeLine: true,
            onTap: () => AcoesCarga.abrirDocumento(context, d),
            trailing: PopupMenuButton<String>(
              tooltip: 'Ações',
              onSelected: (acao) {
                switch (acao) {
                  case 'abrir':
                    AcoesCarga.abrirDocumento(context, d);
                  case 'carga':
                    AcoesCarga.abrirDetalhe(context, c.id);
                  case 'excluir':
                    AcoesCarga.excluirDocumento(context, d);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'abrir', child: Text('Abrir')),
                const PopupMenuItem(value: 'carga', child: Text('Ver carga')),
                if (podeExcluir)
                  const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _listaPendentes(List<Carga> cargas, bool podeEnviar) {
    if (cargas.isEmpty) {
      return const [
        EmptyState(
          icone: Icons.task_alt,
          titulo: 'Nenhuma pendência documental',
          mensagem: 'Todas as cargas no pátio possuem os documentos '
              'necessários para liberação.',
        ),
      ];
    }
    return [
      for (final c in cargas)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(c.conteiner,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  StatusChip(c.status, compacto: true),
                  const Spacer(),
                  if (podeEnviar)
                    TextButton.icon(
                      onPressed: () =>
                          AcoesCarga.enviarDocumento(context, carga: c),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Enviar'),
                    ),
                ]),
                const SizedBox(height: 4),
                for (final f in BusinessRules.documentosFaltantes(c))
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppTheme.alerta),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Falta: $f')),
                  ]),
                Text(c.transportadora,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textoSecundario)),
              ],
            ),
          ),
        ),
    ];
  }
}

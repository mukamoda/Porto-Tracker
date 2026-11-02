import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../models/carga.dart';
import '../../models/documento.dart';
import '../../models/evento.dart';
import '../../models/user_role.dart';
import '../../services/permissions.dart';
import '../../state/cargas_controller.dart';
import '../documentos/upload_documento_sheet.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';
import 'carga_detail_page.dart';
import 'carga_form_page.dart';
import 'evento_form_sheet.dart';

/// Navegação e ações reutilizadas pelo GRID, detalhe, dashboard e documentos.
class AcoesCarga {
  AcoesCarga._();

  static Future<void> abrirDetalhe(BuildContext context, String cargaId) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CargaDetailPage(cargaId: cargaId)),
      );

  static Future<void> novaCarga(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PermissionGuard(
          permitido: (u) => Permissoes.pode(u.papel, Permissao.cadastrarCarga),
          requisito: UserRole.operador,
          child: const CargaFormPage(),
        ),
      ));

  static Future<void> editarCarga(BuildContext context, Carga carga) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PermissionGuard(
          permitido: (u) => Permissoes.pode(u.papel, Permissao.editarCarga),
          requisito: UserRole.operador,
          child: CargaFormPage(carga: carga),
        ),
      ));

  static Future<void> registrarEvento(BuildContext context, Carga carga,
      {TipoEvento? tipoInicial}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => EventoFormSheet(carga: carga, tipoInicial: tipoInicial),
    );
    if (ok == true && context.mounted) {
      AppFeedback.sucesso(context, 'Evento registrado em ${carga.conteiner}.');
    }
  }

  static Future<void> enviarDocumento(BuildContext context,
      {Carga? carga}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => UploadDocumentoSheet(cargaInicial: carga),
    );
    if (ok == true && context.mounted) {
      AppFeedback.sucesso(context, 'Documento enviado com sucesso.');
    }
  }

  /// Abre o documento: URL assinada (Supabase) ou pré-visualização (demo).
  static Future<void> abrirDocumento(BuildContext context, Documento d) async {
    try {
      final url = await context.read<CargasController>().urlDocumento(d);
      if (!context.mounted) return;
      if (url != null) {
        final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) {
          AppFeedback.erro(context, 'Não foi possível abrir o documento.');
        }
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${d.tipo.sigla} · ${d.nomeArquivo}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d.ehImagem && d.bytes != null && d.bytes!.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: Image.memory(d.bytes!),
                  )
                else
                  const Text(
                      'Pré-visualização indisponível no modo demonstração. '
                      'Com o Supabase configurado, o arquivo é aberto por '
                      'uma URL assinada válida por 10 minutos.'),
                const SizedBox(height: 12),
                Text('Tipo: ${d.tipo.label}'),
                if (d.numero != null) Text('Número/chave: ${d.numero}'),
                Text('Tamanho: ${Fmt.tamanhoArquivo(d.tamanhoBytes)}'),
                Text('Enviado por ${d.enviadoPorNome} em '
                    '${Fmt.dataHora(d.enviadoEm)}'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) AppFeedback.erro(context, e);
    }
  }

  static Future<void> excluirDocumento(BuildContext context, Documento d) async {
    final ok = await AppFeedback.confirmar(
      context,
      titulo: 'Excluir documento?',
      mensagem: '${d.tipo.label} "${d.nomeArquivo}" será removido '
          'definitivamente.',
      confirmar: 'Excluir',
      destrutivo: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<CargasController>().excluirDocumento(d);
      if (context.mounted) AppFeedback.sucesso(context, 'Documento excluído.');
    } catch (e) {
      if (context.mounted) AppFeedback.erro(context, e);
    }
  }

  /// Edição rápida de um campo de texto direto no GRID.
  static Future<void> editarCampoTexto(
    BuildContext context, {
    required Carga carga,
    required String titulo,
    required String valorAtual,
    required String? Function(String?) validador,
    required Carga Function(String valor) aplicar,
    TextCapitalization capitalizacao = TextCapitalization.characters,
  }) async {
    final controller = TextEditingController(text: valorAtual);
    final formKey = GlobalKey<FormState>();
    final valor = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$titulo · ${carga.conteiner}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: capitalizacao,
            decoration: InputDecoration(labelText: titulo),
            validator: validador,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (valor == null || !context.mounted) return;
    try {
      await context.read<CargasController>().atualizarCarga(aplicar(valor));
      if (context.mounted) AppFeedback.sucesso(context, '$titulo atualizado.');
    } catch (e) {
      if (context.mounted) AppFeedback.erro(context, e);
    }
  }

  static Future<void> editarPrevisao(BuildContext context, Carga carga) async {
    final data = await showDatePicker(
      context: context,
      initialDate: carga.dataPrevista.isBefore(DateTime(2020))
          ? DateTime.now()
          : carga.dataPrevista,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Nova data prevista',
    );
    if (data == null || !context.mounted) return;
    final hora = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(carga.dataPrevista));
    if (hora == null || !context.mounted) return;
    final nova =
        DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
    try {
      await context
          .read<CargasController>()
          .atualizarCarga(carga.copyWith(dataPrevista: nova));
      if (context.mounted) {
        AppFeedback.sucesso(context, 'Previsão atualizada para ${Fmt.dataHora(nova)}.');
      }
    } catch (e) {
      if (context.mounted) AppFeedback.erro(context, e);
    }
  }
}

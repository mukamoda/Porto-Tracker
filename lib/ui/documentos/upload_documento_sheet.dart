import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../models/carga.dart';
import '../../models/documento.dart';
import '../../state/cargas_controller.dart';
import '../theme.dart';
import '../widgets/feedback.dart';

/// Envio de documento vinculado a uma carga (NF, DANFE, DI, BL...).
class UploadDocumentoSheet extends StatefulWidget {
  const UploadDocumentoSheet({super.key, this.cargaInicial});

  final Carga? cargaInicial;

  @override
  State<UploadDocumentoSheet> createState() => _UploadDocumentoSheetState();
}

class _UploadDocumentoSheetState extends State<UploadDocumentoSheet> {
  final _form = GlobalKey<FormState>();
  final _numero = TextEditingController();
  String? _cargaId;
  TipoDocumento? _tipo;
  String? _nomeArquivo;
  Uint8List? _bytes;
  String? _erroArquivo;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargaId = widget.cargaInicial?.id;
    final faltantes = widget.cargaInicial == null
        ? const <String>[]
        : _sugestao(widget.cargaInicial!);
    if (faltantes.isNotEmpty) _tipo = TipoDocumento.fromCodigo(faltantes.first);
  }

  /// Sugere o tipo de documento que falta para a liberação.
  List<String> _sugestao(Carga c) => [
        if (!c.possuiDocumento(
            {TipoDocumento.notaFiscal, TipoDocumento.danfe}))
          TipoDocumento.danfe.codigo,
        if (!c.possuiDocumento(
            {TipoDocumento.di, TipoDocumento.duimp, TipoDocumento.due}))
          TipoDocumento.di.codigo,
      ];

  @override
  void dispose() {
    _numero.dispose();
    super.dispose();
  }

  Future<void> _selecionarArquivo() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConfig.extensoesPermitidas,
        withData: true,
      );
      if (resultado == null || resultado.files.isEmpty) return;
      final arquivo = resultado.files.single;
      final bytes = arquivo.bytes;
      String? erro;
      if (bytes == null) {
        erro = 'Não foi possível ler o arquivo selecionado.';
      } else if (bytes.length > AppConfig.tamanhoMaximoArquivo) {
        erro = 'Arquivo com ${Fmt.tamanhoArquivo(bytes.length)}: '
            'o limite é 10 MB.';
      } else if (!AppConfig.extensoesPermitidas
          .contains(arquivo.extension?.toLowerCase())) {
        erro = 'Formato não permitido. Use PDF, XML, JPG ou PNG.';
      }
      setState(() {
        _erroArquivo = erro;
        _nomeArquivo = arquivo.name;
        _bytes = erro == null ? bytes : null;
      });
    } catch (e) {
      if (mounted) AppFeedback.erro(context, 'Falha ao selecionar arquivo.');
    }
  }

  Future<void> _enviar() async {
    final formOk = _form.currentState!.validate();
    if (_bytes == null) {
      setState(() => _erroArquivo ??= 'Selecione um arquivo.');
    }
    if (!formOk || _bytes == null) return;

    setState(() => _enviando = true);
    try {
      final numero = _numero.text.trim();
      await context.read<CargasController>().enviarDocumento(
            cargaId: _cargaId!,
            tipo: _tipo!,
            nomeArquivo: _nomeArquivo!,
            bytes: _bytes!,
            numero: numero.isEmpty
                ? null
                : (_tipo!.exigeChaveNfe ? somenteDigitos(numero) : numero),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppFeedback.erro(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String? _validarNumero(String? v) {
    final tipo = _tipo;
    if (tipo == null) return null;
    if (tipo.exigeChaveNfe) return Validators.chaveNfe(v);
    if (tipo.exigeNumero) {
      return Validators.obrigatorio(v, 'Número do ${tipo.sigla}');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cargas = context
        .watch<CargasController>()
        .cargas
        .where((c) => c.status != StatusCarga.retirado || c.id == _cargaId)
        .toList()
      ..sort((a, b) => a.conteiner.compareTo(b.conteiner));

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Enviar documento',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: cargas.any((c) => c.id == _cargaId) ? _cargaId : null,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Carga / contêiner',
                    prefixIcon: Icon(Icons.inventory_2_outlined)),
                items: [
                  for (final c in cargas)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.conteiner} · ${c.status.label}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: widget.cargaInicial != null
                    ? null
                    : (v) => setState(() => _cargaId = v),
                validator: (v) => v == null ? 'Selecione a carga' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TipoDocumento>(
                initialValue: _tipo,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Tipo de documento',
                    prefixIcon: Icon(Icons.description_outlined)),
                items: [
                  for (final t in TipoDocumento.values)
                    DropdownMenuItem(
                        value: t, child: Text('${t.sigla} — ${t.label}')),
                ],
                onChanged: (v) => setState(() => _tipo = v),
                validator: (v) => v == null ? 'Selecione o tipo' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numero,
                keyboardType: (_tipo?.exigeChaveNfe ?? false)
                    ? TextInputType.number
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: (_tipo?.exigeChaveNfe ?? false)
                      ? 'Chave de acesso (44 dígitos)'
                      : 'Número do documento${(_tipo?.exigeNumero ?? false) ? '' : ' (opcional)'}',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  helperText: (_tipo?.exigeChaveNfe ?? false)
                      ? 'O dígito verificador da chave é validado'
                      : null,
                ),
                validator: _validarNumero,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _enviando ? null : _selecionarArquivo,
                icon: const Icon(Icons.attach_file),
                label: Text(_nomeArquivo == null
                    ? 'Selecionar arquivo (PDF, XML, JPG, PNG · até 10 MB)'
                    : 'Trocar arquivo'),
              ),
              if (_nomeArquivo != null && _erroArquivo == null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_outlined,
                      color: AppTheme.azulPorto),
                  title: Text(_nomeArquivo!),
                  subtitle: Text(Fmt.tamanhoArquivo(_bytes?.length ?? 0)),
                ),
              if (_erroArquivo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_erroArquivo!,
                      style: const TextStyle(color: AppTheme.critico)),
                ),
              const SizedBox(height: 16),
              if (_enviando) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('Enviando arquivo...', textAlign: TextAlign.center),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: _enviando ? null : _enviar,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Enviar documento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

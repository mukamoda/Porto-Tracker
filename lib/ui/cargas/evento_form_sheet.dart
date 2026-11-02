import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/exceptions.dart';
import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../models/carga.dart';
import '../../models/evento.dart';
import '../../services/business_rules.dart';
import '../../services/permissions.dart';
import '../../state/auth_controller.dart';
import '../../state/cargas_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';
import '../widgets/status_chip.dart';
import 'acoes_carga.dart';

/// Formulário de registro de evento operacional.
///
/// Os campos exibidos mudam conforme o tipo de evento e a etapa de destino
/// ("determinados status exigem informações adicionais"). A validação ocorre
/// no formulário, nas regras de negócio e novamente no servidor.
class EventoFormSheet extends StatefulWidget {
  const EventoFormSheet({super.key, required this.carga, this.tipoInicial});

  final Carga carga;
  final TipoEvento? tipoInicial;

  @override
  State<EventoFormSheet> createState() => _EventoFormSheetState();
}

class _EventoFormSheetState extends State<EventoFormSheet> {
  final _form = GlobalKey<FormState>();
  final _placa = TextEditingController();
  final _motorista = TextEditingController();
  final _peso = TextEditingController();
  final _posicao = TextEditingController();
  final _motivo = TextEditingController();
  final _docLiberacao = TextEditingController();
  final _descricao = TextEditingController();
  final _observacao = TextEditingController();

  late TipoEvento _tipo;
  StatusCarga? _alvo;
  DateTime _dataHora = DateTime.now();
  String? _orgao;
  String? _tipoOcorrencia;
  String? _ocorrenciaId;
  bool _enviando = false;
  List<String> _erros = const [];

  @override
  void initState() {
    super.initState();
    final c = widget.carga;
    _placa.text = c.placa ?? '';
    _motorista.text = c.motorista ?? '';
    _posicao.text = c.posicao ?? '';
    final papel = context.read<AuthController>().usuario!.papel;
    final tipos = _tiposDisponiveis(c);
    _tipo = (widget.tipoInicial != null && tipos.contains(widget.tipoInicial))
        ? widget.tipoInicial!
        : (tipos.isEmpty ? TipoEvento.status : tipos.first);
    final permitidos = BusinessRules.proximosStatus(c.status)
        .where((s) => BusinessRules.podeLevarPara(papel, s));
    _alvo = permitidos.isEmpty ? null : permitidos.first;
    if (c.ocorrenciasAbertas.isNotEmpty) {
      _ocorrenciaId = c.ocorrenciasAbertas.first.id;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _placa,
      _motorista,
      _peso,
      _posicao,
      _motivo,
      _docLiberacao,
      _descricao,
      _observacao,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<TipoEvento> _tiposDisponiveis(Carga c) {
    final papel = context.read<AuthController>().usuario!.papel;
    bool pode(Permissao p) => Permissoes.pode(papel, p);
    return [
      if (BusinessRules.proximosStatus(c.status).isNotEmpty) TipoEvento.status,
      if (pode(Permissao.registrarArmazenagem) &&
          BusinessRules.statusMovimentaveis.contains(c.status))
        TipoEvento.movimentacao,
      if (pode(Permissao.registrarOcorrencia) &&
          c.status != StatusCarga.retirado)
        TipoEvento.ocorrencia,
      if (pode(Permissao.resolverOcorrencia) && c.ocorrenciasAbertas.isNotEmpty)
        TipoEvento.resolucao,
    ];
  }

  Map<String, String> _dados() {
    String t(TextEditingController c) => c.text.trim();
    switch (_tipo) {
      case TipoEvento.status:
        switch (_alvo) {
          case StatusCarga.recepcionado:
            final peso = Validators.parsePeso(_peso.text);
            return {
              CampoEvento.placa: Validators.normalizarPlaca(_placa.text),
              CampoEvento.motorista: t(_motorista),
              CampoEvento.peso: peso == null ? '' : peso.round().toString(),
            };
          case StatusCarga.retirado:
            return {
              CampoEvento.placa: Validators.normalizarPlaca(_placa.text),
              CampoEvento.motorista: t(_motorista),
            };
          case StatusCarga.armazenado:
            return {CampoEvento.posicao: t(_posicao).toUpperCase()};
          case StatusCarga.emInspecao:
            return {
              CampoEvento.orgao: _orgao ?? '',
              CampoEvento.motivo: t(_motivo),
            };
          case StatusCarga.liberado:
            return {CampoEvento.documentoLiberacao: t(_docLiberacao)};
          case StatusCarga.previsto:
          case null:
            return {};
        }
      case TipoEvento.movimentacao:
        return {CampoEvento.posicao: t(_posicao).toUpperCase()};
      case TipoEvento.ocorrencia:
        return {
          CampoEvento.tipoOcorrencia: _tipoOcorrencia ?? '',
          CampoEvento.descricao: t(_descricao),
        };
      case TipoEvento.resolucao:
        return {
          CampoEvento.ocorrenciaId: _ocorrenciaId ?? '',
          CampoEvento.descricao: t(_descricao),
        };
      case TipoEvento.criacao:
        return {};
    }
  }

  Future<void> _salvar(Carga carga) async {
    setState(() => _erros = const []);
    if (!_form.currentState!.validate()) return;

    final papel = context.read<AuthController>().usuario!.papel;
    final evento = NovoEvento(
      tipo: _tipo,
      statusNovo: _tipo == TipoEvento.status ? _alvo : null,
      dataHora: _dataHora,
      dados: _dados(),
      observacao: _observacao.text,
    );
    final erros =
        BusinessRules.validarEvento(carga: carga, evento: evento, papel: papel);
    if (erros.isNotEmpty) {
      setState(() => _erros = erros);
      return;
    }

    setState(() => _enviando = true);
    try {
      await context.read<CargasController>().registrarEvento(carga.id, evento);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erros = mensagemDeErro(e).split('\n'));
      AppFeedback.erro(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthController>();
    final carga = context.watch<CargasController>().porId(widget.carga.id) ??
        widget.carga;
    final tipos = _tiposDisponiveis(carga);
    final ultimo = carga.ultimoEvento;

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
              Text('Registrar evento',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Row(children: [
                Text(carga.conteiner,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                StatusChip(carga.status, compacto: true),
              ]),
              const SizedBox(height: 4),
              Text('Próxima etapa sugerida: ${BusinessRules.proximaEtapa(carga)}',
                  style: const TextStyle(color: AppTheme.textoSecundario)),
              const SizedBox(height: 16),
              if (tipos.isEmpty)
                const EmptyState(
                  icone: Icons.task_alt,
                  titulo: 'Nenhum evento disponível',
                  mensagem: 'O ciclo desta carga foi concluído ou seu perfil '
                      'não registra eventos nesta etapa.',
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tipos)
                      ChoiceChip(
                        label: Text(t.label),
                        selected: _tipo == t,
                        onSelected: (_) => setState(() {
                          _tipo = t;
                          _erros = const [];
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._camposDoTipo(carga),
                const SizedBox(height: 12),
                DataHoraField(
                  rotulo: 'Data e hora do evento',
                  valor: _dataHora,
                  primeiraData: ultimo?.dataHora,
                  ultimaData: DateTime.now(),
                  onChanged: (d) => setState(() => _dataHora = d),
                ),
                if (ultimo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'Último evento: ${ultimo.titulo} em '
                      '${Fmt.dataHora(ultimo.dataHora)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textoSecundario),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _observacao,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Observação (opcional)',
                      prefixIcon: Icon(Icons.notes)),
                ),
                const SizedBox(height: 12),
                ErrosBox(_erros),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _enviando ? null : () => _salvar(carga),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_enviando ? 'Registrando...' : 'Registrar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _camposDoTipo(Carga carga) {
    switch (_tipo) {
      case TipoEvento.status:
        return _camposStatus(carga);
      case TipoEvento.movimentacao:
        return [
          InfoItem('Posição atual', carga.posicao ?? '—'),
          const SizedBox(height: 12),
          _campoPosicao(rotulo: 'Nova posição'),
        ];
      case TipoEvento.ocorrencia:
        return [
          DropdownButtonFormField<String>(
            initialValue: _tipoOcorrencia,
            decoration: const InputDecoration(
                labelText: 'Tipo de ocorrência',
                prefixIcon: Icon(Icons.report_problem_outlined)),
            items: [
              for (final t in TipoOcorrencia.values)
                DropdownMenuItem(value: t.codigo, child: Text(t.label)),
            ],
            onChanged: (v) => setState(() => _tipoOcorrencia = v),
            validator: (v) => v == null ? 'Selecione o tipo' : null,
          ),
          const SizedBox(height: 12),
          _campoDescricao('Descrição da ocorrência'),
          const SizedBox(height: 6),
          const Text(
            'Ocorrências abertas bloqueiam a liberação até serem resolvidas.',
            style: TextStyle(fontSize: 12, color: AppTheme.textoSecundario),
          ),
        ];
      case TipoEvento.resolucao:
        final abertas = carga.ocorrenciasAbertas;
        return [
          DropdownButtonFormField<String>(
            initialValue: abertas.any((o) => o.id == _ocorrenciaId)
                ? _ocorrenciaId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Ocorrência', prefixIcon: Icon(Icons.flag_outlined)),
            items: [
              for (final o in abertas)
                DropdownMenuItem(
                  value: o.id,
                  child: Text(
                      '${o.titulo} · ${Fmt.dataHoraCurta(o.dataHora)}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _ocorrenciaId = v),
            validator: (v) => v == null ? 'Selecione a ocorrência' : null,
          ),
          const SizedBox(height: 12),
          _campoDescricao('Solução aplicada'),
        ];
      case TipoEvento.criacao:
        return const [];
    }
  }

  List<Widget> _camposStatus(Carga carga) {
    final papel = context.read<AuthController>().usuario!.papel;
    final proximos = BusinessRules.proximosStatus(carga.status);
    final alvoValido = _alvo != null && proximos.contains(_alvo);
    return [
      Text('Avançar para',
          style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in proximos)
            Tooltip(
              message: BusinessRules.podeLevarPara(papel, s)
                  ? s.label
                  : 'Requer perfil '
                      '${Permissoes.minimo(BusinessRules.permissaoPara(s)).label}',
              child: ChoiceChip(
                avatar: Icon(s.icone, size: 18, color: s.cor),
                label: Text(s.label),
                selected: _alvo == s,
                onSelected: BusinessRules.podeLevarPara(papel, s)
                    ? (_) => setState(() {
                          _alvo = s;
                          _erros = const [];
                        })
                    : null,
              ),
            ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Fluxo: Previsto → Recepcionado → Armazenado ⇄ Em inspeção → '
        'Liberado → Retirado',
        style: const TextStyle(fontSize: 11, color: AppTheme.textoSecundario),
      ),
      const SizedBox(height: 16),
      if (alvoValido) ..._camposDoAlvo(carga, _alvo!),
    ];
  }

  List<Widget> _camposDoAlvo(Carga carga, StatusCarga alvo) {
    switch (alvo) {
      case StatusCarga.recepcionado:
        return [
          _campoPlaca(),
          const SizedBox(height: 12),
          _campoMotorista(),
          const SizedBox(height: 12),
          TextFormField(
            controller: _peso,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Peso bruto aferido (kg)',
                hintText: 'ex.: 24500',
                prefixIcon: Icon(Icons.scale_outlined)),
            validator: Validators.peso,
          ),
        ];
      case StatusCarga.retirado:
        return [
          const Text('Confirme o veículo que está retirando o contêiner:'),
          const SizedBox(height: 8),
          _campoPlaca(),
          const SizedBox(height: 12),
          _campoMotorista(),
        ];
      case StatusCarga.armazenado:
        return [_campoPosicao(rotulo: 'Posição no pátio')];
      case StatusCarga.emInspecao:
        return [
          DropdownButtonFormField<String>(
            initialValue: _orgao,
            decoration: const InputDecoration(
                labelText: 'Órgão responsável',
                prefixIcon: Icon(Icons.account_balance_outlined)),
            items: [
              for (final o in OrgaoInspecao.values)
                DropdownMenuItem(value: o.codigo, child: Text(o.label)),
            ],
            onChanged: (v) => setState(() => _orgao = v),
            validator: (v) => v == null ? 'Selecione o órgão' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _motivo,
            decoration: const InputDecoration(
                labelText: 'Motivo / canal de parametrização',
                hintText: 'ex.: Canal vermelho — conferência física',
                prefixIcon: Icon(Icons.manage_search)),
            validator: (v) => Validators.obrigatorio(v, 'Motivo'),
          ),
        ];
      case StatusCarga.liberado:
        return [
          _ChecklistLiberacao(carga: carga),
          const SizedBox(height: 12),
          TextFormField(
            controller: _docLiberacao,
            decoration: const InputDecoration(
                labelText: 'Nº do documento de liberação',
                hintText: 'ex.: DI 26/0123456-7',
                prefixIcon: Icon(Icons.verified_outlined)),
            validator: (v) =>
                Validators.obrigatorio(v, 'Documento de liberação'),
          ),
        ];
      case StatusCarga.previsto:
        return const [];
    }
  }

  Widget _campoPlaca() => TextFormField(
        controller: _placa,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
            labelText: 'Placa do veículo',
            hintText: 'ABC1D23',
            prefixIcon: Icon(Icons.directions_car_outlined)),
        validator: Validators.placa,
      );

  Widget _campoMotorista() => TextFormField(
        controller: _motorista,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
            labelText: 'Motorista', prefixIcon: Icon(Icons.badge_outlined)),
        validator: (v) => Validators.obrigatorio(v, 'Motorista'),
      );

  Widget _campoPosicao({required String rotulo}) => TextFormField(
        controller: _posicao,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
            labelText: rotulo,
            hintText: 'Bloco-Fila-Altura (ex.: A-12-03)',
            prefixIcon: const Icon(Icons.grid_on)),
        validator: Validators.posicao,
      );

  Widget _campoDescricao(String rotulo) => TextFormField(
        controller: _descricao,
        maxLines: 3,
        decoration: InputDecoration(
            labelText: rotulo, alignLabelWithHint: true),
        validator: (v) => (v == null || v.trim().length < 5)
            ? 'Descreva com pelo menos 5 caracteres'
            : null,
      );
}

/// Pré-requisitos para liberação, exibidos como checklist.
class _ChecklistLiberacao extends StatelessWidget {
  const _ChecklistLiberacao({required this.carga});

  final Carga carga;

  @override
  Widget build(BuildContext context) {
    final semOcorrencias = carga.ocorrenciasAbertas.isEmpty;
    final fiscal = carga.possuiDocumento(BusinessRules.docsFiscais);
    final despacho = carga.possuiDocumento(BusinessRules.docsDespacho);
    Widget item(bool ok, String texto) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Icon(ok ? Icons.check_circle : Icons.cancel,
                size: 18, color: ok ? AppTheme.sucesso : AppTheme.critico),
            const SizedBox(width: 8),
            Expanded(child: Text(texto)),
            Text(ok ? 'OK' : 'Pendente',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textoSecundario)),
          ]),
        );
    return SectionCard(
      titulo: 'Pré-requisitos para liberação',
      icone: Icons.checklist,
      padding: const EdgeInsets.all(12),
      trailing: (!fiscal || !despacho)
          ? TextButton.icon(
              onPressed: () => AcoesCarga.enviarDocumento(context, carga: carga),
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Enviar doc.'),
            )
          : null,
      child: Column(children: [
        item(semOcorrencias, 'Sem ocorrências abertas'),
        item(fiscal, 'Documento fiscal (NF ou DANFE)'),
        item(despacho, 'Documento de despacho (DI, DUIMP ou DU-E)'),
      ]),
    );
  }
}

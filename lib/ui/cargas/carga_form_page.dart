import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../models/carga.dart';
import '../../services/brasil_api_service.dart';
import '../../state/cargas_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';

/// Cadastro/edição de carga prevista (Operador+).
class CargaFormPage extends StatefulWidget {
  const CargaFormPage({super.key, this.carga});

  final Carga? carga;

  @override
  State<CargaFormPage> createState() => _CargaFormPageState();
}

class _CargaFormPageState extends State<CargaFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _conteiner, _booking, _navio, _viagem,
      _cnpj, _transportadora, _placa, _motorista, _peso;
  late DateTime _dataPrevista;
  bool _salvando = false;
  bool _consultando = false;
  EmpresaInfo? _empresa;

  bool get _edicao => widget.carga != null;

  @override
  void initState() {
    super.initState();
    final c = widget.carga;
    _conteiner = TextEditingController(text: c?.conteiner);
    _booking = TextEditingController(text: c?.booking);
    _navio = TextEditingController(text: c?.navio);
    _viagem = TextEditingController(text: c?.viagem);
    _cnpj = TextEditingController(
        text: c?.transportadoraCnpj == null ? '' : Fmt.cnpj(c!.transportadoraCnpj));
    _transportadora = TextEditingController(text: c?.transportadora);
    _placa = TextEditingController(text: c?.placa);
    _motorista = TextEditingController(text: c?.motorista);
    _peso = TextEditingController(
        text: c?.pesoKg == null ? '' : c!.pesoKg!.round().toString());
    _dataPrevista =
        c?.dataPrevista ?? DateTime.now().add(const Duration(hours: 6));
  }

  @override
  void dispose() {
    for (final c in [
      _conteiner,
      _booking,
      _navio,
      _viagem,
      _cnpj,
      _transportadora,
      _placa,
      _motorista,
      _peso,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _consultarCnpj() async {
    final erro = Validators.cnpj(_cnpj.text);
    if (erro != null) {
      AppFeedback.erro(context, erro);
      return;
    }
    setState(() => _consultando = true);
    try {
      final info =
          await context.read<BrasilApiService>().consultarCnpj(_cnpj.text);
      if (!mounted) return;
      setState(() {
        _empresa = info;
        _transportadora.text = info.razaoSocial;
        _cnpj.text = Fmt.cnpj(info.cnpj);
      });
      if (!info.ativa) {
        AppFeedback.info(context,
            'Atenção: situação cadastral "${info.situacao ?? 'desconhecida'}".');
      }
    } catch (e) {
      if (mounted) AppFeedback.erro(context, e);
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    String? opcional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final base = widget.carga;
    final agora = DateTime.now();
    final placa = opcional(_placa);
    final carga = Carga(
      id: base?.id ?? '',
      conteiner: Iso6346.normalizar(_conteiner.text),
      booking: _booking.text.trim().toUpperCase(),
      navio: _navio.text.trim().toUpperCase(),
      viagem: _viagem.text.trim().toUpperCase(),
      transportadora: _transportadora.text.trim(),
      transportadoraCnpj:
          somenteDigitos(_cnpj.text).isEmpty ? null : somenteDigitos(_cnpj.text),
      placa: placa == null ? null : Validators.normalizarPlaca(placa),
      motorista: opcional(_motorista),
      pesoKg: opcional(_peso) == null ? null : Validators.parsePeso(_peso.text),
      dataPrevista: _dataPrevista,
      dataEntrada: base?.dataEntrada,
      dataSaida: base?.dataSaida,
      posicao: base?.posicao,
      status: base?.status ?? StatusCarga.previsto,
      criadoEm: base?.criadoEm ?? agora,
      atualizadoEm: agora,
      eventos: base?.eventos ?? const [],
      documentos: base?.documentos ?? const [],
    );

    setState(() => _salvando = true);
    final ctrl = context.read<CargasController>();
    try {
      if (_edicao) {
        await ctrl.atualizarCarga(carga);
      } else {
        await ctrl.criarCarga(carga);
      }
      if (!mounted) return;
      AppFeedback.sucesso(
          context,
          _edicao
              ? 'Carga ${carga.conteiner} atualizada.'
              : 'Carga ${carga.conteiner} cadastrada como Prevista.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) AppFeedback.erro(context, e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previsto = widget.carga == null ||
        widget.carga!.status == StatusCarga.previsto;
    return Scaffold(
      appBar: AppBar(
        title: Text(_edicao ? 'Editar carga' : 'Nova carga prevista'),
        actions: const [RoleBadge()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  titulo: 'Identificação',
                  icone: Icons.inventory_2_outlined,
                  child: Column(children: [
                    TextFormField(
                      controller: _conteiner,
                      enabled: previsto,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Número do contêiner *',
                        hintText: 'CSQU3054383',
                        helperText: 'Validado pelo dígito verificador ISO 6346',
                        prefixIcon: Icon(Icons.qr_code_2),
                      ),
                      validator: Validators.conteiner,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _booking,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: 'Booking *',
                          prefixIcon: Icon(Icons.confirmation_number_outlined)),
                      validator: Validators.booking,
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  titulo: 'Navio e previsão',
                  icone: Icons.directions_boat_outlined,
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _navio,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Navio *'),
                          validator: (v) => Validators.obrigatorio(v, 'Navio'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _viagem,
                          textCapitalization: TextCapitalization.characters,
                          decoration:
                              const InputDecoration(labelText: 'Viagem *'),
                          validator: (v) => Validators.obrigatorio(v, 'Viagem'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    DataHoraField(
                      rotulo: 'Data prevista de chegada *',
                      valor: _dataPrevista,
                      onChanged: (d) => setState(() => _dataPrevista = d),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  titulo: 'Transportadora',
                  icone: Icons.local_shipping_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cnpj,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'CNPJ *',
                                  prefixIcon: Icon(Icons.business)),
                              validator: Validators.cnpj,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _consultando ? null : _consultarCnpj,
                              icon: _consultando
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.travel_explore),
                              label: const Text('BrasilAPI'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _transportadora,
                        decoration: const InputDecoration(
                            labelText: 'Razão social *',
                            prefixIcon: Icon(Icons.apartment)),
                        validator: (v) =>
                            Validators.obrigatorio(v, 'Transportadora'),
                      ),
                      if (_empresa != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${_empresa!.nomeExibicao} · '
                            '${_empresa!.municipio ?? ''}/${_empresa!.uf ?? ''} · '
                            '${_empresa!.situacao ?? ''}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textoSecundario),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  titulo: 'Agendamento (opcional)',
                  icone: Icons.event_available_outlined,
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _placa,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                              labelText: 'Placa', hintText: 'ABC1D23'),
                          validator: (v) =>
                              Validators.placa(v, obrigatoria: false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _peso,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Peso declarado (kg)'),
                          validator: (v) =>
                              Validators.peso(v, obrigatorio: false),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _motorista,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Motorista'),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: _salvando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: Text(_edicao ? 'Salvar alterações' : 'Cadastrar carga'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../services/brasil_api_service.dart';
import '../../state/auth_controller.dart';
import '../theme.dart';
import '../widgets/feedback.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  final _cnpj = TextEditingController();
  final _empresa = TextEditingController();
  bool _consultando = false;
  bool _ocultarSenha = true;

  @override
  void dispose() {
    for (final c in [_nome, _email, _senha, _confirmacao, _cnpj, _empresa]) {
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
        _empresa.text = info.razaoSocial;
        _cnpj.text = Fmt.cnpj(info.cnpj);
      });
      AppFeedback.sucesso(context,
          'Empresa encontrada: ${info.nomeExibicao} (${info.situacao ?? 'situação n/d'})');
    } catch (e) {
      if (mounted) AppFeedback.erro(context, e);
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  Future<void> _cadastrar() async {
    if (!_form.currentState!.validate()) return;
    final cnpj = somenteDigitos(_cnpj.text);
    try {
      await context.read<AuthController>().cadastrar(
            nome: _nome.text,
            email: _email.text,
            senha: _senha.text,
            empresa: _empresa.text.trim().isEmpty ? null : _empresa.text.trim(),
            empresaCnpj: cnpj.isEmpty ? null : cnpj,
          );
      if (!mounted) return;
      AppFeedback.sucesso(context, 'Conta criada! Faça login para continuar.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) AppFeedback.erro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final carregando = context.watch<AuthController>().carregando;
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.azulPorto.withAlpha(18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.azulPorto),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Novas contas iniciam com o perfil Transportador '
                            '(nível 1). Um administrador pode promover o '
                            'usuário para Gate, Conferente, Operador ou '
                            'Supervisor.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nome,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        prefixIcon: Icon(Icons.person_outline)),
                    validator: Validators.nome,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.alternate_email)),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senha,
                    obscureText: _ocultarSenha,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      helperText: 'Mínimo 6 caracteres, com letras e números',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_ocultarSenha
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _ocultarSenha = !_ocultarSenha),
                      ),
                    ),
                    validator: Validators.senha,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmacao,
                    obscureText: _ocultarSenha,
                    decoration: const InputDecoration(
                        labelText: 'Confirmar senha',
                        prefixIcon: Icon(Icons.lock_reset)),
                    validator: (v) =>
                        v != _senha.text ? 'As senhas não conferem' : null,
                  ),
                  const SizedBox(height: 20),
                  Text('Transportadora (opcional)',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  const Text(
                    'Transportadores enxergam apenas as cargas da empresa '
                    'vinculada ao CNPJ informado.',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textoSecundario),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cnpj,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'CNPJ',
                              prefixIcon: Icon(Icons.business)),
                          validator: (v) =>
                              Validators.cnpj(v, obrigatorio: false),
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
                          label: const Text('Buscar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _empresa,
                    decoration: const InputDecoration(
                        labelText: 'Razão social',
                        helperText: 'Preenchida automaticamente via BrasilAPI',
                        prefixIcon: Icon(Icons.apartment)),
                    validator: (v) {
                      final temCnpj = somenteDigitos(_cnpj.text).isNotEmpty;
                      if (temCnpj && (v == null || v.trim().isEmpty)) {
                        return 'Informe a razão social (ou busque pelo CNPJ)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: carregando ? null : _cadastrar,
                    icon: carregando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_add_alt_1),
                    label: const Text('Criar conta'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

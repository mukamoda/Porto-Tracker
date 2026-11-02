import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/validators.dart';
import '../../data/demo_repository.dart';
import '../../data/demo_seed.dart';
import '../../state/auth_controller.dart';
import '../theme.dart';
import '../widgets/feedback.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _ocultarSenha = true;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    try {
      await context.read<AuthController>().entrar(_email.text, _senha.text);
    } catch (e) {
      if (mounted) AppFeedback.erro(context, e);
    }
  }

  void _preencherDemo(String email) {
    setState(() {
      _email.text = email;
      _senha.text = DemoRepository.senhaDemo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.azulPorto, Color(0xFF145A86)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const Icon(Icons.directions_boat_filled,
                        size: 64, color: AppTheme.laranjaConteiner),
                    const SizedBox(height: 8),
                    Text(AppConfig.nomeApp,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                    const Text('Controle operacional de cargas e contêineres',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Entrar',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'E-mail',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                                validator: Validators.email,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _senha,
                                obscureText: _ocultarSenha,
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _ocultarSenha
                                        ? 'Mostrar senha'
                                        : 'Ocultar senha',
                                    icon: Icon(_ocultarSenha
                                        ? Icons.visibility
                                        : Icons.visibility_off),
                                    onPressed: () => setState(
                                        () => _ocultarSenha = !_ocultarSenha),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Informe a senha'
                                    : null,
                                onFieldSubmitted: (_) => _entrar(),
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: auth.carregando ? null : _entrar,
                                style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14)),
                                child: auth.carregando
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Text('Entrar'),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const SignupPage())),
                                child: const Text('Não tem conta? Cadastre-se'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (auth.modoDemonstracao) ...[
                      const SizedBox(height: 16),
                      _ContasDemo(onSelecionar: _preencherDemo),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContasDemo extends StatelessWidget {
  const _ContasDemo({required this.onSelecionar});

  final ValueChanged<String> onSelecionar;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withAlpha(235),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.science_outlined, size: 18),
              SizedBox(width: 6),
              Text('Modo demonstração',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            const Text(
              'Toque em um perfil para preencher o acesso '
              '(senha: ${DemoRepository.senhaDemo}). '
              'Quanto maior o nível, mais o usuário enxerga.',
              style: TextStyle(fontSize: 12, color: AppTheme.textoSecundario),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (papel, email) in DemoSeed.contas.reversed)
                  ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor: AppTheme.azulPorto,
                      child: Text('${papel.nivel}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ),
                    label: Text(papel.label),
                    onPressed: () => onSelecionar(email),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

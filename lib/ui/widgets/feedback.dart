import 'package:flutter/material.dart';

import '../../core/exceptions.dart';
import '../theme.dart';

/// Feedback visual padronizado para operações.
class AppFeedback {
  AppFeedback._();

  static void sucesso(BuildContext context, String mensagem) {
    _mostrar(context, mensagem, Icons.check_circle, AppTheme.sucesso);
  }

  static void erro(BuildContext context, Object erro) {
    final msg = erro is String ? erro : mensagemDeErro(erro);
    _mostrar(context, msg, Icons.error_outline, AppTheme.critico);
  }

  static void info(BuildContext context, String mensagem) {
    _mostrar(context, mensagem, Icons.info_outline, AppTheme.azulPorto);
  }

  static void _mostrar(
      BuildContext context, String msg, IconData icone, Color cor) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: cor,
        content: Row(
          children: [
            Icon(icone, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
      ));
  }

  static Future<bool> confirmar(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    String confirmar = 'Confirmar',
    bool destrutivo = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: destrutivo
                ? FilledButton.styleFrom(backgroundColor: AppTheme.critico)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmar),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icone,
    required this.titulo,
    this.mensagem,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String? mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56, color: AppTheme.textoSecundario),
            const SizedBox(height: 12),
            Text(titulo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (mensagem != null) ...[
              const SizedBox(height: 6),
              Text(mensagem!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textoSecundario)),
            ],
            if (acao != null) ...[const SizedBox(height: 16), acao!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.mensagem, required this.onRetry});

  final String mensagem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icone: Icons.cloud_off,
      titulo: 'Não foi possível carregar os dados',
      mensagem: mensagem,
      acao: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Tentar novamente'),
      ),
    );
  }
}

/// Caixa de erros de validação (regras de negócio) exibida em formulários.
class ErrosBox extends StatelessWidget {
  const ErrosBox(this.erros, {super.key});

  final List<String> erros;

  @override
  Widget build(BuildContext context) {
    if (erros.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.critico.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.critico.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.block, color: AppTheme.critico, size: 18),
            SizedBox(width: 6),
            Text('Não é possível registrar',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.textoPrimario)),
          ]),
          const SizedBox(height: 6),
          for (final e in erros)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $e',
                  style: const TextStyle(color: AppTheme.textoPrimario)),
            ),
        ],
      ),
    );
  }
}

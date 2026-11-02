import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../state/auth_controller.dart';
import '../theme.dart';
import 'feedback.dart';

/// Selo do perfil do usuário logado (exibido nas AppBars).
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthController>().usuario;
    if (u == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: '${u.nome} · ${u.papel.label} (nível ${u.papel.nivel})',
        child: Chip(
          visualDensity: VisualDensity.compact,
          avatar: Icon(u.papel.icone, size: 16, color: AppTheme.azulPorto),
          label: Text(u.papel.label, style: const TextStyle(fontSize: 12)),
          backgroundColor: Colors.white,
          side: BorderSide.none,
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.titulo,
    required this.child,
    this.icone,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final String titulo;
  final IconData? icone;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icone != null) ...[
                  Icon(icone, size: 20, color: AppTheme.azulPorto),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(titulo,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Par rótulo/valor usado nas telas de detalhe.
class InfoItem extends StatelessWidget {
  const InfoItem(this.rotulo, this.valor, {super.key, this.largura = 160});

  final String rotulo;
  final String valor;
  final double largura;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largura,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textoSecundario)),
          const SizedBox(height: 2),
          Text(valor,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppTheme.textoPrimario)),
        ],
      ),
    );
  }
}

/// Proteção de rota: só exibe [child] se o usuário atender a [permitido].
class PermissionGuard extends StatelessWidget {
  const PermissionGuard({
    super.key,
    required this.permitido,
    required this.child,
    this.requisito,
  });

  final bool Function(AppUser usuario) permitido;
  final Widget child;

  /// Perfil mínimo exibido na mensagem de acesso negado.
  final UserRole? requisito;

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthController>().usuario;
    if (u != null && permitido(u)) return child;
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso restrito')),
      body: EmptyState(
        icone: Icons.lock_outline,
        titulo: 'Você não tem acesso a esta tela',
        mensagem: requisito == null
            ? 'Solicite acesso a um administrador.'
            : 'Requer perfil ${requisito!.label} ou superior.',
      ),
    );
  }
}

/// Seletor de data + hora em um único campo.
class DataHoraField extends StatelessWidget {
  const DataHoraField({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.onChanged,
    this.primeiraData,
    this.ultimaData,
  });

  final String rotulo;
  final DateTime valor;
  final ValueChanged<DateTime> onChanged;
  final DateTime? primeiraData;
  final DateTime? ultimaData;

  Future<void> _selecionar(BuildContext context) async {
    final primeira = primeiraData ?? DateTime(2020);
    final ultima = ultimaData ?? DateTime(2035);
    var inicial = valor;
    if (inicial.isBefore(primeira)) inicial = primeira;
    if (inicial.isAfter(ultima)) inicial = ultima;
    final data = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: primeira,
      lastDate: ultima,
    );
    if (data == null || !context.mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(valor),
    );
    if (hora == null) return;
    onChanged(DateTime(data.year, data.month, data.day, hora.hour, hora.minute));
  }

  @override
  Widget build(BuildContext context) {
    String dois(int n) => n.toString().padLeft(2, '0');
    final texto = '${dois(valor.day)}/${dois(valor.month)}/${valor.year} '
        '${dois(valor.hour)}:${dois(valor.minute)}';
    return InkWell(
      onTap: () => _selecionar(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: rotulo,
          prefixIcon: const Icon(Icons.event),
          suffixIcon: const Icon(Icons.edit_calendar_outlined),
        ),
        child: Text(texto),
      ),
    );
  }
}

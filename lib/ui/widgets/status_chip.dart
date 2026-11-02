import 'package:flutter/material.dart';

import '../../models/carga.dart';
import '../../models/pendencia.dart';
import '../theme.dart';

/// Chip de etapa: ícone colorido + rótulo em tinta de texto.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.compacto = false});

  final StatusCarga status;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compacto ? 6 : 10, vertical: compacto ? 2 : 4),
      decoration: BoxDecoration(
        color: status.cor.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.cor.withAlpha(110)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icone, size: compacto ? 14 : 16, color: status.cor),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: compacto ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textoPrimario,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador de pendências (quantidade + maior gravidade) com tooltip.
class PendenciasBadge extends StatelessWidget {
  const PendenciasBadge(this.pendencias, {super.key});

  final List<Pendencia> pendencias;

  @override
  Widget build(BuildContext context) {
    if (pendencias.isEmpty) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: AppTheme.sucesso),
          SizedBox(width: 4),
          Text('OK', style: TextStyle(color: AppTheme.textoSecundario)),
        ],
      );
    }
    final pior = pendencias.first.gravidade; // lista já ordenada
    return Tooltip(
      message: pendencias.map((p) => '• ${p.descricao}').join('\n'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pior.icone, size: 16, color: pior.cor),
          const SizedBox(width: 4),
          Text(
            '${pendencias.length} ${pendencias.length == 1 ? 'pendência' : 'pendências'}',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppTheme.textoPrimario),
          ),
        ],
      ),
    );
  }
}

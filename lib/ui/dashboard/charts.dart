import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Indicador (stat tile): número em destaque + rótulo.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icone,
    this.subtitulo,
    this.corIcone = AppTheme.azulPorto,
    this.onTap,
  });

  final String titulo;
  final String valor;
  final IconData icone;
  final String? subtitulo;
  final Color corIcone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icone, size: 18, color: corIcone),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textoSecundario)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(valor,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textoPrimario)),
              if (subtitulo != null)
                Text(subtitulo!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textoSecundario)),
            ],
          ),
        ),
      ),
    );
  }
}

class BarraItem {
  const BarraItem(this.rotulo, this.valor, {this.cor, this.icone, this.onTap});

  final String rotulo;
  final int valor;
  final Color? cor;
  final IconData? icone;
  final VoidCallback? onTap;
}

/// Barras horizontais com rótulo e valor diretos (magnitude por categoria).
class BarrasHorizontais extends StatelessWidget {
  const BarrasHorizontais({
    super.key,
    required this.itens,
    this.larguraRotulo = 120,
    this.unidade = '',
  });

  final List<BarraItem> itens;
  final double larguraRotulo;
  final String unidade;

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Sem dados no período.',
            style: TextStyle(color: AppTheme.textoSecundario)),
      );
    }
    final maximo = itens.map((i) => i.valor).fold<int>(0, math.max);
    return Column(
      children: [
        for (final item in itens)
          Tooltip(
            message: '${item.rotulo}: ${item.valor}$unidade',
            child: InkWell(
              onTap: item.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: larguraRotulo,
                      child: Row(children: [
                        if (item.icone != null) ...[
                          Icon(item.icone,
                              size: 16, color: item.cor ?? AppTheme.serie1),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(item.rotulo,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textoPrimario)),
                        ),
                      ]),
                    ),
                    Expanded(
                      child: LayoutBuilder(builder: (context, c) {
                        final fracao = maximo == 0 ? 0.0 : item.valor / maximo;
                        final largura = math.max(
                            item.valor == 0 ? 0.0 : 4.0, c.maxWidth * fracao);
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: largura,
                            height: 14,
                            decoration: BoxDecoration(
                              color: item.cor ?? AppTheme.serie1,
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(4)),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      child: Text('${item.valor}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textoPrimario)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class SerieColunas {
  const SerieColunas(this.nome, this.cor, this.valores);
  final String nome;
  final Color cor;
  final List<int> valores;
}

/// Colunas agrupadas (ex.: gate in × gate out por dia), com legenda e
/// tooltip por barra.
class ColunasAgrupadas extends StatelessWidget {
  const ColunasAgrupadas({
    super.key,
    required this.rotulos,
    required this.series,
    this.altura = 150,
  });

  final List<String> rotulos;
  final List<SerieColunas> series;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final maximo = series
        .expand((s) => s.valores)
        .fold<int>(0, math.max)
        .clamp(1, 1 << 30);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 16, children: [
          for (final s in series)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: s.cor, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Text(s.nome,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textoPrimario)),
            ]),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: altura,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < rotulos.length; i++)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final s in series) ...[
                        Tooltip(
                          message: '${rotulos[i]} · ${s.nome}: ${s.valores[i]}',
                          child: Container(
                            width: 14,
                            height: math.max(
                                s.valores[i] == 0 ? 0.0 : 3.0,
                                (altura - 4) * s.valores[i] / maximo),
                            decoration: BoxDecoration(
                              color: s.cor,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        Container(height: 1, color: Colors.grey.shade300),
        const SizedBox(height: 4),
        Row(children: [
          for (final r in rotulos)
            Expanded(
              child: Text(r,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textoSecundario)),
            ),
        ]),
      ],
    );
  }
}

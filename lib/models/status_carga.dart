/// Etapas do ciclo operacional da carga/contêiner no terminal.
enum StatusCarga {
  previsto('previsto', 'Previsto', 0),
  recepcionado('recepcionado', 'Recepcionado', 1),
  armazenado('armazenado', 'Armazenado', 2),
  emInspecao('em_inspecao', 'Em inspeção', 3),
  liberado('liberado', 'Liberado', 4),
  retirado('retirado', 'Retirado', 5);

  const StatusCarga(this.codigo, this.label, this.ordem);

  final String codigo;
  final String label;
  final int ordem;

  /// Cargas fisicamente dentro do terminal.
  bool get noTerminal =>
      this != StatusCarga.previsto && this != StatusCarga.retirado;

  static StatusCarga fromCodigo(String? c) =>
      tryCodigo(c) ?? StatusCarga.previsto;

  static StatusCarga? tryCodigo(String? c) {
    if (c == null) return null;
    for (final s in StatusCarga.values) {
      if (s.codigo == c) return s;
    }
    return null;
  }
}

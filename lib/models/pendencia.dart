enum Gravidade {
  alta('Alta'),
  media('Média'),
  baixa('Baixa');

  const Gravidade(this.label);
  final String label;
}

/// Pendência calculada a partir do estado da carga (regras de negócio).
class Pendencia {
  const Pendencia(this.descricao, this.gravidade);

  final String descricao;
  final Gravidade gravidade;
}

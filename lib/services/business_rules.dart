import '../core/formatters.dart';
import '../core/validators.dart';
import '../models/carga.dart';
import '../models/documento.dart';
import '../models/evento.dart';
import '../models/pendencia.dart';
import '../models/user_role.dart';
import 'permissions.dart';

/// Regras de negócio do ciclo operacional.
///
/// As mesmas regras são replicadas no banco (função `registrar_evento`
/// em `supabase/schema.sql`), garantindo validação no app e no servidor.
class BusinessRules {
  BusinessRules._();

  /// Tolerância para relógios dessincronizados ao validar "data no futuro".
  static const Duration toleranciaFuturo = Duration(minutes: 5);

  /// Máquina de estados: status atual → próximos status permitidos.
  static const Map<StatusCarga, List<StatusCarga>> _transicoes = {
    StatusCarga.previsto: [StatusCarga.recepcionado],
    StatusCarga.recepcionado: [StatusCarga.armazenado, StatusCarga.emInspecao],
    StatusCarga.armazenado: [StatusCarga.emInspecao, StatusCarga.liberado],
    StatusCarga.emInspecao: [StatusCarga.armazenado, StatusCarga.liberado],
    StatusCarga.liberado: [StatusCarga.retirado],
    StatusCarga.retirado: [],
  };

  /// Status nos quais o contêiner pode ser movimentado no pátio.
  static const Set<StatusCarga> statusMovimentaveis = {
    StatusCarga.recepcionado,
    StatusCarga.armazenado,
    StatusCarga.emInspecao,
    StatusCarga.liberado,
  };

  static const Set<TipoDocumento> docsFiscais = {
    TipoDocumento.notaFiscal,
    TipoDocumento.danfe,
  };
  static const Set<TipoDocumento> docsDespacho = {
    TipoDocumento.di,
    TipoDocumento.duimp,
    TipoDocumento.due,
  };

  static List<StatusCarga> proximosStatus(StatusCarga atual) =>
      _transicoes[atual] ?? const [];

  /// Permissão exigida para levar a carga ao status [alvo].
  static Permissao permissaoPara(StatusCarga alvo) => switch (alvo) {
        StatusCarga.previsto => Permissao.cadastrarCarga,
        StatusCarga.recepcionado || StatusCarga.retirado =>
          Permissao.registrarGate,
        StatusCarga.armazenado || StatusCarga.emInspecao =>
          Permissao.registrarArmazenagem,
        StatusCarga.liberado => Permissao.liberarCarga,
      };

  static bool podeLevarPara(UserRole papel, StatusCarga alvo) =>
      Permissoes.pode(papel, permissaoPara(alvo));

  /// Mensagem explicando por que a transição não é permitida (ou null).
  static String? motivoTransicaoInvalida(StatusCarga de, StatusCarga para) {
    if (de == para) return 'A carga já está em "${para.label}".';
    if (proximosStatus(de).contains(para)) return null;
    if (de == StatusCarga.retirado) {
      return 'Contêiner já retirado: não pode voltar para "${para.label}".';
    }
    if (para == StatusCarga.retirado) {
      return 'Um contêiner só pode ser retirado depois de ser liberado.';
    }
    return 'Transição não permitida: ${de.label} → ${para.label}.';
  }

  /// Documentos obrigatórios que ainda faltam para a liberação.
  static List<String> documentosFaltantes(Carga c) => [
        if (!c.possuiDocumento(docsFiscais)) 'Documento fiscal (NF ou DANFE)',
        if (!c.possuiDocumento(docsDespacho))
          'Documento de despacho (DI, DUIMP ou DU-E)',
      ];

  /// Valida um novo evento. Retorna a lista de erros (vazia = válido).
  static List<String> validarEvento({
    required Carga carga,
    required NovoEvento evento,
    required UserRole papel,
    DateTime? agora,
  }) {
    final erros = <String>[];
    final now = agora ?? DateTime.now();

    // Data e horário são obrigatórios e coerentes com o histórico.
    if (evento.dataHora.isAfter(now.add(toleranciaFuturo))) {
      erros.add('A data/hora do evento não pode estar no futuro.');
    }
    final ultimo = carga.ultimoEvento;
    if (ultimo != null && evento.dataHora.isBefore(ultimo.dataHora)) {
      erros.add('A data/hora não pode ser anterior ao último evento '
          '(${Fmt.dataHora(ultimo.dataHora)}).');
    }

    switch (evento.tipo) {
      case TipoEvento.criacao:
        erros.add('O evento de cadastro é gerado automaticamente.');
      case TipoEvento.status:
        _validarStatus(carga, evento, papel, erros);
      case TipoEvento.movimentacao:
        if (!Permissoes.pode(papel, Permissao.registrarArmazenagem)) {
          erros.add('Seu perfil não pode movimentar contêineres.');
        }
        if (!statusMovimentaveis.contains(carga.status)) {
          erros.add('Não é possível movimentar uma carga '
              '"${carga.status.label}".');
        }
        final pos = evento.dado(CampoEvento.posicao)?.toUpperCase();
        final erroPos = Validators.posicao(pos);
        if (erroPos != null) erros.add(erroPos);
        if (pos != null && pos == carga.posicao) {
          erros.add('A nova posição é igual à posição atual.');
        }
      case TipoEvento.ocorrencia:
        if (!Permissoes.pode(papel, Permissao.registrarOcorrencia)) {
          erros.add('Seu perfil não pode registrar ocorrências.');
        }
        if (carga.status == StatusCarga.retirado) {
          erros.add('A carga já foi retirada do terminal.');
        }
        if (evento.dado(CampoEvento.tipoOcorrencia) == null) {
          erros.add('Informe o tipo de ocorrência.');
        }
        if ((evento.dado(CampoEvento.descricao) ?? '').length < 5) {
          erros.add('Descreva a ocorrência (mínimo 5 caracteres).');
        }
      case TipoEvento.resolucao:
        if (!Permissoes.pode(papel, Permissao.resolverOcorrencia)) {
          erros.add('Seu perfil não pode resolver ocorrências.');
        }
        final id = evento.dado(CampoEvento.ocorrenciaId);
        if (id == null || !carga.ocorrenciasAbertas.any((o) => o.id == id)) {
          erros.add('Selecione uma ocorrência aberta.');
        }
        if ((evento.dado(CampoEvento.descricao) ?? '').length < 5) {
          erros.add('Descreva a solução (mínimo 5 caracteres).');
        }
    }
    return erros;
  }

  static void _validarStatus(
      Carga carga, NovoEvento evento, UserRole papel, List<String> erros) {
    final alvo = evento.statusNovo;
    if (alvo == null) {
      erros.add('Selecione a nova etapa.');
      return;
    }
    final motivo = motivoTransicaoInvalida(carga.status, alvo);
    if (motivo != null) {
      erros.add(motivo);
      return;
    }
    if (!podeLevarPara(papel, alvo)) {
      erros.add('O perfil ${papel.label} não pode registrar "${alvo.label}" '
          '(requer ${Permissoes.minimo(permissaoPara(alvo)).label}).');
    }

    // Informações adicionais exigidas por status.
    switch (alvo) {
      case StatusCarga.recepcionado:
      case StatusCarga.retirado:
        final ep = Validators.placa(evento.dado(CampoEvento.placa));
        if (ep != null) erros.add(ep);
        if (evento.dado(CampoEvento.motorista) == null) {
          erros.add('Informe o motorista.');
        }
        if (alvo == StatusCarga.recepcionado) {
          final epeso = Validators.peso(evento.dado(CampoEvento.peso));
          if (epeso != null) erros.add(epeso);
        }
      case StatusCarga.armazenado:
        final e = Validators.posicao(evento.dado(CampoEvento.posicao));
        if (e != null) erros.add(e);
      case StatusCarga.emInspecao:
        if (evento.dado(CampoEvento.orgao) == null) {
          erros.add('Informe o órgão responsável pela inspeção.');
        }
        if (evento.dado(CampoEvento.motivo) == null) {
          erros.add('Informe o motivo da inspeção.');
        }
      case StatusCarga.liberado:
        if (evento.dado(CampoEvento.documentoLiberacao) == null) {
          erros.add('Informe o número do documento de liberação.');
        }
        if (carga.ocorrenciasAbertas.isNotEmpty) {
          erros.add('Existem ${carga.ocorrenciasAbertas.length} ocorrência(s) '
              'aberta(s). Resolva antes de liberar.');
        }
        for (final f in documentosFaltantes(carga)) {
          erros.add('Documento obrigatório ausente: $f.');
        }
      case StatusCarga.previsto:
        break;
    }
  }

  /// Calcula as pendências da carga.
  static List<Pendencia> pendencias(Carga c, {DateTime? agora}) {
    final now = agora ?? DateTime.now();
    final lista = <Pendencia>[];

    for (final o in c.ocorrenciasAbertas) {
      final tipo =
          TipoOcorrencia.fromCodigo(o.dado(CampoEvento.tipoOcorrencia)).label;
      lista.add(Pendencia('Ocorrência aberta: $tipo', Gravidade.alta));
    }

    final desde = now.difference(c.statusDesde);
    switch (c.status) {
      case StatusCarga.previsto:
        if (now.difference(c.dataPrevista) > const Duration(hours: 12)) {
          lista.add(Pendencia(
              'Chegada atrasada (previsão ${Fmt.dataHoraCurta(c.dataPrevista)})',
              Gravidade.media));
        }
      case StatusCarga.recepcionado:
        if (desde > const Duration(hours: 6)) {
          lista.add(Pendencia(
              'Sem posição de armazenagem há ${Fmt.duracao(desde)}',
              Gravidade.baixa));
        }
      case StatusCarga.armazenado:
      case StatusCarga.emInspecao:
        for (final f in documentosFaltantes(c)) {
          lista.add(Pendencia('Documento ausente: $f', Gravidade.media));
        }
        if (c.status == StatusCarga.emInspecao &&
            desde > const Duration(hours: 48)) {
          lista.add(Pendencia(
              'Em inspeção há ${Fmt.duracao(desde)}', Gravidade.media));
        }
      case StatusCarga.liberado:
        if (desde > const Duration(hours: 72)) {
          lista.add(Pendencia(
              'Liberado aguardando retirada há ${Fmt.duracao(desde)}',
              Gravidade.baixa));
        }
      case StatusCarga.retirado:
        break;
    }
    lista.sort((a, b) => a.gravidade.index.compareTo(b.gravidade.index));
    return lista;
  }

  /// Orientação de próxima etapa exibida ao operador.
  static String proximaEtapa(Carga c) {
    if (c.ocorrenciasAbertas.isNotEmpty) return 'Resolver ocorrência';
    return switch (c.status) {
      StatusCarga.previsto => 'Aguardar chegada (gate in)',
      StatusCarga.recepcionado => 'Armazenar ou enviar à inspeção',
      StatusCarga.armazenado => documentosFaltantes(c).isEmpty
          ? 'Liberar ou inspecionar'
          : 'Enviar documentos p/ liberação',
      StatusCarga.emInspecao => documentosFaltantes(c).isEmpty
          ? 'Concluir inspeção / liberar'
          : 'Enviar documentos p/ liberação',
      StatusCarga.liberado => 'Aguardar retirada (gate out)',
      StatusCarga.retirado => 'Ciclo concluído',
    };
  }

  /// Indica se o perfil pode registrar ao menos um tipo de evento na carga.
  static bool podeRegistrarAlgo(UserRole papel, Carga c) {
    if (c.status == StatusCarga.retirado) return false;
    final porStatus =
        proximosStatus(c.status).any((s) => podeLevarPara(papel, s));
    return porStatus ||
        Permissoes.pode(papel, Permissao.registrarOcorrencia) ||
        (c.ocorrenciasAbertas.isNotEmpty &&
            Permissoes.pode(papel, Permissao.resolverOcorrencia));
  }
}

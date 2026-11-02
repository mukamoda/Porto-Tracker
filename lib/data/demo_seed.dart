import 'dart:typed_data';

import '../core/validators.dart';
import '../models/app_user.dart';
import '../models/carga.dart';
import '../models/documento.dart';
import '../models/evento.dart';
import '../models/user_role.dart';
import 'demo_repository.dart';

class DemoSeedResultado {
  const DemoSeedResultado(this.usuarios, this.cargas);
  final List<AppUser> usuarios;
  final List<Carga> cargas;
}

/// Gera dados realistas, relativos ao momento atual, cobrindo todas as etapas
/// do fluxo, pendências, ocorrências e documentos.
class DemoSeed {
  DemoSeed._(this.agora);

  final DateTime agora;
  int _seq = 0;

  static const contas = <(UserRole, String)>[
    (UserRole.admin, 'admin@porto.com'),
    (UserRole.supervisor, 'supervisor@porto.com'),
    (UserRole.operador, 'operador@porto.com'),
    (UserRole.conferente, 'conferente@porto.com'),
    (UserRole.gate, 'gate@porto.com'),
    (UserRole.transportador, 'transportador@porto.com'),
  ];

  static const _transportadoras = <(String, String)>[
    ('TransLog Cargas Ltda', '12345678000195'),
    ('Rodomar Transportes S.A.', '45678912000155'),
    ('Santos Express Logística', '78912345000109'),
  ];

  static const _navios = <(String, String)>[
    ('MV ATLÂNTICO SUL', '045S'),
    ('MV CORAL BAY', '112N'),
    ('MV ORIENT STAR', '019E'),
  ];

  static const _motoristas = <(String, String)>[
    ('BRA2E19', 'João Pereira'),
    ('RIO4A21', 'Marcos Silva'),
    ('SPX7C33', 'Paulo Rocha'),
    ('QWE1234', 'Ricardo Nunes'),
    ('KLM5F67', 'Sérgio Dias'),
    ('PTA9B88', 'Luiz Martins'),
  ];

  static const chaveNfeExemplo = '35261100000000000001550010000123451000123453';

  late final AppUser admin, supervisor, operador, conferente, gate, transp;

  static DemoSeedResultado gerar(DateTime agora) {
    final s = DemoSeed._(agora);
    s._criarUsuarios();
    return DemoSeedResultado(
      [s.admin, s.supervisor, s.operador, s.conferente, s.gate, s.transp],
      s._criarCargas(),
    );
  }

  void _criarUsuarios() {
    AppUser u(String id, String nome, UserRole papel,
            {String? empresa, String? cnpj}) =>
        AppUser(
          id: id,
          nome: nome,
          email: contas.firstWhere((c) => c.$1 == papel).$2,
          papel: papel,
          empresa: empresa,
          empresaCnpj: cnpj,
          criadoEm: agora.subtract(const Duration(days: 60)),
        );
    admin = u('usr_admin', 'Ana Ribeiro', UserRole.admin);
    supervisor = u('usr_sup', 'Carlos Menezes', UserRole.supervisor);
    operador = u('usr_op', 'Beatriz Lima', UserRole.operador);
    conferente = u('usr_conf', 'Diego Souza', UserRole.conferente);
    gate = u('usr_gate', 'Eduardo Alves', UserRole.gate);
    transp = u('usr_transp', 'Fernanda Costa', UserRole.transportador,
        empresa: _transportadoras[0].$1, cnpj: _transportadoras[0].$2);
  }

  // ------------------------------------------------------------ construtores

  String _id(String p) => '${p}_seed_${(++_seq).toString().padLeft(4, '0')}';
  DateTime _h(num horasAtras) =>
      agora.subtract(Duration(minutes: (horasAtras * 60).round()));

  Carga _nova(String prefixo10, int t, int n,
      {required DateTime prevista, required num criadaHa}) {
    final id = _id('cg');
    final criada = _h(criadaHa);
    return Carga(
      id: id,
      conteiner: Iso6346.comDigito(prefixo10),
      booking: 'BKG${(482100 + _seq * 37)}',
      navio: _navios[n].$1,
      viagem: _navios[n].$2,
      transportadora: _transportadoras[t].$1,
      transportadoraCnpj: _transportadoras[t].$2,
      dataPrevista: prevista,
      status: StatusCarga.previsto,
      criadoEm: criada,
      atualizadoEm: criada,
      eventos: [
        EventoOperacional(
          id: _id('ev'),
          cargaId: id,
          tipo: TipoEvento.criacao,
          statusNovo: StatusCarga.previsto,
          dataHora: criada,
          registradoEm: criada,
          usuarioId: operador.id,
          usuarioNome: operador.nome,
        ),
      ],
    );
  }

  Carga _evento(Carga c, TipoEvento tipo, num horasAtras, AppUser u,
      {StatusCarga? status, Map<String, dynamic> dados = const {}, String? obs}) {
    final quando = _h(horasAtras);
    return DemoRepository.aplicarEvento(
      c,
      EventoOperacional(
        id: _id('ev'),
        cargaId: c.id,
        tipo: tipo,
        statusAnterior: tipo == TipoEvento.status ? c.status : null,
        statusNovo: status,
        dataHora: quando,
        registradoEm: quando,
        usuarioId: u.id,
        usuarioNome: u.nome,
        dados: dados,
        observacao: obs,
      ),
    );
  }

  Carga _recepcionar(Carga c, num h, int motorista, {int peso = 24500}) =>
      _evento(c, TipoEvento.status, h, gate,
          status: StatusCarga.recepcionado,
          dados: {
            CampoEvento.placa: _motoristas[motorista].$1,
            CampoEvento.motorista: _motoristas[motorista].$2,
            CampoEvento.peso: '$peso',
          });

  Carga _armazenar(Carga c, num h, String pos) =>
      _evento(c, TipoEvento.status, h, conferente,
          status: StatusCarga.armazenado, dados: {CampoEvento.posicao: pos});

  Carga _inspecionar(Carga c, num h, String motivo) =>
      _evento(c, TipoEvento.status, h, conferente,
          status: StatusCarga.emInspecao,
          dados: {
            CampoEvento.orgao: OrgaoInspecao.receita.codigo,
            CampoEvento.motivo: motivo,
          });

  Carga _liberar(Carga c, num h) => _evento(c, TipoEvento.status, h, supervisor,
      status: StatusCarga.liberado,
      dados: {CampoEvento.documentoLiberacao: 'DI 26/0${4410 + _seq}-3'});

  Carga _retirar(Carga c, num h, int motorista) =>
      _evento(c, TipoEvento.status, h, gate,
          status: StatusCarga.retirado,
          dados: {
            CampoEvento.placa: _motoristas[motorista].$1,
            CampoEvento.motorista: _motoristas[motorista].$2,
          });

  Carga _doc(Carga c, TipoDocumento tipo, num h, AppUser u) {
    final numero = switch (tipo) {
      TipoDocumento.danfe || TipoDocumento.notaFiscal => chaveNfeExemplo,
      TipoDocumento.di => '26/0${3300 + _seq}-1',
      _ => null,
    };
    final doc = Documento(
      id: _id('doc'),
      cargaId: c.id,
      tipo: tipo,
      nomeArquivo: '${tipo.sigla.replaceAll('-', '')}_${c.conteiner}.pdf',
      caminho: '${c.id}/${tipo.codigo}.pdf',
      tamanhoBytes: 180000 + _seq * 2311,
      mimeType: 'application/pdf',
      numero: numero,
      enviadoPorNome: u.nome,
      enviadoEm: _h(h),
      bytes: Uint8List(0),
    );
    return c.copyWith(documentos: [doc, ...c.documentos]);
  }

  // ------------------------------------------------------------------ dados

  List<Carga> _criarCargas() {
    final cargas = <Carga>[];

    // Previstos
    cargas.add(_nova('MSCU123456', 0, 0, prevista: _h(-6), criadaHa: 30));
    cargas.add(_nova('MAEU765432', 1, 1, prevista: _h(20), criadaHa: 70));
    cargas.add(_nova('CMAU234567', 2, 2, prevista: _h(-30), criadaHa: 8));

    // Recepcionados
    var c = _nova('HLXU345678', 0, 0, prevista: _h(4), criadaHa: 50);
    cargas.add(_recepcionar(c, 3, 0));
    c = _nova('TGHU456789', 1, 1, prevista: _h(10), criadaHa: 60);
    cargas.add(_recepcionar(c, 9, 1, peso: 27800));

    // Armazenados
    c = _nova('MSCU567890', 0, 2, prevista: _h(40), criadaHa: 96);
    c = _recepcionar(c, 38, 2);
    c = _armazenar(c, 37, 'A-03-02');
    cargas.add(_doc(c, TipoDocumento.danfe, 30, transp));

    c = _nova('MAEU678901', 2, 0, prevista: _h(52), criadaHa: 100);
    c = _recepcionar(c, 50, 3, peso: 21350);
    c = _armazenar(c, 49, 'B-11-01');
    c = _doc(c, TipoDocumento.danfe, 45, operador);
    cargas.add(_doc(c, TipoDocumento.di, 20, operador));

    c = _nova('CMAU789012', 1, 1, prevista: _h(26), criadaHa: 80);
    c = _recepcionar(c, 25, 4, peso: 30120);
    c = _armazenar(c, 24, 'C-05-03');
    c = _doc(c, TipoDocumento.notaFiscal, 22, operador);
    c = _doc(c, TipoDocumento.duimp, 18, operador);
    cargas.add(_evento(c, TipoEvento.ocorrencia, 16, conferente, dados: {
      CampoEvento.tipoOcorrencia: TipoOcorrencia.avaria.codigo,
      CampoEvento.descricao: 'Amassado na porta traseira, lado esquerdo.',
    }));

    c = _nova('TGHU445566', 0, 2, prevista: _h(34), criadaHa: 90);
    c = _recepcionar(c, 33, 5, peso: 19800);
    c = _armazenar(c, 32, 'D-02-04');
    c = _evento(c, TipoEvento.movimentacao, 12, conferente, dados: {
      CampoEvento.posicaoAnterior: 'D-02-04',
      CampoEvento.posicao: 'A-07-01',
    }, obs: 'Remanejado para bloco A (próximo ao gate).');
    c = _doc(c, TipoDocumento.danfe, 11, transp);
    cargas.add(_doc(c, TipoDocumento.di, 10, operador));

    // Em inspeção
    c = _nova('HLXU890123', 0, 1, prevista: _h(75), criadaHa: 120);
    c = _recepcionar(c, 72, 0, peso: 26400);
    c = _armazenar(c, 70, 'B-04-02');
    c = _doc(c, TipoDocumento.danfe, 68, transp);
    c = _doc(c, TipoDocumento.di, 66, operador);
    cargas.add(_inspecionar(c, 60, 'Canal vermelho — conferência física'));

    c = _nova('TGHU901234', 2, 0, prevista: _h(14), criadaHa: 40);
    c = _recepcionar(c, 12, 1, peso: 22900);
    c = _doc(c, TipoDocumento.notaFiscal, 8, operador);
    cargas.add(_inspecionar(c, 5, 'Canal amarelo — conferência documental'));

    // Liberados
    c = _nova('MSCU012345', 0, 2, prevista: _h(60), criadaHa: 110);
    c = _recepcionar(c, 58, 2, peso: 25100);
    c = _armazenar(c, 57, 'C-09-01');
    c = _doc(c, TipoDocumento.danfe, 40, transp);
    c = _doc(c, TipoDocumento.di, 30, operador);
    cargas.add(_liberar(c, 10));

    c = _nova('MAEU112233', 1, 0, prevista: _h(150), criadaHa: 200);
    c = _recepcionar(c, 148, 3, peso: 28700);
    c = _armazenar(c, 147, 'A-01-03');
    c = _doc(c, TipoDocumento.notaFiscal, 120, operador);
    c = _doc(c, TipoDocumento.due, 110, operador);
    cargas.add(_liberar(c, 90));

    // Retirados (ciclo completo)
    c = _nova('CMAU223344', 2, 1, prevista: _h(100), criadaHa: 160);
    c = _recepcionar(c, 98, 4, peso: 23300);
    c = _armazenar(c, 97, 'B-08-02');
    c = _doc(c, TipoDocumento.danfe, 90, operador);
    c = _doc(c, TipoDocumento.di, 80, operador);
    c = _liberar(c, 60);
    cargas.add(_retirar(c, 48, 4));

    c = _nova('HLXU334455', 0, 0, prevista: _h(170), criadaHa: 220);
    c = _recepcionar(c, 168, 5, peso: 26050);
    c = _armazenar(c, 166, 'D-06-01');
    c = _evento(c, TipoEvento.ocorrencia, 160, conferente, dados: {
      CampoEvento.tipoOcorrencia: TipoOcorrencia.lacre.codigo,
      CampoEvento.descricao: 'Número do lacre divergente do BL.',
    });
    final ocorrenciaId = c.eventos.last.id;
    c = _evento(c, TipoEvento.resolucao, 150, operador, dados: {
      CampoEvento.ocorrenciaId: ocorrenciaId,
      CampoEvento.descricao: 'Armador confirmou troca de lacre; BL corrigido.',
    });
    c = _doc(c, TipoDocumento.danfe, 148, transp);
    c = _doc(c, TipoDocumento.di, 140, operador);
    c = _liberar(c, 130);
    cargas.add(_retirar(c, 120, 5));

    c = _nova('MSCU778899', 1, 2, prevista: _h(30), criadaHa: 75);
    c = _recepcionar(c, 29, 2, peso: 20500);
    c = _armazenar(c, 28, 'A-10-02');
    c = _doc(c, TipoDocumento.notaFiscal, 26, operador);
    c = _doc(c, TipoDocumento.di, 25, operador);
    c = _liberar(c, 20);
    cargas.add(_retirar(c, 4, 3));

    return cargas;
  }
}

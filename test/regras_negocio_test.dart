import 'package:flutter_test/flutter_test.dart';
import 'package:porto_track/core/validators.dart';
import 'package:porto_track/models/carga.dart';
import 'package:porto_track/models/evento.dart';
import 'package:porto_track/models/user_role.dart';
import 'package:porto_track/services/business_rules.dart';

Carga _carga(StatusCarga status) {
  final agora = DateTime.now().subtract(const Duration(hours: 1));
  return Carga(
    id: 'c1',
    conteiner: 'CSQU3054383',
    booking: 'BKG123456',
    navio: 'MV TESTE',
    viagem: '001N',
    transportadora: 'Teste Ltda',
    dataPrevista: agora,
    status: status,
    criadoEm: agora,
    atualizadoEm: agora,
  );
}

void main() {
  group('Validadores', () {
    test('ISO 6346 aceita dígito correto e rejeita incorreto', () {
      expect(Iso6346.valido('CSQU3054383'), isTrue);
      expect(Iso6346.valido('CSQU3054384'), isFalse);
      expect(Iso6346.comDigito('CSQU305438'), 'CSQU3054383');
    });

    test('CNPJ', () {
      expect(Cnpj.valido('12.345.678/0001-95'), isTrue);
      expect(Cnpj.valido('12.345.678/0001-96'), isFalse);
      expect(Cnpj.valido('11111111111111'), isFalse);
    });

    test('Chave de acesso NF-e', () {
      expect(ChaveNfe.valida('35261100000000000001550010000123451000123453'),
          isTrue);
      expect(ChaveNfe.valida('35261100000000000001550010000123451000123454'),
          isFalse);
    });

    test('Placa Mercosul e antiga', () {
      expect(Validators.placa('BRA2E19'), isNull);
      expect(Validators.placa('ABC-1234'), isNull);
      expect(Validators.placa('AB1234'), isNotNull);
    });
  });

  group('Sequência de status', () {
    test('não permite retirar antes de liberar', () {
      final erros = BusinessRules.validarEvento(
        carga: _carga(StatusCarga.armazenado),
        evento: NovoEvento(
          tipo: TipoEvento.status,
          statusNovo: StatusCarga.retirado,
          dataHora: DateTime.now(),
          dados: const {'placa': 'BRA2E19', 'motorista': 'João'},
        ),
        papel: UserRole.admin,
      );
      expect(erros.first, contains('liberado'));
    });

    test('retirado não volta para recepcionado', () {
      expect(
        BusinessRules.motivoTransicaoInvalida(
            StatusCarga.retirado, StatusCarga.recepcionado),
        isNotNull,
      );
    });

    test('gate não pode liberar carga', () {
      expect(
          BusinessRules.podeLevarPara(UserRole.gate, StatusCarga.liberado),
          isFalse);
      expect(BusinessRules.podeLevarPara(UserRole.supervisor,
          StatusCarga.liberado), isTrue);
    });

    test('armazenar exige posição válida', () {
      final erros = BusinessRules.validarEvento(
        carga: _carga(StatusCarga.recepcionado),
        evento: NovoEvento(
          tipo: TipoEvento.status,
          statusNovo: StatusCarga.armazenado,
          dataHora: DateTime.now(),
          dados: const {'posicao': 'X1'},
        ),
        papel: UserRole.conferente,
      );
      expect(erros, isNotEmpty);
    });

    test('evento no futuro é rejeitado', () {
      final erros = BusinessRules.validarEvento(
        carga: _carga(StatusCarga.recepcionado),
        evento: NovoEvento(
          tipo: TipoEvento.status,
          statusNovo: StatusCarga.armazenado,
          dataHora: DateTime.now().add(const Duration(days: 1)),
          dados: const {'posicao': 'A-01-01'},
        ),
        papel: UserRole.conferente,
      );
      expect(erros.any((e) => e.contains('futuro')), isTrue);
    });

    test('liberação exige documentos', () {
      final erros = BusinessRules.validarEvento(
        carga: _carga(StatusCarga.armazenado),
        evento: NovoEvento(
          tipo: TipoEvento.status,
          statusNovo: StatusCarga.liberado,
          dataHora: DateTime.now(),
          dados: const {'documento_liberacao': 'DI 123'},
        ),
        papel: UserRole.supervisor,
      );
      expect(erros.where((e) => e.contains('Documento obrigatório')).length, 2);
    });
  });
}

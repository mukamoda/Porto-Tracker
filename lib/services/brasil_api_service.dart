import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/exceptions.dart';
import '../core/formatters.dart';
import '../core/validators.dart';

class EmpresaInfo {
  const EmpresaInfo({
    required this.cnpj,
    required this.razaoSocial,
    this.nomeFantasia,
    this.municipio,
    this.uf,
    this.situacao,
  });

  final String cnpj;
  final String razaoSocial;
  final String? nomeFantasia;
  final String? municipio;
  final String? uf;
  final String? situacao;

  String get nomeExibicao =>
      (nomeFantasia != null && nomeFantasia!.trim().isNotEmpty)
          ? nomeFantasia!
          : razaoSocial;

  bool get ativa => (situacao ?? '').toUpperCase() == 'ATIVA';
}

/// Integração com a BrasilAPI (https://brasilapi.com.br) — API pública de
/// terceiros usada para consultar transportadoras pelo CNPJ.
class BrasilApiService {
  BrasilApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<EmpresaInfo> consultarCnpj(String cnpj) async {
    final digitos = somenteDigitos(cnpj);
    if (!Cnpj.valido(digitos)) {
      throw const AppException('CNPJ inválido. Verifique os dígitos.');
    }
    try {
      final resp = await _client
          .get(Uri.parse('${AppConfig.brasilApiBaseUrl}/cnpj/v1/$digitos'))
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 404) {
        throw const AppException('CNPJ não encontrado na base da Receita.');
      }
      if (resp.statusCode == 429) {
        throw const AppException(
            'Muitas consultas seguidas. Aguarde alguns segundos.');
      }
      if (resp.statusCode != 200) {
        throw AppException(
            'BrasilAPI indisponível no momento (HTTP ${resp.statusCode}).');
      }

      final json = jsonDecode(utf8.decode(resp.bodyBytes));
      if (json is! Map<String, dynamic>) {
        throw const AppException('Resposta inesperada da BrasilAPI.');
      }
      return EmpresaInfo(
        cnpj: digitos,
        razaoSocial: (json['razao_social'] as String?) ?? '',
        nomeFantasia: json['nome_fantasia'] as String?,
        municipio: json['municipio'] as String?,
        uf: json['uf'] as String?,
        situacao: json['descricao_situacao_cadastral'] as String?,
      );
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException('Tempo esgotado ao consultar a BrasilAPI.');
    } catch (e) {
      throw AppException(
          'Não foi possível consultar o CNPJ. Verifique sua conexão.', e);
    }
  }
}

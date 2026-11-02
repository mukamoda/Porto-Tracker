import 'formatters.dart';

/// Validação do número de contêiner segundo a norma ISO 6346
/// (3 letras do proprietário + categoria U/J/Z + 6 dígitos + dígito verificador).
class Iso6346 {
  Iso6346._();

  static const Map<String, int> _valores = {
    'A': 10, 'B': 12, 'C': 13, 'D': 14, 'E': 15, 'F': 16, 'G': 17, //
    'H': 18, 'I': 19, 'J': 20, 'K': 21, 'L': 23, 'M': 24, 'N': 25, //
    'O': 26, 'P': 27, 'Q': 28, 'R': 29, 'S': 30, 'T': 31, 'U': 32, //
    'V': 34, 'W': 35, 'X': 36, 'Y': 37, 'Z': 38,
  };

  static String normalizar(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool formatoValido(String n) =>
      RegExp(r'^[A-Z]{3}[UJZ][0-9]{7}$').hasMatch(n);

  static int calcularDigito(String dezPrimeiros) {
    var soma = 0;
    for (var i = 0; i < 10; i++) {
      final c = dezPrimeiros[i];
      final valor = _valores[c] ?? int.parse(c);
      soma += valor * (1 << i);
    }
    return (soma % 11) % 10;
  }

  static bool valido(String numero) {
    final n = normalizar(numero);
    return formatoValido(n) &&
        calcularDigito(n.substring(0, 10)) == int.parse(n[10]);
  }

  /// Gera um número completo a partir dos 10 primeiros caracteres.
  static String comDigito(String dez) => '$dez${calcularDigito(dez)}';
}

/// Validação de CNPJ (dígitos verificadores módulo 11).
class Cnpj {
  Cnpj._();

  static bool valido(String valor) {
    final d = somenteDigitos(valor);
    if (d.length != 14) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(d)) return false;
    int calc(String base, List<int> pesos) {
      var soma = 0;
      for (var i = 0; i < pesos.length; i++) {
        soma += int.parse(base[i]) * pesos[i];
      }
      final r = soma % 11;
      return r < 2 ? 0 : 11 - r;
    }

    const p1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    const p2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    final d1 = calc(d, p1);
    final d2 = calc(d, p2);
    return d1 == int.parse(d[12]) && d2 == int.parse(d[13]);
  }
}

/// Validação da chave de acesso da NF-e/DANFE (44 dígitos, DV módulo 11).
class ChaveNfe {
  ChaveNfe._();

  static bool valida(String valor) {
    final d = somenteDigitos(valor);
    if (d.length != 44) return false;
    var soma = 0;
    var peso = 2;
    for (var i = 42; i >= 0; i--) {
      soma += int.parse(d[i]) * peso;
      peso = peso == 9 ? 2 : peso + 1;
    }
    final r = soma % 11;
    final dv = r < 2 ? 0 : 11 - r;
    return dv == int.parse(d[43]);
  }
}

/// Validadores prontos para `TextFormField.validator`.
class Validators {
  Validators._();

  static final RegExp _regexPosicao = RegExp(r'^[A-Z]-\d{2}-\d{2}$');
  static final RegExp _regexPlaca = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$');

  static String? obrigatorio(String? v, [String campo = 'Campo']) =>
      (v == null || v.trim().isEmpty) ? '$campo é obrigatório' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
    final ok = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(v.trim());
    return ok ? null : 'E-mail inválido';
  }

  static String? senha(String? v) {
    if (v == null || v.isEmpty) return 'Informe a senha';
    if (v.length < 6) return 'Mínimo de 6 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Use letras e números';
    }
    return null;
  }

  static String? nome(String? v) {
    if (v == null || v.trim().length < 3) return 'Informe o nome completo';
    return null;
  }

  static String? conteiner(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o número do contêiner';
    final n = Iso6346.normalizar(v);
    if (!Iso6346.formatoValido(n)) {
      return 'Formato ISO 6346: 4 letras + 7 dígitos (ex.: CSQU3054383)';
    }
    if (!Iso6346.valido(n)) {
      final correto = Iso6346.calcularDigito(n.substring(0, 10));
      return 'Dígito verificador inválido (esperado: $correto)';
    }
    return null;
  }

  static String normalizarPlaca(String v) =>
      v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static String? placa(String? v, {bool obrigatoria = true}) {
    if (v == null || v.trim().isEmpty) {
      return obrigatoria ? 'Informe a placa do veículo' : null;
    }
    return _regexPlaca.hasMatch(normalizarPlaca(v))
        ? null
        : 'Placa inválida (ex.: ABC1D23 ou ABC1234)';
  }

  static String? cnpj(String? v, {bool obrigatorio = true}) {
    if (v == null || v.trim().isEmpty) {
      return obrigatorio ? 'Informe o CNPJ' : null;
    }
    return Cnpj.valido(v) ? null : 'CNPJ inválido';
  }

  static double? parsePeso(String v) {
    final limpo = v.trim().replaceAll(' ', '').replaceAll('.', '');
    return double.tryParse(limpo.replaceAll(',', '.'));
  }

  static String? peso(String? v, {bool obrigatorio = true}) {
    if (v == null || v.trim().isEmpty) {
      return obrigatorio ? 'Informe o peso bruto (kg)' : null;
    }
    final p = parsePeso(v);
    if (p == null) return 'Peso inválido';
    if (p <= 0) return 'O peso deve ser maior que zero';
    if (p > 40000) return 'Peso acima do limite de 40.000 kg';
    return null;
  }

  static String? posicao(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe a posição no pátio';
    return _regexPosicao.hasMatch(v.trim().toUpperCase())
        ? null
        : 'Formato Bloco-Fila-Altura (ex.: A-12-03)';
  }

  static bool posicaoValida(String? v) =>
      v != null && _regexPosicao.hasMatch(v.trim().toUpperCase());

  static String? booking(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o booking';
    return RegExp(r'^[A-Za-z0-9-]{6,20}$').hasMatch(v.trim())
        ? null
        : 'Booking: 6 a 20 caracteres alfanuméricos';
  }

  static String? chaveNfe(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe a chave de acesso';
    final d = somenteDigitos(v);
    if (d.length != 44) return 'A chave deve ter 44 dígitos (${d.length})';
    return ChaveNfe.valida(d) ? null : 'Chave de acesso inválida (DV)';
  }
}

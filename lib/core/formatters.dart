/// Funções de formatação (datas, pesos, tamanhos) no padrão brasileiro.
String somenteDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');

String _dois(int n) => n.toString().padLeft(2, '0');

class Fmt {
  Fmt._();

  static String data(DateTime? d) =>
      d == null ? '—' : '${_dois(d.day)}/${_dois(d.month)}/${d.year}';

  static String dataCurta(DateTime? d) =>
      d == null ? '—' : '${_dois(d.day)}/${_dois(d.month)}';

  static String hora(DateTime? d) =>
      d == null ? '—' : '${_dois(d.hour)}:${_dois(d.minute)}';

  static String dataHora(DateTime? d) =>
      d == null ? '—' : '${data(d)} ${hora(d)}';

  static String dataHoraCurta(DateTime? d) =>
      d == null ? '—' : '${dataCurta(d)} ${hora(d)}';

  static String milhar(int v) {
    final s = v.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${v < 0 ? '-' : ''}$buf';
  }

  static String peso(double? kg) =>
      kg == null ? '—' : '${milhar(kg.round())} kg';

  static String duracao(Duration d) {
    if (d.isNegative) return '0min';
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}min';
    return '${d.inMinutes}min';
  }

  static String relativo(DateTime d, {DateTime? agora}) {
    final diff = (agora ?? DateTime.now()).difference(d);
    if (diff.isNegative) return 'em ${duracao(-diff)}';
    if (diff.inMinutes < 1) return 'agora';
    return 'há ${duracao(diff)}';
  }

  static String tamanhoArquivo(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String cnpj(String? valor) {
    if (valor == null) return '—';
    final d = somenteDigitos(valor);
    if (d.length != 14) return valor;
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/'
        '${d.substring(8, 12)}-${d.substring(12)}';
  }

  static String iniciais(String nome) {
    final partes =
        nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }
}

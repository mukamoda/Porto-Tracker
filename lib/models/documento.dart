import 'dart:typed_data';

enum TipoDocumento {
  notaFiscal('nf', 'NF', 'Nota Fiscal'),
  danfe('danfe', 'DANFE', 'DANFE (NF-e)'),
  di('di', 'DI', 'Declaração de Importação'),
  duimp('duimp', 'DUIMP', 'Declaração Única de Importação'),
  due('due', 'DU-E', 'Declaração Única de Exportação'),
  billOfLading('bl', 'BL', 'Bill of Lading'),
  ceMercante('ce_mercante', 'CE', 'CE Mercante'),
  packingList('packing_list', 'PL', 'Packing List'),
  outro('outro', 'Outro', 'Outro documento');

  const TipoDocumento(this.codigo, this.sigla, this.label);

  final String codigo;
  final String sigla;
  final String label;

  /// NF e DANFE exigem a chave de acesso de 44 dígitos.
  bool get exigeChaveNfe =>
      this == TipoDocumento.notaFiscal || this == TipoDocumento.danfe;

  /// Documentos de despacho aduaneiro exigem número.
  bool get exigeNumero =>
      exigeChaveNfe ||
      this == TipoDocumento.di ||
      this == TipoDocumento.duimp ||
      this == TipoDocumento.due;

  static TipoDocumento fromCodigo(String? c) => TipoDocumento.values
      .firstWhere((t) => t.codigo == c, orElse: () => TipoDocumento.outro);
}

class Documento {
  const Documento({
    required this.id,
    required this.cargaId,
    required this.tipo,
    required this.nomeArquivo,
    required this.caminho,
    required this.tamanhoBytes,
    required this.mimeType,
    required this.enviadoPorNome,
    required this.enviadoEm,
    this.numero,
    this.bytes,
  });

  final String id;
  final String cargaId;
  final TipoDocumento tipo;
  final String nomeArquivo;

  /// Caminho no bucket do Storage (`<carga_id>/<arquivo>`).
  final String caminho;
  final int tamanhoBytes;
  final String mimeType;
  final String? numero;
  final String enviadoPorNome;
  final DateTime enviadoEm;

  /// Conteúdo em memória (usado apenas no modo demonstração).
  final Uint8List? bytes;

  bool get ehImagem => mimeType.startsWith('image/');
  bool get ehPdf => mimeType == 'application/pdf';

  factory Documento.fromMap(Map<String, dynamic> m) => Documento(
        id: m['id'] as String,
        cargaId: m['carga_id'] as String,
        tipo: TipoDocumento.fromCodigo(m['tipo'] as String?),
        nomeArquivo: (m['nome_arquivo'] as String?) ?? 'arquivo',
        caminho: (m['caminho'] as String?) ?? '',
        tamanhoBytes: (m['tamanho_bytes'] as num?)?.toInt() ?? 0,
        mimeType: (m['mime_type'] as String?) ?? 'application/octet-stream',
        numero: m['numero'] as String?,
        enviadoPorNome: (m['enviado_por_nome'] as String?) ?? '—',
        enviadoEm: DateTime.parse(m['enviado_em'] as String).toLocal(),
      );

  static String mimePorExtensao(String nomeArquivo) {
    final ext = nomeArquivo.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'xml' => 'application/xml',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
  }
}

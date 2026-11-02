/// Configurações globais da aplicação.
///
/// As credenciais do Supabase são passadas via `--dart-define`:
/// ```
/// flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
/// Sem elas, o app roda em **modo demonstração** (dados em memória).
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get usaSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const String nomeApp = 'PortoTrack';
  static const String brasilApiBaseUrl = 'https://brasilapi.com.br/api';
  static const String storageBucket = 'documentos';

  /// Tamanho máximo de arquivo para upload (10 MB).
  static const int tamanhoMaximoArquivo = 10 * 1024 * 1024;
  static const List<String> extensoesPermitidas = [
    'pdf',
    'xml',
    'jpg',
    'jpeg',
    'png',
  ];
}

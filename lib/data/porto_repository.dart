import 'dart:typed_data';

import '../models/app_user.dart';
import '../models/carga.dart';
import '../models/documento.dart';
import '../models/evento.dart';
import '../models/user_role.dart';

/// Contrato de acesso a dados. Implementações:
/// * [SupabaseRepository] — persistência remota (Auth, Postgres, Storage);
/// * [DemoRepository] — dados em memória para apresentação sem backend.
///
/// A visibilidade por perfil é aplicada pela implementação (RLS no Supabase),
/// e não apenas pela interface.
abstract class PortoRepository {
  bool get modoDemonstracao;

  // Autenticação
  Future<AppUser?> usuarioAtual();
  Future<AppUser> entrar(String email, String senha);
  Future<void> cadastrar({
    required String nome,
    required String email,
    required String senha,
    String? empresa,
    String? empresaCnpj,
  });
  Future<void> sair();

  // Cargas
  Future<List<Carga>> listarCargas();
  Future<Carga> obterCarga(String id);
  Future<Carga> criarCarga(Carga nova);
  Future<Carga> atualizarCarga(Carga carga);
  Future<void> excluirCarga(String id);

  // Eventos operacionais
  Future<void> registrarEvento(String cargaId, NovoEvento evento);

  // Documentos
  Future<Documento> enviarDocumento({
    required String cargaId,
    required TipoDocumento tipo,
    required String nomeArquivo,
    required Uint8List bytes,
    String? numero,
  });
  Future<Uri?> urlDocumento(Documento documento);
  Future<void> excluirDocumento(Documento documento);

  // Usuários (admin)
  Future<List<AppUser>> listarUsuarios();
  Future<void> alterarPapel(String usuarioId, UserRole papel);
}

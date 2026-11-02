import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/exceptions.dart';
import '../models/app_user.dart';
import '../models/carga.dart';
import '../models/documento.dart';
import '../models/evento.dart';
import '../models/user_role.dart';
import 'porto_repository.dart';

/// Persistência remota no Supabase (Auth + Postgres + Storage).
///
/// Visibilidade e permissões são garantidas no banco pelas políticas RLS e
/// pela função `registrar_evento` (ver `supabase/schema.sql`).
class SupabaseRepository implements PortoRepository {
  SupabaseRepository(this._client);

  final SupabaseClient _client;

  static const String _selectCarga = '*, eventos(*), documentos(*)';

  @override
  bool get modoDemonstracao => false;

  // ---------------------------------------------------------------- helpers

  Future<T> _executar<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on AppException {
      rethrow;
    } on AuthException catch (e) {
      throw AppException(_traduzirAuth(e.message), e);
    } on PostgrestException catch (e) {
      throw AppException(_traduzirPostgrest(e), e);
    } on StorageException catch (e) {
      throw AppException('Falha no armazenamento de arquivos: ${e.message}', e);
    } catch (e) {
      throw AppException(
          'Erro de comunicação com o servidor. Verifique sua conexão.', e);
    }
  }

  String _traduzirAuth(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login')) return 'E-mail ou senha inválidos.';
    if (m.contains('already registered')) {
      return 'Este e-mail já está cadastrado.';
    }
    if (m.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de entrar.';
    }
    if (m.contains('password')) return 'Senha não atende aos requisitos.';
    return msg;
  }

  String _traduzirPostgrest(PostgrestException e) {
    switch (e.code) {
      case '23505':
        return 'Registro duplicado (o contêiner já está cadastrado?).';
      case '42501':
        return 'Seu perfil não tem permissão para esta operação.';
      case 'PGRST116':
        return 'Registro não encontrado ou sem acesso.';
      case 'P0001': // RAISE EXCEPTION das regras de negócio
        return e.message;
      default:
        return e.message;
    }
  }

  String get _uid {
    final u = _client.auth.currentUser;
    if (u == null) throw const AppException('Sessão expirada. Entre novamente.');
    return u.id;
  }

  Future<AppUser> _perfil(String id) async {
    final row =
        await _client.from('profiles').select().eq('id', id).single();
    return AppUser.fromMap(row);
  }

  // ----------------------------------------------------------- autenticação

  @override
  Future<AppUser?> usuarioAtual() => _executar(() async {
        final u = _client.auth.currentUser;
        if (u == null) return null;
        return _perfil(u.id);
      });

  @override
  Future<AppUser> entrar(String email, String senha) => _executar(() async {
        final resp = await _client.auth
            .signInWithPassword(email: email.trim(), password: senha);
        final user = resp.user;
        if (user == null) throw const AppException('Falha na autenticação.');
        return _perfil(user.id);
      });

  @override
  Future<void> cadastrar({
    required String nome,
    required String email,
    required String senha,
    String? empresa,
    String? empresaCnpj,
  }) =>
      _executar(() async {
        // O perfil é criado pelo trigger `handle_new_user` com papel
        // "transportador"; promoções são feitas por um administrador.
        await _client.auth.signUp(
          email: email.trim(),
          password: senha,
          data: {
            'nome': nome.trim(),
            'empresa': empresa,
            'empresa_cnpj': empresaCnpj,
          },
        );
        // Mantém o fluxo "cadastrar → entrar" explícito.
        await _client.auth.signOut();
      });

  @override
  Future<void> sair() => _executar(() => _client.auth.signOut());

  // ----------------------------------------------------------------- cargas

  @override
  Future<List<Carga>> listarCargas() => _executar(() async {
        final rows = await _client
            .from('cargas')
            .select(_selectCarga)
            .order('atualizado_em', ascending: false);
        return rows.map(Carga.fromMap).toList();
      });

  @override
  Future<Carga> obterCarga(String id) => _executar(() async {
        final row = await _client
            .from('cargas')
            .select(_selectCarga)
            .eq('id', id)
            .single();
        return Carga.fromMap(row);
      });

  @override
  Future<Carga> criarCarga(Carga nova) => _executar(() async {
        final row = await _client
            .from('cargas')
            .insert({...nova.toEditMap(), 'criado_por': _uid})
            .select('id')
            .single();
        return obterCarga(row['id'] as String);
      });

  @override
  Future<Carga> atualizarCarga(Carga carga) => _executar(() async {
        await _client
            .from('cargas')
            .update(carga.toEditMap())
            .eq('id', carga.id);
        return obterCarga(carga.id);
      });

  @override
  Future<void> excluirCarga(String id) => _executar(() async {
        final removidas =
            await _client.from('cargas').delete().eq('id', id).select('id');
        if (removidas.isEmpty) {
          throw const AppException('Seu perfil não pode excluir cargas.');
        }
      });

  // ---------------------------------------------------------------- eventos

  @override
  Future<void> registrarEvento(String cargaId, NovoEvento evento) =>
      _executar(() async {
        await _client.rpc('registrar_evento',
            params: evento.toRpcParams(cargaId));
      });

  // ------------------------------------------------------------- documentos

  @override
  Future<Documento> enviarDocumento({
    required String cargaId,
    required TipoDocumento tipo,
    required String nomeArquivo,
    required Uint8List bytes,
    String? numero,
  }) =>
      _executar(() async {
        if (bytes.length > AppConfig.tamanhoMaximoArquivo) {
          throw const AppException('Arquivo maior que 10 MB.');
        }
        final mime = Documento.mimePorExtensao(nomeArquivo);
        final seguro = nomeArquivo.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final caminho =
            '$cargaId/${DateTime.now().millisecondsSinceEpoch}_$seguro';
        final bucket = _client.storage.from(AppConfig.storageBucket);

        await bucket.uploadBinary(caminho, bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false));

        try {
          final perfil = await _perfil(_uid);
          final row = await _client
              .from('documentos')
              .insert({
                'carga_id': cargaId,
                'tipo': tipo.codigo,
                'numero': numero,
                'nome_arquivo': nomeArquivo,
                'caminho': caminho,
                'tamanho_bytes': bytes.length,
                'mime_type': mime,
                'enviado_por': perfil.id,
                'enviado_por_nome': perfil.nome,
              })
              .select()
              .single();
          return Documento.fromMap(row);
        } catch (_) {
          // Desfaz o upload se o registro não puder ser gravado.
          await bucket.remove([caminho]);
          rethrow;
        }
      });

  @override
  Future<Uri?> urlDocumento(Documento documento) => _executar(() async {
        final url = await _client.storage
            .from(AppConfig.storageBucket)
            .createSignedUrl(documento.caminho, 600);
        return Uri.parse(url);
      });

  @override
  Future<void> excluirDocumento(Documento documento) => _executar(() async {
        final removidos = await _client
            .from('documentos')
            .delete()
            .eq('id', documento.id)
            .select('id');
        if (removidos.isEmpty) {
          throw const AppException('Seu perfil não pode excluir documentos.');
        }
        await _client.storage
            .from(AppConfig.storageBucket)
            .remove([documento.caminho]);
      });

  // --------------------------------------------------------------- usuários

  @override
  Future<List<AppUser>> listarUsuarios() => _executar(() async {
        final rows = await _client.from('profiles').select().order('nome');
        final lista = rows.map(AppUser.fromMap).toList()
          ..sort((a, b) => b.papel.nivel.compareTo(a.papel.nivel));
        return lista;
      });

  @override
  Future<void> alterarPapel(String usuarioId, UserRole papel) =>
      _executar(() async {
        if (usuarioId == _uid) {
          throw const AppException('Você não pode alterar o próprio perfil.');
        }
        final rows = await _client
            .from('profiles')
            .update({'papel': papel.codigo})
            .eq('id', usuarioId)
            .select('id');
        if (rows.isEmpty) {
          throw const AppException('Sem permissão para alterar perfis.');
        }
      });
}

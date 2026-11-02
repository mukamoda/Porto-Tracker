import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'data/porto_repository.dart';
import 'services/brasil_api_service.dart';
import 'state/auth_controller.dart';
import 'state/cargas_controller.dart';
import 'state/navegacao_controller.dart';
import 'state/usuarios_controller.dart';
import 'ui/auth/login_page.dart';
import 'ui/shell/app_shell.dart';
import 'ui/theme.dart';

class PortoTrackApp extends StatelessWidget {
  const PortoTrackApp({super.key, required this.repositorio});

  final PortoRepository repositorio;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PortoRepository>.value(value: repositorio),
        Provider<BrasilApiService>(create: (_) => BrasilApiService()),
        ChangeNotifierProvider(
            create: (_) => AuthController(repositorio)..inicializar()),
        ChangeNotifierProvider(create: (_) => CargasController(repositorio)),
        ChangeNotifierProvider(create: (_) => UsuariosController(repositorio)),
        ChangeNotifierProvider(create: (_) => NavegacaoController()),
      ],
      child: MaterialApp(
        title: AppConfig.nomeApp,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const AuthGate(),
      ),
    );
  }
}

/// Decide entre login e área logada conforme o estado de autenticação.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.inicializado) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final usuario = auth.usuario;
    if (usuario == null) return const LoginPage();
    // A chave força a reconstrução completa ao trocar de usuário/perfil.
    return AppShell(key: ValueKey('${usuario.id}-${usuario.papel.codigo}'));
  }
}

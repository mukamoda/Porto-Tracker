import 'package:flutter/material.dart';

import '../models/carga.dart';
import '../models/pendencia.dart';
import '../models/user_role.dart';

class AppTheme {
  AppTheme._();

  static const Color azulPorto = Color(0xFF0B3C5D);
  static const Color laranjaConteiner = Color(0xFFE8833A);
  static const Color fundo = Color(0xFFF4F6F8);

  // Tinta de texto (valores e rótulos nunca usam a cor da série).
  static const Color textoPrimario = Color(0xFF1F2933);
  static const Color textoSecundario = Color(0xFF52606D);

  // Cor de série única para gráficos de magnitude.
  static const Color serie1 = Color(0xFF2A78D6);
  static const Color serie2 = Color(0xFFEB6834);

  // Status reservados (sempre com ícone + rótulo).
  static const Color critico = Color(0xFFC62828);
  static const Color alerta = Color(0xFFB26A00);
  static const Color info = Color(0xFF52606D);
  static const Color sucesso = Color(0xFF2E7D32);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: azulPorto,
      primary: azulPorto,
      secondary: laranjaConteiner,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: fundo,
      appBarTheme: const AppBarTheme(
        backgroundColor: azulPorto,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: laranjaConteiner,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    );
  }
}

/// Identidade visual de cada etapa (paleta categórica validada para
/// daltonismo; sempre acompanhada de ícone + rótulo).
extension StatusVisual on StatusCarga {
  Color get cor => switch (this) {
        StatusCarga.previsto => const Color(0xFF2A78D6),
        StatusCarga.recepcionado => const Color(0xFFEB6834),
        StatusCarga.armazenado => const Color(0xFF1BAF7A),
        StatusCarga.emInspecao => const Color(0xFFEDA100),
        StatusCarga.liberado => const Color(0xFF008300),
        StatusCarga.retirado => const Color(0xFFE87BA4),
      };

  IconData get icone => switch (this) {
        StatusCarga.previsto => Icons.schedule,
        StatusCarga.recepcionado => Icons.login,
        StatusCarga.armazenado => Icons.inventory_2_outlined,
        StatusCarga.emInspecao => Icons.manage_search,
        StatusCarga.liberado => Icons.verified_outlined,
        StatusCarga.retirado => Icons.logout,
      };
}

extension GravidadeVisual on Gravidade {
  Color get cor => switch (this) {
        Gravidade.alta => AppTheme.critico,
        Gravidade.media => AppTheme.alerta,
        Gravidade.baixa => AppTheme.info,
      };

  IconData get icone => switch (this) {
        Gravidade.alta => Icons.error,
        Gravidade.media => Icons.warning_amber_rounded,
        Gravidade.baixa => Icons.info_outline,
      };
}

extension RoleVisual on UserRole {
  IconData get icone => switch (this) {
        UserRole.transportador => Icons.local_shipping_outlined,
        UserRole.gate => Icons.door_sliding_outlined,
        UserRole.conferente => Icons.fact_check_outlined,
        UserRole.operador => Icons.engineering_outlined,
        UserRole.supervisor => Icons.supervisor_account_outlined,
        UserRole.admin => Icons.admin_panel_settings_outlined,
      };
}

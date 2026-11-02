import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/demo_repository.dart';
import 'data/porto_repository.dart';
import 'data/supabase_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final PortoRepository repositorio;
  if (AppConfig.usaSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    repositorio = SupabaseRepository(Supabase.instance.client);
  } else {
    // Sem credenciais: modo demonstração com dados em memória.
    repositorio = DemoRepository();
  }

  runApp(PortoTrackApp(repositorio: repositorio));
}

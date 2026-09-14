import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/permission_service.dart';
import 'core/services/supabase_service.dart';
import 'state/app_state.dart';
import 'core/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabaseService = SupabaseService();
  await supabaseService.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(EliteApp(supabaseService: supabaseService));
}

class EliteApp extends StatelessWidget {
  final SupabaseService? supabaseService;

  const EliteApp({super.key, this.supabaseService});

  @override
  Widget build(BuildContext context) {
    final supa = supabaseService ?? SupabaseService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: supa),
        ChangeNotifierProvider(create: (_) => AppState(supa)),
        ChangeNotifierProvider(create: (_) => PermissionService()..checkAllPermissions()),
      ],
      child: Builder(
        builder: (context) {
          final appState = context.read<AppState>();
          final router = AppRouter.createRouter(appState);
          
          return MaterialApp.router(
            title: 'ELITE IT',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: router,
          );
        },
      ),
    );
  }
}


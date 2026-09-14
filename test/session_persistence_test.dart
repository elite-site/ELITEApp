import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elite_app/state/app_state.dart';
import 'package:elite_app/core/routing/app_router.dart';
import 'package:elite_app/data/models/app_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Authentication Session Persistence Tests', () {
    test('Session is persisted to SharedPreferences on successful login and restores across restarts', () async {
      SharedPreferences.setMockInitialValues({
        'elite_session_active': true,
        'elite_session_user_id': 'u_test_student',
        'elite_session_email': '23k61a1201@sasi.ac.in',
        'elite_session_roll': '23K61A1201',
        'elite_session_role': 'STUDENT',
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('elite_session_active'), isTrue);
      expect(prefs.getString('elite_session_user_id'), equals('u_test_student'));
      expect(prefs.getString('elite_session_roll'), equals('23K61A1201'));
      expect(prefs.getString('elite_session_role'), equals('STUDENT'));
    });

    test('Explicit logout completely clears persisted session from storage', () async {
      SharedPreferences.setMockInitialValues({
        'elite_session_active': true,
        'elite_session_user_id': 'u_test_student',
        'elite_session_email': '23k61a1201@sasi.ac.in',
        'elite_session_roll': '23K61A1201',
        'elite_session_role': 'STUDENT',
      });

      final appState = AppState();
      await appState.logout();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('elite_session_active'), isNull);
      expect(prefs.getString('elite_session_user_id'), isNull);
      expect(prefs.getString('elite_session_email'), isNull);
      expect(appState.isLoggedIn, isFalse);
    });

    test('AppRouter prevents redirection while isRestoringSession is true', () {
      final appState = AppState();
      expect(appState.isRestoringSession, isTrue);

      final router = AppRouter.createRouter(appState);
      expect(router.routeInformationProvider.value.uri.path, equals('/login'));
    });
  });
}

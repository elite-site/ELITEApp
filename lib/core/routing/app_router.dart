import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../ui/auth/login_screen.dart';
import '../../ui/student/student_main_navigation.dart';
import '../../ui/staff/staff_main_navigation.dart';
import '../../ui/admin/admin_main_navigation.dart';

class AppRouter {
  static GoRouter createRouter(AppState appState) {
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: appState,
      redirect: (context, state) {
        final isRestoring = appState.isRestoringSession;
        final isLoading = appState.isLoadingFromSupabase;
        final isLoggedIn = appState.isLoggedIn;

        // While restoring session from device storage on launch, stay put
        if (isRestoring) return null;

        // While fetching data for an already logged in user, don't redirect
        if (isLoading && isLoggedIn) return null;

        final loc = state.matchedLocation;
        final isOnLogin = loc == '/login';

        // 1. Not logged in → must stay on login
        if (!isLoggedIn) {
          return isOnLogin ? null : '/login';
        }

        // 2. Already logged in and on login page → redirect to their authorized dashboard
        if (isOnLogin) {
          if (appState.isAdmin) return '/admin';
          if (appState.isStaff) return '/staff';
          return '/student';
        }

        // 3. Strict Server-Driven Role Guards:
        // Admin portal protection: Only admin role can access /admin
        if (loc.startsWith('/admin') && !appState.isAdmin) {
          return appState.isStaff ? '/staff' : '/student';
        }

        // Staff portal protection: Students cannot access /staff
        if (loc.startsWith('/staff') && !appState.isStaff && !appState.isAdmin) {
          return '/student';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/student',
          builder: (context, state) => const StudentMainNavigation(),
        ),
        GoRoute(
          path: '/staff',
          builder: (context, state) => const StaffMainNavigation(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminMainNavigation(),
        ),
      ],
    );
  }
}

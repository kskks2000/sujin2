import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/allocations/presentation/allocations_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dispatch/presentation/dispatch_screen.dart';
import '../../features/load_plans/presentation/load_plans_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/shipments/presentation/shipments_screen.dart';
import '../auth/session_controller.dart';
import '../widgets/shell_frame.dart';

class AppRouter {
  static GoRouter createRouter(SessionController sessionController) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: sessionController,
      redirect: (context, state) {
        final loggingIn = state.matchedLocation == '/login';
        if (!sessionController.isAuthenticated && !loggingIn) {
          return '/login';
        }
        if (sessionController.isAuthenticated && loggingIn) {
          return '/';
        }
        return null;
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LoginScreen()),
        ),
        ShellRoute(
          builder: (context, state, child) => ShellFrame(child: child),
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DashboardScreen()),
            ),
            GoRoute(
              path: '/orders',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: OrdersScreen()),
            ),
            GoRoute(
              path: '/load-plans',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: LoadPlansScreen()),
            ),
            GoRoute(
              path: '/allocations',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AllocationsScreen()),
            ),
            GoRoute(
              path: '/shipments',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ShipmentsScreen()),
            ),
            GoRoute(
              path: '/dispatch',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DispatchScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

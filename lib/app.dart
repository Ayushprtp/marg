import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/vehicles/screens/add_vehicle_screen.dart';
import 'features/home/screens/main_screen.dart';
import 'features/profile/screens/my_parks_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/map/screens/map_screen.dart';
import 'features/map/screens/lot_detail_screen.dart';
import 'features/parking/screens/active_session_screen.dart';
import 'features/parking/screens/live_monitor_screen.dart';
import 'features/operator/screens/operator_dashboard.dart';
import 'features/operator/screens/add_lot_screen.dart';
import 'features/operator/screens/add_camera_screen.dart';
import 'features/admin/screens/admin_dashboard.dart';
import 'main.dart';

/// A simple listenable that GoRouter uses to re-evaluate redirects.
/// We use a ValueNotifier<int> and bump its value whenever auth changes.
final _routerRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final notifier = ValueNotifier<int>(0);

  ref.listen<AuthState>(authProvider, (_, __) {
    notifier.value++;
  });

  ref.onDispose(() {
    notifier.dispose();
  });

  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshProvider);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.isLoading) return null;

      final loggedIn = authState.user != null;
      final role = authState.role;

      if (!loggedIn) {
        if (state.matchedLocation == '/') return null;
        return '/';
      }

      if (state.matchedLocation == '/') {
        if (role == 'operator') return '/operator';
        if (role == 'root') return '/admin';
        return '/my-parks';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          final authState = ref.read(authProvider);
          if (authState.isLoading) {
            return const Scaffold(
              backgroundColor: Color(0xFF121212),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF799E83)),
              ),
            );
          }
          return const AuthScreen();
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScreen(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Parks (My Bookings)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-parks',
                builder: (context, state) => const MyParksScreen(),
              ),
            ],
          ),
          // Branch 1: Map
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          // Branch 2: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/lot/:id',
        builder: (context, state) {
          final lot = state.extra as Map<String, dynamic>? ?? {};
          return LotDetailScreen(lot: lot);
        },
      ),
      GoRoute(
        path: '/add-vehicle',
        builder: (context, state) => const AddVehicleScreen(),
      ),
      GoRoute(
        path: '/active-session',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          return ActiveSessionScreen(bookingData: data);
        },
      ),
      GoRoute(
        path: '/live-monitor',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return LiveMonitorScreen(booking: data);
        },
      ),
      GoRoute(
        path: '/operator',
        builder: (context, state) => const OperatorDashboard(),
        routes: [
          GoRoute(
            path: 'add-lot',
            builder: (context, state) => const AddLotScreen(),
          ),
          GoRoute(
            path: 'add-camera',
            builder: (context, state) => const AddCameraScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboard(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
  });

  return router;
});

class SmartParkApp extends ConsumerWidget {
  const SmartParkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SmartPark',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeProvider),
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
    );
  }
}

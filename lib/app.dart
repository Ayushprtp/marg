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
import 'features/map/screens/map_screen.dart';
import 'features/map/screens/lot_detail_screen.dart';
import 'features/parking/screens/active_session_screen.dart';
import 'features/operator/screens/operator_dashboard.dart';
import 'features/operator/screens/add_lot_screen.dart';
import 'features/operator/screens/add_camera_screen.dart';
import 'features/admin/screens/admin_dashboard.dart';
import 'main.dart';

class SmartParkApp extends ConsumerWidget {
  const SmartParkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    final GoRouter router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
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
          return '/home';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            if (authState.isLoading) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return const AuthScreen();
          },
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const MainScreen(),
        ),
        GoRoute(
          path: '/map',
          builder: (context, state) => const MapScreen(),
        ),
        GoRoute(
          path: '/my-parks',
          builder: (context, state) => const MyParksScreen(),
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
          builder: (context, state) => const ActiveSessionScreen(),
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
          ]
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboard(),
        ),
      ],
    );

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

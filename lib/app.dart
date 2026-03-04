import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/friends/screens/users_screen.dart';
import 'features/friends/screens/requests_screen.dart';
import 'features/groups/screens/create_group_screen.dart';
import 'features/groups/screens/group_chat_screen.dart';
import 'features/groups/screens/group_info_screen.dart';
import 'features/calls/screens/call_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/auth/providers/auth_provider.dart';

/// GoRouter provider — reactive to auth state changes
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _GoRouterRefreshStream(ref),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/users',
        builder: (_, __) => const UsersScreen(),
      ),
      GoRoute(
        path: '/requests',
        builder: (_, __) => const RequestsScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, state) {
          return ChatScreen(
            chatId: state.uri.queryParameters['chatId'] ?? '',
            partnerUid: state.uri.queryParameters['partnerUid'] ?? '',
            partnerName: state.uri.queryParameters['partnerName'] ?? '',
            partnerPhoto: state.uri.queryParameters['partnerPhoto'],
          );
        },
      ),
      GoRoute(
        path: '/create-group',
        builder: (_, __) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/group-chat',
        builder: (_, state) {
          return GroupChatScreen(
            groupId: state.uri.queryParameters['groupId'] ?? '',
            groupName: state.uri.queryParameters['groupName'] ?? '',
            groupPhoto: state.uri.queryParameters['groupPhoto'],
          );
        },
      ),
      GoRoute(
        path: '/group-info',
        builder: (_, state) {
          return GroupInfoScreen(
            groupId: state.uri.queryParameters['groupId'] ?? '',
            groupName: state.uri.queryParameters['groupName'] ?? '',
            groupPhoto: state.uri.queryParameters['groupPhoto'],
          );
        },
      ),
      GoRoute(
        path: '/call',
        builder: (_, state) {
          return CallScreen(
            callerName: state.uri.queryParameters['callerName'] ?? '',
            callerPhoto: state.uri.queryParameters['callerPhoto'],
            isVideo: state.uri.queryParameters['isVideo'] == 'true',
            isIncoming: state.uri.queryParameters['isIncoming'] == 'true',
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoading = authState.isLoading;
      final isOnSplash = state.matchedLocation == '/splash';
      final isOnLogin = state.matchedLocation == '/login';

      // Allow splash while loading
      if (isOnSplash) return null;

      // Still loading auth state, stay where we are
      if (isLoading) return null;

      // Not logged in → go to login
      if (!isLoggedIn && !isOnLogin) return '/login';

      // Logged in but on login → go home
      if (isLoggedIn && isOnLogin) return '/home';

      return null;
    },
  );
});

/// Helper to make GoRouter refresh when auth state changes
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Ref ref) {
    ref.listen(authStateProvider, (previous, next) {
      final prevUid = previous?.valueOrNull?.uid;
      final nextUid = next.valueOrNull?.uid;

      // When user changes (sign out or switch account),
      // invalidate ALL data providers so streams re-subscribe
      // with the new user's credentials
      if (prevUid != nextUid) {
        ref.invalidate(currentUserProvider);
      }

      notifyListeners();
    });
  }
}

/// MaterialApp.router with GoRouter — auth-aware navigation
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Ripple',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}

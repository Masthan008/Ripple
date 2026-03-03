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

/// MaterialApp.router with GoRouter — auth-aware navigation
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Ripple',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router(ref),
    );
  }

  GoRouter _router(WidgetRef ref) {
    return GoRouter(
      initialLocation: '/splash',
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
        final authState = ref.read(authStateProvider);
        final isLoggedIn = authState.valueOrNull != null;
        final isOnSplash = state.matchedLocation == '/splash';
        final isOnLogin = state.matchedLocation == '/login';

        // Allow splash to play its animation
        if (isOnSplash) return null;

        // If not logged in and not on login, redirect to login
        if (!isLoggedIn && !isOnLogin) return '/login';

        // If logged in and on login, redirect to home
        if (isLoggedIn && isOnLogin) return '/home';

        return null;
      },
    );
  }
}


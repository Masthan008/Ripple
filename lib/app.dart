import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/friends/screens/users_screen.dart';
import 'features/friends/screens/requests_screen.dart';
import 'features/groups/screens/create_group_screen.dart';
import 'features/groups/screens/group_chat_screen.dart';
import 'features/groups/screens/group_info_screen.dart';
import 'features/groups/providers/group_provider.dart';
import 'features/calls/screens/call_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/search/screens/global_search_screen.dart';
import 'features/chat/screens/saved_messages_screen.dart';
import 'features/chat/screens/archived_chats_screen.dart';
import 'features/ai/screens/ai_settings_screen.dart';

/// GoRouter provider — created ONCE, uses refreshListenable to re-run redirect
final routerProvider = Provider<GoRouter>((ref) {
  // DO NOT use ref.watch here — it destroys and recreates the GoRouter
  // on every state change, resetting to initialLocation: '/splash'.
  // Instead, use ref.read() inside the redirect closure.
  // The _GoRouterRefreshStream handles triggering redirect re-evaluation.

  return GoRouter(
    navigatorKey: navigatorKey,
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
        path: '/register',
        builder: (_, state) {
          return RegisterScreen(
            uid: state.uri.queryParameters['uid'] ?? '',
            name: state.uri.queryParameters['name'] ?? '',
            email: state.uri.queryParameters['email'] ?? '',
            photoUrl: state.uri.queryParameters['photoUrl'] ?? '',
            isGoogleSignIn:
                state.uri.queryParameters['isGoogleSignIn'] == 'true',
          );
        },
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
      GoRoute(
        path: '/search',
        builder: (_, __) => const GlobalSearchScreen(),
      ),
      GoRoute(
        path: '/saved-messages',
        builder: (_, __) => const SavedMessagesScreen(),
      ),
      GoRoute(
        path: '/archived-chats',
        builder: (_, __) => const ArchivedChatsScreen(),
      ),
      GoRoute(
        path: '/ai-settings',
        builder: (_, __) => const AiSettingsScreen(),
      ),
    ],
    redirect: (context, state) {
      // Read current state on each redirect evaluation (NOT watch)
      final authState = ref.read(authStateProvider);
      final currentUser = ref.read(currentUserProvider);

      final isFirebaseAuthed = authState.valueOrNull != null;
      final isFullyRegistered = currentUser.valueOrNull != null;
      final isAuthLoading = authState.isLoading;
      final isUserLoading = currentUser.isLoading;
      final loc = state.matchedLocation;

      // ── Rule 1: Splash always allowed ─────────────────────
      if (loc == '/splash') return null;

      // ── Rule 2: Still loading — don't redirect yet ────────
      if (isAuthLoading || isUserLoading) return null;

      // ── Rule 3: Not logged in ─────────────────────────────
      if (!isFirebaseAuthed) {
        if (loc == '/login') return null;
        return '/login';
      }

      // ── Rule 4: Logged in but NOT fully registered ────────
      if (!isFullyRegistered) {
        if (loc == '/register') return null;
        if (loc == '/login') return null;
        return '/login';
      }

      // ── Rule 5: Fully registered ──────────────────────────
      if (loc == '/login' || loc == '/register') return '/home';

      // Already on correct screen — no redirect
      return null;
    },
  );
});

/// Helper to make GoRouter refresh when auth state changes.
/// Also invalidates all user-dependent providers on account switch.
class _GoRouterRefreshStream extends ChangeNotifier {
  String? _previousUid;

  _GoRouterRefreshStream(Ref ref) {
    // Watch auth changes — invalidate providers when UID changes
    ref.listen(authStateProvider, (previous, next) {
      final prevUid = previous?.valueOrNull?.uid;
      final nextUid = next.valueOrNull?.uid;

      // When user changes (sign out or switch account),
      // invalidate ALL data providers so Firestore streams re-subscribe
      if (_previousUid != null && _previousUid != nextUid) {
        ref.invalidate(currentUserProvider);
        ref.invalidate(myGroupsProvider);
      }
      _previousUid = nextUid;

      notifyListeners();
    });

    // Watch current user changes (for registration completion detection)
    ref.listen(currentUserProvider, (previous, next) {
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

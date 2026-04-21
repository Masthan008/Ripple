import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/l10n.dart';
import 'core/services/notification_service.dart';
import 'features/profile/providers/accessibility_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/chat/screens/cloud_drive_screen.dart';
import 'features/chat/screens/video_player_screen.dart';
import 'features/chat/screens/chat_media_gallery_screen.dart';
import 'features/groups/screens/join_group_screen.dart';
import 'features/ai/screens/ai_chat_screen.dart';
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
import 'features/calls/screens/daily_call_screen.dart';
import 'features/calls/screens/incoming_call_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/search/screens/global_search_screen.dart';
import 'features/chat/screens/saved_messages_screen.dart';
import 'features/chat/screens/archived_chats_screen.dart';
import 'features/ai/screens/ai_settings_screen.dart';
import 'features/privacy/screens/privacy_settings_screen.dart';
import 'features/privacy/screens/privacy_dashboard_screen.dart';
import 'features/privacy/screens/chat_lock_settings_screen.dart';
import 'features/privacy/screens/fake_passcode_screen.dart';
import 'features/profile/screens/other_user_profile_screen.dart';
import 'features/social/screens/achievements_screen.dart';
import 'features/social/screens/leaderboard_screen.dart';
import 'features/social/screens/friend_suggestions_screen.dart';
import 'features/social/screens/activity_feed_screen.dart';
import 'features/social/screens/profile_visitors_screen.dart';
import 'features/challenges/screens/challenges_screen.dart';
import 'features/gifts/screens/gift_cards_screen.dart';
import 'features/status/screens/status_list_screen.dart';
import 'features/status/screens/create_status_screen.dart';
import 'features/status/screens/status_viewer_screen.dart';
import 'features/profile/providers/settings_provider.dart';

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
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const SplashScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(
                  opacity: CurveTween(
                    curve: Curves.easeInOut,
                  ).animate(animation),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const LoginScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(
                  opacity: CurveTween(
                    curve: Curves.easeInOut,
                  ).animate(animation),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: RegisterScreen(
              uid: state.uri.queryParameters['uid'] ?? '',
              name: state.uri.queryParameters['name'] ?? '',
              email: state.uri.queryParameters['email'] ?? '',
              photoUrl: state.uri.queryParameters['photoUrl'] ?? '',
              isGoogleSignIn:
                  state.uri.queryParameters['isGoogleSignIn'] == 'true',
            ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutQuart)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/home',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const HomeScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(
                  opacity: CurveTween(
                    curve: Curves.easeInOut,
                  ).animate(animation),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/users',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const UsersScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/requests',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const RequestsScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/chat',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: ChatScreen(
              chatId: state.uri.queryParameters['chatId'] ?? '',
              partnerUid: state.uri.queryParameters['partnerUid'] ?? '',
              partnerName: state.uri.queryParameters['partnerName'] ?? '',
              partnerPhoto: state.uri.queryParameters['partnerPhoto'],
            ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutQuart)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/create-group',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const CreateGroupScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/group-chat',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: GroupChatScreen(
              groupId: state.uri.queryParameters['groupId'] ?? '',
              groupName: state.uri.queryParameters['groupName'] ?? '',
              groupPhoto: state.uri.queryParameters['groupPhoto'],
            ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutQuart)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/group-info',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: GroupInfoScreen(
              groupId: state.uri.queryParameters['groupId'] ?? '',
              groupName: state.uri.queryParameters['groupName'] ?? '',
              groupPhoto: state.uri.queryParameters['groupPhoto'],
            ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutQuart)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/call',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: CallScreen(
              callerName: state.uri.queryParameters['callerName'] ?? '',
              callerPhoto: state.uri.queryParameters['callerPhoto'],
              isVideo: state.uri.queryParameters['isVideo'] == 'true',
              isIncoming: state.uri.queryParameters['isIncoming'] == 'true',
            ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return ScaleTransition(
                scale: animation.drive(
                  Tween(
                    begin: 0.0,
                    end: 1.0,
                  ).chain(CurveTween(curve: Curves.easeOutBack)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/profile',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ProfileScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const GlobalSearchScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(
                  opacity: CurveTween(
                    curve: Curves.easeInOut,
                  ).animate(animation),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/saved-messages',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const SavedMessagesScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/archived-chats',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ArchivedChatsScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/ai-settings',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const AiSettingsScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/privacy-settings',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const PrivacySettingsScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/privacy-dashboard',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const PrivacyDashboardScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/chat-lock-settings',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ChatLockSettingsScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/fake-passcode',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const FakePasscodeScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/other-profile',
        pageBuilder: (context, state) {
          final uid = state.uri.queryParameters['uid'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: OtherUserProfileScreen(uid: uid),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutQuart)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/achievements',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const AchievementsScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/leaderboard',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const LeaderboardScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/friend-suggestions',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const FriendSuggestionsScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/activity-feed',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ActivityFeedScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/profile-visitors',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ProfileVisitorsScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/challenges',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ChallengesScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/gift-cards',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const GiftCardsScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/daily-call',
        pageBuilder: (context, state) {
          final callId = state.uri.queryParameters['callId'] ?? '';
          final channelName = state.uri.queryParameters['channelName'] ?? '';
          final currentUserId = state.uri.queryParameters['currentUserId'] ?? '';
          final currentUserName = state.uri.queryParameters['currentUserName'] ?? '';
          final otherUserName = state.uri.queryParameters['otherUserName'] ?? '';
          final otherUserId = state.uri.queryParameters['otherUserId'];
          final isVideo = state.uri.queryParameters['isVideo'] == 'true';
          return CustomTransitionPage(
            key: state.pageKey,
            child: DailyCallScreen(
              callId: callId,
              channelName: channelName,
              currentUserId: currentUserId,
              currentUserName: currentUserName,
              otherUserName: otherUserName,
              otherUserId: otherUserId,
              isVideo: isVideo,
            ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutQuart)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/incoming-call',
        pageBuilder: (context, state) {
          final callId = state.uri.queryParameters['callId'] ?? '';
          final channelName = state.uri.queryParameters['channelName'] ?? '';
          final callerName = state.uri.queryParameters['callerName'] ?? 'Unknown';
          final callerUserId = state.uri.queryParameters['callerUserId'] ?? '';
          final isVideo = state.uri.queryParameters['isVideo'] == 'true';
          return CustomTransitionPage(
            key: state.pageKey,
            child: IncomingCallScreen(
              callId: callId,
              channelName: channelName,
              callerName: callerName,
              callerUserId: callerUserId,
              isVideo: isVideo,
            ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutQuart)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/ai-chat',
        pageBuilder: (context, state) {
          final botId = state.uri.queryParameters['botId'] ?? 'ripple';
          return CustomTransitionPage(
            key: state.pageKey,
            child: AiChatScreen(botId: botId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutQuart)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/chat-media-gallery',
        pageBuilder: (context, state) {
          final chatId = state.uri.queryParameters['chatId'] ?? '';
          final isGroup = state.uri.queryParameters['isGroup'] == 'true';
          return CustomTransitionPage(
            key: state.pageKey,
            child: ChatMediaGalleryScreen(
              chatId: chatId,
              isGroup: isGroup,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutQuart)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/video-player',
        pageBuilder: (context, state) {
          final videoUrl = state.uri.queryParameters['url'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: VideoPlayerScreen(
              videoUrl: videoUrl,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutQuart)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/cloud-drive',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const CloudDriveScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutQuart)),
              ),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/join-group',
        pageBuilder: (context, state) {
          final inviteCode = state.uri.queryParameters['inviteCode'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: JoinGroupScreen(
              inviteCode: inviteCode,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutQuart)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/status-list',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const StatusListScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/create-status',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const CreateStatusSheet(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart)),
                  ),
                  child: child,
                );
              },
            ),
      ),
      // Note: StatusViewerScreen requires a list of statuses and viewerName
      // Use MaterialPageRoute navigation from chat list instead
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

      // ── Rule 1: Root redirects to home ────────────────────
      if (loc == '/') return '/home';

      // ── Rule 2: Splash always allowed ─────────────────────
      if (loc == '/splash') return null;

      // ── Rule 3: Still loading — don't redirect yet ────────
      if (isAuthLoading || isUserLoading) return null;

      // ── Rule 4: Not logged in ─────────────────────────────
      if (!isFirebaseAuthed) {
        if (loc == '/login') return null;
        return '/login';
      }

      // ── Rule 5: Logged in but NOT fully registered ────────
      if (!isFullyRegistered) {
        if (loc == '/register') return null;
        if (loc == '/login') return null;
        return '/login';
      }

      // ── Rule 6: Fully registered ──────────────────────────
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
    final currentLang = ref.watch(languageProvider);
    final currentTheme = ref.watch(rippleThemeProvider);
    final accessibility = ref.watch(accessibilityProvider);

    return MaterialApp.router(
      title: 'Ripple',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromRippleTheme(currentTheme),
      routerConfig: router,
      locale: L10n.supportedLocales[currentLang] ?? const Locale('en'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.supportedLocales.values.toList(),
      builder: (context, child) {
        // Apply accessibility settings globally
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(accessibility.effectiveTextScale),
            boldText: accessibility.highContrast,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

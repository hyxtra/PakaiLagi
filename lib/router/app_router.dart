import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/activity_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/home_screen.dart';
import '../screens/item_detail_screen.dart';
import '../screens/manage_request_screen.dart';
import '../screens/post_item_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/sign_in_screen.dart';
import '../widgets/scaffold_with_nav_bar.dart';

/// Nama path terpusat agar pemanggilan konsisten & bebas typo.
abstract class AppRoutes {
  static const signIn = '/signin';
  static const home = '/home';
  static const post = '/post';
  static const activity = '/activity';
  static const profile = '/profile';

  static String itemDetail(String id) => '/item/$id';
  static String manageRequest(String id) => '/manage-request/$id';
  static String chat(String itemId, String peerName) =>
      '/chat/$itemId?peer=${Uri.encodeComponent(peerName)}';
}

final _rootKey = GlobalKey<NavigatorState>();

/// Router dibuat lewat provider agar bisa merespons perubahan state auth
/// (redirect) melalui [refreshListenable].
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    // Redirect: menjaga URL/route asli. Refresh (web) mempertahankan lokasi
    // terakhir SELAMA user masih login; kalau belum login → paksa ke /signin.
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider) != null;
      final atSignIn = state.matchedLocation == AppRoutes.signIn;
      if (!loggedIn) return atSignIn ? null : AppRoutes.signIn;
      if (atSignIn) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, __) => const SignInScreen(),
      ),

      // 4 tab utama dengan bottom navigation yang persisten.
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ScaffoldWithNavBar(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: AppRoutes.post,
                builder: (_, __) => const PostItemScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: AppRoutes.activity,
                builder: (_, __) => const ActivityScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: AppRoutes.profile,
                builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),

      // Route full-screen di luar shell (tanpa bottom nav).
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/item/:itemId',
        builder: (_, state) =>
            ItemDetailScreen(itemId: state.pathParameters['itemId']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/manage-request/:itemId',
        builder: (_, state) =>
            ManageRequestScreen(itemId: state.pathParameters['itemId']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/chat/:itemId',
        builder: (_, state) => ChatScreen(
          itemId: state.pathParameters['itemId']!,
          peerName: state.uri.queryParameters['peer'] ?? 'Pengguna',
        ),
      ),
    ],
  );
});

/// Menjembatani perubahan [authProvider] ke [GoRouter.refreshListenable].
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen(authProvider, (_, __) => notifyListeners());
  }
  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

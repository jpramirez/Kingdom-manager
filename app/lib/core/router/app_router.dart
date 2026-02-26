import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/calendar/screens/calendar_screen.dart';
import '../../features/chores/screens/chore_detail_screen.dart';
import '../../features/chores/screens/chores_screen.dart';
import '../../features/chores/screens/create_chore_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/grocery/screens/grocery_detail_screen.dart';
import '../../features/grocery/screens/grocery_screen.dart';
import '../../features/calendar/screens/create_event_screen.dart';
import '../../features/meals/screens/meals_screen.dart';
import '../../features/meals/screens/create_recipe_screen.dart';
import '../../features/meals/screens/recipe_detail_screen.dart';
import '../../features/approvals/screens/approvals_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/ai/screens/ai_chat_screen.dart';
import '../../features/ai/screens/ai_onboarding_screen.dart';
import '../../features/household/providers/household_provider.dart';
import '../../features/household/screens/create_household_screen.dart';
import '../../features/household/screens/household_setup_screen.dart';
import '../../features/household/screens/join_household_screen.dart';
import '../../features/household/screens/members_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../l10n/generated/app_localizations.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final householdState = ref.watch(activeHouseholdProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // While auth is loading, stay put (show splash / current screen)
      if (authState.isLoading) return null;

      final user = authState.valueOrNull;
      final isAuthRoute = state.uri.path == '/login' || state.uri.path == '/register';
      final isHouseholdSetup = state.uri.path == '/household-setup' ||
          state.uri.path == '/create-household' ||
          state.uri.path == '/join-household';

      // Not logged in -> go to login
      if (user == null && !isAuthRoute) return '/login';

      // Logged in user on auth route
      if (user != null && isAuthRoute) {
        // Household still loading -> stay on auth route, don't flash setup
        if (householdState.isLoading) return null;
        return householdState.household == null ? '/household-setup' : '/';
      }

      // Logged in, household still loading -> stay put
      if (user != null && householdState.isLoading) return null;

      // Logged in, no household, not on setup -> go to setup
      if (user != null && householdState.household == null && !isHouseholdSetup) {
        return '/household-setup';
      }

      // Logged in, has household, but on setup -> go home
      if (user != null && householdState.household != null && isHouseholdSetup) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth routes (no shell)
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // Household setup (no shell)
      GoRoute(path: '/household-setup', builder: (_, __) => const HouseholdSetupScreen()),
      GoRoute(path: '/create-household', builder: (_, __) => const CreateHouseholdScreen()),
      GoRoute(path: '/join-household', builder: (_, __) => const JoinHouseholdScreen()),

      // Members (full screen)
      GoRoute(path: '/members', builder: (_, __) => const MembersScreen()),

      // Chore routes (full screen, outside shell)
      GoRoute(
        path: '/chores/create',
        builder: (_, __) => const CreateChoreScreen(),
      ),
      GoRoute(
        path: '/chores/:id',
        builder: (_, state) => ChoreDetailScreen(
          choreId: state.pathParameters['id']!,
        ),
      ),

      // Calendar routes (full screen)
      GoRoute(
        path: '/calendar/create',
        builder: (_, __) => const CreateEventScreen(),
      ),

      // Grocery routes (full screen)
      GoRoute(
        path: '/grocery/:id',
        builder: (_, state) => GroceryDetailScreen(
          listId: state.pathParameters['id']!,
        ),
      ),

      // Meals routes (full screen)
      GoRoute(
        path: '/meals/create',
        builder: (_, __) => const CreateRecipeScreen(),
      ),
      GoRoute(
        path: '/meals/recipes/:id',
        builder: (_, state) => RecipeDetailScreen(
          recipeId: state.pathParameters['id']!,
        ),
      ),

      // Approvals route (full screen)
      GoRoute(
        path: '/approvals',
        builder: (_, __) => const ApprovalsScreen(),
      ),

      // Notifications route (full screen)
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),

      // AI Chat routes (full screen)
      GoRoute(
        path: '/ai-chat',
        builder: (_, __) => const AiChatScreen(),
      ),
      GoRoute(
        path: '/ai-chat/:id',
        builder: (_, state) => AiChatScreen(
          conversationId: state.pathParameters['id']!,
        ),
      ),

      // AI Onboarding route (full screen)
      GoRoute(
        path: '/ai-onboarding',
        builder: (_, __) => const AiOnboardingScreen(),
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/chores', builder: (_, __) => const ChoresScreen()),
          GoRoute(path: '/meals', builder: (_, __) => const MealsScreen()),
          GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
          GoRoute(path: '/grocery', builder: (_, __) => const GroceryScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.dashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.checklist_outlined),
            selectedIcon: const Icon(Icons.checklist),
            label: l10n.chores,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: l10n.calendar,
          ),
          NavigationDestination(
            icon: const Icon(Icons.shopping_cart_outlined),
            selectedIcon: const Icon(Icons.shopping_cart),
            label: l10n.grocery,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    try {
      final location = GoRouterState.of(context).uri.path;
      if (location.startsWith('/chores')) return 1;
      if (location.startsWith('/calendar')) return 2;
      if (location.startsWith('/grocery')) return 3;
      if (location.startsWith('/settings')) return 4;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/chores');
      case 2:
        context.go('/calendar');
      case 3:
        context.go('/grocery');
      case 4:
        context.go('/settings');
    }
  }
}

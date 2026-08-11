import 'package:go_router/go_router.dart';

import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';
import '../features/companion/companion_gallery_screen.dart';

abstract final class SelahRoutes {
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const settings = '/settings';
  static const companionGallery = '/companion-gallery';
}

final appRouter = GoRouter(
  initialLocation: SelahRoutes.onboarding,
  routes: [
    GoRoute(
      path: SelahRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: SelahRoutes.today,
      builder: (context, state) => const TodayScreen(),
    ),
    GoRoute(
      path: SelahRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: SelahRoutes.companionGallery,
      builder: (context, state) => const CompanionGalleryScreen(),
    ),
  ],
);

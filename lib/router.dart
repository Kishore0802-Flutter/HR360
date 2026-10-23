import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'design.dart';
import 'directory.dart';
import 'shell.dart';
import 'welcome.dart';

class AppGate extends ChangeNotifier {
  final Api api;
  bool splash = true;
  bool loading = true;
  bool stories = false;
  Object? error;

  AppGate(this.api) {
    api.addListener(notifyListeners);
  }

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      stories = !(preferences.getBool('onboarded') ?? false);
      await api.restore();
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void finishSplash() {
    splash = false;
    notifyListeners();
  }

  Future<void> finishStories() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('onboarded', true);
    stories = false;
    notifyListeners();
  }

  @override
  void dispose() {
    api.removeListener(notifyListeners);
    super.dispose();
  }
}

GoRouter buildRouter(AppGate gate) {
  final api = gate.api;
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: gate,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (gate.splash) return location == '/splash' ? null : '/splash';
      if (gate.loading) return location == '/loading' ? null : '/loading';
      if (gate.error != null) return location == '/error' ? null : '/error';
      if (gate.stories) return location == '/stories' ? null : '/stories';
      final signedIn = api.token != null;
      final public = location == '/login' || location == '/recovery';
      if (!signedIn) return public ? null : '/login';
      if (public ||
          location == '/splash' ||
          location == '/loading' ||
          location == '/stories' ||
          location == '/error') {
        return '/app';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => SplashPage(onContinue: gate.finishSplash),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const Scaffold(body: DashboardShimmer()),
      ),
      GoRoute(
        path: '/error',
        builder: (context, state) => Scaffold(
          body: FailureView(
            gate.error ?? 'Something went wrong.',
            gate.initialize,
          ),
        ),
      ),
      GoRoute(
        path: '/stories',
        builder: (context, state) => StoryPage(onFinish: gate.finishStories),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(api: api),
      ),
      GoRoute(
        path: '/recovery',
        builder: (context, state) => RecoveryPage(api: api),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) => Shell(api: api),
      ),
      GoRoute(
        path: '/team/employees',
        builder: (context, state) => EmployeesPage(api: api),
      ),
      GoRoute(
        path: '/team/attendance',
        builder: (context, state) => TeamAttendancePage(api: api),
      ),
      GoRoute(
        path: '/holidays',
        builder: (context, state) => HolidaysPage(api: api),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens a go_router location when the app router is mounted, and a normal
/// page route in widget tests that build a screen on their own.
Future<void> openRoute(
  BuildContext context,
  String location,
  Widget Function() page,
) async {
  if (GoRouter.maybeOf(context) != null) {
    await context.push(location);
    return;
  }
  await Navigator.push(context, MaterialPageRoute(builder: (_) => page()));
}

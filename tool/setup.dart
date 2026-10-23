// Run from mobile/: dart run tool/setup.dart
// Regenerates platform scaffolding without replacing application code.
import 'dart:io';

Future<void> main() async {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run this command from the mobile directory.');
    exit(1);
  }
  final result = await Process.run('flutter', [
    'create',
    '--platforms=android,ios,web',
    '--project-name',
    'hr360_mobile',
    '--org',
    'com.hr360',
    '.',
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) exit(result.exitCode);
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  var xml = manifest.readAsStringSync();
  for (final permission in [
    'INTERNET',
    'ACCESS_FINE_LOCATION',
    'ACCESS_COARSE_LOCATION',
  ]) {
    if (!xml.contains('android.permission.$permission')) {
      xml = xml.replaceFirst(
        '<application',
        '<uses-permission android:name="android.permission.$permission"/>\n    <application',
      );
    }
  }
  xml = xml.replaceAll(
    'android:label="hr360_mobile"',
    'android:label="HR#360"',
  );
  if (!xml.contains('android:allowBackup=')) {
    xml = xml.replaceFirst(
      '<application',
      '<application android:allowBackup="false"',
    );
  }
  manifest.writeAsStringSync(xml);
  final debug = File('android/app/src/debug/AndroidManifest.xml');
  debug.parent.createSync(recursive: true);
  debug.writeAsStringSync(
    '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:usesCleartextTraffic="true"/><uses-permission android:name="android.permission.INTERNET"/></manifest>',
  );
  final plist = File('ios/Runner/Info.plist');
  var info = plist.readAsStringSync();
  if (!info.contains('NSLocationWhenInUseUsageDescription')) {
    info = info.replaceFirst(
      '</dict>',
      '<key>NSLocationWhenInUseUsageDescription</key><string>Your location verifies that you are at your assigned office when recording attendance.</string>\n<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>\n</dict>',
    );
  }
  info = info.replaceAll(
    '<string>Hr360 Mobile</string>',
    '<string>HR#360</string>',
  );
  plist.writeAsStringSync(info);
  final sample = File('test/widget_test.dart');
  if (sample.existsSync() && sample.readAsStringSync().contains('MyApp')) {
    sample.deleteSync();
  }
  stdout.writeln(
    'Platform setup complete. Configure signing and run flutter pub get.',
  );
}

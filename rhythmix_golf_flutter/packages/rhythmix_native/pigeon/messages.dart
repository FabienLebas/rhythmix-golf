import 'package:pigeon/pigeon.dart';

// This file is where you define the interface between Dart code and host
// platform code. After editing this file, run
//   dart run pigeon --input pigeon/messages.dart
// to re-generate all of the output files.
//
// If you add new platforms to your plugin, add the corresponding output
// options in the PigeonOptions below.
//
// To learn more about Pigeon, see https://pub.dev/packages/pigeon.

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'rhythmix_native',
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/rhythmix/rhythmix_native/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.rhythmix.rhythmix_native'),
    swiftOut: [
      'ios/rhythmix_native/Sources/rhythmix_native/Messages.g.swift',
    ],
  ),
)
@HostApi()
abstract class RhythmixNativePluginApi {
  /// Returns the system version of the host platform.
  String getPlatformVersion();
}

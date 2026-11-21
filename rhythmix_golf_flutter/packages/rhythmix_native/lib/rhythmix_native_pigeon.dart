import 'package:flutter/foundation.dart';

import 'rhythmix_native_platform_interface.dart';
import 'src/messages.g.dart';

/// An implementation of [RhythmixNativePlatform] that uses Pigeon, for
/// non-web platforms.
class PigeonRhythmixNative extends RhythmixNativePlatform {
  /// Creates a new plugin implementation instance.
  PigeonRhythmixNative({@visibleForTesting RhythmixNativePluginApi? api})
    : _hostApi = api ?? RhythmixNativePluginApi();

  final RhythmixNativePluginApi _hostApi;

  @override
  Future<String?> getPlatformVersion() async {
    return _hostApi.getPlatformVersion();
  }
}

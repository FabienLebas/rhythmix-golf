import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'rhythmix_native_pigeon.dart';

abstract class RhythmixNativePlatform extends PlatformInterface {
  /// Constructs a RhythmixNativePlatform.
  RhythmixNativePlatform() : super(token: _token);

  static final Object _token = Object();

  static RhythmixNativePlatform _instance = PigeonRhythmixNative();

  /// The instance of [RhythmixNativePlatform] to use.
  ///
  /// Defaults to [PigeonRhythmixNative].
  static RhythmixNativePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RhythmixNativePlatform] when
  /// they register themselves.
  static set instance(RhythmixNativePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}

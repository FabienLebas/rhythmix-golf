
import 'rhythmix_native_platform_interface.dart';

class RhythmixNative {
  Future<String?> getPlatformVersion() {
    return RhythmixNativePlatform.instance.getPlatformVersion();
  }
}

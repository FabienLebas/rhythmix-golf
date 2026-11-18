// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Rhythmix Golf';

  @override
  String get modeGrand => '🏌️ Full swing';

  @override
  String get modeGrandSub => '3 : 1 tempo';

  @override
  String get modePutt => '⛳ Putting';

  @override
  String get modePuttSub => '2 : 1 tempo';

  @override
  String get markerStart => 'Start';

  @override
  String get markerTop => 'Top';

  @override
  String get markerImpact => 'Impact';

  @override
  String metroTitle(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand': 'Metronome · full swing 3:1',
        'other': 'Metronome · putting 2:1',
      },
    );
    return '$_temp0';
  }

  @override
  String get fieldUp => 'Backswing (seconds)';

  @override
  String get fieldDown => 'Downswing (seconds)';

  @override
  String get keepRatio => 'Keep the ratio when I change a number';

  @override
  String swingSpeed(int percent) {
    return 'Swing speed: $percent%';
  }

  @override
  String get resetDefaults => 'Default values';

  @override
  String metroSummary(String up, String down, String ratio, String total) {
    return 'Backswing $up s · Downswing $down s · Ratio $ratio:1 · Swing $total s';
  }

  @override
  String pauseBetween(String seconds) {
    return 'Pause between swings: $seconds s';
  }

  @override
  String get metroStart => '▶ Start';

  @override
  String get metroStop => '■ Stop';

  @override
  String get metroHelp =>
      'Three sounds per swing: start (low), top of the backswing (medium), impact (high). The sound keeps playing with the screen locked and in silent mode.';

  @override
  String analyzeTitle(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand': 'Analyze a full swing',
        'other': 'Analyze a putt',
      },
    );
    return '$_temp0';
  }

  @override
  String get filmTip =>
      '📱 Film yourself face-on (facing the camera), with the phone held still and your whole body in the frame, and with sound on: the sound of the ball is used to find the impact. For more precision, record at 60 fps with the camera app, then pick the video.';

  @override
  String get btnFilm => 'Record';

  @override
  String get btnPick => 'Choose a video';

  @override
  String get videoIntro =>
      'Record or choose a video: the app reads the frame rate, analyzes every frame and places the three markers by itself.';

  @override
  String get videoCheck =>
      'Check each marker: drag the frame strip to find the right frame.';

  @override
  String get stripHelp =>
      'Drag the frame strip like in a video editor. Tap Start, Top or Impact to select it: as you drag, the marker follows the frame shown under the white line. Tap the same button again to deselect it.';

  @override
  String frameLabel(int index, int last, String time) {
    return 'Frame $index / $last · $time s';
  }

  @override
  String videoInfo(int width, int height, String fps, String seconds) {
    return 'Video: $width × $height · $fps frames/s · $seconds s';
  }

  @override
  String get statusLoading => 'Loading…';

  @override
  String statusAnalyzing(int percent, int done, int total, int seconds) {
    return 'Analyzing… $percent% (frame $done / $total, $seconds s)';
  }

  @override
  String hintFps(String fps) {
    return 'Frame rate read from the file: $fps frames/s.';
  }

  @override
  String get hintPutt =>
      'Detection complete (putt: markers found from the motion, without sound).';

  @override
  String hintGrandBall(String time) {
    return 'Detection complete (impact found from the sound of the ball, at $time s).';
  }

  @override
  String hintGrandBallHip(String time) {
    return 'Detection complete (impact found from the sound of the ball, at $time s), top found when the hips start to move.';
  }

  @override
  String get hintGrandMotion =>
      'Detection complete (sound unusable: impact estimated from the motion, less accurate).';

  @override
  String get hintGrandMotionHip =>
      'Detection complete (sound unusable: impact estimated from the motion, less accurate), top found when the hips start to move.';

  @override
  String errOpenCamera(String detail) {
    return 'Couldn’t open the camera ($detail).';
  }

  @override
  String errOpenGallery(String detail) {
    return 'Couldn’t open the gallery ($detail).';
  }

  @override
  String errAnalyze(String detail) {
    return 'Couldn’t analyze this video ($detail).';
  }

  @override
  String get failUnreadable => 'unreadable video';

  @override
  String get failTooShort => 'video too short';

  @override
  String get failNoMotion => 'no motion detected';

  @override
  String get resultOrder => 'The order must be: start, top, impact.';

  @override
  String resultRhythm(String up, String down, String ratio, String total) {
    return 'Your tempo: backswing $up s, downswing $down s, ratio $ratio:1 (swing $total s).';
  }

  @override
  String resultMetroSet(String mode, int ratio, String up, String down) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand':
            'The metronome is set to your target full-swing tempo $ratio:1: backswing $up s, downswing $down s.',
        'other':
            'The metronome is set to your target putting tempo $ratio:1: backswing $up s, downswing $down s.',
      },
    );
    return '$_temp0';
  }

  @override
  String adviceClose(int ratio) {
    return 'Your tempo is already close to $ratio:1, keep it up.';
  }

  @override
  String adviceGrandSlow(String delta, String from, String to) {
    return 'Your backswing is too slow: speed it up by about $delta s (from $from s to $to s) and keep the same downswing.';
  }

  @override
  String adviceGrandFast(String delta, String from, String to) {
    return 'Your backswing is too fast: slow it down by about $delta s (from $from s to $to s) and keep the same downswing.';
  }

  @override
  String advicePuttSlow(String from, String to) {
    return 'Your backswing is too long compared with your downswing. Take the putter back a bit more briskly (about $to s instead of $from s), or let it come down more gently, without pushing it toward the ball.';
  }

  @override
  String advicePuttFast(String from, String to) {
    return 'You take the putter back too fast compared with your downswing. Take your time on the way back (about $to s instead of $from s), or accelerate a bit more decisively through the ball.';
  }

  @override
  String historyTitle(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand': 'History · full swing',
        'other': 'History · putting',
      },
    );
    return '$_temp0';
  }

  @override
  String get historyEmpty =>
      'No analysis yet. Each analyzed video adds a point (backswing : downswing ratio) to this chart.';

  @override
  String get historyClear => 'Clear this history';

  @override
  String historyClearTitle(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand': 'Clear the full swing history?',
        'other': 'Clear the putting history?',
      },
    );
    return '$_temp0';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get erase => 'Clear';

  @override
  String get tempoOk => 'On target';

  @override
  String get tempoSlow => 'Too slow';

  @override
  String get tempoFast => 'Too fast';

  @override
  String chartTarget(int target) {
    return 'target $target:1';
  }

  @override
  String priceClause(String price) {
    return ': $price';
  }

  @override
  String priceLaunch(String price, String regular) {
    return '$price launch price, then $regular';
  }

  @override
  String freeIntro(int count, String priceClause) {
    return '🎁 The first $count video analyses are free. After that, a single payment, for the price of a bucket of range balls$priceClause, and you’ll have the app to analyze as many swings as you want and track your progress over time.';
  }

  @override
  String freeLeft(int left, int count, String priceClause) {
    return '🎁 Free analyses: $left of $count left. After that, a single payment, for the price of a bucket of range balls$priceClause, and you’ll have the app to analyze as many swings as you want and track your progress over time.';
  }

  @override
  String freeUsed(int count, String priceClause) {
    return '🔒 Your $count free analyses have been used. To keep analyzing your swings, get unlimited analyses for life for the price of a bucket of range balls!$priceClause';
  }

  @override
  String priceEndLaunch(String price, String regular) {
    return ' $price launch price instead of $regular.';
  }

  @override
  String priceEnd(String price) {
    return ' $price.';
  }

  @override
  String get unlock => 'Unlock';

  @override
  String get payTitle => 'For the price of a bucket of range balls';

  @override
  String payLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You have $count free analyses left.',
      one: 'You have 1 free analysis left.',
    );
    return '$_temp0';
  }

  @override
  String payUsed(int count) {
    return 'Your $count free analyses have been used.';
  }

  @override
  String get payBody =>
      'Unlock unlimited video analyses with a single payment: no subscription, no surprises.';

  @override
  String get payLaunchLabel => 'Launch price';

  @override
  String payBuy(String price) {
    return 'Unlock for $price';
  }

  @override
  String get payRestore => 'Restore purchases';

  @override
  String get payLater => 'Later';

  @override
  String get payClose => 'Close';

  @override
  String get payThanks => 'Thank you, it’s unlocked!';

  @override
  String get payThanksSub => 'Unlimited video analyses, forever.';

  @override
  String get payContinue => 'Continue';

  @override
  String get msgBuyUnavailable =>
      'Purchase unavailable right now. Check your connection and try again.';

  @override
  String get msgBuyFailed => 'Purchase failed.';

  @override
  String msgBuyFailedDetail(String detail) {
    return 'Purchase failed ($detail).';
  }

  @override
  String msgRestoreFailed(String detail) {
    return 'Couldn’t restore purchases ($detail).';
  }

  @override
  String get msgNothingToRestore => 'No purchase to restore on this account.';

  @override
  String get msgStoreUnavailable => 'Store unavailable right now.';
}

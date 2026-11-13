import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app_state.dart';
import 'history_card.dart';
import 'metronome_card.dart';
import 'video_card.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // L'écran de démarrage (logo complet) reste affiché au moins 1,5 s.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  final shown = Stopwatch()..start();
  final state = AppState();
  await state.load();
  runApp(RhythmixApp(state: state));
  final left = const Duration(milliseconds: 1500) - shown.elapsed;
  if (left > Duration.zero) await Future<void>.delayed(left);
  FlutterNativeSplash.remove();
}

class RhythmixApp extends StatelessWidget {
  const RhythmixApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final seed = state.mode == 'grand' ? const Color(0xFF2F7D4F) : const Color(0xFF2F6FB0);
        return MaterialApp(
          title: 'Rhythmix Golf',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.light, useMaterial3: true),
          darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
          home: HomePage(state: state),
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final modes = _ModeSelector(state: state);
    final metro = MetronomeCard(state: state);
    final video = VideoCard(state: state);
    final hist = HistoryCard(state: state);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth >= 900) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 560, child: modes),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 400, child: metro),
                        const SizedBox(width: 24),
                        Expanded(child: video),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(width: 560, child: hist),
                  ],
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [modes, const SizedBox(height: 12), metro, const SizedBox(height: 12), video, const SizedBox(height: 12), hist],
            );
          },
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.state});
  final AppState state;

  Widget _btn(BuildContext context, String m, String title, String sub) {
    final on = state.mode == m;
    final t = Theme.of(context);
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        Text(sub, style: const TextStyle(fontSize: 12)),
      ],
    );
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 14, horizontal: 8)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
    return Expanded(
      child: on
          ? FilledButton(style: style, onPressed: () {}, child: child)
          : OutlinedButton(
              style: style.copyWith(foregroundColor: WidgetStatePropertyAll(t.colorScheme.onSurface)),
              onPressed: () => state.setMode(m),
              child: child,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _btn(context, 'grand', '🏌️ Grand jeu', 'tempo 3 : 1'),
        const SizedBox(width: 8),
        _btn(context, 'putt', '⛳ Putting', 'tempo 2 : 1'),
      ],
    );
  }
}

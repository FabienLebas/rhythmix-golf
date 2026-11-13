// Outils communs aux tests : faux métronome, faux store, fausse galerie,
// faux décodeur vidéo natif, chargement des cas de référence.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:rhythmix_golf/app_state.dart';
import 'package:rhythmix_golf/main.dart';
import 'package:rhythmix_golf/metronome.dart';
import 'package:rhythmix_golf/purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- Métronome

/// Métronome sans son : enregistre les démarrages pour vérifier les réglages.
class FakeMetronome extends Metronome {
  final List<(double, double, double)> starts = [];
  int stops = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> start(double b, double d, double pause) async {
    running = true;
    starts.add((b, d, pause));
  }

  @override
  Future<void> stop() async {
    running = false;
    stops++;
  }

  @override
  String? label() => running ? 'Départ' : null;
}

// ---------------------------------------------------------------- Store

ProductDetails fakeProduct({String price = '2,99 €'}) => ProductDetails(
      id: kProductId,
      title: 'Rhythmix Golf',
      description: 'Analyses illimitées',
      price: price,
      rawPrice: 2.99,
      currencyCode: 'EUR',
    );

PurchaseDetails fakePurchase(PurchaseStatus status, {String productId = kProductId, bool pending = true}) {
  final d = PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: '', source: 'test'),
    transactionDate: '0',
    status: status,
  );
  d.pendingCompletePurchase = pending;
  if (status == PurchaseStatus.error) d.error = IAPError(source: 'test', code: 'e', message: 'carte refusée');
  return d;
}

/// Faux App Store / Google Play.
class FakeStore extends InAppPurchasePlatform {
  FakeStore({this.available = true, this.products, this.buyStarts = true, this.restoreWith});

  bool available;
  List<ProductDetails>? products;
  bool buyStarts;

  /// Achat renvoyé par « Restaurer mes achats » (null : rien à restaurer).
  PurchaseStatus? restoreWith;

  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  final List<String> bought = [];
  final List<PurchaseDetails> completed = [];
  int restores = 0;

  void emit(List<PurchaseDetails> l) => controller.add(l);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async => ProductDetailsResponse(
        productDetails: products ?? [fakeProduct()],
        notFoundIDs: const [],
      );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought.add(purchaseParam.productDetails.id);
    return buyStarts;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async => completed.add(purchase);

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restores++;
    final r = restoreWith;
    if (r != null) scheduleMicrotask(() => emit([fakePurchase(r)]));
  }
}

FakeStore installFakeStore({bool available = true, List<ProductDetails>? products, PurchaseStatus? restoreWith}) {
  final s = FakeStore(available: available, products: products, restoreWith: restoreWith);
  InAppPurchasePlatform.instance = s;
  return s;
}

// ---------------------------------------------------------------- Galerie / caméra

class FakeImagePicker extends ImagePickerPlatform {
  FakeImagePicker({this.path = '/fake/swing.mp4'});
  String? path;
  final List<ImageSource> calls = [];

  @override
  Future<XFile?> getVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    calls.add(source);
    return path == null ? null : XFile(path!);
  }
}

// ---------------------------------------------------------------- Décodeur natif

/// Vidéo synthétique servie par un faux plugin natif : une barre (le club)
/// qui part à l'image [start], monte jusqu'à [top], redescend jusqu'à [impact],
/// avec un « clac » sonore à l'impact.
class FakeVideo {
  FakeVideo({
    this.width = 120,
    this.height = 216,
    this.fps = 60,
    this.frames = 120,
    this.start = 30,
    this.top = 70,
    this.impact = 85,
    this.withSound = true,
  });

  final int width, height, frames, start, top, impact;
  final double fps;
  final bool withSound;
  final List<String> calls = [];

  double barX(int i) {
    final x0 = width * 0.3, x1 = width * 0.75;
    if (i <= start) return x0;
    if (i <= top) {
      final u = (i - start) / (top - start);
      return x0 + (x1 - x0) * (u * u * (3 - 2 * u));
    }
    if (i <= impact) {
      final u = (i - top) / (impact - top);
      return x1 - (x1 - x0) * u * u;
    }
    final u = math.min(1.0, (i - impact) / 15);
    return x0 - (width * 0.2) * (2 * u - u * u);
  }

  Uint8List gray(int i, int aw, int ah) {
    final g = Uint8List(aw * ah)..fillRange(0, aw * ah, 100);
    final cx = barX(i) * aw / width;
    for (var y = (ah * 0.2).round(); y < (ah * 0.9).round(); y++) {
      for (var x = 0; x < aw; x++) {
        final cov = (3.5 - (x + 0.5 - cx).abs()).clamp(0.0, 1.0);
        g[y * aw + x] = (100 + 130 * cov).round();
      }
    }
    return g;
  }

  List<double> envelope() {
    final n = (frames / fps * 100).floor();
    final r = math.Random(7);
    final env = List<double>.generate(n, (_) => 0.004 + 0.004 * r.nextDouble());
    if (withSound) env[(impact / fps * 100).round()] = 0.6;
    return env;
  }

  /// Branche le faux plugin sur le canal « rhythmix_native ».
  void install(WidgetTester t) {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('rhythmix_native'), (c) async {
      calls.add(c.method);
      final a = (c.arguments as Map).cast<String, dynamic>();
      switch (c.method) {
        case 'info':
          return {
            'width': width,
            'height': height,
            'fps': fps,
            'durationMs': frames / fps * 1000,
            'frameCount': frames,
          };
        case 'frames':
          final s = a['start'] as int, count = a['count'] as int;
          final aw = a['aw'] as int, ah = a['ah'] as int, tw = a['tw'] as int, th = a['th'] as int;
          final gray = BytesBuilder(copy: false);
          for (var k = 0; k < count; k++) {
            gray.add(this.gray(s + k, aw, ah));
          }
          return {'gray': gray.takeBytes(), 'rgba': Uint8List(count * tw * th * 4)..fillRange(0, count * tw * th * 4, 255)};
        case 'preview':
          return null;
        case 'audioEnvelope':
          return {'env': envelope()};
      }
      return null;
    });
  }
}

// ---------------------------------------------------------------- Application

/// Affiche l'application complète, sur une surface assez haute pour que tout
/// soit visible sans défilement (ou en mode large, >= 900 px).
/// La police des tests (un carré par caractère) est ~30 % plus large qu'une
/// vraie police : 560 px de test ≈ un téléphone de 420 px.
Future<AppState> pumpApp(
  WidgetTester t, {
  Map<String, Object> prefs = const {},
  FakeMetronome? metronome,
  bool wide = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  t.view.physicalSize = wide ? const Size(1400, 2400) : const Size(560, 3600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final s = AppState(metronome: metronome ?? FakeMetronome());
  await t.runAsync(() async {
    await s.load();
    // le store répond en tâche de fond (disponibilité, prix)
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await t.pumpWidget(RhythmixApp(state: s));
  await t.pump();
  return s;
}

/// Livre les évènements du faux store (son flux vit hors du temps simulé).
Future<void> deliver(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await t.pumpAndSettle();
}

/// Laisse tourner le vrai temps (décodage d'images, E/S) jusqu'à [done].
Future<void> pumpUntil(WidgetTester t, bool Function() done, {int maxSteps = 400}) async {
  for (var i = 0; i < maxSteps && !done(); i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await t.pump();
  }
  expect(done(), isTrue, reason: 'condition non atteinte à temps');
}

// ---------------------------------------------------------------- Cas de référence

/// Cas générés à partir du code du site (tests/fixtures/detection-cases.json).
List<Map<String, dynamic>> loadDetectionCases() {
  final f = File('../tests/fixtures/detection-cases.json');
  final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  return (j['cases'] as List).cast<Map<String, dynamic>>();
}

List<double> doubles(Object? l) => (l as List).map((e) => (e as num).toDouble()).toList();

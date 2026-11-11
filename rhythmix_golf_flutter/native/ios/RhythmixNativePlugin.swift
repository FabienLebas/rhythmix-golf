import AVFoundation
import Flutter
import UIKit

/// Décodage vidéo natif pour Rhythmix Golf (iOS, AVFoundation).
/// - info : dimensions affichées, cadence, durée, nombre d'images
/// - frames : images exactes en niveaux de gris + miniatures RGBA
/// - preview : une image en JPEG pour l'aperçu
/// - audioEnvelope : amplitude max par fenêtre de 10 ms (bruit d'impact)
public class RhythmixNativePlugin: NSObject, FlutterPlugin {
  private let work = DispatchQueue(label: "rhythmix.native.work", qos: .userInitiated)
  private let previewQueue = DispatchQueue(label: "rhythmix.native.preview", qos: .userInitiated)
  private var pvPath: String?
  private var pvGen: AVAssetImageGenerator?
  private var pvMax = 0

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "rhythmix_native", binaryMessenger: registrar.messenger())
    let instance = RhythmixNativePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    WatchBridge.register(with: registrar)  // liaison avec l'Apple Watch
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let a = call.arguments as? [String: Any] ?? [:]
    guard let path = a["path"] as? String else {
      result(FlutterError(code: "args", message: "Chemin de la vidéo manquant", details: nil))
      return
    }
    let method = call.method
    let queue = method == "preview" ? previewQueue : work
    queue.async {
      do {
        let out: Any?
        switch method {
        case "info": out = try self.info(path)
        case "frames": out = try self.frames(path, a)
        case "preview": out = try self.preview(path, a)
        case "audioEnvelope": out = self.audioEnvelope(path)
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
          return
        }
        DispatchQueue.main.async { result(out) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "native", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  // MARK: - Utilitaires

  private func argInt(_ a: [String: Any], _ k: String, _ def: Int = 0) -> Int {
    return (a[k] as? NSNumber)?.intValue ?? def
  }

  private func argDouble(_ a: [String: Any], _ k: String, _ def: Double) -> Double {
    return (a[k] as? NSNumber)?.doubleValue ?? def
  }

  private func fail(_ msg: String) -> NSError {
    return NSError(domain: "rhythmix", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
  }

  /// Dessine l'image dans un tampon RGBA de w x h (lignes de haut en bas).
  private func render(_ img: CGImage, _ w: Int, _ h: Int) -> [UInt8] {
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    buf.withUnsafeMutableBytes { p in
      if let ctx = CGContext(
        data: p.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      {
        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
      }
    }
    return buf
  }

  private func generator(_ path: String, maxSide: Int) -> AVAssetImageGenerator {
    let gen = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: path)))
    gen.appliesPreferredTrackTransform = true
    gen.requestedTimeToleranceBefore = .zero
    gen.requestedTimeToleranceAfter = .zero
    gen.maximumSize = CGSize(width: maxSide, height: maxSide)
    return gen
  }

  // MARK: - info

  private func info(_ path: String) throws -> [String: Any] {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let t = asset.tracks(withMediaType: .video).first else { throw fail("pas de piste vidéo") }
    let sz = t.naturalSize.applying(t.preferredTransform)
    let w = Int(abs(sz.width).rounded())
    let h = Int(abs(sz.height).rounded())
    let dur = CMTimeGetSeconds(t.timeRange.duration)
    let fps = Double(t.nominalFrameRate)
    let count = (dur.isFinite && fps > 0) ? Int((dur * fps).rounded()) : 0
    return [
      "width": w,
      "height": h,
      "fps": fps,
      "durationMs": dur.isFinite ? dur * 1000 : 0,
      "frameCount": count,
    ]
  }

  // MARK: - frames

  private func frames(_ path: String, _ a: [String: Any]) throws -> [String: Any] {
    let start = argInt(a, "start")
    let count = max(0, argInt(a, "count"))
    let aw = max(1, argInt(a, "aw", 1))
    let ah = max(1, argInt(a, "ah", 1))
    let tw = max(1, argInt(a, "tw", 1))
    let th = max(1, argInt(a, "th", 1))
    let fps = argDouble(a, "fps", 30)
    var gray = [UInt8](repeating: 0, count: count * aw * ah)
    var rgba = [UInt8](repeating: 0, count: count * tw * th * 4)
    if count > 0 {
      let gen = generator(path, maxSide: max(aw, ah) * 2)
      let times: [NSValue] = (0..<count).map { k in
        NSValue(time: CMTime(seconds: (Double(start + k) + 0.5) / fps, preferredTimescale: 600_000))
      }
      var images = [CGImage?](repeating: nil, count: count)
      var remaining = count
      let lock = NSLock()
      let group = DispatchGroup()
      group.enter()
      gen.generateCGImagesAsynchronously(forTimes: times) { requested, image, _, _, _ in
        let k = Int((CMTimeGetSeconds(requested) * fps - 0.5).rounded()) - start
        lock.lock()
        if let image = image, k >= 0, k < count { images[k] = image }
        remaining -= 1
        let done = remaining == 0
        lock.unlock()
        if done { group.leave() }
      }
      group.wait()

      for k in 0..<count {
        guard let img = images[k] else { continue }
        // Image au double de la taille, puis moyenne exacte de 2 x 2 pixels
        // (même réduction par moitiés que la version web et Android).
        let w2 = aw * 2
        let dbl = render(img, w2, ah * 2)
        let base = k * aw * ah
        for y in 0..<ah {
          for x in 0..<aw {
            let p00 = ((2 * y) * w2 + 2 * x) * 4
            let p01 = p00 + 4
            let p10 = p00 + w2 * 4
            let p11 = p10 + 4
            let r = Double(dbl[p00]) + Double(dbl[p01]) + Double(dbl[p10]) + Double(dbl[p11])
            let g = Double(dbl[p00 + 1]) + Double(dbl[p01 + 1]) + Double(dbl[p10 + 1]) + Double(dbl[p11 + 1])
            let b = Double(dbl[p00 + 2]) + Double(dbl[p01 + 2]) + Double(dbl[p10 + 2]) + Double(dbl[p11 + 2])
            let v = (0.3 * r + 0.59 * g + 0.11 * b) / 4
            gray[base + y * aw + x] = UInt8(min(255.0, v))
          }
        }
        let small = render(img, tw, th)
        let sb = k * tw * th * 4
        rgba.replaceSubrange(sb..<(sb + small.count), with: small)
      }
    }
    return [
      "gray": FlutterStandardTypedData(bytes: Data(gray)),
      "rgba": FlutterStandardTypedData(bytes: Data(rgba)),
    ]
  }

  // MARK: - preview

  private func preview(_ path: String, _ a: [String: Any]) throws -> Any? {
    let index = argInt(a, "index")
    let fps = argDouble(a, "fps", 30)
    let maxH = max(64, argInt(a, "maxH", 720))
    if pvPath != path || pvGen == nil || pvMax != maxH {
      pvGen = generator(path, maxSide: maxH)
      pvPath = path
      pvMax = maxH
    }
    guard let gen = pvGen else { return nil }
    let t = CMTime(seconds: (Double(index) + 0.5) / fps, preferredTimescale: 600_000)
    let img = try gen.copyCGImage(at: t, actualTime: nil)
    guard let data = UIImage(cgImage: img).jpegData(compressionQuality: 0.85) else { return nil }
    return FlutterStandardTypedData(bytes: data)
  }

  // MARK: - audioEnvelope

  private func audioEnvelope(_ path: String) -> [String: Any]? {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let track = asset.tracks(withMediaType: .audio).first,
      let reader = try? AVAssetReader(asset: asset)
    else { return nil }
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVLinearPCMBitDepthKey: 32,
      AVLinearPCMIsFloatKey: true,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else { return nil }
    reader.add(output)
    guard reader.startReading() else { return nil }

    var ch = 1
    var win = 441
    var first = true
    var env = [Double]()
    var cur: Float = 0
    var cnt = 0
    while let sb = output.copyNextSampleBuffer() {
      if first {
        if let fd = CMSampleBufferGetFormatDescription(sb),
          let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd)?.pointee
        {
          ch = max(1, Int(asbd.mChannelsPerFrame))
          win = max(1, Int((asbd.mSampleRate / 100).rounded()))
        }
        first = false
      }
      guard let bb = CMSampleBufferGetDataBuffer(sb) else { continue }
      let total = CMBlockBufferGetDataLength(bb)
      if total < 4 { continue }
      var floats = [Float](repeating: 0, count: total / 4)
      let status = floats.withUnsafeMutableBytes { raw -> OSStatus in
        guard let base = raw.baseAddress else { return -1 }
        return CMBlockBufferCopyDataBytes(bb, atOffset: 0, dataLength: (total / 4) * 4, destination: base)
      }
      if status != kCMBlockBufferNoErr { continue }
      var i = 0
      while i < floats.count {
        let v = abs(floats[i])
        if v > cur { cur = v }
        cnt += 1
        if cnt == win {
          env.append(Double(cur))
          cur = 0
          cnt = 0
        }
        i += ch
      }
    }
    return ["env": env]
  }
}

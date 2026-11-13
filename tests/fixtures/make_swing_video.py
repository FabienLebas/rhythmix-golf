#!/usr/bin/env python3
"""Génère une vidéo de swing synthétique à repères connus (vérité terrain).

Golfeur stylisé filmé de face, 60 images/s, 3 s, 270 x 480 px, avec le bruit
de la balle à l'impact. Repères exacts :
  départ = image 48, sommet = image 96, impact = image 112  (ratio 3 : 1)

Sorties (dans tests/fixtures/) :
  swing_60fps.mp4       H.264 + AAC : lu par iOS (AVFoundation), Android (MediaCodec)
  swing_60fps_vp9.mp4   VP9 + Opus  : lu par le Chromium open source des tests web
  ../../rhythmix_golf_flutter/integration_test/swing_video.g.dart
                        la vidéo H.264 en base64, embarquée uniquement dans les
                        tests sur appareil (rien n'est ajouté à l'app publiée)

Le résultat est déterministe : relancer le script ne doit rien changer.
Prérequis : python3 + numpy, ffmpeg (libx264, aac, libvpx-vp9, libopus).
"""

import base64
import json
import math
import pathlib
import subprocess
import tempfile
import wave

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
FLUTTER_IT = HERE.parent.parent / "rhythmix_golf_flutter" / "integration_test"

W, H, FPS, N = 270, 480, 60, 180
# Le dessin est fait dans un repère de 180 x 320 unités, agrandi x 1,5.
# (petit côté >= 240 px : les images de travail sont réduites une fois,
# comme pour une vraie vidéo de téléphone)
SCALE = 1.5
START, TOP, IMPACT, END_FT = 48, 96, 112, 136
SR = 48000

TRUTH = {"fps": FPS, "frames": N, "width": W, "height": H,
         "start": START, "top": TOP, "impact": IMPACT,
         "impactTime": IMPACT / FPS}


def smooth(u):
    u = min(1.0, max(0.0, u))
    return u * u * (3 - 2 * u)


def club_angle(i):
    """Angle du club (radians, 0 = club vers la balle)."""
    top = math.radians(200)
    if i <= START:
        return 0.0
    if i <= TOP:  # montée : lente, accélère puis ralentit au sommet
        return top * smooth((i - START) / (TOP - START))
    if i <= IMPACT:  # descente : accélère jusqu'à l'impact
        u = (i - TOP) / (IMPACT - TOP)
        return top * (1 - u * u)
    if i <= END_FT:  # finish : ralentit
        u = (i - IMPACT) / (END_FT - IMPACT)
        return -top * (2 * u - u * u)
    return -top


def hip_shift(i):
    """Décalage latéral des hanches (px) : léger recul à la montée, puis
    transfert franc vers la cible juste avant le sommet."""
    if i <= START:
        return 0.0
    if i <= 90:
        return -3.0 * smooth((i - START) / (90 - START))
    if i <= IMPACT:
        return -3.0 + 11.0 * smooth((i - 90) / (IMPACT - 90))
    return 8.0


rng = np.random.default_rng(20261113)
# Texture de la ceinture / du bassin : profil lissé, non périodique.
_raw = rng.uniform(0, 1, 180 + 64)
BELT = np.convolve(_raw, np.ones(5) / 5, mode="same") * 140 + 60
UW, UH = W / SCALE, H / SCALE

yy, xx = np.mgrid[0:H, 0:W].astype(np.float64) / SCALE
CX, SHOULDER_Y = UW / 2, 120.0


def seg_coverage(x0, y0, x1, y1, width):
    dx, dy = x1 - x0, y1 - y0
    L2 = dx * dx + dy * dy
    t = np.clip(((xx - x0) * dx + (yy - y0) * dy) / L2, 0, 1)
    d = np.hypot(xx - (x0 + t * dx), yy - (y0 + t * dy))
    return np.clip(width / 2 + 0.5 - d, 0, 1)


def frame(i):
    img = np.full((H, W), 112.0)
    img += (yy / UH) * 25  # léger dégradé du fond
    # jambes
    img = np.where((yy > 205) & (yy < 300) & (np.abs(xx - CX) > 8) & (np.abs(xx - CX) < 26), 70, img)
    # bassin texturé (décalé latéralement)
    s = hip_shift(i)
    u = xx - CX + 32 - s + 16
    u0 = np.clip(np.floor(u).astype(int), 0, len(BELT) - 2)
    fr = u - np.floor(u)
    belt = BELT[u0] * (1 - fr) + BELT[u0 + 1] * fr
    hip_mask = (yy >= 180) & (yy < 210) & (np.abs(xx - CX - s) < 30)
    img = np.where(hip_mask, belt, img)
    # torse et tête (légère rotation simulée par un petit décalage)
    tor = s * 0.4
    img = np.where((yy >= 110) & (yy < 180) & (np.abs(xx - CX - tor) < 24), 55, img)
    img = np.where(np.hypot(xx - CX - tor * 0.5, yy - 92) < 15, 185, img)
    # bras + club : pivot aux épaules
    a = club_angle(i)
    hx, hy = CX + 50 * math.sin(a), SHOULDER_Y + 50 * math.cos(a)
    cx, cy = CX + 150 * math.sin(a), SHOULDER_Y + 150 * math.cos(a)
    arms = seg_coverage(CX + tor, SHOULDER_Y, hx, hy, 9)
    club = seg_coverage(hx, hy, cx, cy, 3)
    img = img * (1 - arms) + 160 * arms
    img = img * (1 - club) + 235 * club
    # balle
    img = np.where(np.hypot(xx - (CX + 2), yy - 286) < 4, 250, img)
    return np.clip(np.round(img), 0, 255).astype(np.uint8)


def audio():
    n = int(SR * N / FPS)
    a = rng.normal(0, 0.002, n)
    k = int(round(IMPACT / FPS * SR))
    t = np.arange(int(0.03 * SR)) / SR
    burst = 0.8 * np.exp(-t / 0.004) * rng.uniform(-1, 1, len(t))
    a[k:k + len(t)] += burst
    return np.clip(a, -1, 1)


def main():
    frames = np.stack([frame(i) for i in range(N)])
    rgb = np.repeat(frames[..., None], 3, axis=3)
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / "a.wav"
        pcm = (audio() * 32767).astype("<i2")
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        raw = rgb.tobytes()
        common = ["ffmpeg", "-y", "-loglevel", "error",
                  "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                  "-i", str(wav), "-map", "0:v", "-map", "1:a", "-shortest",
                  "-fflags", "+bitexact", "-flags:v", "+bitexact", "-flags:a", "+bitexact",
                  "-map_metadata", "-1"]
        subprocess.run(common + ["-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
                                 "-x264-params", "threads=1", "-g", "60", "-bf", "0",
                                 "-c:a", "aac", "-b:a", "96k", "-movflags", "+faststart",
                                 str(HERE / "swing_60fps.mp4")], input=raw, check=True)
        subprocess.run(common + ["-c:v", "libvpx-vp9", "-crf", "20", "-b:v", "0", "-row-mt", "0", "-threads", "1",
                                 "-pix_fmt", "yuv420p", "-c:a", "libopus", "-b:a", "96k",
                                 str(HERE / "swing_60fps_vp9.mp4")], input=raw, check=True)
    (HERE / "swing_truth.json").write_text(json.dumps(TRUTH, indent=2) + "\n")
    b64 = base64.b64encode((HERE / "swing_60fps.mp4").read_bytes()).decode()
    lines = [b64[i:i + 100] for i in range(0, len(b64), 100)]
    dart = ("// GÉNÉRÉ par tests/fixtures/make_swing_video.py : ne pas modifier à la main.\n"
            "// Vidéo de swing synthétique (H.264 + AAC), embarquée seulement dans les tests.\n"
            "// ignore_for_file: lines_longer_than_80_chars\n\n"
            f"const swingTruth = (fps: {FPS}, frames: {N}, width: {W}, height: {H}, "
            f"start: {START}, top: {TOP}, impact: {IMPACT});\n\n"
            "const String swingVideoBase64 =\n" +
            "\n".join(f"    '{l}'" for l in lines) + ";\n")
    FLUTTER_IT.mkdir(parents=True, exist_ok=True)
    (FLUTTER_IT / "swing_video.g.dart").write_text(dart)
    for f in ("swing_60fps.mp4", "swing_60fps_vp9.mp4"):
        print(f, (HERE / f).stat().st_size, "octets")


if __name__ == "__main__":
    main()

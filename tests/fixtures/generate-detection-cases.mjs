// Génère tests/fixtures/detection-cases.json : des cas de détection
// (courbe de mouvement, son d'impact, images des hanches) avec les repères
// attendus, CALCULÉS EN EXÉCUTANT LE CODE DU SITE (index.html) dans Chromium.
//
// Ce fichier sert de référence commune (« golden master ») :
//   - tests/web/detection.spec.js vérifie que le site donne toujours ces repères ;
//   - rhythmix_golf_flutter/test/detection_parity_test.dart vérifie que l'app
//     Flutter donne EXACTEMENT les mêmes (parité web <-> iOS / Android).
//
// À relancer uniquement après une modification VOULUE de l'algorithme :
//   npm run fixtures
// puis relire le diff de detection-cases.json avant de le commiter.

import { chromium } from '@playwright/test';
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..', '..');
const OUT = join(HERE, 'detection-cases.json');

// Générateur pseudo-aléatoire déterministe (mulberry32).
function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const r4 = (x) => Math.round(x * 1e4) / 1e4;

/** Courbe de mouvement synthétique d'un swing (grand jeu). */
function swingCurve({ fps, seconds, start, top, impact, seed, peak = 2.4 }) {
  const n = Math.round(fps * seconds), R = rng(seed), q = [];
  const f = (s) => s * fps;
  for (let i = 0; i < n; i++) {
    let v = 0.01 + 0.02 * R();
    const t = i;
    if (t >= f(start) && t < f(top)) {
      const u = (t - f(start)) / (f(top) - f(start));
      v += 1.2 * Math.sin(Math.PI * Math.min(1, u * 1.1));
    } else if (t >= f(top) && t < f(impact)) {
      const u = (t - f(top)) / (f(impact) - f(top));
      v += 0.15 + peak * u * u;
    } else if (t >= f(impact) && t < f(impact + 0.5)) {
      const u = (t - f(impact)) / (0.5 * fps);
      v += peak * (1 - u) * (1 - u);
    }
    q.push(r4(v + 0.05 * R()));
  }
  return q;
}

/** Courbe de mouvement synthétique d'un putt. */
function puttCurve({ fps, seconds, start, top, impact, seed }) {
  const n = Math.round(fps * seconds), R = rng(seed), q = [];
  const f = (s) => s * fps;
  for (let i = 0; i < n; i++) {
    let v = 0.004 + 0.004 * R();
    if (i >= f(start) && i < f(top)) v += 0.25 * Math.sin(Math.PI * (i - f(start)) / (f(top) - f(start)));
    else if (i >= f(top) && i < f(impact) + 0.15 * fps) v += 0.45 * Math.sin(Math.PI * (i - f(top)) / (f(impact) + 0.15 * fps - f(top)));
    q.push(r4(v));
  }
  return q;
}

/** Enveloppe sonore (max par 10 ms) avec un « clac » à l'instant t. */
function envelope({ seconds, t, amp, noise, seed }) {
  const R = rng(seed), env = [];
  for (let i = 0; i < Math.round(seconds * 100); i++) env.push(r4(noise * (0.5 + R())));
  if (t != null) env[Math.round(t * 100)] = amp;
  return env;
}

/** Même formule que audioImpact() du site et de detection.dart. */
function audioImpact(env) {
  if (!env || !env.length) return null;
  const sorted = env.slice().sort((x, y) => x - y), med = sorted[Math.floor(sorted.length / 2)];
  const pk = env.indexOf(Math.max(...env));
  return { t: pk / 100, amp: env[pk], ratio: env[pk] / Math.max(med, 0.0005) };
}

/** Images des hanches : profil entier décalé d'un nombre entier de pixels
 *  par image (reconstruites à l'identique en Dart, sans flottants). */
function hipImages({ n, w, h, fps, ip, seed }) {
  const R = rng(seed), pad = 12, profile = [];
  let v = 120;
  for (let x = 0; x < w + 2 * pad; x++) { v = Math.max(20, Math.min(235, v + Math.round((R() - 0.5) * 60))); profile.push(v); }
  const shifts = [];
  const t0 = ip - Math.round(0.3 * fps); // départ latéral des hanches
  for (let i = 0; i < n; i++) {
    let s = 0;
    if (i > ip - Math.round(0.8 * fps) && i <= t0) s = -Math.round(2 * (i - (ip - 0.8 * fps)) / (0.5 * fps));
    if (i > t0) s = -2 + Math.min(8, Math.round(8 * (i - t0) / (0.3 * fps)));
    shifts.push(s);
  }
  return { w, h, rowFrom: Math.round(h * 0.2), rowTo: Math.round(h * 0.85), background: 90, pad, profile, shifts };
}

// Courbe de mouvement réelle : analyse de la vidéo synthétique par le site.
const browser = await chromium.launch();
const page = await browser.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
await page.goto(pathToFileURL(join(ROOT, 'index.html')).href);
await page.setInputFiles('#vf', join(HERE, 'swing_60fps.mp4'));
await page.waitForFunction(() => /Détection terminée/.test(document.getElementById('vhint').textContent), null, { timeout: 120000 });
const swingQ = (await page.evaluate(() => lastQ)).map(r4);

const cases = [];
const add = (c) => cases.push(c);

// 1. Courbe réelle mesurée sur la vidéo synthétique (tests/fixtures/swing_60fps.mp4)
add({ name: 'grand · vidéo de référence · son exploitable', mode: 'grand', fps: 60, q: swingQ,
  au: { t: 1.86, amp: 0.695, ratio: 127.06 } });
add({ name: 'grand · vidéo de référence · sans son', mode: 'grand', fps: 60, q: swingQ, au: null });
add({ name: 'grand · son trop faible (amp <= 0,05) ignoré', mode: 'grand', fps: 60, q: swingQ,
  au: { t: 1.5, amp: 0.04, ratio: 50 } });
add({ name: 'grand · pic sonore peu marqué (ratio <= 8) ignoré', mode: 'grand', fps: 60, q: swingQ,
  au: { t: 1.5, amp: 0.4, ratio: 6 } });
// 2. Courbes synthétiques
const g60 = { fps: 60, seconds: 4, start: 1.0, top: 1.81, impact: 2.08, seed: 11 };
add({ name: 'grand · 60 i/s · son', mode: 'grand', fps: 60, q: swingCurve(g60),
  env: envelope({ seconds: 4, t: 2.08, amp: 0.6, noise: 0.01, seed: 12 }) });
add({ name: 'grand · 30 i/s · son', mode: 'grand', fps: 30,
  q: swingCurve({ ...g60, fps: 30, seed: 13 }), env: envelope({ seconds: 4, t: 2.08, amp: 0.6, noise: 0.01, seed: 14 }) });
add({ name: 'grand · 120 i/s · sans son', mode: 'grand', fps: 120,
  q: swingCurve({ ...g60, fps: 120, seconds: 3.5, seed: 15 }), au: null });
add({ name: 'grand · swing lent (4:1) · son', mode: 'grand', fps: 60,
  q: swingCurve({ fps: 60, seconds: 4, start: 0.8, top: 2.0, impact: 2.3, seed: 16 }),
  env: envelope({ seconds: 4, t: 2.3, amp: 0.5, noise: 0.008, seed: 17 }) });
add({ name: 'grand · swing rapide (2:1) · son', mode: 'grand', fps: 60,
  q: swingCurve({ fps: 60, seconds: 3, start: 0.9, top: 1.4, impact: 1.65, seed: 18 }),
  env: envelope({ seconds: 3, t: 1.65, amp: 0.5, noise: 0.008, seed: 19 }) });
// 3. Sommet par les hanches
{
  const q = swingCurve({ ...g60, seed: 21 });
  const env = envelope({ seconds: 4, t: 2.08, amp: 0.6, noise: 0.01, seed: 22 });
  const ip = Math.round(2.08 * 60);
  add({ name: 'grand · sommet repéré par les hanches', mode: 'grand', fps: 60, q, env,
    hip: hipImages({ n: q.length, w: 54, h: 96, fps: 60, ip, seed: 23 }) });
  add({ name: 'grand · images des hanches immobiles (repli sur le mouvement)', mode: 'grand', fps: 60, q, env,
    hip: { ...hipImages({ n: q.length, w: 54, h: 96, fps: 60, ip, seed: 23 }), shifts: q.map(() => 0) } });
}
// 4. Putting (mouvement seul)
const p = { fps: 60, seconds: 3, start: 0.8, top: 1.4, impact: 1.7, seed: 31 };
add({ name: 'putt · 60 i/s', mode: 'putt', fps: 60, q: puttCurve(p) });
add({ name: 'putt · 30 i/s', mode: 'putt', fps: 30, q: puttCurve({ ...p, fps: 30, seed: 32 }) });
add({ name: 'putt · 240 i/s', mode: 'putt', fps: 240, q: puttCurve({ ...p, fps: 240, seconds: 2.5, seed: 33 }) });
add({ name: 'putt · son ignoré même s\'il est fort', mode: 'putt', fps: 60, q: puttCurve({ ...p, seed: 34 }),
  env: envelope({ seconds: 3, t: 0.5, amp: 0.9, noise: 0.01, seed: 35 }) });
// 5. Cas limites
add({ name: 'grand · vidéo très courte (12 images)', mode: 'grand', fps: 30,
  q: [0.01, 0.02, 0.01, 0.3, 0.6, 0.5, 0.2, 0.9, 1.5, 0.7, 0.1, 0.02], au: null });
add({ name: 'putt · vidéo très courte (12 images)', mode: 'putt', fps: 30,
  q: [0.01, 0.02, 0.01, 0.3, 0.6, 0.5, 0.2, 0.9, 1.5, 0.7, 0.1, 0.02] });

for (const c of cases) {
  if (c.env) c.au = audioImpact(c.env);
  if (c.au === undefined) c.au = null;
}

// ----- Calcul des repères attendus par le code du site -----
for (const c of cases) {
  c.expected = await page.evaluate((c) => {
    S.mode = c.mode; lastQ = c.q; n = c.q.length; fpsv = c.fps; lastAu = c.au; BIG = []; AW = 0; AH = 0;
    if (c.hip) {
      const H = c.hip; AW = H.w; AH = H.h;
      for (let i = 0; i < n; i++) {
        const im = new Uint8Array(H.w * H.h).fill(H.background);
        for (let y = H.rowFrom; y < H.rowTo; y++) for (let x = 0; x < H.w; x++) im[y * H.w + x] = H.profile[x - H.shifts[i] + H.pad];
        BIG.push(im);
      }
    }
    detect();
    const hint = document.getElementById('vhint').textContent;
    return { markers: M.slice(), audioUsed: /bruit de la balle/.test(hint), viaHip: /hanches/.test(hint) };
  }, c);
}
await browser.close();
if (errors.length) throw new Error('Erreurs JS : ' + errors.join(' | '));

const header = {
  _comment: 'GÉNÉRÉ par tests/fixtures/generate-detection-cases.mjs (npm run fixtures). Repères attendus = résultat du code de index.html. Ne pas modifier à la main.',
};
writeFileSync(OUT, JSON.stringify({ ...header, cases }, null, 1) + '\n');
for (const c of cases) console.log(c.expected.markers.join(' / ').padEnd(16), c.expected.audioUsed ? 'son ' : '    ', c.expected.viaHip ? 'hanches' : '       ', c.name);

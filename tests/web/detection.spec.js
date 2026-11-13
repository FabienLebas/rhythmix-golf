// Site : algorithme de détection (golden master partagé avec l'app Flutter)
// et lecture de la cadence dans le fichier MP4.
const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');
const { openApp, FIXTURES, SWING_VIDEO } = require('./helpers');

const { cases } = JSON.parse(fs.readFileSync(path.join(FIXTURES, 'detection-cases.json'), 'utf8'));

test('réglages de détection inchangés', async ({ page }) => {
  const app = await openApp(page);
  expect(await page.evaluate(() => PARAMS)).toEqual({
    grand: { hip: true, off: 0, pre: 0.35, bw: 0.6, fb: 0.5, amp: 0.05, ratio: 8, ratioT: 3 },
    putt: { hip: false, off: 0, pre: 0.3, bw: 0.5, fb: 0.4, amp: 0.008, ratio: 5, ratioT: 2, audio: false },
  });
  await app.noErrors();
});

test.describe('repères de référence (identiques dans l’app Flutter)', () => {
  for (const c of cases) {
    test(c.name, async ({ page }) => {
      const app = await openApp(page);
      const got = await page.evaluate((c) => {
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
      expect(got).toEqual(c.expected);
      await app.noErrors();
    });
  }
});

test.describe('arrondi du tempo', () => {
  test('snap : ratio cible exact au centième, sinon valeurs arrondies', async ({ page }) => {
    const app = await openApp(page);
    expect(await page.evaluate(() => [
      snap(1, 1 / 3, 3, 'grand'), snap(0.9, 0.3, 3, 'grand'), snap(1, 0.27, 3.7, 'grand'),
      snap(0.61, 0.304, 2.006, 'putt'), snap(0, 0, 5, 'grand'),
    ])).toEqual([{ b: 0.99, d: 0.33 }, { b: 0.9, d: 0.3 }, { b: 1, d: 0.27 }, { b: 0.6, d: 0.3 }, { b: 0.01, d: 0.01 }]);
    await app.noErrors();
  });
});

test.describe('cadence lue dans le fichier MP4', () => {
  test('vidéo H.264 60 i/s', async ({ page }) => {
    const app = await openApp(page);
    const bytes = [...fs.readFileSync(SWING_VIDEO)];
    const fps = await page.evaluate((b) => mp4Fps(new File([new Uint8Array(b)], 'swing.mp4')), bytes);
    expect(fps).toBeCloseTo(60, 6);
    await app.noErrors();
  });

  test('fichier qui n’est pas un MP4 : null, sans erreur', async ({ page }) => {
    const app = await openApp(page);
    expect(await page.evaluate(() => mp4Fps(new File([new Uint8Array(64)], 'x.mp4')))).toBeNull();
    expect(await page.evaluate(() => mp4Fps(new File(['bonjour, je ne suis pas une vidéo'], 'x.txt')))).toBeNull();
    await app.noErrors();
  });
});

// Site : analyse vidéo de bout en bout, avec une vraie vidéo de swing
// (tests/fixtures/swing_60fps.mp4, repères réels : 48 / 96 / 112).
const { test, expect } = require('@playwright/test');
const path = require('node:path');
const { openApp, state, stored, analyseSwing, markers, TRUTH, FIXTURES } = require('./helpers');

// Écart toléré avec la vérité terrain (images) ; le site trouve 49 / 99 / 112.
const TOL = 4;
const fmt = (x) => x.toFixed(2).replace('.', ',');

test.describe.configure({ timeout: 180_000 });

test('analyse complète : cadence, repères, tempo, conseil, métronome, historique, gratuité', async ({ page }) => {
  const app = await openApp(page);
  await analyseSwing(page);

  await expect(page.locator('#vmeta')).toHaveText('Vidéo : 270 × 480 · 60 images/s · 3,0 s');
  await expect(page.locator('#vmeta')).toBeVisible();
  await expect(page.locator('#vhint')).toContainText('impact repéré grâce au bruit de la balle');
  await expect(page.locator('#vhint')).toContainText('sommet repéré au départ des hanches');

  const m = await markers(page);
  expect(Math.abs(m[0] - TRUTH.start), 'départ').toBeLessThanOrEqual(TOL);
  expect(Math.abs(m[1] - TRUTH.top), 'sommet').toBeLessThanOrEqual(TOL);
  expect(Math.abs(m[2] - TRUTH.impact), 'impact').toBeLessThanOrEqual(TOL);
  await expect(page.locator('#k1')).toHaveText(`Départ · image ${m[0]}`);
  await expect(page.locator('#k2')).toHaveText(`Sommet · image ${m[1]}`);
  await expect(page.locator('#k3')).toHaveText(`Impact · image ${m[2]}`);
  await expect(page.locator('#k1')).toHaveClass(/on/);
  await expect(page.locator('#o1')).toBeVisible();
  await expect(page.locator('#vbadge')).toHaveText(`Image ${m[0]} / 179 · ${(m[0] / 60).toFixed(3)} s`);

  const b = (m[1] - m[0]) / 60, d = (m[2] - m[1]) / 60;
  await expect(page.locator('#vres')).toHaveText(
    `Ton rythme : montée ${fmt(b)} s, descente ${fmt(d)} s, ratio ${(b / d).toFixed(1).replace('.', ',')}:1 (swing ${fmt(b + d)} s).`);
  await expect(page.locator('#vsug .info')).toContainText(b / d > 3.15 ? 'Ta montée est trop lente' : /Ta montée|déjà proche/);
  const dd = Math.round(d * 100) / 100;
  await expect(page.locator('#vsug p')).toHaveText(
    `Le métronome est réglé sur ton tempo cible grand jeu 3:1 : montée ${fmt(dd * 3)} s, descente ${fmt(dd)} s.`);
  // métronome réglé sur le tempo cible
  expect(await state(page)).toMatchObject({ d: dd, b: Math.round(dd * 300) / 100, sp: 100 });
  await expect(page.locator('#d')).toHaveValue(dd.toFixed(2));

  // historique et gratuité
  await expect(page.locator('#hbody li')).toHaveCount(1);
  await expect(page.locator('#hbody svg circle')).toHaveCount(1);
  expect((await stored(page, 'tg_hist')).grand[0].r).toBeCloseTo(b / d, 6);
  expect(await page.evaluate(() => localStorage.getItem('tg_free'))).toBe('1');
  await expect(page.locator('#free')).toContainText('il t’en reste 2 sur 3');
  await app.noErrors();
});

test('corriger les repères : boutons, clavier, bande d’images, molette', async ({ page }, info) => {
  const app = await openApp(page);
  await analyseSwing(page);
  const m = await markers(page);

  // Sélectionner Impact puis ±1 / ±5
  await page.locator('#k3').click();
  await expect(page.locator('#k3')).toHaveClass(/on/);
  await page.locator('#p1').click();
  await page.locator('#p5').click();
  await expect(page.locator('#k3')).toHaveText(`Impact · image ${m[2] + 6}`);
  await page.locator('#m5').click();
  await page.locator('#m1').click();
  await page.locator('#m1').click();
  await expect(page.locator('#k3')).toHaveText(`Impact · image ${m[2] - 1}`);
  const d = (m[2] - 1 - m[1]) / 60;
  expect((await state(page)).d).toBeCloseTo(Math.round(d * 100) / 100, 6);

  // Retouche : le point d'historique est mis à jour, pas dupliqué ; rien n'est décompté
  await expect(page.locator('#hbody li')).toHaveCount(1);
  expect((await stored(page, 'tg_hist')).grand[0].d).toBeCloseTo(d * 1000, 6);
  expect(await page.evaluate(() => localStorage.getItem('tg_free'))).toBe('1');

  // Toucher à nouveau le repère sélectionné le désélectionne
  await page.locator('#k3').click();
  await expect(page.locator('#k3')).not.toHaveClass(/on/);
  await page.locator('#p5').click();
  await expect(page.locator('#k3')).toHaveText(`Impact · image ${m[2] - 1}`);

  if (info.project.name === 'ordinateur') {
    // Raccourcis clavier : 2 = Sommet, flèches = ±1, Maj = ±5
    await page.keyboard.press('2');
    await expect(page.locator('#k2')).toHaveClass(/on/);
    await page.keyboard.press('ArrowRight');
    await page.keyboard.press('Shift+ArrowLeft');
    await expect(page.locator('#k2')).toHaveText(`Sommet · image ${m[1] - 4}`);
    // Molette sur la bande d'images
    const before = (await markers(page))[1];
    await page.locator('#strip').hover();
    await page.mouse.wheel(0, 44 * 3);
    await expect.poll(async () => (await markers(page))[1]).toBeGreaterThan(before);
  }

  // Glisser la bande d'images vers la gauche avance dans la vidéo
  await page.locator('#k1').click();
  const box = await page.locator('#strip').boundingBox();
  const start = (await markers(page))[0];
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width / 2 - 100, box.y + box.height / 2, { steps: 10 });
  await page.mouse.up();
  await expect.poll(async () => (await markers(page))[0]).toBeGreaterThan(start);

  // Repères dans le désordre : message
  await page.evaluate(() => { M = [120, 100, 110]; updateUI(); });
  await expect(page.locator('#vres')).toHaveText('L’ordre doit être : départ, sommet, impact.');
  await expect(page.locator('#vsug')).toBeEmpty();
  await app.noErrors();
});

test('changer de mode après l’analyse : nouvelle détection en putting, sans décompter', async ({ page }) => {
  const app = await openApp(page);
  await analyseSwing(page);
  await page.getByRole('button', { name: /Putting/ }).click();
  await expect(page.locator('#vhint')).toContainText('putt : repérage par le mouvement, sans le son');
  await expect(page.locator('#vsug p')).toContainText('tempo cible putting 2:1');
  const m = await markers(page);
  expect(m[0]).toBeLessThan(m[1]);
  expect(m[1]).toBeLessThan(m[2]);
  expect((await state(page)).b).toBeCloseTo((await state(page)).d * 2, 6);
  const h = await stored(page, 'tg_hist');
  expect([h.grand.length, h.putt.length]).toEqual([1, 1]);
  expect(await page.evaluate(() => localStorage.getItem('tg_free'))).toBe('1');
  await app.noErrors();
});

test('3 analyses gratuites puis blocage', async ({ page }) => {
  const app = await openApp(page, { tg_free: '2' });
  await analyseSwing(page);
  await expect(page.locator('#free')).toContainText('🔒 Tes 3 analyses gratuites sont utilisées.');
  let opened = false;
  page.on('filechooser', () => { opened = true; });
  await page.locator('#vf').click();
  await page.waitForTimeout(500);
  expect(opened).toBe(false);
  await app.noErrors();
});

test('fichier illisible : message clair, rien n’est décompté', async ({ page }) => {
  const app = await openApp(page);
  await page.setInputFiles('#vf', { name: 'pas-une-video.mp4', mimeType: 'video/mp4', buffer: Buffer.from('bonjour') });
  await expect(page.locator('#vres')).toHaveText(/Impossible de lire cette vidéo ici\.|navigateur|Erreur/);
  expect(await page.evaluate(() => localStorage.getItem('tg_free'))).toBeNull();
  await expect(page.locator('#k1')).toHaveText('Départ —');
  app.errors.length = 0; // le navigateur signale lui-même le fichier invalide
});

test('vidéo VP9 (autre codec, même conteneur MP4) : mêmes repères', async ({ page }, info) => {
  test.skip(info.project.name !== 'ordinateur', 'une fois suffit');
  const app = await openApp(page);
  await analyseSwing(page);
  const h264 = await markers(page);
  await page.setInputFiles('#vf', path.join(FIXTURES, 'swing_60fps_vp9.mp4'));
  await expect(page.locator('#vres')).toContainText('Analyse', { timeout: 20_000 });
  await expect(page.locator('#vhint')).toContainText('Détection terminée', { timeout: 120_000 });
  const vp9 = await markers(page);
  vp9.forEach((v, i) => expect(Math.abs(v - h264[i])).toBeLessThanOrEqual(1));
  await app.noErrors();
});

test('petite vidéo (180 × 320, rien à réduire) : images de travail pleine taille, même sommet', async ({ page }, info) => {
  test.skip(info.project.name !== 'ordinateur', 'une fois suffit');
  const app = await openApp(page);
  // Référence : 270 × 480 (images de travail réduites une fois, 135 × 240)
  await analyseSwing(page);
  const ref = await page.evaluate(() => ({ M: M.slice(), hip: hipTop(M[2]) }));
  expect(ref.hip, 'sommet par les hanches, vidéo 270 × 480').not.toBeNull();

  await page.setInputFiles('#vf', path.join(FIXTURES, 'swing_60fps_small.mp4'));
  await expect(page.locator('#vres')).toContainText('Analyse', { timeout: 20_000 });
  await expect(page.locator('#vhint')).toContainText('Détection terminée', { timeout: 120_000 });
  await expect(page.locator('#vmeta')).toHaveText('Vidéo : 180 × 320 · 60 images/s · 3,0 s');
  const small = await page.evaluate(() => {
    // chaque image de travail doit être entièrement remplie (AW × AH = taille de la vidéo)
    let filled = true;
    for (const b of BIG) {
      let zeros = 0;
      for (let k = 0; k < b.length; k++) if (!b[k]) zeros++;
      if (b.length !== AW * AH || zeros > b.length / 100) { filled = false; break; }
    }
    return { AW, AH, n, big: BIG.length, filled, M: M.slice(), hip: hipTop(M[2]) };
  });
  expect([small.AW, small.AH]).toEqual([180, 320]);
  expect(small.big).toBe(small.n);
  expect(small.filled, 'images de travail entièrement remplies').toBe(true);
  expect(small.hip, 'sommet par les hanches, vidéo 180 × 320').not.toBeNull();
  expect(Math.abs(small.hip - ref.hip)).toBeLessThanOrEqual(1);
  expect(Math.abs(small.hip - TRUTH.top)).toBeLessThanOrEqual(TOL);
  await expect(page.locator('#vhint')).toContainText('sommet repéré au départ des hanches');
  small.M.forEach((v, i) => expect(Math.abs(v - ref.M[i]), `repère ${i}`).toBeLessThanOrEqual(1));
  await app.noErrors();
});

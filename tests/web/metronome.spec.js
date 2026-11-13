// Site : choix du mode et métronome (réglages, persistance, son).
const { test, expect } = require('@playwright/test');
const { openApp, state, stored, setRange } = require('./helpers');

test.describe('écran et modes', () => {
  test('titre, logo et les trois cartes', async ({ page }) => {
    const app = await openApp(page);
    await expect(page).toHaveTitle(/Rhythmix Golf/);
    await expect(page.locator('h1')).toHaveText('Rhythmix Golf');
    await expect(page.locator('h1 img.logo')).toBeVisible();
    await expect(page.locator('#modes button')).toHaveText([/Grand jeu\s*tempo 3 : 1/, /Putting\s*tempo 2 : 1/]);
    await expect(page.locator('#mt')).toHaveText('Métronome · grand jeu 3:1');
    await expect(page.locator('#vt')).toHaveText('Analyser un grand jeu');
    await expect(page.locator('#ht')).toHaveText('Historique · grand jeu');
    await app.noErrors();
  });

  test('valeurs par défaut du grand jeu : 0,81 / 0,27 s, ratio 3:1', async ({ page }) => {
    const app = await openApp(page);
    await expect(page.locator('#b')).toHaveValue('0.81');
    await expect(page.locator('#d')).toHaveValue('0.27');
    await expect(page.locator('#info')).toHaveText('Montée 0,81 s · Descente 0,27 s · Ratio 3,00:1 · Swing 1,08 s');
    await expect(page.locator('#lock')).toBeChecked();
    await expect(page.locator('#sv')).toHaveText('100');
    await expect(page.locator('#pv')).toHaveText('3');
    await expect(page.locator('#go')).toHaveText('▶ Démarrer');
    await app.noErrors();
  });

  test('putting : 0,60 / 0,30 s, ratio 2:1, couleur bleue ; retour au grand jeu', async ({ page }) => {
    const app = await openApp(page);
    await page.getByRole('button', { name: /Putting/ }).click();
    await expect(page.locator('html')).toHaveAttribute('data-mode', 'putt');
    await expect(page.locator('#modes button.on')).toHaveText(/Putting/);
    await expect(page.locator('#mt')).toHaveText('Métronome · putting 2:1');
    await expect(page.locator('#vt')).toHaveText('Analyser un putt');
    await expect(page.locator('#ht')).toHaveText('Historique · putting');
    await expect(page.locator('#b')).toHaveValue('0.60');
    await expect(page.locator('#d')).toHaveValue('0.30');
    await expect(page.locator('#info')).toHaveText('Montée 0,60 s · Descente 0,30 s · Ratio 2,00:1 · Swing 0,90 s');
    const blue = await page.locator('#go').evaluate((e) => getComputedStyle(e).backgroundColor);
    await page.getByRole('button', { name: /Grand jeu/ }).click();
    await expect(page.locator('html')).toHaveAttribute('data-mode', 'grand');
    const green = await page.locator('#go').evaluate((e) => getComputedStyle(e).backgroundColor);
    expect(green).not.toBe(blue);
    await expect(page.locator('#b')).toHaveValue('0.81');
    await app.noErrors();
  });
});

test.describe('réglages', () => {
  test('ratio gardé : changer la montée recalcule la descente', async ({ page }) => {
    const app = await openApp(page);
    await page.locator('#b').fill('0.9');
    await expect(page.locator('#d')).toHaveValue('0.30');
    await expect(page.locator('#info')).toHaveText('Montée 0,90 s · Descente 0,30 s · Ratio 3,00:1 · Swing 1,20 s');
    await page.locator('#d').fill('0.25');
    await expect(page.locator('#b')).toHaveValue('0.75');
    // arrondi au centième, montée = descente x 3 telle qu'affichée
    await page.locator('#b').fill('1');
    await expect(page.locator('#d')).toHaveValue('0.33');
    await page.locator('#b').blur();
    await expect(page.locator('#b')).toHaveValue('0.99');
    await app.noErrors();
  });

  test('ratio libre : une seule durée change', async ({ page }) => {
    const app = await openApp(page);
    await page.locator('#lock').uncheck();
    await page.locator('#b').fill('1.2');
    await expect(page.locator('#d')).toHaveValue('0.27');
    expect(await state(page)).toMatchObject({ lock: false, b: 1.2, d: 0.27 });
    await expect(page.locator('#info')).toContainText('Ratio 4,44:1');
    await app.noErrors();
  });

  test('valeurs vides ou nulles ignorées', async ({ page }) => {
    const app = await openApp(page);
    await page.locator('#b').fill('0');
    await page.locator('#b').fill('');
    expect(await state(page)).toMatchObject({ b: 0.81, d: 0.27 });
    await app.noErrors();
  });

  test('vitesse : à droite plus rapide, ratio gardé, retour exact à 100 %', async ({ page }) => {
    const app = await openApp(page);
    await setRange(page, '#speed', 120);
    await expect(page.locator('#sv')).toHaveText('120');
    expect(await state(page)).toMatchObject({ b: 0.69, d: 0.23 });
    await setRange(page, '#speed', 60);
    expect(await state(page)).toMatchObject({ b: 1.35, d: 0.45 });
    await setRange(page, '#speed', 100);
    expect(await state(page)).toMatchObject({ b: 0.81, d: 0.27 });
    // modifier une durée remet la vitesse à 100 %
    await setRange(page, '#speed', 110);
    await page.locator('#b').fill('0.9');
    await expect(page.locator('#sv')).toHaveText('100');
    await app.noErrors();
  });

  test('valeurs par défaut du mode courant uniquement', async ({ page }) => {
    const app = await openApp(page);
    await page.locator('#b').fill('0.9');
    await page.getByRole('button', { name: /Putting/ }).click();
    await page.locator('#b').fill('0.8');
    await page.locator('#reset').click();
    await expect(page.locator('#b')).toHaveValue('0.60');
    await page.getByRole('button', { name: /Grand jeu/ }).click();
    await expect(page.locator('#b')).toHaveValue('0.90');
    await app.noErrors();
  });

  test('pause entre deux swings de 1 à 8 s', async ({ page }) => {
    const app = await openApp(page);
    await expect(page.locator('#pause')).toHaveAttribute('min', '1');
    await expect(page.locator('#pause')).toHaveAttribute('max', '8');
    await setRange(page, '#pause', 5.5);
    await expect(page.locator('#pv')).toHaveText('5.5');
    expect((await state(page)).pause).toBe(5.5);
    await app.noErrors();
  });
});

test.describe('mémorisation (localStorage)', () => {
  test('réglages conservés après rechargement', async ({ page }) => {
    const app = await openApp(page);
    await page.locator('#b').fill('0.96');
    await page.getByRole('button', { name: /Putting/ }).click();
    await page.locator('#lock').uncheck();
    await setRange(page, '#pause', 6);
    const s = await stored(page, 'tg2');
    expect(s).toMatchObject({ mode: 'putt', lock: false, pause: 6, unit: 'img' });
    expect(s.grand.d / 30).toBeCloseTo(0.32, 6);
    await page.reload();
    await expect(page.locator('#mt')).toHaveText('Métronome · putting 2:1');
    await expect(page.locator('#lock')).not.toBeChecked();
    await expect(page.locator('#pv')).toHaveText('6');
    await page.getByRole('button', { name: /Grand jeu/ }).click();
    await expect(page.locator('#b')).toHaveValue('0.96');
    await expect(page.locator('#d')).toHaveValue('0.32');
    await app.noErrors();
  });

  // BUG CONNU : 0,90 / 0,30 s vaut 27 / 9 « images », exactement l'ancienne valeur
  // par défaut que la migration (début du script, [[27,9,"grand"],…]) remplace
  // par 0,81 / 0,27 à chaque chargement. Idem 0,60 / 0,60 au putting.
  // Retirer « fixme » une fois la migration corrigée (ne la faire qu'une fois).
  test.fixme('BUG : un réglage de 0,90 / 0,30 s est perdu au rechargement', async ({ page }) => {
    await openApp(page);
    await page.locator('#b').fill('0.9');
    await page.reload();
    await expect(page.locator('#b')).toHaveValue('0.90');
  });

  test('anciennes valeurs par défaut migrées vers les nouvelles', async ({ page }) => {
    const app = await openApp(page, {
      tg2: { mode: 'grand', unit: 'img', pause: 3, lock: true, sp: 100, grand: { b: 27, d: 9 }, putt: { b: 20, d: 10 } },
    });
    await expect(page.locator('#b')).toHaveValue('0.81');
    await page.getByRole('button', { name: /Putting/ }).click();
    await expect(page.locator('#b')).toHaveValue('0.60');
    await app.noErrors();
  });

  test('ancien format en millisecondes converti', async ({ page }) => {
    const app = await openApp(page, {
      tg2: { mode: 'grand', unit: 'ms', pause: 3, lock: true, grand: { b: 1200, d: 400 }, putt: { b: 600, d: 300 } },
    });
    await expect(page.locator('#b')).toHaveValue('1.20');
    await expect(page.locator('#d')).toHaveValue('0.40');
    await app.noErrors();
  });

  test('stockage corrompu : la page démarre quand même', async ({ page }) => {
    const app = await openApp(page, { tg2: '{pas du json', tg_hist: 'n’importe quoi', tg_free: 'abc' });
    await expect(page.locator('#b')).toHaveValue('0.81');
    await expect(page.locator('#free')).toContainText('Les 3 premières analyses vidéo sont gratuites');
    await app.noErrors();
  });
});

test.describe('son', () => {
  test('Démarrer / Arrêter : trois temps affichés en rythme', async ({ page }) => {
    const app = await openApp(page);
    await page.locator('#go').click();
    await expect(page.locator('#go')).toHaveText('■ Arrêter');
    const seen = new Set();
    for (let i = 0; i < 200 && seen.size < 3; i++) {
      const v = (await page.locator('#flash').textContent()).trim();
      if (v) seen.add(v);
      await page.waitForTimeout(40);
    }
    expect([...seen].filter(Boolean).sort()).toEqual(['Départ', 'Impact', 'Sommet']);
    // planification : départ, puis sommet après la montée, impact après la descente
    const t = await page.evaluate(() => ({ running, ctx: !!ctx, state: ctx.state }));
    expect(t).toMatchObject({ running: true, ctx: true });
    await page.locator('#go').click();
    await expect(page.locator('#go')).toHaveText('▶ Démarrer');
    await expect(page.locator('#flash')).toHaveText(/^\s*$/);
    expect(await page.evaluate(() => running)).toBe(false);
    await app.noErrors();
  });

  test('bips planifiés aux bons instants (660 / 880 / 1320 Hz)', async ({ page }) => {
    const app = await openApp(page);
    await page.evaluate(() => {
      window.__tones = [];
      const orig = tone;
      window.tone = function (t, f, len) { window.__tones.push({ t, f, len }); return orig(t, f, len); };
    });
    await page.locator('#go').click();
    await page.waitForTimeout(400);
    await page.locator('#go').click();
    const tones = await page.evaluate(() => window.__tones);
    expect(tones.length).toBeGreaterThanOrEqual(3);
    const [a, b, c] = tones;
    expect([a.f, b.f, c.f]).toEqual([660, 880, 1320]);
    expect(b.t - a.t).toBeCloseTo(0.81, 6);
    expect(c.t - b.t).toBeCloseTo(0.27, 6);
    expect(c.len).toBe(0.25);
    if (tones[3]) expect(tones[3].t - a.t).toBeCloseTo(0.81 + 0.27 + 3, 6); // pause de 3 s
    await app.noErrors();
  });
});

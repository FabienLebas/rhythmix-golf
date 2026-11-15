// Site : langues (français, anglais, espagnol). Les autres fichiers de tests
// tournent en français (locale fr-FR) ; ici on change la langue du navigateur.
const { test, expect } = require('@playwright/test');
const { openApp, SWING_VIDEO } = require('./helpers');

const T1 = new Date('2026-03-14T10:00:00+01:00').getTime();
const e = (id, t, b, d) => ({ id, t, b, d, r: b / d });
const NB = ' ';

async function analyse(page, done) {
  await page.setInputFiles('#vf', SWING_VIDEO);
  await expect(page.locator('#vhint')).toContainText(done, { timeout: 120_000 });
}

test.describe('anglais (en-US)', () => {
  test.use({ locale: 'en-US' });

  test('page, métronome (point décimal) et dollars', async ({ page }) => {
    const app = await openApp(page);
    await expect(page.locator('html')).toHaveAttribute('lang', 'en');
    await expect(page.locator('#modes button').first()).toHaveText('🏌️ Full swing3 : 1 tempo');
    await expect(page.locator('#mt')).toHaveText('Metronome · full swing 3:1');
    await expect(page.locator('#vt')).toHaveText('Analyze a full swing');
    await expect(page.locator('#info')).toHaveText('Backswing 0.81 s · Downswing 0.27 s · Ratio 3.00:1 · Swing 1.08 s');
    await expect(page.locator('label.small', { hasText: 'Swing speed' })).toContainText('Swing speed: 100%');
    await expect(page.locator('label.small', { hasText: 'Pause between swings' })).toContainText('Pause between swings: 3 s');
    await expect(page.locator('#go')).toHaveText('▶ Start');
    await expect(page.locator('#k1')).toHaveText('Start —');
    await expect(page.locator('#k2')).toHaveText('Top —');
    await expect(page.locator('#k3')).toHaveText('Impact —');
    await expect(page.locator('#hbody')).toContainText('No analysis yet.');
    await expect(page.locator('#free')).toHaveText(
      '🎁 The first 3 video analyses are free. After that, get Rhythmix Golf in the mobile app, '
      + 'for the price of a bucket of range balls: $2.99 launch price, then $4.99, as a single payment.');
    await app.noErrors();
  });

  test('putting, historique et message d’effacement', async ({ page }) => {
    const app = await openApp(page, { tg_hist: { grand: [e('a', T1, 1050, 300)], putt: [] } });
    await expect(page.locator('#hbody li')).toHaveText([/Mar 14\s*·\s*3\.5:1\s*Too slow/]);
    await expect(page.locator('#hbody svg')).toHaveAttribute('aria-label', 'Tempo ratio over time');
    await expect(page.locator('#hbody svg text.zl')).toHaveText(['Too slow', 'Too fast', 'target 3:1']);
    let msg = '';
    page.on('dialog', (d) => { msg = d.message(); d.dismiss(); });
    await page.click('#hclear');
    expect(msg).toBe('Clear the full swing history?');
    await page.click('#modes button[data-m="putt"]');
    await expect(page.locator('#mt')).toHaveText('Metronome · putting 2:1');
    await expect(page.locator('#ht')).toHaveText('History · putting');
    await expect(page.locator('#info')).toHaveText('Backswing 0.60 s · Downswing 0.30 s · Ratio 2.00:1 · Swing 0.90 s');
    await app.noErrors();
  });

  test('gratuité : il en reste 1, puis épuisée', async ({ page }) => {
    await openApp(page, { tg_free: '2' });
    await expect(page.locator('#free')).toContainText('Free analyses: 1 of 3 left.');
    await page.evaluate(() => { freeUsed = 3; freeRender(); });
    await expect(page.locator('#free')).toContainText('Your 3 free analyses have been used.');
    await expect(page.locator('#free')).toContainText('The metronome stays free here.');
  });

  test('analyse d’une vidéo : repères, conseil et métronome en anglais', async ({ page }) => {
    const app = await openApp(page);
    await analyse(page, 'Detection complete');
    await expect(page.locator('#vhint')).toContainText('impact found from the sound of the ball');
    await expect(page.locator('#vhint')).toContainText('Check each marker');
    await expect(page.locator('#vres')).toContainText('Your tempo: backswing');
    await expect(page.locator('#vsug')).toContainText('The metronome is set to your target full-swing tempo 3:1');
    await expect(page.locator('#vmeta')).toHaveText('Video: 270 × 480 · 60 frames/s · 3.0 s');
    await expect(page.locator('#k1')).toHaveText(/^Start · frame \d+$/);
    await expect(page.locator('#vbadge')).toHaveText(/^Frame \d+ \/ 179 · \d+\.\d{3} s$/);
    await app.noErrors();
  });

  test('fichier illisible : message en anglais', async ({ page }) => {
    await openApp(page);
    await page.setInputFiles('#vf', { name: 'x.mp4', mimeType: 'video/mp4', buffer: Buffer.from('pas une vidéo') });
    await expect(page.locator('#vres')).toContainText(/doesn’t display correctly|Can’t play/);
  });
});

test.describe('anglais britannique (en-GB)', () => {
  test.use({ locale: 'en-GB' });
  test('livres', async ({ page }) => {
    await openApp(page);
    await expect(page.locator('#free')).toContainText('£2.99 launch price, then £4.99');
  });
});

test.describe('espagnol (es-ES)', () => {
  test.use({ locale: 'es-ES' });

  test('page, métronome (virgule) et euros', async ({ page }) => {
    const app = await openApp(page);
    await expect(page.locator('html')).toHaveAttribute('lang', 'es');
    await expect(page.locator('#mt')).toHaveText('Metrónomo · swing completo 3:1');
    await expect(page.locator('#vt')).toHaveText('Analizar un swing completo');
    await expect(page.locator('#info')).toHaveText('Subida 0,81 s · Bajada 0,27 s · Proporción 3,00:1 · Swing 1,08 s');
    await expect(page.locator('#go')).toHaveText('▶ Iniciar');
    await expect(page.locator('#k1')).toHaveText('Inicio —');
    await expect(page.locator('#k2')).toHaveText('Cima —');
    await expect(page.locator('#k3')).toHaveText('Impacto —');
    await expect(page.locator('#hbody')).toContainText('Todavía no hay ningún análisis.');
    await expect(page.locator('#free')).toHaveText(
      '🎁 Los primeros 3 análisis de video son gratis. Después, consigue Rhythmix Golf en la app móvil, '
      + `por el precio de un cubo de bolas: 2,99${NB}€ de precio de lanzamiento, luego 4,99${NB}€, en un solo pago.`);
    await app.noErrors();
  });

  test('historique : date et ratio à l’espagnole', async ({ page }) => {
    await openApp(page, { tg_hist: { grand: [e('a', T1, 1050, 300)], putt: [] } });
    await expect(page.locator('#hbody li')).toHaveText([/14 mar\s*·\s*3,5:1\s*Demasiado lento/]);
  });

  test('analyse d’une vidéo en espagnol', async ({ page }) => {
    const app = await openApp(page);
    await analyse(page, 'Detección terminada');
    await expect(page.locator('#vres')).toContainText('Tu ritmo: subida');
    await expect(page.locator('#vmeta')).toHaveText('Video: 270 × 480 · 60 fotogramas/s · 3,0 s');
    await expect(page.locator('#k3')).toHaveText(/^Impacto · fotograma \d+$/);
    await app.noErrors();
  });
});

const MARKETS = [
  // [langue du navigateur, texte attendu dans l'encadré de gratuité]
  ['en-CA', 'CA$3.99 launch price, then CA$6.99'],
  ['fr-CA', `3,99${NB}CA$ en prix de lancement, puis 6,99${NB}CA$`],
  ['en-AU', 'A$4.49 launch price, then A$7.99'],
  ['fr-CH', `2,90${NB}CHF en prix de lancement, puis 4,90${NB}CHF`],
  ['en-CH', `CHF${NB}2.90 launch price, then CHF${NB}4.90`],
  ['es-MX', `59${NB}MX$ de precio de lanzamiento, luego 99${NB}MX$`],
  ['ja-JP', '¥480 launch price, then ¥800'],
  ['ko-KR', '₩4,400 launch price, then ₩6,900'],
  ['pt-BR', 'R$14.90 launch price, then R$24.90'],
  ['es-ES', `2,99${NB}€ de precio de lanzamiento, luego 4,99${NB}€`],
];
// Le WebKit de Playwright remplace ces langues par la plus proche qu'il connaît
// (en-CH → en-GB, ja-JP → ja sans pays, fr-CH → fr) : le pays n'arrive pas à la
// page, ce qui ne dit rien du site. Ces marchés restent testés sur Chromium.
const WEBKIT_DROPS_REGION = ['fr-CH', 'en-CH', 'ja-JP'];

for (const [locale, text] of MARKETS) {
  test.describe(`marché ${locale}`, () => {
    test.use({ locale });
    test.skip(({ browserName }) => browserName === 'webkit' && WEBKIT_DROPS_REGION.includes(locale),
      'WebKit (Playwright) ne transmet pas le pays de cette langue');
    test('prix de lancement puis prix normal dans la devise du pays', async ({ page }) => {
      await openApp(page);
      await expect(page.locator('#free')).toContainText(text);
    });
  });
}

test.describe('pays sans prix annoncé', () => {
  test.use({ locale: 'sv-SE' });
  test('suédois : anglais, aucun prix (affiché par le store)', async ({ page }) => {
    await openApp(page);
    await expect(page.locator('html')).toHaveAttribute('lang', 'en');
    await expect(page.locator('#free')).toHaveText(
      '🎁 The first 3 video analyses are free. After that, get Rhythmix Golf in the mobile app, '
      + 'for the price of a bucket of range balls, as a single payment.');
  });
});

test.describe('langue non traduite', () => {
  test.use({ locale: 'de-DE' });
  test('allemand : anglais', async ({ page }) => {
    await openApp(page);
    await expect(page.locator('html')).toHaveAttribute('lang', 'en');
    await expect(page.locator('#mt')).toHaveText('Metronome · full swing 3:1');
  });
});

test.describe('liste de langues préférées', () => {
  test('première langue traduite de la liste (allemand, espagnol, français → espagnol)', async ({ page }) => {
    await page.addInitScript(() => {
      Object.defineProperty(navigator, 'languages', { get: () => ['de-DE', 'es-ES', 'fr-FR'] });
    });
    await openApp(page);
    await expect(page.locator('html')).toHaveAttribute('lang', 'es');
    await expect(page.locator('#mt')).toHaveText('Metrónomo · swing completo 3:1');
  });
});

test.describe('français', () => {
  test.use({ locale: 'fr-BE' });
  test('français de Belgique : euros', async ({ page }) => {
    await openApp(page);
    await expect(page.locator('#free')).toContainText(`2,99${NB}€ en prix de lancement, puis 4,99${NB}€`);
  });
});

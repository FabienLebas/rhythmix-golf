// Site : historique du tempo et gratuité (3 analyses, puis l'app mobile).
const { test, expect } = require('@playwright/test');
const { openApp, stored } = require('./helpers');

const T1 = new Date('2026-03-14T10:00:00+01:00').getTime();
const T2 = new Date('2026-11-02T10:00:00+01:00').getTime();
const e = (id, t, b, d) => ({ id, t, b, d, r: b / d });

test.describe('historique', () => {
  test('vide : explication, pas de bouton Effacer', async ({ page }) => {
    const app = await openApp(page);
    await expect(page.locator('#hbody')).toContainText('Aucune analyse pour l’instant');
    await expect(page.locator('#hclear')).toBeHidden();
    await app.noErrors();
  });

  test('graphique, zones, cible et liste des analyses (plus récente en haut)', async ({ page }) => {
    const app = await openApp(page, {
      tg_hist: { grand: [e('a', T1, 1050, 300), e('b', T1, 900, 300), e('c', T2, 750, 300)], putt: [] },
    });
    const svg = page.locator('#hbody svg');
    await expect(svg).toHaveAttribute('aria-label', 'Évolution du ratio de tempo');
    await expect(svg.locator('circle')).toHaveCount(3);
    await expect(svg.locator('polyline')).toHaveCount(1);
    await expect(svg.locator('text.zl')).toHaveText(['Trop lent', 'Trop rapide', 'cible 3:1']);
    expect(await svg.locator('circle').evaluateAll((c) => c.map((x) => x.getAttribute('fill'))))
      .toEqual(['#d6453d', '#2f9e5a', '#e08a1e']);
    await expect(page.locator('#hbody li')).toHaveText([
      /2 nov\.\s*·\s*2,5:1\s*Trop rapide/,
      /14 mars\s*·\s*3,0:1\s*Dans la cible/,
      /14 mars\s*·\s*3,5:1\s*Trop lent/,
    ]);
    await expect(page.locator('#hclear')).toBeVisible();
    await app.noErrors();
  });

  test('tolérance ± 0,15 autour de la cible', async ({ page }) => {
    const app = await openApp(page);
    expect(await page.evaluate(() => [hStatus(3.15, 'grand'), hStatus(2.85, 'grand'), hStatus(3.16, 'grand'),
      hStatus(2.84, 'grand'), hStatus(2.1, 'putt'), hStatus(2.2, 'putt'), hStatus(1.8, 'putt')]))
      .toEqual(['ok', 'ok', 'slow', 'fast', 'ok', 'slow', 'fast']);
    await app.noErrors();
  });

  test('8 dernières analyses listées au maximum', async ({ page }) => {
    const app = await openApp(page, {
      tg_hist: { grand: Array.from({ length: 12 }, (_, i) => e('v' + i, T1, 900, 300)), putt: [] },
    });
    await expect(page.locator('#hbody li')).toHaveCount(8);
    await expect(page.locator('#hbody svg circle')).toHaveCount(12);
    await app.noErrors();
  });

  test('un historique par mode', async ({ page }) => {
    const app = await openApp(page, {
      tg_hist: { grand: [e('a', T1, 900, 300)], putt: [e('b', T1, 660, 300), e('c', T1, 600, 300)] },
    });
    await expect(page.locator('#hbody li')).toHaveCount(1);
    await page.getByRole('button', { name: /Putting/ }).click();
    await expect(page.locator('#ht')).toHaveText('Historique · putting');
    await expect(page.locator('#hbody li')).toHaveText([/2,0:1\s*Dans la cible/, /2,2:1\s*Trop lent/]);
    await expect(page.locator('#hbody svg text.zl').last()).toHaveText('cible 2:1');
    await app.noErrors();
  });

  test('effacer : confirmation ; Annuler conserve ; OK vide le mode courant seulement', async ({ page }) => {
    const app = await openApp(page, {
      tg_hist: { grand: [e('a', T1, 900, 300)], putt: [e('b', T1, 600, 300)] },
    });
    let msg = '';
    page.once('dialog', (d) => { msg = d.message(); d.dismiss(); });
    await page.locator('#hclear').click();
    expect(msg).toBe('Effacer l’historique du grand jeu ?');
    await expect(page.locator('#hbody li')).toHaveCount(1);
    page.once('dialog', (d) => d.accept());
    await page.locator('#hclear').click();
    await expect(page.locator('#hbody')).toContainText('Aucune analyse pour l’instant');
    const h = await stored(page, 'tg_hist');
    expect(h.grand).toEqual([]);
    expect(h.putt.length).toBe(1);
    await app.noErrors();
  });

  test('enregistrement : un point par vidéo et par mode, mis à jour (pas de doublon), 200 maximum', async ({ page }) => {
    const app = await openApp(page);
    const h = await page.evaluate(() => {
      curId = 1; hRecord(900, 300); hRecord(950, 300); // retouche des repères
      curId = 2; hRecord(600, 300);
      S.mode = 'putt'; curId = 1; hRecord(600, 300);
      S.mode = 'grand';
      for (let i = 0; i < 205; i++) { curId = 100 + i; hRecord(900, 300); }
      return JSON.parse(localStorage.getItem('tg_hist'));
    });
    expect(h.grand.length).toBe(200);
    expect(h.grand[0].id).toBe('105-grand');
    expect(h.putt.map((x) => x.id)).toEqual(['1-putt']);
    await app.noErrors();
  });

  test('entrées invalides ignorées au chargement', async ({ page }) => {
    const app = await openApp(page, {
      tg_hist: { grand: [e('a', T1, 900, 300), null, { id: 'x', t: T1, b: 1, d: 1, r: -1 }], putt: 'bof' },
    });
    await expect(page.locator('#hbody li')).toHaveCount(1);
    await app.noErrors();
  });
});

test.describe('gratuité', () => {
  test('aucune analyse utilisée', async ({ page }) => {
    const app = await openApp(page);
    await expect(page.locator('#free')).toHaveText(
      '🎁 Les 3 premières analyses vidéo sont gratuites. Ensuite, retrouve Rhythmix Golf dans l’app mobile, '
      + 'pour le prix d’un seau de balles : 2,99 € en prix de lancement, puis 4,99 €, en un seul paiement.');
    await app.noErrors();
  });

  test('il en reste 1 sur 3', async ({ page }) => {
    const app = await openApp(page, { tg_free: '2' });
    await expect(page.locator('#free')).toContainText('🎁 Analyses gratuites : il t’en reste 1 sur 3. Ensuite, télécharge l’app mobile');
    await app.noErrors();
  });

  test('épuisé : invitation à l’app mobile, le sélecteur de fichier ne s’ouvre plus', async ({ page }) => {
    const app = await openApp(page, { tg_free: '3' });
    await expect(page.locator('#free')).toContainText('🔒 Tes 3 analyses gratuites sont utilisées.');
    await expect(page.locator('#free')).toContainText('Le métronome reste gratuit ici.');
    let opened = false;
    page.on('filechooser', () => { opened = true; });
    await page.locator('#vf').click();
    await page.waitForTimeout(500);
    expect(opened).toBe(false);
    await app.noErrors();
  });

  test('le métronome reste utilisable quand la gratuité est épuisée', async ({ page }) => {
    const app = await openApp(page, { tg_free: '5' });
    await page.locator('#go').click();
    await expect(page.locator('#go')).toHaveText('■ Arrêter');
    await page.locator('#go').click();
    await app.noErrors();
  });
});

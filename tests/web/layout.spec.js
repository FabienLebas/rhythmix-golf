// Site : mise en page téléphone / ordinateur, thème sombre, accessibilité de base.
const { test, expect } = require('@playwright/test');
const { openApp } = require('./helpers');

test('aucun défilement horizontal', async ({ page }) => {
  const app = await openApp(page);
  const { sw, cw } = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }));
  expect(sw).toBeLessThanOrEqual(cw);
  await app.noErrors();
});

test('téléphone : une colonne, dans l’ordre mode, métronome, vidéo, historique', async ({ page }, info) => {
  test.skip(info.project.name === 'ordinateur', 'mise en page mobile');
  const app = await openApp(page);
  const ys = await page.evaluate(() => ['#modes', '#mt', '#vt', '#ht'].map((s) => document.querySelector(s).getBoundingClientRect().top));
  expect(ys).toEqual([...ys].sort((a, b) => a - b));
  const xs = await page.evaluate(() => ['#mt', '#vt'].map((s) => Math.round(document.querySelector(s).closest('.card').getBoundingClientRect().left)));
  expect(xs[0]).toBe(xs[1]);
  await expect(page.locator('.desk')).toBeHidden();
  await app.noErrors();
});

test('ordinateur : métronome et vidéo côte à côte, historique en pleine largeur', async ({ page }, info) => {
  test.skip(info.project.name !== 'ordinateur', 'mise en page large');
  const app = await openApp(page);
  const r = await page.evaluate(() => Object.fromEntries(['#mt', '#vt', '#ht'].map((s) => {
    const b = document.querySelector(s).closest('.card').getBoundingClientRect();
    return [s, { x: b.left, y: b.top, w: b.width }];
  })));
  expect(Math.abs(r['#mt'].y - r['#vt'].y)).toBeLessThan(2);
  expect(r['#vt'].x).toBeGreaterThan(r['#mt'].x + 300);
  expect(r['#ht'].w).toBeGreaterThan(r['#vt'].w);
  await expect(page.locator('.desk')).toBeVisible();
  await app.noErrors();
});

test('thème sombre : couleurs adaptées, texte lisible', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  const app = await openApp(page);
  const bg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
  expect(bg).toBe('rgb(18, 26, 20)');
  await page.emulateMedia({ colorScheme: 'light' });
  expect(await page.evaluate(() => getComputedStyle(document.body).backgroundColor)).toBe('rgb(246, 247, 244)');
  await app.noErrors();
});

test('page autonome : aucune ressource externe chargée', async ({ page }) => {
  const external = [];
  page.on('request', (r) => { if (!/^(http:\/\/127\.0\.0\.1|data:|blob:)/.test(r.url())) external.push(r.url()); });
  const app = await openApp(page);
  await page.waitForLoadState('networkidle');
  expect(external).toEqual([]);
  await expect(page.locator('meta[name=viewport]')).toHaveCount(1);
  await expect(page.locator('html')).toHaveAttribute('lang', 'fr');
  await app.noErrors();
});

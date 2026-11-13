// Outils communs aux tests du site.
const { expect } = require('@playwright/test');
const path = require('node:path');

const FIXTURES = path.join(__dirname, '..', 'fixtures');
const SWING_VIDEO = path.join(FIXTURES, 'swing_60fps.mp4');
const TRUTH = require(path.join(FIXTURES, 'swing_truth.json'));

/**
 * Ouvre le site avec un stockage local donné (réglages, historique, compteur).
 * Toute erreur JavaScript de la page fait échouer le test.
 */
async function openApp(page, storage = {}) {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.addInitScript((s) => {
    // une seule fois par onglet : un rechargement garde ce que la page a enregistré
    if (sessionStorage.getItem('__init')) return;
    sessionStorage.setItem('__init', '1');
    localStorage.clear();
    for (const [k, v] of Object.entries(s)) localStorage.setItem(k, typeof v === 'string' ? v : JSON.stringify(v));
  }, storage);
  await page.goto('/index.html');
  await expect(page.locator('#info')).not.toBeEmpty();
  return {
    errors,
    /** À appeler en fin de test. */
    async noErrors() { expect(errors, 'erreurs JavaScript sur la page').toEqual([]); },
  };
}

/** Lit l'état interne du site (variables globales du script). */
const state = (page) => page.evaluate(() => ({
  mode: S.mode, lock: S.lock, pause: S.pause, sp: S.sp,
  b: +(S[S.mode].b / 30).toFixed(4), d: +(S[S.mode].d / 30).toFixed(4),
}));

const stored = (page, key) => page.evaluate((k) => JSON.parse(localStorage.getItem(k) || 'null'), key);

/** Règle un curseur (input range) comme un utilisateur. */
async function setRange(page, sel, value) {
  await page.locator(sel).evaluate((el, v) => { el.value = String(v); el.dispatchEvent(new Event('input', { bubbles: true })); }, value);
}

/** Charge la vidéo de swing de référence et attend la fin de la détection. */
async function analyseSwing(page, file = SWING_VIDEO) {
  await page.setInputFiles('#vf', file);
  await expect(page.locator('#vhint')).toContainText('Détection terminée', { timeout: 120_000 });
}

const markers = (page) => page.evaluate(() => M.slice());

module.exports = { openApp, state, stored, setRange, analyseSwing, markers, SWING_VIDEO, TRUTH, FIXTURES };

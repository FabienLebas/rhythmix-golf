// Tests de non-régression du site (index.html) avec Playwright.
//   npm test                       Chromium ordinateur + Chromium mobile
//   PW_WEBKIT=1 npm test           ajoute WebKit (moteur de Safari / iPhone)
const { defineConfig, devices } = require('@playwright/test');

const PORT = 4173;

const projects = [
  { name: 'ordinateur', use: { ...devices['Desktop Chrome'], viewport: { width: 1280, height: 900 } } },
  // l'algorithme de détection ne dépend pas de l'écran : testé une fois
  { name: 'mobile', use: { ...devices['Pixel 7'] }, testIgnore: /detection\.spec/ },
];
if (process.env.PW_WEBKIT) {
  projects.push({ name: 'iphone-webkit', use: { ...devices['iPhone 13'] }, testIgnore: /detection\.spec/ });
}

module.exports = defineConfig({
  testDir: 'tests/web',
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    locale: 'fr-FR',
    timezoneId: 'Europe/Paris',
    trace: 'off',
  },
  projects,
  webServer: {
    command: `node tests/web/serve.mjs ${PORT}`,
    url: `http://127.0.0.1:${PORT}/index.html`,
    reuseExistingServer: !process.env.CI,
  },
});

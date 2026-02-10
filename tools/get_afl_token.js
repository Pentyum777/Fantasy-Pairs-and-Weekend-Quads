const { chromium } = require('playwright');
const fs = require('fs');

(async () => {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  console.log("Opening AFL website…");

  // Capture network requests
  context.on('response', async (response) => {
    const url = response.url();

    if (url.includes("WMCTok")) {
      try {
        const body = await response.json();
        const token = body.token || body.authHeader;

        if (token) {
          console.log("✅ Captured token:", token);

          fs.writeFileSync(
            'token.json',
            JSON.stringify({ authHeader: `Bearer ${token}` }, null, 2)
          );

          console.log("💾 Saved to token.json");
          await browser.close();
          process.exit(0);
        }
      } catch (err) {
        // ignore non‑JSON responses
      }
    }
  });

  await page.goto("https://www.afl.com.au", { waitUntil: "networkidle" });

  console.log("Waiting for WMCTok request…");
})();
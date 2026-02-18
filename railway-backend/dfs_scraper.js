import playwright from "playwright";

let browser = null;
let page = null;

export async function initScraper() {
  if (!browser) {
    browser = await playwright.chromium.launch({
      headless: true,
      args: ["--disable-gpu", "--no-sandbox"],
    });

    page = await browser.newPage();

    // Block heavy resources
    await page.route("**/*", (route) => {
      const type = route.request().resourceType();
      if (["image", "font", "media", "stylesheet"].includes(type)) {
        route.abort();
      } else {
        route.continue();
      }
    });
  }
}

export async function scrapeDFS(dfsId) {
  await initScraper();

  const url = `https://dfsaustralia.com/afl-game-stats/?gameId=${dfsId}`;

  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 15000 });

    await page.waitForSelector("table tbody tr", { timeout: 8000 });

    const players = await page.$$eval("table tbody tr", (rows) => {
      const parse = (v) => parseInt((v || "0").replace(/\s+/g, ""), 10);

      return rows
        .map((row) => {
          const cells = Array.from(row.querySelectorAll("td"));
          if (cells.length === 0) return null;

          const link = cells[0].querySelector("a");
          const name = link?.innerText.trim() || cells[0].innerText.trim();
          const href = link?.getAttribute("href") || "";
          const idMatch = href.match(/playerId=([^&]+)/);
          const playerId = idMatch ? idMatch[1] : name;

          const kicks = parse(cells[1].innerText);
          const handballs = parse(cells[2].innerText);
          const marks = parse(cells[3].innerText);
          const tackles = parse(cells[4].innerText);
          const hitouts = parse(cells[5].innerText);
          const freesFor = parse(cells[6].innerText);
          const freesAgainst = parse(cells[7].innerText);
          const goals = parse(cells[8].innerText);
          const behinds = parse(cells[9].innerText);
          const tog = parse(cells[10].innerText);

          const fantasyPoints =
            kicks * 3 +
            handballs * 2 +
            marks * 3 +
            tackles * 4 +
            hitouts * 1 +
            freesFor * 1 +
            freesAgainst * -3 +
            goals * 6 +
            behinds * 1;

          return {
            id: playerId,
            name,
            team: "",
            stats: {
              fantasyPoints,
              kicks,
              handballs,
              marks,
              tackles,
              hitouts,
              freesFor,
              freesAgainst,
              goals,
              behinds,
              timeOnGroundPercentage: tog,
            },
          };
        })
        .filter(Boolean);
    });

    return { players, meta: {} };
  } catch (err) {
    console.error("Playwright DFS scrape failed:", err);
    return { players: [], meta: {} };
  }
}

export async function shutdownScraper() {
  if (browser) {
    await browser.close();
    browser = null;
    page = null;
  }
}
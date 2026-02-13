import { chromium } from "playwright";

let browser = null;

// Launch or reuse browser
async function getBrowser() {
  if (!browser || browser.isConnected() === false) {
    browser = await chromium.launch({
      headless: true,
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });
  }
  return browser;
}

// Safe navigation with auto-restart
async function safeGoto(page, url) {
  try {
    await page.goto(url, {
      waitUntil: "domcontentloaded",
      timeout: 15000,
    });
    return page;
  } catch (err) {
    console.error("Goto failed, restarting browser:", err);

    try {
      await browser?.close();
    } catch (_) {}

    browser = await chromium.launch({
      headless: true,
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });

    const newPage = await browser.newPage();
    await newPage.goto(url, {
      waitUntil: "domcontentloaded",
      timeout: 15000,
    });

    return newPage;
  }
}

export async function scrapeDFS(dfsId) {
  const url = `https://dfsaustralia.com/afl-game-stats/?gameId=${dfsId}`;

  const browser = await getBrowser();
  let page = await browser.newPage();

  page = await safeGoto(page, url);

  // Ensure table exists
  try {
    await page.waitForSelector("table.dataTable tbody tr", {
      timeout: 8000,
    });
  } catch (_) {
    console.warn("No table rows found — returning empty stats");
    return { players: [], meta: {} };
  }

  // Extract players
  const players = await page.$$eval("table.dataTable tbody tr", rows =>
    rows
      .map(row => {
        const cells = [...row.querySelectorAll("td")];
        if (cells.length === 0) return null;

        const nameCell = cells[0];
        const link = nameCell.querySelector("a");

        const name = link?.innerText.trim() || nameCell.innerText.trim() || "";
        const href = link?.getAttribute("href") || "";

        // DFS uses AFL IDs directly (CD_Ixxxxxx)
        const idMatch = href.match(/playerId=([^&]+)/);
        const playerId = idMatch ? idMatch[1] : "";

        const startingPosition = row.getAttribute("data-startingposition") || "";
        const benchReason = row.getAttribute("data-benchreason") || "";

        const isSubOrOut =
          startingPosition === "SUB" ||
          benchReason === "Sub Tactical" ||
          benchReason === "Sub Injured" ||
          benchReason === "Injured" ||
          benchReason === "OUT";

        if (isSubOrOut) return null;

        const parse = v => parseInt(v || "0", 10);

        const kicks = parse(cells[1]?.innerText);
        const handballs = parse(cells[2]?.innerText);
        const marks = parse(cells[3]?.innerText);
        const tackles = parse(cells[4]?.innerText);
        const hitouts = parse(cells[5]?.innerText);
        const freesFor = parse(cells[6]?.innerText);
        const freesAgainst = parse(cells[7]?.innerText);
        const goals = parse(cells[8]?.innerText);
        const behinds = parse(cells[9]?.innerText);

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
          id: playerId || name,
          name,
          team: "",   // <-- will be filled in below
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
            timeOnGroundPercentage: parse(cells[10]?.innerText),
          },
        };
      })
      .filter(Boolean)
  );

  // ⭐ Robust metadata extraction using page text
  const meta = await page.evaluate(() => {
    const text = document.body.innerText || "";

    // Score pattern like "88 - 74"
    const scoreMatch = text.match(/(\d+)\s*-\s*(\d+)/);
    const homeScore = scoreMatch ? parseInt(scoreMatch[1], 10) : 0;
    const awayScore = scoreMatch ? parseInt(scoreMatch[2], 10) : 0;

    // Quarter: Q1/Q2/Q3/Q4 or Final
    const quarterMatch = text.match(/\b(Q[1-4]|Final)\b/i);
    const quarter = quarterMatch ? quarterMatch[1] : "";

    // Clock: 12:34
    const clockMatch = text.match(/\b(\d{1,2}:\d{2})\b/);
    const clock = clockMatch ? clockMatch[1] : "";

    return {
      homeScore,
      awayScore,
      quarter,
      clock,
    };
  });

  await page.close();

  return { players, meta };
}
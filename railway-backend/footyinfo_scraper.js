import { chromium } from "playwright";

let browser = null;

async function getBrowser() {
  if (!browser || browser.isConnected() === false) {
    browser = await chromium.launch({
      headless: true,
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });
  }
  return browser;
}

async function safeGoto(page, url) {
  try {
    await page.goto(url, {
      waitUntil: "domcontentloaded",
      timeout: 15000,
    });
    return page;
  } catch (err) {
    console.error("FootyInfo goto failed, restarting browser:", err);

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

/**
 * Scrape match metadata from FootyInfo using Playwright.
 * @param {string|number} footyInfoId - numeric ID at the end of the URL
 */
export async function scrapeFootyInfoMeta(footyInfoId) {
  const url = `https://www.footyinfo.com/match/${footyInfoId}`;

  const browser = await getBrowser();
  let page = await browser.newPage();
  page = await safeGoto(page, url);

  const meta = await page.evaluate(() => {
    const text = document.body.innerText || "";
    const lower = text.toLowerCase();

    // Extract scores – last two integers on the page are usually final scores
    const numbers = Array.from(text.matchAll(/\b(\d{1,3})\b/g)).map(m =>
      parseInt(m[1], 10)
    );

    let homeScore = 0;
    let awayScore = 0;

    if (numbers.length >= 2) {
      awayScore = numbers[numbers.length - 1];
      homeScore = numbers[numbers.length - 2];
    }

    let quarter = "";
    let clock = "";
    let status = "";

    if (lower.includes("full time")) {
      status = "Full Time";
      quarter = "Final";
      clock = "FT";
    } else if (lower.includes("three quarter time") || lower.includes("3qt")) {
      status = "3QT";
      quarter = "Q4";
    } else if (lower.includes("half time")) {
      status = "Half Time";
      quarter = "Q3";
    } else if (lower.includes("quarter time")) {
      status = "Quarter Time";
      quarter = "Q2";
    }

    const clockMatch = text.match(/\b(\d{1,2}:\d{2})\b/);
    if (clockMatch) {
      clock = clockMatch[1];
    }

    return {
      homeScore,
      awayScore,
      quarter,
      clock,
      status,
    };
  });

  await page.close();
  return meta;
}
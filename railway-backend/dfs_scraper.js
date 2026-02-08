// C:\FlutterProjects\my_app\backend\dfs_scraper.js
import { chromium } from "playwright";

export async function scrapeDFS(dfsId) {
  const url = `https://dfsaustralia.com/afl-game-stats/?gameId=${dfsId}`;

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  await page.goto(url, { waitUntil: "networkidle" });

  // Wait for the DataTable to be present
  await page.waitForSelector("table.dataTable tbody tr");

  const players = await page.$$eval("table.dataTable tbody tr", rows =>
    rows
      .map(row => {
        const cells = [...row.querySelectorAll("td")];
        if (cells.length === 0) return null;

        // Column layout from the DataTables config:
        // 0: playerName (rendered as <a href="...playerId=CD_xxx">Name</a>)
        // 1: kicks
        // 2: handballs
        // 3: marks
        // 4: tackles
        // 5: hitouts
        // 6: freesFor
        // 7: freesAgainst
        // 8: goals
        // 9: behinds
        // 10: timeOnGroundPercentage

        const nameCell = cells[0];
        const link = nameCell.querySelector("a");

        const name = link?.innerText.trim() || nameCell.innerText.trim() || "";
        const href = link?.getAttribute("href") || "";
        const idMatch = href.match(/playerId=([^&]+)/);
        const playerId = idMatch ? idMatch[1] : "";

        // Optional: if DFS encodes fantasy points somewhere (e.g. data-fp), grab it here.
        // For now, we default to 0 and let your Flutter side compute if needed.
        const fantasyPointsAttr =
          nameCell.getAttribute("data-fp") ||
          row.getAttribute("data-fp") ||
          "0";

        const startingPosition =
          row.getAttribute("data-startingposition") || "";
        const benchReason = row.getAttribute("data-benchreason") || "";

        const isSubOrOut =
          startingPosition === "SUB" ||
          benchReason === "Sub Tactical" ||
          benchReason === "Sub Injured" ||
          benchReason === "Injured" ||
          benchReason === "OUT";

        // Filter out subs / injured / OUT if attributes are present
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
    timeOnGroundPercentage: parse(cells[10]?.innerText)
  }
};
      })
      .filter(Boolean)
  );

  // Basic match metadata (kept from your earlier version)
  const meta = await page.evaluate(() => {
    const home = document.querySelector(".team-home .team-name")?.textContent?.trim() || "";
    const away = document.querySelector(".team-away .team-name")?.textContent?.trim() || "";

    const homeScore = parseInt(
      document.querySelector(".team-home .team-score")?.textContent || "0",
      10
    );
    const awayScore = parseInt(
      document.querySelector(".team-away .team-score")?.textContent || "0",
      10
    );

    const quarter =
      document.querySelector(".match-status")?.textContent?.trim() || "";
    const clock =
      document.querySelector(".match-clock")?.textContent?.trim() || "";

    return {
      homeTeam: { name: home, score: homeScore },
      awayTeam: { name: away, score: awayScore },
      quarter,
      clock
    };
  });

  await browser.close();

  return { players, meta };
}
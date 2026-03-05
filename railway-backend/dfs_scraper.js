// dfs_scraper_html.js
import fetch from "node-fetch";
import * as cheerio from "cheerio";

export async function scrapeDFS_HTML(dfsId) {
  const url = `https://dfsaustralia.com/live-scoring/?gameId=${dfsId}`;

  try {
    const res = await fetch(url, {
      headers: {
        "User-Agent": "Mozilla/5.0",
        "Accept": "text/html",
      },
    });

    if (!res.ok) {
      console.error("DFS HTML page returned error:", res.status);
      return { players: [], meta: {} };
    }

    const html = await res.text();
    const $ = cheerio.load(html);

    const players = [];

    // Find ALL tables and detect the stats table by header names
    const allTables = $("table");

    let statsTable = null;

    allTables.each((_, table) => {
      const headers = $(table).find("thead th").map((__, th) =>
        $(th).text().trim().toUpperCase()
      ).get();

      // Look for the known DFS stats headers
      if (
        headers.includes("PLAYER") &&
        headers.includes("D") &&
        headers.includes("M") &&
        headers.includes("T") &&
        headers.includes("HO") &&
        headers.includes("FF") &&
        headers.includes("FA") &&
        (headers.includes("G.B") || headers.includes("G.B.")) &&
        headers.includes("FP")
      ) {
        statsTable = table;
      }
    });

    if (!statsTable) {
      console.warn("⚠ No DFS stats table found in HTML");
      return { players: [], meta: {} };
    }

    // Parse rows
    const rows = $(statsTable).find("tbody tr");

    rows.each((_, row) => {
      const cells = $(row).find("td");
      if (cells.length < 10) return;

      const name = $(cells[1]).text().trim(); // Column 1 = PLAYER
      if (!name) return;

      const parse = (v) => parseInt(String(v).trim() || "0", 10);

      const disposals = parse($(cells[2]).text());
      const marks = parse($(cells[3]).text());
      const tackles = parse($(cells[4]).text());
      const hitouts = parse($(cells[5]).text());
      const freesFor = parse($(cells[6]).text());
      const freesAgainst = parse($(cells[7]).text());

      // G.B column → "1.2" or "0.1" or "2.0"
      const gb = $(cells[8]).text().trim();
      let goals = 0;
      let behinds = 0;
      if (gb.includes(".")) {
        const [g, b] = gb.split(".");
        goals = parse(g);
        behinds = parse(b);
      }

      const fantasyPoints = parse($(cells[11]).text()); // FP column

      players.push({
        id: name, // DFS does not expose playerId in this table
        name,
        fantasyPoints,
        goals,
        behinds,
        disposals,
        marks,
        tackles,
        hitouts,
        freesFor,
        freesAgainst,
      });
    });

    // Extract scoreboard metadata
    const scoreText = $("div.scoreboard h2").text().trim();
    const scoreMatch = scoreText.match(/(\d+)\s*-\s*(\d+)/);
    const homeScore = scoreMatch ? parseInt(scoreMatch[1], 10) : 0;
    const awayScore = scoreMatch ? parseInt(scoreMatch[2], 10) : 0;

    const quarterText = $("div.scoreboard h3").text().trim();
    const quarterMatch = quarterText.match(/(Q\d|Final)/i);
    const clockMatch = quarterText.match(/(\d{1,2}:\d{2})/);

    const meta = {
      homeScore,
      awayScore,
      quarter: quarterMatch ? quarterMatch[1] : "",
      clock: clockMatch ? clockMatch[1] : "",
      status: quarterMatch ? "In Progress" : "",
    };

    return { players, meta };
  } catch (err) {
    console.error("DFS HTML scrape failed:", err);
    return { players: [], meta: {} };
  }
}
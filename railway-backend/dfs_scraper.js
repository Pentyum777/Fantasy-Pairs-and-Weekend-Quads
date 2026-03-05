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

    // Select both home + away tables
    const tables = $("table.dataTable");

    tables.each((_, table) => {
      const rows = $(table).find("tbody tr");

      rows.each((__, row) => {
        const cells = $(row).find("td");
        if (cells.length === 0) return;

        const nameCell = $(cells[0]);
        const link = nameCell.find("a");
        const name = link.text().trim() || nameCell.text().trim();
        const href = link.attr("href") || "";

        const idMatch = href.match(/playerId=([^&]+)/);
        const playerId = idMatch ? idMatch[1] : name;

        const parse = (v) => parseInt(v || "0", 10);

        const disposals = parse($(cells[1]).text());
        const marks = parse($(cells[2]).text());
        const tackles = parse($(cells[3]).text());
        const hitouts = parse($(cells[4]).text());
        const freesFor = parse($(cells[5]).text());
        const freesAgainst = parse($(cells[6]).text());
        const goals = parse($(cells[7]).text());
        const behinds = parse($(cells[8]).text());
        const fantasyPoints = parse($(cells[9]).text());

        players.push({
          id: playerId,
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

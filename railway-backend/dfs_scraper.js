import fetch from "node-fetch";
import * as cheerio from "cheerio";

export async function scrapeDFS(dfsId) {
  const url =
    "https://dfsaustralia.com/wp-admin/admin-ajax.php?action=afl_game_stats_call_mysql";

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "User-Agent": "Mozilla/5.0",
        "Accept": "text/html, */*;q=0.8",
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
        "X-Requested-With": "XMLHttpRequest",
        Origin: "https://dfsaustralia.com",
        Referer: "https://dfsaustralia.com/",
      },
      // ⭐ THE FIX — DFS expects "id", not "gameId"
      body: `id=${encodeURIComponent(dfsId)}`,
      timeout: 10000,
    });

    if (!res.ok) {
      console.error("DFS AJAX endpoint returned error:", res.status);
      return { players: [], meta: {} };
    }

    const html = await res.text();
    const $ = cheerio.load(html);

    const rows = $("tbody tr");
    if (rows.length === 0) {
      console.warn("No table rows found in DFS AJAX response — returning empty stats");
      return { players: [], meta: {} };
    }

    const players = [];

    rows.each((_, row) => {
      const cells = $(row).find("td");
      if (cells.length === 0) return;

      const nameCell = $(cells[0]);
      const link = nameCell.find("a");
      const name = link.text().trim() || nameCell.text().trim();
      const href = link.attr("href") || "";

      const idMatch = href.match(/playerId=([^&]+)/);
      const playerId = idMatch ? idMatch[1] : "";

      const startingPosition = $(row).attr("data-startingposition") || "";
      const benchReason = $(row).attr("data-benchreason") || "";

      const isSubOrOut =
        startingPosition === "SUB" ||
        benchReason === "Sub Tactical" ||
        benchReason === "Sub Injured" ||
        benchReason === "Injured" ||
        benchReason === "OUT";

      if (isSubOrOut) return;

      const parse = (v) => parseInt((v || "0").replace(/\s+/g, ""), 10);

      const kicks = parse($(cells[1]).text());
      const handballs = parse($(cells[2]).text());
      const marks = parse($(cells[3]).text());
      const tackles = parse($(cells[4]).text());
      const hitouts = parse($(cells[5]).text());
      const freesFor = parse($(cells[6]).text());
      const freesAgainst = parse($(cells[7]).text());
      const goals = parse($(cells[8]).text());
      const behinds = parse($(cells[9]).text());
      const tog = parse($(cells[10]).text());

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

      players.push({
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
          timeOnGroundPercentage: tog,
        },
      });
    });

    return { players, meta: {} };
  } catch (err) {
    console.error("DFS AJAX scrape failed:", err);
    return { players: [], meta: {} };
  }
}
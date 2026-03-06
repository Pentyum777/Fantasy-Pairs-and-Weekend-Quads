// dfs_worker.js (non-blocking, fast-fail)
import { load } from "cheerio";

export async function startDFSWorker(dfsId) {
  const url = `https://dfsaustralia.com/live-scoring/?gameId=${dfsId}`;

  let consecutiveEmpty = 0;
  const MAX_EMPTY = 3;
  const INTERVAL_MS = 15000; // 15s between polls
  const FETCH_TIMEOUT_MS = 3000; // 3s hard timeout

  async function scrape() {
    if (consecutiveEmpty >= MAX_EMPTY) {
      console.log(
        `DFS worker ${dfsId}: stopping after ${MAX_EMPTY} empty polls`
      );
      return;
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

    try {
      const res = await fetch(url, { signal: controller.signal });
      clearTimeout(timeout);

      if (!res.ok) {
        console.log(`DFS worker ${dfsId}: HTTP ${res.status}`);
        return;
      }

      const html = await res.text();
      const $ = load(html);

      const tables = $("table").toArray();

      const statsTable = tables.find((t) => {
        const headers = $(t)
          .find("th")
          .toArray()
          .map((th) => $(th).text().trim().toUpperCase());
        return headers.includes("PLAYER") && headers.includes("FP");
      });

      if (!statsTable) {
        consecutiveEmpty++;
        console.log(
          `DFS worker ${dfsId}: no stats table found (#${consecutiveEmpty})`
        );
        return;
      }

      consecutiveEmpty = 0;

      const rows = $(statsTable).find("tbody tr").toArray();

      const players = rows
        .map((row) => {
          const cells = $(row)
            .find("td")
            .toArray()
            .map((td) => $(td).text().trim());

          const name = cells[1];
          if (!name) return null;

          const parse = (v) => parseInt(v || "0", 10);

          const disposals = parse(cells[2]);
          const marks = parse(cells[3]);
          const tackles = parse(cells[4]);
          const hitouts = parse(cells[5]);
          const freesFor = parse(cells[6]);
          const freesAgainst = parse(cells[7]);

          let goals = 0,
            behinds = 0;
          if (cells[8]?.includes(".")) {
            const [g, b] = cells[8].split(".");
            goals = parse(g);
            behinds = parse(b);
          }

          const fantasyPoints = parse(cells[11]);

          return {
            id: name,
            name,
            disposals,
            marks,
            tackles,
            hitouts,
            freesFor,
            freesAgainst,
            goals,
            behinds,
            fantasyPoints,
          };
        })
        .filter(Boolean);

      const scoreEl = $("div.scoreboard h2").first().text();
      const metaEl = $("div.scoreboard h3").first().text();

      let homeScore = 0,
        awayScore = 0;
      const match = scoreEl.match(/(\d+)\s*-\s*(\d+)/);
      if (match) {
        homeScore = parseInt(match[1], 10);
        awayScore = parseInt(match[2], 10);
      }

      const quarter = metaEl || "";

      global.liveStatsCache[dfsId] = {
        players,
        meta: {
          homeScore,
          awayScore,
          quarter,
          status: quarter ? "In Progress" : "",
        },
        timestamp: Date.now(),
      };

      console.log(
        `DFS worker ${dfsId}: updated stats for ${players.length} players`
      );
    } catch (err) {
      clearTimeout(timeout);

      if (err.name === "AbortError") {
        console.log(
          `DFS worker ${dfsId}: fetch timeout after ${FETCH_TIMEOUT_MS}ms`
        );
        return;
      }

      console.error(`DFS worker ${dfsId} error:`, err.message || err);
    }
  }

  scrape().catch((err) =>
    console.error(`DFS worker ${dfsId} initial scrape error:`, err)
  );

  setInterval(() => {
    scrape().catch((err) =>
      console.error(`DFS worker ${dfsId} interval scrape error:`, err)
    );
  }, INTERVAL_MS);
}
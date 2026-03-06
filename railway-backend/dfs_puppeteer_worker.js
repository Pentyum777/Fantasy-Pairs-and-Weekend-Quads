// dfs_puppeteer_worker.js (browserless version)
import fetch from "node-fetch";
import cheerio from "cheerio";

export async function startDFSWorker(dfsId) {
  const url = `https://dfsaustralia.com/live-scoring/?gameId=${dfsId}`;

  async function scrape() {
    try {
      const res = await fetch(url, { timeout: 30000 });
      const html = await res.text();
      const $ = cheerio.load(html);

      const tables = $("table").toArray();

      const statsTable = tables.find(t => {
        const headers = $(t)
          .find("th")
          .toArray()
          .map(th => $(th).text().trim().toUpperCase());
        return headers.includes("PLAYER") && headers.includes("FP");
      });

      if (!statsTable) {
        console.log("No stats table found");
        return;
      }

      const rows = $(statsTable).find("tbody tr").toArray();

      const players = rows
        .map(row => {
          const cells = $(row)
            .find("td")
            .toArray()
            .map(td => $(td).text().trim());

          const name = cells[1];
          if (!name) return null;

          const parse = v => parseInt(v || "0", 10);

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
            fantasyPoints
          };
        })
        .filter(Boolean);

      const scoreEl = $("div.scoreboard h2").first().text();
      const metaEl = $("div.scoreboard h3").first().text();

      let homeScore = 0,
        awayScore = 0;
      const match = scoreEl.match(/(\d+)\s*-\s*(\d+)/);
      if (match) {
        homeScore = parseInt(match[1]);
        awayScore = parseInt(match[2]);
      }

      const quarter = metaEl || "";

      const data = {
        players,
        meta: {
          homeScore,
          awayScore,
          quarter,
          status: quarter ? "In Progress" : ""
        }
      };

      global.liveStatsCache[dfsId] = {
        ...data,
        timestamp: Date.now()
      };

      console.log("DFS worker updated stats:", players.length);
    } catch (err) {
      console.error("DFS worker error:", err);
    }
  }

  await scrape();
  setInterval(scrape, 5000);
}
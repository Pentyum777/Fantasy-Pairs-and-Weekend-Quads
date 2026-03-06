// dfs_puppeteer_worker.js
import puppeteer from "puppeteer";

export async function startDFSWorker(dfsId) {
  const url = `https://dfsaustralia.com/live-scoring/?gameId=${dfsId}`;

  const browser = await puppeteer.launch({
  executablePath: puppeteer.executablePath(),
  headless: true,
  args: [
    "--no-sandbox",
    "--disable-setuid-sandbox",
    "--disable-dev-shm-usage",
    "--disable-gpu",
    "--disable-software-rasterizer",
    "--disable-dev-tools",
    "--no-zygote",
    "--single-process",
    "--disable-background-networking",
    "--disable-background-timer-throttling",
    "--disable-breakpad",
    "--disable-client-side-phishing-detection",
    "--disable-default-apps",
    "--disable-hang-monitor",
    "--disable-popup-blocking",
    "--disable-prompt-on-repost",
    "--disable-sync",
    "--metrics-recording-only",
    "--no-first-run",
    "--no-default-browser-check",
    "--ignore-certificate-errors",
    "--ignore-ssl-errors",
    "--disable-features=AudioServiceOutOfProcess,IsolateOrigins,site-per-process",
    "--disable-ipc-flooding-protection",
    "--disable-renderer-backgrounding",
    "--disable-web-security"
  ]
});

  const page = await browser.newPage();

  async function scrape() {
    try {
      await page.goto(url, { waitUntil: "networkidle2", timeout: 30000 });
      await page.waitForSelector("table", { timeout: 15000 });

      const data = await page.evaluate(() => {
        const tables = Array.from(document.querySelectorAll("table"));

        const statsTable = tables.find(t => {
          const headers = Array.from(t.querySelectorAll("th"))
            .map(th => th.innerText.trim().toUpperCase());
          return headers.includes("PLAYER") && headers.includes("FP");
        });

        if (!statsTable) return { players: [], meta: {} };

        const rows = Array.from(statsTable.querySelectorAll("tbody tr"));

        const players = rows.map(row => {
          const cells = Array.from(row.querySelectorAll("td")).map(td => td.innerText.trim());
          const name = cells[1];
          if (!name) return null;

          const parse = v => parseInt(v || "0", 10);

          const disposals = parse(cells[2]);
          const marks = parse(cells[3]);
          const tackles = parse(cells[4]);
          const hitouts = parse(cells[5]);
          const freesFor = parse(cells[6]);
          const freesAgainst = parse(cells[7]);

          let goals = 0, behinds = 0;
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
        }).filter(Boolean);

        const scoreEl = document.querySelector("div.scoreboard h2");
        const metaEl = document.querySelector("div.scoreboard h3");

        let homeScore = 0, awayScore = 0;
        if (scoreEl) {
          const match = scoreEl.innerText.match(/(\d+)\s*-\s*(\d+)/);
          if (match) {
            homeScore = parseInt(match[1]);
            awayScore = parseInt(match[2]);
          }
        }

        const quarter = metaEl?.innerText || "";

        return {
          players,
          meta: {
            homeScore,
            awayScore,
            quarter,
            status: quarter ? "In Progress" : ""
          }
        };
      });

      global.liveStatsCache[dfsId] = {
        ...data,
        timestamp: Date.now()
      };

      console.log("DFS worker updated stats:", data.players.length);

    } catch (err) {
      console.error("DFS worker error:", err);
    }
  }

  await scrape();
  setInterval(scrape, 5000);
}
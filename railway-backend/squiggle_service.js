import fs from "fs";
import fetch from "node-fetch";
import path from "path";

// Load JSON manually (Railway-safe)
const squiggleMap = JSON.parse(
  fs.readFileSync(path.resolve("squiggle_map.json"), "utf8")
);

/**
 * Fetches Squiggle game status for a matchId.
 * Returns: "Upcoming" | "In Progress" | "Final"
 */
export async function getSquiggleStatusForMatch(matchId) {
  const squiggleId = squiggleMap[matchId];

  if (!squiggleId) {
    console.warn(`⚠ No Squiggle ID found for match ${matchId}`);
    return "Upcoming";
  }

  try {
    const url = `https://api.squiggle.com.au/?q=games;game=${squiggleId}`;
    const res = await fetch(url, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "en-US,en;q=0.9",
        "Origin": "https://squiggle.com.au",
        "Referer": "https://squiggle.com.au/",
        "Cache-Control": "no-cache",
      },
    });

    // Guard against HTML error pages (e.g. 403/rate-limit responses)
    const contentType = res.headers.get("content-type") || "";
    if (!contentType.includes("application/json")) {
      const text = await res.text();
      console.warn(`⚠ Squiggle returned non-JSON (status ${res.status}): ${text.substring(0, 100)}`);
      return "Upcoming";
    }

    const json = await res.json();

    const game = json?.games?.[0];

    if (!game) {
      console.warn(`⚠ No Squiggle game data for ID ${squiggleId}`);
      return "Upcoming";
    }

    // 🔍 DEBUG LOG — this is the important one
    const computedStatus =
      game.complete === 100
        ? "Final"
        : game.complete > 0
        ? "In Progress"
        : "Upcoming";

    console.log(
      `Squiggle → matchId ${matchId}, squiggleId ${squiggleId}, complete=${game.complete}, status=${computedStatus}`
    );

    return computedStatus;
  } catch (err) {
    console.error("Squiggle fetch failed:", err);
    return "Upcoming";
  }
}
import fs from "fs";
import fetch from "node-fetch";

// Load JSON manually (Railway-safe)
const squiggleMap = JSON.parse(fs.readFileSync("./squiggle_map.json", "utf8"));

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
    const res = await fetch(url);
    const json = await res.json();

    const game = json?.games?.[0];
    if (!game) {
      console.warn(`⚠ No Squiggle game data for ID ${squiggleId}`);
      return "Upcoming";
    }

    return game.complete === 100
      ? "Final"
      : game.complete > 0
      ? "In Progress"
      : "Upcoming";
  } catch (err) {
    console.error("Squiggle fetch failed:", err);
    return "Upcoming";
  }
}
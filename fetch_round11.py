"""
fetch_round11.py
----------------
Fetches all Round 11 data from the Fantasy Pairs backend and prints:
  1. Match stats for every Round 11 game (all player AF scores)
  2. All selections for every game type in Round 11
  3. A scored leaderboard for Weekend Quads using the full 4 picks

Run with:  python fetch_round11.py
Requires:  pip install requests
"""

import requests
import json

BASE = "https://fantasy-pairs-and-weekend-quads-production.up.railway.app"

ROUND_11_MATCHES = {
    "CD_M20260141101": "HAW vs ADE",
    "CD_M20260141102": "RIC vs ESS",
    "CD_M20260141103": "FRE vs STK",
    "CD_M20260141104": "NTH vs GCS",
    "CD_M20260141105": "GEE vs SYD",
    "CD_M20260141106": "COL vs WCE",
    "CD_M20260141107": "PTA vs CAR",
    "CD_M20260141108": "GWS vs BRL",
    "CD_M20260141109": "WBD vs MELB",
}

GAME_TYPES = [
    "thursday_pairs",
    "friday_pairs",
    "saturday_pairs",
    "sunday_pairs",
    "monday_pairs",
    "weekend_quads",
]

# ── 1. Fetch match stats for every Round 11 game ─────────────────────────────

print("=" * 70)
print("ROUND 11 — MATCH STATS")
print("=" * 70)

all_player_scores = {}  # playerId -> {name, af}

for match_id, label in ROUND_11_MATCHES.items():
    print(f"\n{label} ({match_id})")
    print("-" * 50)
    try:
        r = requests.get(f"{BASE}/matchStats/{match_id}", timeout=15)
        data = r.json()
        if not data.get("ok"):
            print(f"  ERROR: {data}")
            continue
        players = data.get("players", [])
        if not players:
            print("  No stats available")
            continue
        players.sort(key=lambda p: p.get("fantasyPoints", p.get("af", 0)), reverse=True)
        for p in players:
            af   = p.get("fantasyPoints") or p.get("af") or 0
            name = p.get("playerName") or p.get("player_name") or "Unknown"
            pid  = p.get("playerId") or p.get("player_id") or ""
            if pid:
                all_player_scores[pid] = {"name": name, "af": af}
            print(f"  {name:<30} {af:>4}  ({pid})")
    except Exception as e:
        print(f"  Request failed: {e}")

# ── 2. Fetch selections for every game type ───────────────────────────────────

print("\n\n" + "=" * 70)
print("ROUND 11 — SELECTIONS BY GAME TYPE")
print("=" * 70)

quads_data = None

for gt in GAME_TYPES:
    print(f"\n{gt.upper().replace('_', ' ')}")
    print("-" * 50)
    try:
        r = requests.get(
            f"{BASE}/loadSelections",
            params={"season": 2026, "round": 11, "gameType": gt},
            timeout=15,
        )
        data = r.json()
        if not data.get("ok") or not data.get("data"):
            print("  No data saved for this game type")
            continue
        payload = data["data"]
        names   = payload.get("punterNames", [])
        picks   = payload.get("picks", [])
        if not names:
            print("  No punters found")
            continue
        if gt == "weekend_quads":
            quads_data = payload
        for i, (punter, punter_picks) in enumerate(zip(names, picks)):
            filled = [p for p in punter_picks if p.get("playerId")]
            print(f"  {punter:<12} {len(filled)} picks", end="")
            if filled:
                ids = [p["playerId"] for p in filled]
                player_names = [all_player_scores.get(pid, {}).get("name", pid) for pid in ids]
                print(f"  →  {', '.join(player_names)}", end="")
            print()
    except Exception as e:
        print(f"  Request failed: {e}")

# ── 3. Full Weekend Quads leaderboard with live AF scores ─────────────────────

print("\n\n" + "=" * 70)
print("ROUND 11 — WEEKEND QUADS LEADERBOARD (using live match stats)")
print("=" * 70)

if not quads_data:
    print("No quads data available")
else:
    names = quads_data.get("punterNames", [])
    picks = quads_data.get("picks", [])

    results = []
    for punter, punter_picks in zip(names, picks):
        total       = 0
        pick_labels = []
        for p in punter_picks:
            pid = p.get("playerId", "")
            if not pid:
                pick_labels.append("—")
                continue
            # Prefer live match stats score; fall back to saved stats in payload
            if pid in all_player_scores:
                af   = all_player_scores[pid]["af"]
                name = all_player_scores[pid]["name"]
            else:
                af   = p.get("stats", {}).get("AF", 0)
                name = pid  # ID only if not in match stats
            total += af
            pick_labels.append(f"{name} ({af})")
        results.append((total, punter, pick_labels))

    results.sort(reverse=True)

    print(f"\n{'Pos':<4} {'Punter':<12} {'Total':>5}  Picks")
    print("-" * 90)
    for pos, (total, punter, pick_labels) in enumerate(results, 1):
        picks_str = " | ".join(pick_labels)
        print(f"{pos:<4} {punter:<12} {total:>5}  {picks_str}")

print("\n\nDone.")

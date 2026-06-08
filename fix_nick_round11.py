"""
fix_nick_round11.py
-------------------
Corrects NICK's Pick 1 in Round 11 Weekend Quads from
Lachie Whitfield (CD_I294305, AF=0) to Keidean Coleman (CD_I1006059, AF=63).

Run with:  python fix_nick_round11.py
Requires:  pip install requests
"""

import requests
import json

BASE   = "https://fantasy-pairs-and-weekend-quads-production.up.railway.app"
SEASON = 2026
ROUND  = 11
GT     = "weekend_quads"

# ── 1. Load current selections ────────────────────────────────────────────────
print("Loading current Round 11 Weekend Quads selections...")
r = requests.get(f"{BASE}/loadSelections",
                 params={"season": SEASON, "round": ROUND, "gameType": GT})
r.raise_for_status()
data = r.json()

if not data.get("ok") or not data.get("data"):
    print("ERROR: No data returned")
    exit(1)

punter_names = data["data"]["punterNames"]
picks        = data["data"]["picks"]

print(f"Loaded {len(punter_names)} punters")

# ── 2. Find NICK ──────────────────────────────────────────────────────────────
nick_index = None
for i, name in enumerate(punter_names):
    if name.upper() == "NICK":
        nick_index = i
        break

if nick_index is None:
    print("ERROR: Could not find punter named NICK")
    print("Punter names:", punter_names)
    exit(1)

print(f"\nFound NICK at index {nick_index} (draft position {nick_index + 1})")
print(f"Current picks for NICK:")
for j, pick in enumerate(picks[nick_index]):
    pid = pick.get("playerId", "")
    af  = pick.get("stats", {}).get("AF", 0)
    print(f"  Pick {j+1}: {pid}  AF={af}")

# ── 3. Confirm the fix ────────────────────────────────────────────────────────
current_pick1 = picks[nick_index][0]
print(f"\nChanging Pick 1: {current_pick1.get('playerId')} (AF={current_pick1.get('stats',{}).get('AF',0)})")
print(f"              → CD_I1006059 (Keidean Coleman, AF=63)")

confirm = input("\nProceed? (y/n): ").strip().lower()
if confirm != "y":
    print("Aborted.")
    exit(0)

# ── 4. Apply the fix ──────────────────────────────────────────────────────────
picks[nick_index][0] = {
    "playerId": "CD_I1006059",
    "stats": {
        "AF": 63,
        "K":  8,
        "HB": 8,
        "D":  16,
        "M":  3,
        "T":  5,
        "G":  0,
        "B":  0,
        "HO": 0,
        "FF": 1,
        "FA": 1,
        "TOG": 0
    }
}

# ── 5. Save back ──────────────────────────────────────────────────────────────
print("\nSaving corrected selections...")
payload = {
    "season":      SEASON,
    "round":       ROUND,
    "gameType":    GT,
    "punterNames": punter_names,
    "picks":       picks,
}

save_r = requests.post(
    f"{BASE}/saveSelections",
    headers={"Content-Type": "application/json"},
    data=json.dumps(payload),
)
save_r.raise_for_status()
save_data = save_r.json()

if save_data.get("ok"):
    print("✅ Saved successfully!")
    print(f"\nNICK's updated picks:")
    for j, pick in enumerate(picks[nick_index]):
        pid = pick.get("playerId", "")
        af  = pick.get("stats", {}).get("AF", 0)
        print(f"  Pick {j+1}: {pid}  AF={af}")
    
    # Recalculate NICK's total
    total = sum(p.get("stats", {}).get("AF", 0) for p in picks[nick_index] if p.get("playerId"))
    print(f"\nNICK's new total: {total}")
else:
    print("ERROR saving:", save_data)

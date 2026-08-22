#!/usr/bin/python3
# ============================================================================
# boom_ab_report.py — READ-ONLY A/B check-in for the BOOM market_regime opt-in overlay.
#
# Two paper legs run the SAME boom book and diverge only by the overlay flag:
#   A = CONTROL   (alpaca_boom.env,        BB_MARKET_OVERLAY=0)
#   B = TREATMENT (alpaca_boom_market.env, BB_MARKET_OVERLAY=1)
# So B−A is the overlay's live P&L, and the thesis to watch is DRAWDOWN: the overlay should show a
# SHALLOWER drawdown-from-high-water-mark in risk-off stretches, at the cost of ~20% of return
# (validation: live/boom_market_regime_validation.jl). Both legs read benchmark's shared market_regime.txt,
# so B only diverges when that signal is risk-off — the emitter must be running for the A/B to mean anything.
#
#   python3 live/boom_ab_report.py
# ============================================================================
import os, json, urllib.request

CFG = os.path.join(os.path.expanduser("~"), ".config", "blaquebaux")
BASE = "https://paper-api.alpaca.markets/v2"
LEGS = [("A CONTROL  (overlay OFF)", "boom"), ("B TREATMENT(overlay ON)", "boom_market")]

def read_keys(path):
    if not os.path.exists(path): return None
    kv = {}
    for line in open(path):
        line = line.strip()
        if line.startswith("export "): line = line[7:]
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1); kv[k.strip()] = v.strip().strip('"').strip("'")
    kid, sec = kv.get("ALPACA_KEY_ID"), kv.get("ALPACA_SECRET_KEY")
    return (kid, sec) if kid and sec else None

def get(path, keys):
    req = urllib.request.Request(BASE + path, headers={"APCA-API-KEY-ID": keys[0], "APCA-API-SECRET-KEY": keys[1]})
    with urllib.request.urlopen(req, timeout=25) as r: return json.load(r)

def f(x):
    try: return float(x)
    except (TypeError, ValueError): return 0.0

def read_hwm(leg):
    p = os.path.join(CFG, "equity_hwm_%s.txt" % leg)
    try: return float(open(p).read().strip())
    except Exception: return None

def snapshot(label, leg):
    keys = read_keys(os.path.join(CFG, "alpaca_%s.env" % leg))
    if keys is None: return {"label": label, "leg": leg, "note": "no keys (alpaca_%s.env) — not active" % leg}
    try:
        a = get("/account", keys); ps = get("/positions", keys)
    except Exception as e:
        return {"label": label, "leg": leg, "note": "query error: %s" % e}
    eq, le = f(a["equity"]), f(a["last_equity"])
    gross = abs(f(a["long_market_value"])) + abs(f(a["short_market_value"]))
    hwm = read_hwm(leg); dd = (eq / hwm - 1) if hwm else None
    return {"label": label, "leg": leg, "acct": a.get("account_number", "?"), "eq": eq, "le": le,
            "day_pl": eq - le, "gross_x": gross / eq if eq else 0.0, "npos": len(ps),
            "hwm": hwm, "dd": dd}

def main():
    print("=" * 68)
    print(" BOOM — market_regime opt-in  LIVE A/B  (B−A = the overlay's P&L)")
    print("=" * 68)
    snaps = [snapshot(l, leg) for (l, leg) in LEGS]
    for s in snaps:
        print("\n %s" % s["label"])
        if "note" in s: print("   %s" % s["note"]); continue
        print(f"   acct {s['acct']}   equity ${s['eq']:,.0f}   day P&L ${s['day_pl']:,.0f}"
              f"   gross {s['gross_x']:.2f}x   {s['npos']} pos")
        if s["dd"] is not None:
            print(f"   high-water ${s['hwm']:,.0f}   drawdown-from-HWM {s['dd']*100:+.1f}%")

    a, b = snaps[0], snaps[1]
    if all("note" not in s for s in (a, b)):
        print("\n " + "-" * 66)
        d_eq = b["eq"] - a["eq"]
        d_pct = (d_eq / a["eq"] * 100) if a["eq"] else 0.0
        print(" A/B DELTA (treatment − control):")
        print(f"   equity  B−A = ${d_eq:,.0f}   ({d_pct:+.2f}% of control)  ← overlay's cumulative live P&L")
        if a["dd"] is not None and b["dd"] is not None:
            shallower = b["dd"] > a["dd"]
            print("   drawdown-from-HWM:  control %+.1f%%   treatment %+.1f%%   → overlay is %s"
                  % (a["dd"] * 100, b["dd"] * 100,
                     "SHALLOWER (thesis holding)" if shallower else "not shallower yet"))
        print("\n Read: the overlay only acts when benchmark's market_regime is RISK-OFF; in calm regimes the")
        print(" legs should track (B≈A). Watch the drawdown gap open in the next risk-off stretch — that is")
        print(" the insurance the validation priced (cut maxDD 41%, ~20% less return).")
    else:
        print("\n (activate both legs: create two paper accounts, drop alpaca_boom.env + alpaca_boom_market.env)")

if __name__ == "__main__":
    main()

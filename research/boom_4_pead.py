#!/usr/bin/python3
# =============================================================================
# boom_4_pead.py — BLAQUE BAUX BOOM #4 (re-tested, fairly).
#
# FIRST PASS (gap proxy) said "no PEAD" — but that test was unfair: it used any
# |overnight gap|>4% (not real earnings) and measured RAW returns (dominated by the
# secular megacap uptrend). This is the fair test:
#   - REAL earnings dates + EPS surprise (yfinance),
#   - drift measured EXCESS of SPY (strips the beta that fooled the proxy),
#   - split by EPS-surprise sign AND by the announcement-day price reaction.
#
# FINDING: PEAD is REAL in megacaps (the proxy's rejection was a false negative).
#   Misses drift down hard in excess terms; the announcement-day reaction keeps
#   drifting in its own direction for weeks. The EPS-surprise long/short is weak
#   because megacaps beat ~83% of the time (that leg is nearly all-long); the
#   REACTION-based signal is the tradeable one.
#
# RESULTS AS TESTED (Mag7, ~300 earnings events, 2019-2026, drift EXCESS of SPY):
#   by EPS surprise:   20d beat +28bp / miss -189bp  -> spread +217bp (fades by 60d)
#   by reaction sign:  20d up  +95bp / down -121bp   -> spread +216bp (grows to +357bp @60d)
#   long-beat/short-miss, 20d: +56bp/event, t~1.2 (weak; beat-heavy sample)
#   long-up/short-down reaction, 20d: reported below (the real signal)
#
# Requires: yfinance (+ lxml) for earnings dates, plus Alpaca for prices.
#   pip install --user yfinance lxml
# Read-only.
# =============================================================================
import warnings; warnings.filterwarnings("ignore")
import os, sys, bisect, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _boom_common import MAG7, bars
import yfinance as yf

def series(sym):
    b = bars(sym); ds = sorted(b)
    return ds, {d: k for k, d in enumerate(ds)}, np.array([b[d]["c"] for d in ds], float)

HOR = [1, 5, 20, 40, 60]
spd, spi, spc = series("SPY")
events = []
for s in MAG7:
    ds, idx, c = series(s)
    try:
        edf = yf.Ticker(s).get_earnings_dates(limit=48)
    except Exception as e:
        print(f"  ({s}: earnings fetch failed: {str(e)[:60]})"); continue
    for ts, row in edf.iterrows():
        sur = row.get("Surprise(%)")
        if sur is None or (isinstance(sur, float) and math.isnan(sur)): continue
        edate = ts.date().isoformat(); amc = ts.hour >= 13     # >=13:00 ET ~ after close
        pos = bisect.bisect_right(ds, edate) if amc else bisect.bisect_left(ds, edate)
        if pos <= 0 or pos >= len(ds): continue
        rd = ds[pos]
        if rd not in spi: continue
        R, sp = pos, spi[rd]
        rec = {"sur": float(sur), "ar": c[R] / c[R - 1] - 1}
        for h in HOR:
            if R + h < len(c) and sp + h < len(spc):
                rec[h] = (c[R + h] / c[R] - 1) - (spc[sp + h] / spc[sp] - 1)
        events.append(rec)

print("=" * 72, "\nBOOM #4 (FAIR) — PEAD on real earnings, drift EXCESS of SPY\n" + "=" * 72)
print(f"Mag7 earnings events with surprise data: {len(events)}\n")
beats = [e for e in events if e["sur"] > 0]; miss = [e for e in events if e["sur"] < 0]
print(f"by EPS SURPRISE sign (beats {len(beats)} / misses {len(miss)}) — excess-of-SPY drift (bp):")
print(f"  {'h':>5}{'beat':>9}{'miss':>9}{'beat-miss':>11}")
for h in HOR:
    b = np.mean([e[h] for e in beats if h in e]) * 1e4; m = np.mean([e[h] for e in miss if h in e]) * 1e4
    print(f"  {h:>4}d{b:>+9.0f}{m:>+9.0f}{b-m:>+11.0f}")
up = [e for e in events if e["ar"] > 0]; dn = [e for e in events if e["ar"] < 0]
print(f"\nby ANNOUNCEMENT REACTION sign (up {len(up)} / down {len(dn)}) — excess-of-SPY drift (bp):")
print(f"  {'h':>5}{'up':>9}{'down':>9}{'up-down':>11}")
for h in HOR:
    u = np.mean([e[h] for e in up if h in e]) * 1e4; d = np.mean([e[h] for e in dn if h in e]) * 1e4
    print(f"  {h:>4}d{u:>+9.0f}{d:>+9.0f}{u-d:>+11.0f}")
for label, key in [("EPS surprise", "sur"), ("reaction", "ar")]:
    h = 20; pnl = np.array([np.sign(e[key]) * e[h] for e in events if h in e])
    t = pnl.mean() / (pnl.std() / math.sqrt(len(pnl)))
    print(f"\nlong/short by {label:<12} hold {h}d (excess): {pnl.mean()*1e4:+.0f}bp/event  "
          f"hit {100*(pnl>0).mean():.0f}%  t-stat {t:+.2f}  n={len(pnl)}")
print("\nVERDICT: PEAD is REAL (the proxy's rejection was a false negative from not")
print("stripping beta). The REACTION-based drift is the tradeable signal; the miss side")
print("carries most of it. Modest and event-scale; a candidate overlay, not a core sleeve.")

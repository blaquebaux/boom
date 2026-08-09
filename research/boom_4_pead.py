#!/usr/bin/python3
# =============================================================================
# boom_4_pead.py — BLAQUE BAUX BOOM #4.
#
# QUESTION: is there post-earnings-announcement drift (PEAD) in megacaps — does a
#   big positive earnings reaction keep drifting up (and a negative one down)?
# PROXY:    no earnings calendar here, so use |overnight gap| > 4% as an
#   earnings-reaction proxy, and measure forward 5/10/20-day drift by gap sign.
# FINDING:  no tradeable PEAD. BOTH up-gaps and down-gaps are followed by POSITIVE
#   forward returns — that is just the secular uptrend of these names — and the
#   up-minus-down SPREAD is NEGATIVE (down-gaps drift up MORE), i.e. a mild post-drop
#   bounce, the opposite of drift. There is no continuation edge to harvest; what
#   looks like "drift" is market beta plus short-term reversal.
#
# RESULTS AS TESTED (Mag7, 2016-2026):
#   +5d  after UP gap +0.93% | after DOWN gap +1.18%   (spread -0.25%)
#   +10d after UP gap +1.88% | after DOWN gap +2.27%   (spread -0.39%)
#   +20d after UP gap +4.74% | after DOWN gap +5.16%   (spread -0.42%)
# Read-only.
# =============================================================================
import os, sys, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _boom_common import MAG7, bars

print("=" * 70, "\nBOOM #4 — post-earnings drift (proxy: |overnight gap|>4%)\n" + "=" * 70)
for horizon in (5, 10, 20):
    up, dn = [], []
    for s in MAG7:
        b = bars(s); ds = sorted(b)
        c = np.array([b[d]["c"] for d in ds], float); o = np.array([b[d]["o"] for d in ds], float)
        gap = o[1:] / c[:-1] - 1
        for t in range(len(gap) - horizon - 1):
            if not np.isfinite(gap[t]): continue
            fwd = c[t + 1 + horizon] / c[t + 1] - 1     # drift after the gap day's close
            if gap[t] > 0.04: up.append(fwd)
            elif gap[t] < -0.04: dn.append(fwd)
    u, d = np.mean(up) * 100, np.mean(dn) * 100
    print(f"  +{horizon:>2}d  UP gap {u:+.2f}% (n={len(up)}) | DOWN gap {d:+.2f}% (n={len(dn)}) | spread {u-d:+.2f}%")
print("\nVERDICT: rejected. No continuation edge — both directions drift up (secular")
print("beta) and the up-minus-down spread is negative (mild post-drop bounce, not")
print("PEAD). Any real earnings signal needs a true surprise (actual vs estimate),")
print("which this daily-bar proxy cannot see.")

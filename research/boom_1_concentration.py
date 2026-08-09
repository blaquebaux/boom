#!/usr/bin/python3
# =============================================================================
# boom_1_concentration.py — BLAQUE BAUX BOOM #1.
#
# QUESTION: did concentrating in the megacap leaders beat holding the index?
# FINDING:  spectacularly, over 2016-2026 — but this is HINDSIGHT. The Mag7 are,
#   by definition, the names that won this exact decade; equal-weighting them is
#   selecting the winners after the fact. The +1.0 excess Sharpe is the return to
#   FOREKNOWLEDGE, not a repeatable, prospectively-tradeable edge. The honest use
#   of this result is as a benchmark and a caution, not a strategy. (The prospective
#   version — a momentum RULE that rotates into leaders as they emerge — is #3.)
#
# RESULTS AS TESTED (2016-2026, gross of costs):
#   EW Mag7          Sharpe +1.15  CAGR +33.6%  maxDD -49%
#   SPY              Sharpe +0.88  CAGR +15.0%  maxDD -34%
#   QQQ              Sharpe +0.93  CAGR +19.9%  maxDD -35%
#   RSP (eq-wt S&P)  Sharpe +0.73  CAGR +12.3%  maxDD -39%
#   EW Mag7 - SPY (excess): Sharpe +1.04, ann +17.6%   <- hindsight, not alpha
# Read-only.
# =============================================================================
import os, sys, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _boom_common import MAG7, BENCH, panel, ann

u, dts, M = panel(MAG7 + BENCH); R = M[1:] / M[:-1] - 1; i = {s: u.index(s) for s in u}
ew7 = R[:, [i[s] for s in MAG7 if s in i]].mean(1)
print("=" * 70, "\nBOOM #1 — concentration vs the index\n" + "=" * 70)
print(f"span {dts[1]}..{dts[-1]}  ({len(R)} days)\n")
for name, series in [("EW Mag7", ew7), ("SPY", R[:, i['SPY']]), ("QQQ", R[:, i['QQQ']]), ("RSP eq-wt", R[:, i['RSP']])]:
    s, c, d = ann(series); print(f"  {name:<12} Sharpe {s:+.2f}  CAGR {c*100:+.1f}%  maxDD {d*100:.0f}%")
s, c, d = ann(ew7 - R[:, i['SPY']])
print(f"\n  EW Mag7 - SPY (excess): Sharpe {s:+.2f}  ann {c*100:+.1f}%")
print("\nVERDICT: the concentration bet won huge, but selecting THESE seven ex-post is")
print("hindsight, not a repeatable edge. Use as benchmark/caution. The prospective")
print("version is a momentum rule (see boom_3), and even that inherits the")
print("concentration risk quantified in boom_2.")

#!/usr/bin/python3
# =============================================================================
# boom_2_crowding.py — BLAQUE BAUX BOOM #2.
#
# QUESTION: how much diversification do you actually get from "seven" megacaps?
# FINDING:  far less than seven. The Mag7 average ~0.49 pairwise correlation, one
#   factor explains ~57% of their variance, and the effective number of independent
#   bets (participation ratio of the correlation eigenvalues) is only ~2.8 of 7.
#   They also carry ~0.70 correlation to QQQ. This is the base's "big tech is roughly
#   one factor" law, quantified — and it is WHY a megacap book draws down ~-49%.
#   This is a RISK finding that governs sizing, not a return signal.
#
# RESULTS AS TESTED (Mag7 daily returns, 2016-2026):
#   avg pairwise corr 0.49 (0.30..0.65) | 1 factor = 57% of variance
#   effective independent bets ~2.82 of 7 | avg corr to QQQ 0.70
# Read-only.
# =============================================================================
import os, sys, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _boom_common import MAG7, panel

u, dts, M = panel(MAG7 + ["QQQ"]); R = M[1:] / M[:-1] - 1; i = {s: u.index(s) for s in u}
C7 = R[:, [i[s] for s in MAG7 if s in i]]
CM = np.corrcoef(C7.T); off = CM[np.triu_indices(C7.shape[1], 1)]
lam = np.linalg.eigvalsh(CM); neff = (lam.sum() ** 2) / (lam ** 2).sum()
print("=" * 70, "\nBOOM #2 — crowding / one-factor risk\n" + "=" * 70)
print(f"  Mag7 avg pairwise corr: {off.mean():.2f}  (min {off.min():.2f}, max {off.max():.2f})")
print(f"  effective independent bets (participation ratio): {neff:.2f} of {C7.shape[1]}")
print(f"  top eigenvalue = {100*lam.max()/lam.sum():.0f}% of variance (one factor)")
print(f"  avg Mag7 correlation to QQQ: {np.mean([np.corrcoef(C7[:,k],R[:,i['QQQ']])[0,1] for k in range(C7.shape[1])]):.2f}")
print("\nVERDICT: 'seven names' is really ~3 bets on one factor. Diversification here")
print("is an illusion; this must drive position sizing and the drawdown budget for")
print("any Boom book. A risk input, not alpha.")

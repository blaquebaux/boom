#!/usr/bin/python3
# =============================================================================
# boom_3_leader_momentum.py — BLAQUE BAUX BOOM #3 (the keeper, with caveats).
#
# QUESTION: does a RULE that tilts toward the leaders beat holding the whole megacap
#   set? Unlike #1 (hindsight), 12-1 momentum is prospective — it rotates into
#   whatever is leading, so you could have run it without foreknowledge.
# FINDING:  yes, but fragile. Long the top-quintile by 12-1 momentum, short the
#   equal-weight megacap basket (beta-neutral): a real, cost-robust, sub-period-
#   stable edge. BUT it is heavily concentrated in a few explosive names — remove
#   NVDA and it nearly halves; remove NVDA+TSLA and it is thin. This is boom_2's
#   crowding showing up in the returns: the "diversified tilt" is largely a bet on
#   whichever 1-2 names are exploding. Real, but size it knowing that.
#
# RESULTS AS TESTED (MEGA universe, beta-neutral top-quintile, 2016-2026):
#   daily-rebalance gross top-EW ......... Sharpe +0.75
#   monthly-rebalance, net 2bp/side ...... Sharpe +0.55  ann +8.4%  maxDD -21%
#     sub-periods: first half +0.46 | second half +0.64
#     gross vs net nearly equal (+0.56 vs +0.55) => low turnover, not a cost story
#   leave-one-out (the fragility):
#     drop NVDA ............ +0.39     drop NVDA,TSLA ...... +0.21
#     drop NVDA,AVGO,AMD ... +0.28
#   rebalance sensitivity: 5d +0.60 | 21d +0.55 | 63d +0.37 (momentum decays)
# Read-only. Gross except where marked net.
# =============================================================================
import os, sys, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _boom_common import MAG7, MEGA, panel, ann

COST = 2.0 / 1e4  # 2 bp/side

def momentum_tilt(universe, reb=21, frac=0.2, cost=True):
    """Beta-neutral: long top-quintile by 12-1 momentum, short the EW-all basket."""
    u, dts, M = panel(universe); R = M[1:] / M[:-1] - 1; T, N = R.shape
    mom = np.full((T, N), np.nan)
    for t in range(252, T): mom[t] = np.prod(1 + R[t - 252:t - 21], axis=0) - 1
    k = max(1, int(N * frac)); w_prev = np.zeros(N); pnl = []
    for t in range(252, T - 1):
        if (t - 252) % reb == 0:
            s = mom[t]; m = np.isfinite(s)
            order = np.argsort(np.where(m, s, np.nan))
            wl = np.zeros(N); wl[order[-k:]] = 1.0 / k
            w = wl - m / m.sum()
        else:
            w = w_prev
        p = float(np.nansum(w * R[t + 1]))
        if cost: p -= np.abs(w - w_prev).sum() * COST
        pnl.append(p); w_prev = w
    return np.array(pnl)

print("=" * 70, "\nBOOM #3 — leader-selection momentum tilt (beta-neutral)\n" + "=" * 70)
neu = momentum_tilt(MEGA); s, c, d = ann(neu)
print(f"\nfull sample (monthly reb, net 2bp): Sharpe {s:+.2f}  ann {c*100:+.1f}%  maxDD {d*100:.0f}%")
h = len(neu) // 2
print(f"  sub-periods: first half {ann(neu[:h])[0]:+.2f} | second half {ann(neu[h:])[0]:+.2f}")
print(f"  gross (no cost): Sharpe {ann(momentum_tilt(MEGA, cost=False))[0]:+.2f}")
print("  leave-one-out (fragility check):")
for drop in (["NVDA"], ["NVDA", "TSLA"], ["NVDA", "AVGO", "AMD"]):
    nn = momentum_tilt([x for x in MEGA if x not in drop])
    print(f"    drop {','.join(drop):<16} Sharpe {ann(nn)[0]:+.2f}  ann {ann(nn)[1]*100:+.1f}%")
print("  rebalance sensitivity:")
for reb in (5, 21, 63):
    print(f"    every {reb:>2}d: Sharpe {ann(momentum_tilt(MEGA, reb=reb))[0]:+.2f} (net)")
print("\nVERDICT: real, prospective, cost-robust, sub-period stable — the Boom keeper.")
print("But the edge lives in a few explosive names (NVDA especially); it is a")
print("concentrated momentum bet wearing a diversified costume. Develop it WITH the")
print("boom_2 crowding limits, not despite them.")

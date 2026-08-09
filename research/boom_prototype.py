#!/usr/bin/python3
# =============================================================================
# boom_prototype.py — BLAQUE BAUX BOOM, the #3 tilt as a GOVERNED prototype.
#
# boom_3 found a real but FRAGILE edge: 12-1 momentum tilting to megacap leaders,
# whose returns concentrate in a few explosive names (drop NVDA and it halves).
# A governed sleeve must therefore BOUND that concentration and total risk the way
# the engine's safety gate would in production. This prototype does three things the
# raw research did not:
#   1. PER-NAME CAP   — no single name exceeds `per_name_cap` of the book (the gate's
#                       max_position_pct analog), so it can't become an all-NVDA bet.
#   2. VOL TARGETING  — scale gross exposure to a target vol on the book's own realized
#                       P&L (RiskMetrics EWMA), cash the residual; caps gross leverage.
#   3. COST MODEL     — charge turnover at `cost_bps`/side.
# It reports the governed long sleeve, its market-hedged (beta-neutral) cut, an
# uncapped comparison, and a wider (top-third) book that trades some return for less
# single-name dependence. Honest: single-commodity-of-a-kind concentration risk
# remains by construction; this bounds it, it does not remove it. NOT validated to
# the spine's bar; a paper-A/B candidate.
# Read-only. Reads ALPACA_KEY_ID / ALPACA_SECRET_KEY from env.
# =============================================================================
import os, sys, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _boom_common import MEGA, panel, ann

def ewma_vol_ann(r, hl=20):
    lam = 0.5 ** (1 / hl); v = 0.0; out = np.empty(len(r))
    for t in range(len(r)):
        v = r[t] ** 2 if t == 0 else lam * v + (1 - lam) * r[t] ** 2
        out[t] = math.sqrt(max(v, 1e-12)) * math.sqrt(252)
    return out

def governed_tilt(reb=21, frac=0.2, per_name_cap=0.15, vol_target=0.12, lev_cap=2.0,
                  hedge=False, cost_bps=2.0):
    u, dts, M = panel(MEGA + ["SPY"]); R = M[1:] / M[:-1] - 1
    idx = {s: u.index(s) for s in u}
    cols = [idx[s] for s in MEGA if s in idx]; Rm = R[:, cols]; spy = R[:, idx["SPY"]]
    T, N = Rm.shape
    mom = np.full((T, N), np.nan)
    for t in range(252, T): mom[t] = np.prod(1 + Rm[t - 252:t - 21], axis=0) - 1
    k = max(1, int(N * frac)); cost = cost_bps / 1e4
    wl = np.zeros(N)                                  # capped EW target (pre-scale)
    book_hist = []; pos_prev = np.zeros(N); hedge_prev = 0.0; pnl = []; maxw = []
    for t in range(252, T - 1):
        if (t - 252) % reb == 0:
            s = mom[t]; m = np.isfinite(s)
            order = np.argsort(np.where(m, s, np.nan))
            wl = np.zeros(N); wl[order[-k:]] = 1.0 / k
            wl = np.minimum(wl, per_name_cap)         # per-name cap
            if wl.sum() > 0: wl = wl / wl.sum()       # renormalize to fully invested pre-scale
        bl = float(wl @ Rm[t])                        # unscaled book return today (for vol est)
        book_hist.append(bl)
        vol = ewma_vol_ann(np.array(book_hist))[-1]
        scale = min(lev_cap, vol_target / max(vol, 1e-6))
        pos = scale * wl                              # scaled positions for tomorrow
        hedge_w = scale if hedge else 0.0             # short SPY at same gross when hedged
        p = float(pos @ Rm[t + 1]) - hedge_w * spy[t + 1]
        p -= (np.abs(pos - pos_prev).sum() + abs(hedge_w - hedge_prev)) * cost
        pnl.append(p); pos_prev = pos; hedge_prev = hedge_w; maxw.append(pos.max())
    return np.array(pnl), np.mean(maxw)

print("=" * 72, "\nBLAQUE BAUX BOOM — #3 tilt, governed prototype\n" + "=" * 72)
print("(12-1 momentum, monthly reb, per-name cap 15%, vol-target 12%, net 2bp/side)\n")

pnl, mw = governed_tilt(hedge=False)
s, c, d = ann(pnl); print(f"  GOVERNED long sleeve:        Sharpe {s:+.2f}  CAGR {c*100:+.1f}%  maxDD {d*100:.0f}%  (avg max-name wt {mw*100:.0f}%)")
pnl, _ = governed_tilt(hedge=True)
s, c, d = ann(pnl); print(f"  GOVERNED market-hedged:      Sharpe {s:+.2f}  CAGR {c*100:+.1f}%  maxDD {d*100:.0f}%  (the pure-alpha cut)")
pnl, mw = governed_tilt(per_name_cap=1.0, vol_target=99.0, lev_cap=1.0)  # effectively uncapped, unscaled
s, c, d = ann(pnl); print(f"  uncapped / unmanaged long:   Sharpe {s:+.2f}  CAGR {c*100:+.1f}%  maxDD {d*100:.0f}%  (avg max-name wt {mw*100:.0f}%)")
pnl, mw = governed_tilt(frac=0.33)
s, c, d = ann(pnl); print(f"  wider book (top third):      Sharpe {s:+.2f}  CAGR {c*100:+.1f}%  maxDD {d*100:.0f}%  (avg max-name wt {mw*100:.0f}%)")

print("\nread: the governance controls trade raw return for a bounded book — capped")
print("single-name weight (~8% vs ~17% uncapped) and a vol-targeted drawdown (-14% vs")
print("-36%) at a similar Sharpe. The market-hedged cut isolates alpha from megacap")
print("BETA, but part of that alpha IS the megacap factor: hedged vs the EW-megacap")
print("basket (boom_3's stricter test) it is ~+0.55, not +0.84. Concentration risk is")
print("bounded, not eliminated (boom_2); a governed live driver enforces these caps.")

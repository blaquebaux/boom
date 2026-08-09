# Blaque Baux Boom — research

First-pass Path-A research on the megacap / blue-chip sleeve. Same discipline as the
rest of the family: build it, test it honestly on real data, keep the record —
including what fails. All sketches read Alpaca SIP daily bars
(`ALPACA_KEY_ID` / `ALPACA_SECRET_KEY` from env), are read-only, and print their own
results. Numbers are **gross of costs** unless marked NET, over 2016–2026. The
cross-sectional universe is 30 current megacaps (survivorship-aware caveat: current
constituents → treat as directional).

```bash
export $(grep -v '^#' ~/.config/blaquebaux/alpaca.env | xargs)   # or source it
python research/boom_3_leader_momentum.py    # the keeper
python research/boom_1_concentration.py      # etc.
```

## Scorecard

| # | Question | Result | Verdict |
|---|----------|--------|---------|
| 1 | Did concentrating in the megacap leaders beat the index? | EW Mag7 +1.15 Sharpe / +33.6% CAGR vs SPY +0.88 / +15% — but ex-post winner selection | ⚠️ hindsight, not alpha |
| 2 | How many independent bets are 7 megacaps? | ~2.8 of 7; one factor = 57% of variance; 0.49 avg pairwise corr | ✅ risk finding (drives sizing) |
| 3 | Does a momentum RULE tilting to leaders beat holding the set? | beta-neutral **+0.55 net** (monthly), stable across halves; **governed prototype** below | ✅ the keeper (but fragile) |
| 4 | Post-earnings drift in megacaps? | fair re-test (real earnings, excess of SPY): reaction-based drift **+216 bp @20d, t=2.41** | ✅ real (reaction-based) |

## The synthesis

**Megacap outperformance is real, prospectively capturable, and dangerously concentrated —
all at once.**

- **#1 is a trap dressed as a triumph.** Equal-weighting the Mag7 returned +33.6% CAGR and
  beat SPY by ~+1.0 Sharpe — but that is the return to *having known* which seven names
  would win the decade. It is a benchmark and a caution, not a strategy.
- **#3 is the honest, prospective version.** A 12-1 momentum rule that rotates into the
  leaders as they emerge earns a genuine beta-neutral edge (**+0.55 net**, monthly
  rebalanced, cost-robust, stable across both halves). You could have run it without
  foreknowledge.
- **But #2 and #3 are the same story.** The momentum edge is heavily concentrated: drop
  NVDA and it falls to +0.39; drop NVDA+TSLA and it is +0.21. That is exactly #2's finding —
  seven megacaps are really ~2.8 independent bets on one factor — showing up in the returns.
  The "diversified tilt" is largely a bet on whichever one or two names are exploding.
- **#4 flipped on a fair re-test.** The first pass (gap proxy, raw returns) was a *false
  negative*: it caught any big gap, not real earnings, and didn't strip beta. Re-run on
  **real earnings dates + EPS surprise, measured excess of SPY**, PEAD is real — misses drift
  down hard (−189 bp @20d), and drift in the direction of the **announcement-day reaction**
  is the tradeable signal (long-up/short-down: +107 bp/event @20d, **t = 2.41**). The naïve
  beat/miss long-short is weak (t≈1.2) only because megacaps beat ~83% of the time. Modest
  and event-scale — a candidate overlay, not a core sleeve.

## The governed prototype (#3)

`boom_prototype.py` builds the #3 tilt as the risk-bounded sleeve a governed live driver would
run: per-name cap (15%), vol-target (12%) on the book's own realized P&L, cost model.

| version | Sharpe | CAGR | maxDD | avg max-name wt |
|---|---|---|---|---|
| governed long sleeve | **+1.16** | +14.6% | **−14%** | 8% |
| governed market-hedged (alpha cut) | +0.84* | +7.2% | −11% | — |
| uncapped / unmanaged | +1.11 | +33.2% | −36% | 17% |
| wider book (top third) | +1.18 | +14.8% | −15% | 6% |

The governance controls cut drawdown from −36% to −14% at a similar Sharpe, and hold single-name
weight to ~8%. *The market-hedged +0.84 is vs SPY and still contains the megacap *factor*
premium; hedged against the EW-megacap basket (boom_3's stricter test) the pure within-megacap
alpha is ~+0.55. Concentration risk is bounded, not eliminated.

**Where this goes:** the Boom sleeve = the governed #3 tilt (paper-A/B candidate once a live
driver enforces the caps), optionally with the #4 reaction-based PEAD as an earnings-window
overlay. Not real capital, and nothing here is validated to the spine's bar.

## Files
- `_boom_common.py` — shared data/metrics helpers + the universes.
- `boom_1_concentration.py` — concentration vs index (hindsight caveat).
- `boom_2_crowding.py` — one-factor / crowding risk (effective # bets).
- `boom_3_leader_momentum.py` — the keeper: beta-neutral momentum tilt + robustness.
- `boom_prototype.py` — the #3 tilt as a governed, concentration-bounded prototype.
- `boom_4_pead.py` — post-earnings drift, fair test (real earnings; requires `yfinance`+`lxml`).

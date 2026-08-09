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
| 3 | Does a momentum RULE tilting to leaders beat holding the set? | beta-neutral **+0.55 net** (monthly), stable across halves | ✅ the keeper (but fragile) |
| 4 | Post-earnings drift in megacaps? | up- and down-gaps both drift up; up−down spread negative | ❌ no PEAD (beta + mild bounce) |

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
- **#4 is rejected.** No post-earnings drift survives; the apparent "drift" is secular beta,
  and the up-minus-down spread is negative (a mild post-drop bounce, the opposite of PEAD).

**Where this goes:** a Boom sleeve = the #3 momentum tilt, sized *under* the #2 crowding
limits (cap single-name and single-factor exposure, budget for a ~-20% drawdown, and don't
mistake the name count for diversification). It is a candidate for a paper A/B once built —
not real capital, and not until the concentration risk is explicitly bounded.

## Files
- `_boom_common.py` — shared data/metrics helpers + the universes.
- `boom_1_concentration.py` — concentration vs index (hindsight caveat).
- `boom_2_crowding.py` — one-factor / crowding risk (effective # bets).
- `boom_3_leader_momentum.py` — the keeper: beta-neutral momentum tilt + robustness.
- `boom_4_pead.py` — post-earnings drift (rejected).

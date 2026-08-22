# Blaque Baux Boom

**The names that carry the index. Mega-cap blue chips — the Magnificent 7 and their peers — where liquidity is deepest and leadership is most concentrated.**

Boom is a member of the Blaque Baux family. The [core repo](https://github.com/blaquebaux/base)
is the **engine and blueprint**. Boom points that engine at the top of the market: the
highest-quality, highest-liquidity megacaps that have driven the bulk of index returns. It
inherits the engine's governance wholesale. It is the deliberate opposite of **Bottom** —
same platform, opposite end of the cap ladder.

> **Not investment advice.** Educational/research software. Concentration in a handful of
> megacaps carries crowding and single-name idiosyncratic risk. Nothing here is validated.
> See [LICENSE](LICENSE).

```bash
git clone --recursive https://github.com/blaquebaux/boom.git
julia --project=engine -e 'using Pkg; Pkg.instantiate()'   # one-time engine setup
```

## The thesis

Two base findings point straight at this universe. First, cross-sectionally, **going long
the highest trailing-Sharpe names works** (+1.26 raw, +0.38 beta-neutral) — a quality/
momentum tilt that megacaps have embodied. Second, the correlation study found **big tech
trades as roughly one factor**, cross-name read-through is priced *instantly*, and tech
lead-lag even *reverses* — so the edge here is unlikely to be timing one name off another;
it is more plausibly a disciplined quality/momentum tilt with honest concentration control.
Boom's job is to capture megacap leadership without pretending the crowding risk isn't real.

## Research — first pass done

Full detail, numbers, and both the wins and the rejections are in
[`research/README.md`](research/README.md). The scorecard:

| # | Question | Verdict |
|---|----------|---------|
| 1 | Did concentrating in the leaders beat the index? | ⚠️ won huge (+33.6% CAGR) but it's **hindsight**, not repeatable alpha |
| 2 | How many bets are 7 megacaps really? | ✅ **~2.8 of 7**, one factor = 57% of variance — a risk finding |
| 3 | Does a momentum RULE tilting to leaders beat holding the set? | ✅ **the keeper** — beta-neutral +0.55 net; built into a governed prototype (+1.16 Sharpe, −14% DD) |
| 4 | Post-earnings drift in megacaps? | ✅ **real** on a fair re-test (reaction-based, +216 bp @20d, t=2.41); proxy was a false negative |

**The synthesis:** megacap outperformance is real, prospectively capturable via a 12-1
momentum rule (#3), and dangerously concentrated — dropping NVDA nearly halves the edge,
which is #2's one-factor reality showing up in the returns. The #3 tilt is now a **governed
prototype** (`research/boom_prototype.py`): per-name cap + vol-target take the raw
+33% CAGR / −36% DD book to **+14.6% CAGR / −14% DD at Sharpe +1.16**, with single-name
weight held to ~8%. And a fair re-test resurrected **#4**: real post-earnings drift exists
(reaction-based, t=2.41) as a candidate earnings-window overlay.

## Live driver

`live/boom_live.jl` is the governed graduation of the #3 tilt — it runs on the engine's
ExecutionController + Layer-3 safety gate (idempotency, reconciliation, kill switch, fill
lineage), trades the top-quintile 12-1 momentum book equal-weighted with the per-name
guardrail and vol-target from the prototype, and rebalances the delta daily. Crude single-
name concentration is bounded by vol-targeting and equal-weighting, not eliminated.

```bash
julia --project=engine -e 'using Pkg; Pkg.instantiate()'       # one-time engine setup
BB_DRYRUN=1 julia --project=engine live/boom_live.jl           # prints the book, trades nothing
```

Activate as a paper A/B leg: create an Alpaca paper account, save its keys to
`~/.config/blaquebaux/alpaca_boom.env` (chmod 600), then the installed launchd agent
(`live/com.blaquebaux.boom.plist`) picks it up. PAPER by default; real money needs the
explicit `BB_LIVE_CONFIRM` sentinel.

### Bonds-regime overlay — cross-sleeve sizing (wired, OFF by default)

BOOM can consume the regime read published by [Bonds](https://github.com/blaquebaux/bonds)
(`~/.config/blaquebaux/bonds_regime.txt`): de-risk gross ×0.75 when the stock-bond correlation is
positive (bond hedge dead). It's wired in with a graceful fallback (missing/stale → full gross) and a
`BB_BONDS_OVERLAY=1` toggle — but it ships **OFF by default**, because on the full cycle it does not
earn its place.

**Validated** ([`live/boom_regime_validation.jl`](live/boom_regime_validation.jl)) — causal
walk-forward, net of cost, reusing the real book and the same 63d SPY–IEF regime the bonds driver
publishes, on the **full 2016–2026 SIP history**:

| book | Sharpe | CAGR | vol | maxDD |
|------|--------|------|-----|-------|
| FULL (always full gross) | +1.18 | 16.6% | 13.8% | −19% |
| OVERLAY (regime de-risk) | +1.13 | 14.8% | 12.9% | −19% |

**0% drawdown cut, −0.05 Sharpe** (de-risked 35% of rebalances) — the overlay does *not* help. An
earlier run on the engine's default IEX feed (only ~2021+) showed a −22% drawdown cut, but that was an
**artifact of the 2022-dominated window**: BOOM's worst full-cycle drawdown is the 2020 COVID crash — a
*negative*-correlation episode where the overlay (correctly) does nothing — so trimming gross only in
positive-correlation periods gave up return without touching the max drawdown. Honest verdict: OFF.

```bash
julia --project=engine live/boom_regime_validation.jl   # the overlay-earns-its-place test (full SIP)
```

### Market-regime overlay — the conditional-keeper test (wired, OFF by default / opt-in)

BOOM can *also* consume [benchmark](https://github.com/blaquebaux/benchmark)'s market-internals composite
(`~/.config/blaquebaux/market_regime.txt`): de-risk gross ×0.5 when the regime is risk-off. This is the
**conditional-keeper test** from the "aberrations" question — *does a gate de-risk BOOM into the black-swan
crashes and clear the family bar with them left IN?* — evaluated with the family's new fat-tail toolkit
([`live/boom_market_regime_validation.jl`](live/boom_market_regime_validation.jl), full 2016–2026 SIP):

| book | Sharpe | CAGR | vol | maxDD | skew | JB |
|------|--------|------|-----|-------|------|-----|
| FULL (vol-targeted, always) | +1.22 | 17.2% | 13.8% | −19% | **−0.31** | non-normal |
| OVERLAY (market_regime gate) | **+1.26** | 13.7% | 10.7% | **−11%** | **+0.23** | non-normal |

A genuinely close call, and instructive. The gate **cuts maxDD 41%** (−19%→−11%), nudges Sharpe **up**
(+1.22→+1.26), lifts **M²** (+5.5%→+6.3% excess over SPY), and — most tellingly — **flips return skew from
−0.31 to +0.23**, removing the classic momentum-crash left tail (JB rejects normality for both, so that
tail is real and matters). But it de-risks ~48% of the time and **gives back ~20% of return**, so it
**FAILS the retain-≥80%-return leg** of the default-ON bar (80% kept, just under). Why: **BOOM already
vol-targets (12%)**, so it self-de-risks — like [broad](https://github.com/blaquebaux/broad) and
[bridgewater](https://github.com/blaquebaux/bridgewater), a managed book the blanket overlay can't earn a
default place on (benchmark #4's law). **Verdict: not a default-ON conditional keeper — but a legitimate
drawdown/left-tail *insurance* option**, wired **opt-in** (`BB_MARKET_OVERLAY=1`).

```bash
julia --project=engine live/boom_market_regime_validation.jl   # the conditional-keeper test (full SIP)
```

## Status
**Research complete; keeper prototyped and graduated to a governed live driver**
(`live/boom_live.jl`), plus the #4 PEAD overlay confirmed. **Two regime overlays wired, both OFF by
default**: the bonds-regime sizing overlay (doesn't earn its place — 0% DD cut) and the market-regime
overlay (the conditional-keeper test — cuts DD 41% and flips skew positive, but gives back ~20% return, so
it fails the default-ON bar and ships as opt-in insurance). BOOM already vol-targets, so it self-de-risks.
Paper-A/B ready once account keys are added; nothing validated to the spine's bar, no real capital.

## About Blaque Baux

**Blaque Baux** is a quantitative research initiative and a subsidiary of **[Carter Warrens](https://carterwarrens.com)**.
[**BlaqueBaux.com**](https://blaquebaux.com) is the home for the work; the code lives here on GitHub — open to
study, test, and build bespoke strategies on top of.

Anyone can point an AI at a market. The edge is **understanding what the data actually says — and turning it
into something you can act on.** We test relentlessly and put most of it *on the record as rejected, with the
reason*; what survives is built, governed, and validated before it is ever called real. That combination —
honest research, reproducible evidence, and execution you can trust — is why Carter Warrens leads on
**strategy and implementation**, not merely uses the tools everyone now has.

## The Blaque Baux family
This repo is one sleeve of the **Blaque Baux** family — a single governed engine steered in
many directions. The [core repo](https://github.com/blaquebaux/base) is the
base/blueprint and holds the [full family roster](https://github.com/blaquebaux/base#the-blaquebaux-family).

## Layout
```
engine/     the Blaque Baux platform (git submodule → blaquebaux/base)
research/   Path-A strategy sketches + the #3 governed prototype + scorecard
live/       boom_live.jl (governed driver, bonds + market regime overlays, both opt-in) + boom_regime_validation.jl + boom_market_regime_validation.jl + wrapper + plist
```

## License
[MIT](LICENSE). © 2026 Carter Warrens.

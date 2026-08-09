# Blaque Baux Boom

**The names that carry the index. Mega-cap blue chips — the Magnificent 7 and their peers — where liquidity is deepest and leadership is most concentrated.**

Boom is a member of the Blaque Baux family. The [core repo](https://github.com/Carter-Warrens/blaquebaux)
is the **engine and blueprint**. Boom points that engine at the top of the market: the
highest-quality, highest-liquidity megacaps that have driven the bulk of index returns. It
inherits the engine's governance wholesale. It is the deliberate opposite of **Bottom** —
same platform, opposite end of the cap ladder.

> **Not investment advice.** Educational/research software. Concentration in a handful of
> megacaps carries crowding and single-name idiosyncratic risk. Nothing here is validated.
> See [LICENSE](LICENSE).

```bash
git clone --recursive https://github.com/Carter-Warrens/blaquebaux-boom.git
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

## Status
**Research: keeper prototyped, #4 confirmed** (`research/`). Next graduation step is a
governed live driver enforcing the same caps. No live driver yet; nothing validated to the
spine's bar.

## The Blaque Baux family
- **Blaque Baux** — base engine + validated slow risk-premium spine.
- **Blunt** — short-horizon tactical sleeves.
- **Brash** — highly aggressive (crypto, alternatives).
- **Bleed** — deeply contrarian; positioned for the tails.
- **Bottom** — sub-small-cap / penny names.
- **Brittle** — near-expiry, far-OTM options/ETFs; the other side of the lottery ticket.
- **Boom** *(this repo)* — mega-cap blue chips (the Magnificent 7 and peers).

## Layout
```
engine/     the Blaque Baux platform (git submodule → Carter-Warrens/blaquebaux)
research/   Path-A strategy sketches (to come)
live/       governed live drivers (once a sleeve graduates to paper A/B)
```

## License
[MIT](LICENSE). © 2026 Carter Warrens.

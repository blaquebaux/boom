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

## Research plan (Path A — not yet built)

- **Quality/momentum tilt on megacaps** — extend the base's long-high-Sharpe finding to a
  concentrated blue-chip book; test beta-neutral to isolate real selection from market beta.
- **Concentration vs the index** — when does over/under-weighting the leaders beat just
  holding the cap-weighted index (which is already mostly these names)?
- **Post-earnings drift** — the one megacap event with a plausible, testable signal.
- **Crowding / one-factor risk** — size with the correlation-study reality that these names
  are largely one factor; diversification here is an illusion to guard against.

## Status
**Scaffold.** Engine wired as a submodule; strategy research not yet conducted.

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

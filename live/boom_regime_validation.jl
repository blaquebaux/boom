#!/usr/bin/env julia
# ============================================================================
# boom_regime_validation.jl — does the BONDS regime overlay improve BOOM?
#
# BOOM is a net-long megacap book. The claim being tested: de-risking its gross when the
# stock-bond correlation is POSITIVE (bond hedge dead — no diversification cushion, worse
# equity tails) improves BOOM's RISK-ADJUSTED outcome vs running full gross always.
#
# Fully causal walk-forward reusing boom_weights (the real book) on the megacap universe,
# and the SAME 63d SPY-IEF correlation regime the bonds driver publishes. Compares:
#   FULL    — boom at its vol-targeted gross, always
#   OVERLAY — boom gross x REGIME_DERISK whenever the bond hedge is dead (pos-corr)
# Net of cost. Reuses boom_weights + REGIME_DERISK from boom_live.jl.
#   Run:  julia --project=engine live/boom_regime_validation.jl
# ============================================================================
include(joinpath(@__DIR__, "boom_live.jl"))
using Dates, Printf, Statistics, LinearAlgebra

_sh(r; ann = 252) = (x = r[isfinite.(r)]; s = std(x); s > 0 ? mean(x) / s * sqrt(ann) : NaN)
_dd(r) = (lvl = cumprod(1 .+ r); minimum(lvl ./ accumulate(max, lvl) .- 1))
_cagr(r) = (lvl = cumprod(1 .+ r); lvl[end]^(252 / length(r)) - 1)

function fetch_panel(U, lb = 2600)
    try
        return panel_at(AlpacaPanelProvider(U; lookback = lb))
    catch e
        m = match(r"only (\d+) common", sprint(showerror, e)); m === nothing && rethrow(e)
        n = parse(Int, m.captures[1]) - 20; (n < 400 || n >= lb) && rethrow(e)
        return fetch_panel(U, n)
    end
end

function main_validate(; reb = 21, warmup = MOM_LONG + VOL_WIN + 5, corr_win = 63,
                       cost_bps = parse(Float64, get(ENV, "BB_COST_BPS", "5")),
                       derisk = REGIME_DERISK)
    panel = fetch_panel(vcat(UNIVERSE, "SPY", "IEF"))
    R = panel.returns; syms = panel.symbols; T = size(R, 1); cost = cost_bps / 1e4
    ui = [findfirst(==(s), syms) for s in UNIVERSE]          # universe columns (exclude SPY/IEF)
    spy = R[:, findfirst(==("SPY"), syms)]; ief = R[:, findfirst(==("IEF"), syms)]
    Ru = R[:, ui]

    full = Float64[]; over = Float64[]; oosidx = Int[]
    wf_prev = zeros(length(UNIVERSE)); wo_prev = zeros(length(UNIVERSE)); npos = 0; nderisk = 0
    for t0 in warmup:reb:(T-1)
        w, _, _ = boom_weights(Ru[1:t0, :])                 # vol-targeted book weights (causal)
        corr = cor(spy[t0-corr_win+1:t0], ief[t0-corr_win+1:t0])
        hedge_on = corr < 0; scale = hedge_on ? 1.0 : derisk
        npos += 1; hedge_on || (nderisk += 1)
        wo = w .* scale
        tf = sum(abs, w .- wf_prev); to = sum(abs, wo .- wo_prev)
        for day in (t0+1):min(t0+reb, T)
            rf = dot(w,  Ru[day, :]); ro = dot(wo, Ru[day, :])
            if day == t0 + 1; rf -= tf * cost; ro -= to * cost; end
            push!(full, rf); push!(over, ro); push!(oosidx, day)
        end
        wf_prev = w; wo_prev = wo
    end

    println("="^78, "\nBOOM + bonds-regime overlay — does de-risking in pos-corr help?\n", "="^78)
    @printf("\n  OOS days %d   rebalances %d   de-risked %d of them (%.0f%%)   derisk x%.2f, net %d bps/side\n",
            length(full), npos, nderisk, 100nderisk/npos, derisk, round(Int, cost*1e4))
    @printf("  %-28s %8s %8s %7s %8s\n", "book", "Sharpe", "CAGR", "vol", "maxDD")
    for (lbl, r) in [("FULL (always full gross)", full), ("OVERLAY (regime de-risk)", over)]
        @printf("  %-28s %+8.2f %7.1f%% %6.1f%% %7.0f%%\n", lbl, _sh(r), _cagr(r)*100, std(r)*sqrt(252)*100, _dd(r)*100)
    end

    shF, shO = _sh(full), _sh(over); ddF, ddO = _dd(full), _dd(over)
    dd_cut = 1 - abs(ddO) / abs(ddF); ret_keep = _cagr(over) / _cagr(full)
    println("\n  THE BAR (overlay must earn its place):")
    checks = [
        ("Sharpe not worse (>= FULL - 0.03)", shO >= shF - 0.03, @sprintf("%.2f vs %.2f", shO, shF)),
        ("reduces max drawdown",              ddO > ddF,          @sprintf("%.0f%% -> %.0f%% (%.0f%% cut)", ddF*100, ddO*100, dd_cut*100)),
        ("retains >= 80% of return",          ret_keep >= 0.80,   @sprintf("%.0f%% kept", ret_keep*100)),
    ]
    for (n, ok, v) in checks; @printf("    [%s] %-36s %s\n", ok ? "PASS" : "FAIL", n, v); end
    allpass = all(c -> c[2], checks)
    println("\n  VERDICT: ", allpass ?
        "PASS — the bonds-regime overlay improves BOOM's risk-adjusted profile (shallower drawdown for\n           ~the same Sharpe). Wire it in (BB_BONDS_OVERLAY=1, the default)." :
        "MIXED — the overlay does not clearly earn its place on this sample; ships OFF-by-default until it does.")
    return (; pass = allpass, shF, shO, ddF, ddO, dd_cut, ret_keep)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_validate()
end

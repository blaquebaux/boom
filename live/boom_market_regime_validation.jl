#!/usr/bin/env julia
# ============================================================================
# boom_market_regime_validation.jl — the CONDITIONAL-KEEPER test for BOOM.
#
# The question (from the "aberrations" discussion): BOOM is a net-long megacap 12-1 momentum book. Judged
# on the full sample it's a keeper, but its worst pain is the black-swan crashes (2020, 2022). Is there a
# regime signal that de-risks it INTO those aberrations — and does the GATED book clear the family bar on
# the FULL sample, black swans left IN (not excluded)? benchmark #4 says market_regime (vol-timing) earns
# its keep on naive high-beta long books; the twist is that BOOM already vol-targets (VOL_TARGET=12%), so
# this is a genuine test, not a foregone win (cf. broad, which self-de-risks and DECLINED the overlay).
#
# Fully causal walk-forward reusing boom_weights (the real book), gated by the SAME market-internals
# composite benchmark publishes (market_regime.txt), reconstructed causally here. Full 2016-2026 SIP, net
# of cost. Reports the family overlay bar + the new fat-tail toolkit (Jarque-Bera, Jensen's alpha, M^2) +
# a black-swan-episode breakdown (does the gate actually cut the crash losses?).
#   Run:  julia --project=engine live/boom_market_regime_validation.jl
# ============================================================================
include(joinpath(@__DIR__, "boom_live.jl"))
using Dates, Printf, Statistics, LinearAlgebra

const INTERNALS = ["SPY", "RSP", "HYG", "LQD", "DIA", "IYT", "XLU", "VIXY", "TLT"]
const MARKET_DERISK = parse(Float64, get(ENV, "BB_MARKET_DERISK", "0.5"))   # benchmark's market_regime standard

_sh(r; ann = 252) = (x = r[isfinite.(r)]; s = std(x); s > 0 ? mean(x) / s * sqrt(ann) : NaN)
_dd(r) = (lvl = cumprod(1 .+ r); minimum(lvl ./ accumulate(max, lvl) .- 1))
_cagr(r) = (lvl = cumprod(1 .+ r); lvl[end]^(252 / length(r)) - 1)

# --- fat-tail toolkit (family evaluation standard) ---
function _jb(r)
    r = r[isfinite.(r)]; n = length(r); m = mean(r); s = std(r)
    s == 0 && return (jb=0.0, p=1.0, skew=0.0, exkurt=0.0, normal=true)
    z = (r .- m) ./ s; sk = mean(z.^3); ku = mean(z.^4) - 3
    jb = n/6 * (sk^2 + ku^2/4); (jb=jb, p=exp(-jb/2), skew=sk, exkurt=ku, normal=(exp(-jb/2) >= 0.05))
end
function _jensen(r, rb; rf = 0.0)
    rf_d = rf/252; b = cov(r, rb)/var(rb)
    (alpha_ann = ((mean(r) - rf_d) - b*(mean(rb) - rf_d))*252, beta = b)
end
function _m2(r, rb; rf = 0.0)
    rf_d = rf/252; sh = (mean(r) - rf_d)/std(r)*sqrt(252)
    m2 = rf + sh*std(rb)*sqrt(252); (m2_ann = m2, m2_excess = m2 - ((1+mean(rb))^252 - 1))
end

function fetch_panel(U, lb = 2600)
    try
        return panel_at(AlpacaPanelProvider(U; lookback = lb, calendar_days = 4300, feed = "sip"), Dates.today() - Day(30))
    catch e
        m = match(r"only (\d+) common", sprint(showerror, e)); m === nothing && rethrow(e)
        n = parse(Int, m.captures[1]) - 20; (n < 400 || n >= lb) && rethrow(e)
        return fetch_panel(U, n)
    end
end

# market_regime composite as a causal (lagged) series — mirrors benchmark_live.market_regime
_relpath(R, i) = cumprod(vcat(1.0, 1 .+ R[:, i]))[2:end]
_trend(x, w) = (t = fill(NaN, length(x)); for k in w+1:length(x); t[k] = x[k]/x[k-w]-1; end; t)
_rvol(r, w) = (v = fill(NaN, length(r)); for k in w+1:length(r); v[k] = std(@view r[k-w:k-1])*sqrt(252); end; v)
_rollz(x, w) = ([ (h = [x[j] for j in max(1,k-w):k-1 if isfinite(x[j])]; (length(h) >= w÷2 && std(h) > 0) ? (x[k]-mean(h))/std(h) : NaN) for k in 1:length(x) ])
function composite_lag(R, syms)
    i(s) = findfirst(==(s), syms); rp(s) = _relpath(R, i(s))
    sig = [ _trend(rp("HYG")./rp("LQD"),21), _trend(rp("RSP")./rp("SPY"),21), _trend(rp("IYT")./rp("DIA"),21),
            _trend(rp("SPY")./rp("XLU"),21), -_trend(rp("VIXY"),21), -_rvol(R[:, i("TLT")],20) ]
    Z = hcat([_rollz(s, 252) for s in sig]...)
    comp = [ (v = Z[k, isfinite.(Z[k,:])]; isempty(v) ? NaN : mean(v)) for k in 1:size(Z,1) ]
    vcat(NaN, comp[1:end-1])
end

function main_validate(; reb = 21, warmup = MOM_LONG + VOL_WIN + 5,
                       cost_bps = parse(Float64, get(ENV, "BB_COST_BPS", "5")), derisk = MARKET_DERISK)
    panel = fetch_panel(unique(vcat(UNIVERSE, INTERNALS)))
    R = panel.returns; syms = panel.symbols; T = size(R, 1); cost = cost_bps/1e4
    ui = [findfirst(==(s), syms) for s in UNIVERSE]; Ru = R[:, ui]
    spy = R[:, findfirst(==("SPY"), syms)]
    ron = composite_lag(R, syms) .> 0

    full = Float64[]; over = Float64[]; oosidx = Int[]
    wf_prev = zeros(length(UNIVERSE)); wo_prev = zeros(length(UNIVERSE)); npos = 0; nde = 0
    for t0 in warmup:reb:(T-1)
        w, _, _ = boom_weights(Ru[1:t0, :])
        scale = ron[t0] ? 1.0 : derisk; npos += 1; ron[t0] || (nde += 1)
        wo = w .* scale
        tf = sum(abs, w .- wf_prev); to = sum(abs, wo .- wo_prev)
        for day in (t0+1):min(t0+reb, T)
            rf = dot(w, Ru[day, :]); ro = dot(wo, Ru[day, :])
            if day == t0 + 1; rf -= tf*cost; ro -= to*cost; end
            push!(full, rf); push!(over, ro); push!(oosidx, day)
        end
        wf_prev = w; wo_prev = wo
    end
    spyO = spy[oosidx]

    println("="^80, "\nBOOM + market_regime — the CONDITIONAL-KEEPER test (black swans left IN)\n", "="^80)
    @printf("\n  full 2016-2026 SIP; net %dbps; de-risk x%.2f in risk-off (%.0f%% of rebalances)\n", round(Int,cost*1e4), derisk, 100nde/npos)
    @printf("  %-30s %8s %8s %7s %8s\n", "book", "Sharpe", "CAGR", "vol", "maxDD")
    for (lbl, r) in [("FULL (vol-targeted, always)", full), ("OVERLAY (market_regime gate)", over), ("SPY (reference)", spyO)]
        @printf("  %-30s %+8.2f %7.1f%% %6.1f%% %7.0f%%\n", lbl, _sh(r), _cagr(r)*100, std(r)*sqrt(252)*100, _dd(r)*100)
    end

    # --- fat-tail toolkit ---
    println("\n  Fat-tail toolkit (family standard — Sharpe assumes normality; JB usually rejects it):")
    @printf("  %-30s %8s %7s %8s %9s %8s\n", "book", "JB p", "skew", "exkurt", "Jensen α", "M² exc")
    for (lbl, r) in [("FULL", full), ("OVERLAY", over)]
        j = _jb(r); je = _jensen(r, spyO); m = _m2(r, spyO)
        @printf("  %-30s %8.3f %+7.2f %8.1f %+8.1f%% %+7.1f%%   (%s)\n", lbl, j.p, j.skew, j.exkurt,
                je.alpha_ann*100, m.m2_excess*100, j.normal ? "normal" : "NON-normal → tail matters")
    end

    # --- black-swan episodes: SPY deep-drawdown (<-15%) stretches; does the gate cut the crash? ---
    lvl = cumprod(1 .+ spyO); dd = lvl ./ accumulate(max, lvl) .- 1
    inx = dd .< -0.15; segs = Tuple{Int,Int}[]; s = 0
    for k in 1:length(inx)
        if inx[k] && s == 0; s = k; elseif !inx[k] && s > 0; push!(segs, (s, k-1)); s = 0; end
    end
    s > 0 && push!(segs, (s, length(inx)))
    println("\n  Black-swan episodes (SPY in >15% drawdown) — cumulative return through each:")
    @printf("    %-14s %10s %10s %10s %8s\n", "episode(days)", "SPY", "FULL", "OVERLAY", "gate cut")
    cumret(r, a, b) = prod(1 .+ r[a:b]) - 1
    for (a, b) in segs
        b - a < 5 && continue
        sc, fc, oc = cumret(spyO,a,b), cumret(full,a,b), cumret(over,a,b)
        @printf("    %-14s %+9.0f%% %+9.0f%% %+9.0f%% %+7.0f%%\n", "$(b-a+1)d", sc*100, fc*100, oc*100, (oc-fc)*100)
    end

    # --- the verdict: family overlay bar, on the FULL sample (black swans in) ---
    shF, shO, ddF, ddO = _sh(full), _sh(over), _dd(full), _dd(over)
    dd_cut = 1 - abs(ddO)/abs(ddF); ret_keep = _cagr(over)/_cagr(full)
    println("\n  THE BAR (overlay must earn its place — family standard, full sample):")
    checks = [ ("Sharpe not worse (>= FULL - 0.03)", shO >= shF-0.03, @sprintf("%.2f vs %.2f", shO, shF)),
               ("reduces max drawdown",              ddO > ddF,       @sprintf("%.0f%% -> %.0f%% (%.0f%% cut)", ddF*100, ddO*100, dd_cut*100)),
               ("retains >= 80% of return",          ret_keep >= 0.80, @sprintf("%.0f%% kept", ret_keep*100)) ]
    for (n, ok, v) in checks; @printf("    [%s] %-36s %s\n", ok ? "PASS" : "FAIL", n, v); end
    allpass = all(c -> c[2], checks); improves = shO >= shF + 0.05
    println("\n  CONDITIONAL-KEEPER VERDICT: ", allpass ?
        "PASS — market_regime converts BOOM to a conditional keeper: it de-risks into the black-swan\n     episodes and clears the bar with them left IN. Wire ON (BB_MARKET_OVERLAY=1)." *
        (improves ? " (Also improves Sharpe — an unconditional win.)" : " (Drawdown relief at ~flat Sharpe.)") :
        "MIXED — the gate does not clearly earn its place on the full sample; BOOM already vol-targets, so\n     it self-de-risks (cf. broad). Ships OFF; not a conditional keeper via this signal.")
    return (; pass = allpass, shF, shO, ddF, ddO, dd_cut, ret_keep)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_validate()
end

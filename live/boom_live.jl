#!/usr/bin/env julia
# ============================================================================
# boom_live.jl — BLAQUE BAUX BOOM governed live driver (megacap momentum tilt).
#
# Runs on the Blaque Baux ENGINE (engine/ submodule) — the same governed order
# path and Layer-3 safety gate as the spine. Trades the boom_3 keeper, sized the
# way boom_prototype.py showed a governed sleeve must be:
#
#   data(30 megacaps) -> 12-1 MOMENTUM -> top-quintile, EW, per-name-capped,
#     VOL-TARGETED -> [ SAFETY GATE ] -> governed orders -> reconcile
#
# Risk controls (honest about what each one does):
#   - equal-weight the top quintile   => each name is <= 1/k by construction
#   - per-name hard cap (guardrail)   => bites only if weights ever become unequal
#   - vol-target on trailing book vol => bounds GROSS exposure (the real drawdown
#                                        control; took the prototype to -14% vs -36%)
#   - engine safety gate              => hard account/leverage/loss/staleness limits
# Concentration risk is BOUNDED, not eliminated: the edge still leans on whichever
# 1-2 names are leading (boom_2). This is a paper-A/B sleeve, NOT validated to the
# spine's bar and NOT for real capital.
#
# PAPER by default. Real money requires:  export BB_LIVE_CONFIRM=I_UNDERSTAND_THIS_IS_REAL_MONEY
# Kill switch: create ~/.config/blaquebaux/HALT. Dry run (no connect/trade): export BB_DRYRUN=1
# Run with the engine's Julia project:  julia --project=engine live/boom_live.jl
# ============================================================================
using Dates, Printf, Statistics

const REPO   = normpath(joinpath(@__DIR__, ".."))
const ENGINE = joinpath(REPO, "engine")
include(joinpath(ENGINE, "src/module_7_execution/module_7_execution.jl"))
include(joinpath(ENGINE, "src/module_10_feedback/module_10_feedback.jl"))
include(joinpath(ENGINE, "src/module_13_portfolio/module_13_portfolio.jl"))
include(joinpath(ENGINE, "src/module_1_data/equity_panel.jl"))
include(joinpath(ENGINE, "src/module_1_data/alpaca_panel.jl"))
include(joinpath(ENGINE, "src/module_8_governance/safety_gate.jl"))
using .ExecutionLayer, .FeedbackLayer, .PortfolioOptModule, .EquityPanel, .AlpacaPanel, .SafetyGate
include(joinpath(ENGINE, "scripts/live_execution.jl"))

# 30 megacap / blue-chip universe (mirrors research/_boom_common.py MEGA)
const UNIVERSE = ["AAPL","MSFT","NVDA","AMZN","GOOGL","META","TSLA","AVGO","LLY","JPM","V","MA",
                  "UNH","XOM","COST","HD","PG","JNJ","WMT","ORCL","NFLX","CVX","KO","PEP","BAC",
                  "CRM","MRK","ADBE","AMD","QCOM"]
const LIVE_SENTINEL = "I_UNDERSTAND_THIS_IS_REAL_MONEY"
const MOM_LONG   = 252    # 12-month formation
const MOM_SKIP   = 21     # skip the most recent month (12-1 momentum)
const TOP_FRAC   = 0.2    # top quintile
const PER_NAME_CAP = 0.15
const VOL_TARGET = 0.12
const VOL_WIN    = 60
const LEV_CAP    = 2.0
# --- bonds regime overlay (consumes blaquebaux/bonds' published regime read) -----------------
# When the stock-bond correlation is POSITIVE the bond hedge is DEAD — a long equity book has no
# diversification cushion and tail co-moves are worse — so we DE-RISK gross. When NEGATIVE the hedge
# is live and we carry full size. Graceful: a missing/stale signal defaults to full gross (the overlay
# only ever REDUCES risk, and only on a fresh signal). Toggle off with BB_BONDS_OVERLAY=0.
const REGIME_DERISK   = 0.75    # gross multiplier when the bond hedge is dead (pos-corr regime)
const REGIME_MAXSTALE = Day(7)

_readf(p) = isfile(p) ? (v = tryparse(Float64, strip(read(p, String))); v === nothing ? NaN : v) : NaN
_writef(p, x) = (mkpath(dirname(p)); write(p, string(x)))

"Parse blaquebaux/bonds' published regime file (key=value lines). Returns (; ok, hedge_on, corr, asof)."
function read_bonds_regime(path)
    isfile(path) || return (; ok = false)
    d = Dict{String,String}()
    for ln in eachline(path)
        s = strip(ln); (isempty(s) || startswith(s, "#")) && continue
        kv = split(s, "=", limit = 2); length(kv) == 2 && (d[strip(kv[1])] = strip(kv[2]))
    end
    ho = get(d, "hedge_on", ""); asof = tryparse(Date, get(d, "asof", ""))
    (ho in ("0", "1") && asof !== nothing) || return (; ok = false)
    (; ok = true, hedge_on = ho == "1", corr = tryparse(Float64, get(d, "corr63", "")), asof = asof)
end

"Gross-exposure multiplier from the bonds regime read (graceful: missing/stale/off -> 1.0)."
function regime_gross_scale(path; derisk = parse(Float64, get(ENV, "BB_REGIME_DERISK", string(REGIME_DERISK))))
    get(ENV, "BB_BONDS_OVERLAY", "1") in ("0", "false", "no") && return (1.0, "bonds overlay OFF (full gross)")
    r = read_bonds_regime(path)
    r.ok || return (1.0, "no bonds regime signal -> full gross")
    (Dates.today() - r.asof) > REGIME_MAXSTALE && return (1.0, "bonds regime STALE ($(r.asof)) -> full gross")
    c = r.corr === nothing ? NaN : round(r.corr, digits = 2)
    r.hedge_on ? (1.0,    "bond hedge LIVE (neg-corr $c) -> full gross") :
                 (derisk, "bond hedge DEAD (pos-corr $c) -> de-risk x$derisk")
end

"Compute the governed target weight vector over the panel's symbols (0 for names not held)."
function boom_weights(returns::AbstractMatrix)
    T, N = size(returns)
    T < MOM_LONG + 1 && error("need >= $(MOM_LONG+1) rows of returns, got $T")
    lo = max(1, T - MOM_LONG + 1); hi = T - MOM_SKIP                 # 12-1 window
    mom = vec(prod(1 .+ returns[lo:hi, :], dims = 1)) .- 1
    k = max(1, round(Int, N * TOP_FRAC))
    sel = sortperm(mom)[end - k + 1:end]                             # top-k by momentum
    w = zeros(N); w[sel] .= 1.0 / k
    w = min.(w, PER_NAME_CAP); s = sum(w); s > 0 && (w ./= s)        # per-name guardrail + renorm
    win = returns[max(1, T - VOL_WIN + 1):T, :]                      # trailing book vol (ex-ante)
    book = win * w
    vol = std(book) * sqrt(252)
    scale = clamp(VOL_TARGET / max(vol, 1e-6), 0.0, LEV_CAP)         # vol-target => bounds gross
    return w .* scale, sel, mom
end

function main(; capital = nothing, pool = "us", limits::SafetyLimits = SafetyLimits(),
              state_path  = get(ENV, "BB_STATE_PATH",  joinpath(REPO, "boom_state.jls")),   # reserved; stateless
              db_path     = get(ENV, "BB_LEDGER_PATH", joinpath(REPO, "alpaca_ledger_boom.sqlite")),
              audit_path  = get(ENV, "BB_AUDIT_PATH",  joinpath(REPO, "alpaca_audit_boom.jsonl")),
              hwm_path    = get(ENV, "BB_HWM_PATH",    joinpath(homedir(), ".config", "blaquebaux", "equity_hwm_boom.txt")),
              equity_path = get(ENV, "BB_EQUITY_PATH", joinpath(homedir(), ".config", "blaquebaux", "equity_last_boom.txt")),
              regime_path = get(ENV, "BB_REGIME_PATH", joinpath(homedir(), ".config", "blaquebaux", "bonds_regime.txt")))

    if get(ENV, "ALPACA_KEY_ID", "") == "" || get(ENV, "ALPACA_SECRET_KEY", "") == ""
        error("Set ALPACA_KEY_ID and ALPACA_SECRET_KEY.")
    end
    dryrun = get(ENV, "BB_DRYRUN", "") in ("1", "true", "yes")

    if dryrun
        panel = panel_at(AlpacaPanelProvider(UNIVERSE; lookback = 320))
        w, sel, mom = boom_weights(panel.returns)
        rscale, rnote = regime_gross_scale(regime_path); w = w .* rscale
        cap = capital === nothing ? 100_000.0 : capital
        println("DRYRUN boom (asof ", panel.asof, "): bonds regime -> ", rnote)
        println("  gross ", @sprintf("%.0f%%", 100sum(w)), " (regime x", @sprintf("%.2f", rscale), "):")
        for j in sort(collect(sel), by = x -> -w[x])
            sh = round(Int, w[j] * cap / panel.prices[j])
            println("  ", rpad(panel.symbols[j], 6), @sprintf("wt %5.1f%%  mom %+6.1f%%  %5d sh @ \$%.2f",
                    100w[j], 100mom[j], sh, panel.prices[j]))
        end
        return :dryrun
    end

    live  = get(ENV, "BB_LIVE_CONFIRM", "") == LIVE_SENTINEL
    paper = !live
    mode  = live ? "*** LIVE REAL MONEY ***" : "paper"
    @info "boom_live starting" mode signal="megacap 12-1 momentum tilt"
    live && alert("BOOM LIVE REAL-MONEY mode engaged"; level = :critical)

    venue = AlpacaVenue(AlpacaConfig(; paper = paper))
    built = build_live_controller(; venue = venue,
        ledger_config = LedgerConfig(; db_path = db_path), audit_path = audit_path)
    ctrl, ledger = built.ctrl, built.ledger
    try
        connect!(venue) || (alert("ABORT [$mode]: Alpaca connect failed (boom)"; level = :critical); return :connect_failed)
        acct = account_info(venue)
        acct === nothing && (alert("ABORT [$mode]: could not read account (boom)"; level = :critical); return :no_account)

        cap     = capital === nothing ? acct.equity : capital
        hwm     = max(load_hwm(hwm_path), acct.equity)
        last_eq = _readf(equity_path)
        panel   = panel_at(AlpacaPanelProvider(UNIVERSE; lookback = 320))
        fresh   = (Dates.today() - panel.asof) <= Day(5)

        w, sel, _ = boom_weights(panel.returns)
        rscale, rnote = regime_gross_scale(regime_path); w = w .* rscale     # bonds-regime gross overlay
        # Targets over the WHOLE universe (0 for non-selected) so names that rotate OUT get sold.
        targets = Dict(panel.symbols[j] => round(w[j] * cap / panel.prices[j]) for j in eachindex(w))
        prices  = Dict(panel.symbols[j] => panel.prices[j] for j in eachindex(w))
        reg     = "momtilt-$(length(sel))names-regx$(round(rscale, digits=2))"
        @info "boom book" names=length(sel) gross=sum(w) regime=rnote held=[panel.symbols[j] for j in sel]

        ok, reasons = preflight(; account_status = acct.status, trading_blocked = acct.trading_blocked,
            account_blocked = acct.account_blocked, equity = acct.equity, hwm = hwm,
            last_equity = last_eq, buying_power = acct.buying_power, data_fresh = fresh,
            targets = targets, prices = prices, limits = limits)

        save_hwm(hwm, hwm_path); _writef(equity_path, acct.equity)

        if !ok
            msg = "SAFETY ABORT [$mode] (boom): " * join(reasons, "; ")
            @error msg; halt!(ctrl, "safety gate"); alert(msg; level = :critical); return :aborted
        end

        reset_daily!(ctrl)
        set_pool_budget!(ctrl, pool, limits.max_gross_leverage * acct.equity)
        set_pool_loss_limit!(ctrl, pool, limits.max_daily_loss)
        set_pool_staleness!(ctrl, pool, Day(5))
        feed_staleness!(ctrl, pool; stale = !fresh)
        isfinite(last_eq) && update_pnl!(ctrl, pool, acct.equity - last_eq)

        ncanc = cancel_all_open!(venue); @info "cancelled stale orders" count=ncanc
        ncanc > 0 && sleep(2)

        bpos = positions(venue, ctrl.account)
        for (sym, qty) in bpos
            apply_fill!(ctrl, sym, qty)
        end
        @info "seeded expected positions from broker" held=length(bpos)

        res = execute_rebalance!(ctrl, ledger; targets = targets, prices = prices,
            signal_id = "boom_momentum", regime = reg, solve_id = Dates.format(panel.asof, "yyyymmdd"),
            pool_id = pool, settle_secs = 20)

        if !res.reconciled
            alert("RECONCILE FAILED [$mode] (boom) — halting"; level = :critical)
            halt!(ctrl, "reconcile mismatch")
        end

        summary = "[$mode] boom $(reg); orders=$(length(res.acks)) fills=$(length(res.fills)) " *
                  "reconciled=$(res.reconciled); equity=$(round(Int, acct.equity)) " *
                  "dd=$(round(100*drawdown(acct.equity, hwm), digits=1))%"
        @info "boom_live complete" summary
        alert(summary; level = :info)
        return res.reconciled ? :ok : :reconcile_failed
    finally
        disconnect!(venue); close_ledger(ledger)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

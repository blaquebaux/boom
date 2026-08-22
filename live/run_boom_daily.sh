#!/bin/bash
# ============================================================================
# run_boom_daily.sh — Blaque Baux BOOM daily paper driver (megacap 12-1 momentum
# tilt, governed: EW top-quintile, per-name cap, vol-targeted). Runs on the engine
# submodule; own keys + fully isolated ledger/audit/hwm/equity. Skips cleanly until
# the leg's paper-account env exists.
#
# LIVE A/B on the market_regime opt-in overlay — one script, two isolated legs:
#   bash live/run_boom_daily.sh            # leg A = CONTROL  (overlay OFF, the shipped default)
#   bash live/run_boom_daily.sh market     # leg B = TREATMENT(BB_MARKET_OVERLAY=1)
# Both run the SAME boom_live.jl and read benchmark's SAME market_regime.txt; they diverge ONLY by the
# overlay flag, so B−A is the overlay's live P&L. Each leg has its own paper account + ledger/hwm/equity.
# Validation (live/boom_market_regime_validation.jl): the overlay cuts maxDD 41% and flips skew positive
# but gives back ~20% return — an opt-in insurance tradeoff this A/B now tests forward on paper.
#
# One-time engine setup:  julia --project=engine -e 'using Pkg; Pkg.instantiate()'
# Manual test (dry, no trade):  BB_DRYRUN=1 bash live/run_boom_daily.sh market
# ============================================================================
set -uo pipefail
LEG="${1:-boom}"                                     # "boom" (control) | "boom_market" | "market" (alias)
[ "$LEG" = "market" ] && LEG="boom_market"
case "$LEG" in boom|boom_market) ;; *) echo "unknown leg '$LEG' (use: boom | market)"; exit 2 ;; esac

REPO="/Users/malcolmx/blaquebaux-boom"
ENGINE="$REPO/engine"
ENVFILE="$HOME/.config/blaquebaux/alpaca_${LEG}.env" # this leg's paper account keys
JULIA="/Users/malcolmx/.juliaup/bin/julia"
LOGDIR="$REPO/logs"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/${LEG}_$(TZ=America/New_York date +%Y%m%d).log"

exec >> "$LOG" 2>&1
echo "================ $(TZ=America/New_York date '+%F %T %Z') BOOM leg=$LEG daily run ================"

if [ ! -f "$ENVFILE" ]; then
    echo "no $ENVFILE yet — leg '$LEG' not activated (create the paper account, add its keys). skipping."
    exit 0
fi
set -a; source "$ENVFILE"; set +a
if [ -z "${ALPACA_KEY_ID:-}" ] || [ -z "${ALPACA_SECRET_KEY:-}" ]; then
    echo "ALPACA_KEY_ID / ALPACA_SECRET_KEY not set by $ENVFILE"; exit 1
fi

# --- the one line that defines the A/B: treatment turns the market_regime overlay ON ---
if [ "$LEG" = "boom_market" ]; then export BB_MARKET_OVERLAY=1; else export BB_MARKET_OVERLAY=0; fi
export BB_BONDS_OVERLAY="${BB_BONDS_OVERLAY:-0}"     # both legs keep the bonds overlay off (isolate the variable)
export BB_MARKET_REGIME_PATH="$HOME/.config/blaquebaux/market_regime.txt"   # published by benchmark (shared)

export BB_STRATEGY="$LEG"
export BB_STATE_PATH="$REPO/${LEG}_state.jls"
export BB_LEDGER_PATH="$REPO/alpaca_ledger_${LEG}.sqlite"
export BB_AUDIT_PATH="$REPO/alpaca_audit_${LEG}.jsonl"
export BB_HWM_PATH="$HOME/.config/blaquebaux/equity_hwm_${LEG}.txt"
export BB_EQUITY_PATH="$HOME/.config/blaquebaux/equity_last_${LEG}.txt"

# trading-day gate
CLOCK=$(curl -s --max-time 15 \
    -H "APCA-API-KEY-ID: $ALPACA_KEY_ID" -H "APCA-API-SECRET-KEY: $ALPACA_SECRET_KEY" \
    https://paper-api.alpaca.markets/v2/clock)
IS_OPEN=$(echo "$CLOCK" | grep -Eo '"is_open":(true|false)' | grep -Eo 'true|false' | head -1)
NEXT_OPEN=$(echo "$CLOCK" | grep -o '"next_open":"[^"]*"' | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
ET_TODAY=$(TZ=America/New_York date +%F)
if [ -z "$IS_OPEN" ] && [ -z "$NEXT_OPEN" ]; then
    echo "WARN: could not read Alpaca clock ($CLOCK) — proceeding (idempotency still protects)"
elif [ "$IS_OPEN" != "true" ] && [ "$NEXT_OPEN" != "$ET_TODAY" ]; then
    echo "not a trading day (is_open=$IS_OPEN, next_open=$NEXT_OPEN, et_today=$ET_TODAY) — skipping"; exit 0
fi

# catch-up guard: no-op if this account already placed a book today
ORDERS_TODAY=$(curl -s --max-time 15 \
    -H "APCA-API-KEY-ID: $ALPACA_KEY_ID" -H "APCA-API-SECRET-KEY: $ALPACA_SECRET_KEY" \
    "https://paper-api.alpaca.markets/v2/orders?status=all&limit=10&after=${ET_TODAY}T00:00:00Z" \
    | grep -o '"id"' | wc -l | tr -d ' ')
if [ "${ORDERS_TODAY:-0}" -gt 0 ]; then
    echo "already placed $ORDERS_TODAY order(s) today — skipping (catch-up no-op)"; exit 0
fi

cd "$REPO" || { echo "cannot cd $REPO"; exit 1; }
"$JULIA" --project="$ENGINE" "$REPO/live/boom_live.jl"
RC=$?
BB_STRATEGY="$LEG" /usr/bin/python3 "$ENGINE/scripts/pnl_attribution.py" open || true
echo "================ done rc=$RC $(TZ=America/New_York date '+%T %Z') ================"
exit $RC

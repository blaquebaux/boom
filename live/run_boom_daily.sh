#!/bin/bash
# ============================================================================
# run_boom_daily.sh — Blaque Baux BOOM daily paper driver (megacap 12-1 momentum
# tilt, governed: EW top-quintile, per-name cap, vol-targeted). Runs on the engine
# submodule; own keys + fully isolated ledger/audit/hwm/equity. Skips cleanly until
# ~/.config/blaquebaux/alpaca_boom.env exists.
#
# One-time engine setup:  julia --project=engine -e 'using Pkg; Pkg.instantiate()'
# Manual test (dry, no trade):  BB_DRYRUN=1 bash live/run_boom_daily.sh
# Manual test (real paper run): bash live/run_boom_daily.sh
# ============================================================================
set -uo pipefail
REPO="/Users/malcolmx/blaquebaux-boom"
ENGINE="$REPO/engine"
ENVFILE="$HOME/.config/blaquebaux/alpaca_boom.env"   # Boom paper account keys
JULIA="/Users/malcolmx/.juliaup/bin/julia"
LOGDIR="$REPO/logs"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/boom_$(TZ=America/New_York date +%Y%m%d).log"

exec >> "$LOG" 2>&1
echo "================ $(TZ=America/New_York date '+%F %T %Z') BOOM (megacap momentum) daily run ================"

if [ ! -f "$ENVFILE" ]; then
    echo "no $ENVFILE yet — boom not activated (create the paper account, add its keys). skipping."
    exit 0
fi
set -a; source "$ENVFILE"; set +a
if [ -z "${ALPACA_KEY_ID:-}" ] || [ -z "${ALPACA_SECRET_KEY:-}" ]; then
    echo "ALPACA_KEY_ID / ALPACA_SECRET_KEY not set by $ENVFILE"; exit 1
fi

export BB_STRATEGY=boom
export BB_STATE_PATH="$REPO/boom_state.jls"
export BB_LEDGER_PATH="$REPO/alpaca_ledger_boom.sqlite"
export BB_AUDIT_PATH="$REPO/alpaca_audit_boom.jsonl"
export BB_HWM_PATH="$HOME/.config/blaquebaux/equity_hwm_boom.txt"
export BB_EQUITY_PATH="$HOME/.config/blaquebaux/equity_last_boom.txt"

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
BB_STRATEGY=boom /usr/bin/python3 "$ENGINE/scripts/pnl_attribution.py" open || true
echo "================ done rc=$RC $(TZ=America/New_York date '+%T %Z') ================"
exit $RC

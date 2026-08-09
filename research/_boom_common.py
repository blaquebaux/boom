#!/usr/bin/python3
# =============================================================================
# _boom_common.py — shared data/metrics helpers for the Blaque Baux Boom sketches.
# Alpaca SIP daily bars; reads ALPACA_KEY_ID / ALPACA_SECRET_KEY from env. Read-only.
# =============================================================================
import os, json, urllib.request, math
import numpy as np

H = {"APCA-API-KEY-ID": os.environ["ALPACA_KEY_ID"], "APCA-API-SECRET-KEY": os.environ["ALPACA_SECRET_KEY"]}
START, END = "2016-01-01", "2026-08-01"
_cache = {}

MAG7 = ["AAPL", "MSFT", "NVDA", "AMZN", "GOOGL", "META", "TSLA"]
# Broader megacap / blue-chip universe (current large caps => mild survivorship bias; directional).
MEGA = MAG7 + ["AVGO", "LLY", "JPM", "V", "MA", "UNH", "XOM", "COST", "HD", "PG", "JNJ", "WMT",
               "ORCL", "NFLX", "CVX", "KO", "PEP", "BAC", "CRM", "MRK", "ADBE", "AMD", "QCOM"]
BENCH = ["SPY", "QQQ", "RSP"]

def bars(s):
    if s in _cache: return _cache[s]
    u = (f"https://data.alpaca.markets/v2/stocks/bars?symbols={s}&timeframe=1Day"
         f"&start={START}&end={END}&adjustment=all&feed=sip&limit=10000")
    try:
        d = json.load(urllib.request.urlopen(urllib.request.Request(u, headers=H), timeout=40))
        _cache[s] = {b["t"][:10]: b for b in d.get("bars", {}).get(s, [])}
    except Exception:
        _cache[s] = {}
    return _cache[s]

def panel(syms, field="c"):
    D = {s: bars(s) for s in syms}; D = {s: v for s, v in D.items() if len(v) > 500}
    used = list(D); dates = sorted(set.intersection(*[set(D[s]) for s in used]))
    M = np.array([[D[s][d][field] for s in used] for d in dates], float)
    return used, dates, M

def ann(pnl):
    r = np.asarray(pnl, float); r = r[np.isfinite(r)]
    if len(r) < 30 or r.std() == 0: return (float('nan'),) * 3
    cum = np.cumprod(1 + r)
    return (r.mean() / r.std() * math.sqrt(252),
            cum[-1] ** (252 / len(r)) - 1,
            (cum / np.maximum.accumulate(cum) - 1).min())

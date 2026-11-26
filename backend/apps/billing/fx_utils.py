import json
import urllib.request
from django.core.cache import cache

DEFAULT_USD_RATES = {
    'USD': 1.0,
    'INR': 84.50,
    'QAR': 3.64,
    'AED': 3.6725,
    'SAR': 3.75,
    'OMR': 0.385,
    'KWD': 0.307,
    'BHD': 0.376,
    'EUR': 0.94,
    'GBP': 0.79,
}

CURRENCY_SYMBOLS = {
    'INR': '₹',
    'USD': '$',
    'EUR': '€',
    'GBP': '£',
    'QAR': 'QAR',
    'AED': 'AED',
    'SAR': 'SAR',
    'OMR': 'OMR',
    'KWD': 'KWD',
    'BHD': 'BHD',
}


def get_currency_symbol(currency_code):
    code = (currency_code or 'INR').strip().upper()
    return CURRENCY_SYMBOLS.get(code, code)


def get_fx_rates():
    """Return USD-based exchange rates, cached for 6 hours with offline fallback."""
    cache_key = 'fx_rates_usd_v1'
    cached = cache.get(cache_key)
    if isinstance(cached, dict) and cached:
        return cached

    rates = dict(DEFAULT_USD_RATES)
    try:
        req = urllib.request.Request(
            'https://open.er-api.com/v6/latest/USD',
            headers={'User-Agent': 'StepzCall/1.0'},
        )
        with urllib.request.urlopen(req, timeout=1.5) as resp:
            payload = json.loads(resp.read().decode('utf-8', errors='ignore'))
            api_rates = payload.get('rates') if isinstance(payload, dict) else None
            if isinstance(api_rates, dict):
                for code in list(DEFAULT_USD_RATES.keys()):
                    val = api_rates.get(code)
                    if isinstance(val, (int, float)) and val > 0:
                        rates[code] = float(val)
    except Exception:
        pass

    cache.set(cache_key, rates, 21600)
    return rates


def convert_amount(amount, from_currency, to_currency, rates=None):
    amt = float(amount or 0.0)
    src = (from_currency or 'INR').strip().upper()
    dst = (to_currency or 'INR').strip().upper()
    if src == dst or amt == 0.0:
        return amt

    fx = rates or get_fx_rates()
    src_rate = float(fx.get(src) or 0.0)
    dst_rate = float(fx.get(dst) or 0.0)
    if src_rate <= 0 or dst_rate <= 0:
        return amt
    return (amt / src_rate) * dst_rate


def _fmt_amt(val):
    if abs(val - round(val)) < 0.01:
        return f'{round(val):.0f}'
    return f'{val:.2f}'


def _fmt_money(sym, val):
    sep = ' ' if len(sym) > 1 else ''
    return f'{sym}{sep}{_fmt_amt(val)}'


def build_fx_metric(currency_totals, target_currency, target_symbol, rates=None):
    """
    Given a dict {currency_code: raw_amount}, convert all amounts into target_currency
    and return (converted_total, has_fx, breakdown_text, items_list).
    """
    fx = rates or get_fx_rates()
    dst = (target_currency or 'INR').strip().upper()
    dst_sym = target_symbol or get_currency_symbol(dst)

    items = []
    converted_total = 0.0
    has_fx = False

    # Put target currency first, then others alphabetically
    ordered_codes = sorted(
        currency_totals.keys(),
        key=lambda c: (0 if c == dst else 1, c),
    )

    parts = []
    for code in ordered_codes:
        orig = float(currency_totals[code] or 0.0)
        if orig == 0.0:
            continue
        sym = get_currency_symbol(code)
        conv = convert_amount(orig, code, dst, fx)
        converted_total += conv
        if code != dst:
            has_fx = True
            parts.append(f'{_fmt_money(sym, orig)} (≈{_fmt_money(dst_sym, conv)})')
        else:
            parts.append(_fmt_money(sym, orig))
        items.append({
            'currency': code,
            'symbol': sym,
            'original': round(orig, 2),
            'converted': round(conv, 2),
        })

    breakdown_text = ''
    if has_fx and parts:
        if len(parts) == 1:
            breakdown_text = f'FX: {parts[0]}'
        else:
            breakdown_text = f'FX: {" + ".join(parts)} = {_fmt_money(dst_sym, converted_total)}'

    return round(converted_total, 2), has_fx, breakdown_text, items

import ipaddress
import urllib.request
from django.core.cache import cache

COUNTRY_META = {
    'IN': ('+91', 'INR', '₹'),
    'QA': ('+974', 'QAR', 'QAR'),
    'AE': ('+971', 'AED', 'AED'),
    'SA': ('+966', 'SAR', 'SAR'),
    'OM': ('+968', 'OMR', 'OMR'),
    'KW': ('+965', 'KWD', 'KWD'),
    'BH': ('+973', 'BHD', 'BHD'),
    'US': ('+1', 'USD', '$'),
    'GB': ('+44', 'GBP', '£'),
    'UK': ('+44', 'GBP', '£'),
}


def _extract_client_ip(request):
    if not request:
        return None
    xff = request.META.get('HTTP_X_FORWARDED_FOR')
    if xff:
        ip = xff.split(',')[0].strip()
        if ip:
            return ip
    return request.META.get('REMOTE_ADDR')


def _is_public_ip(ip_str):
    if not ip_str:
        return False
    try:
        ip_obj = ipaddress.ip_address(ip_str.strip())
        return not (
            ip_obj.is_private
            or ip_obj.is_loopback
            or ip_obj.is_link_local
            or ip_obj.is_reserved
            or ip_obj.is_multicast
        )
    except ValueError:
        return False


def _lookup_ip_country(ip_str):
    cache_key = f'geoip_iso_{ip_str}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached or None

    iso = ''
    try:
        req = urllib.request.Request(
            f'https://ipapi.co/{ip_str}/country/',
            headers={'User-Agent': 'StepzCall/1.0'},
        )
        with urllib.request.urlopen(req, timeout=1.2) as resp:
            text = resp.read().decode('utf-8', errors='ignore').strip().upper()
            if len(text) == 2 and text.isalpha():
                iso = text
    except Exception:
        iso = ''

    cache.set(cache_key, iso, 86400)
    return iso or None


def resolve_request_country(request, company=None):
    """
    Resolve (country_iso, dial_code, currency, currency_symbol) from:
    1. Client's public IP geolocation (if public IP)
    2. Client-detected country hint (`detected_country_iso` body or `X-Detected-Country` header)
    3. Company's configured country/currency fallback
    """
    detected_iso = None

    if request is not None:
        client_ip = _extract_client_ip(request)
        if _is_public_ip(client_ip):
            detected_iso = _lookup_ip_country(client_ip)

        if not detected_iso:
            body_iso = ''
            if hasattr(request, 'data') and isinstance(request.data, dict):
                body_iso = str(request.data.get('detected_country_iso') or '').strip().upper()
            header_iso = str(request.META.get('HTTP_X_DETECTED_COUNTRY') or '').strip().upper()
            candidate = body_iso or header_iso
            if candidate in COUNTRY_META:
                detected_iso = candidate

    if detected_iso and detected_iso in COUNTRY_META:
        normalized_iso = 'GB' if detected_iso == 'UK' else detected_iso
        dial_code, currency, symbol = COUNTRY_META[detected_iso]
        return normalized_iso, dial_code, currency, symbol

    if company is not None:
        return (
            company.default_country_iso or 'IN',
            company.default_country_code or '+91',
            company.currency or 'INR',
            company.currency_symbol or '₹',
        )

    return 'IN', '+91', 'INR', '₹'

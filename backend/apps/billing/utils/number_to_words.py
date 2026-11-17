# backend/apps/billing/utils/number_to_words.py
"""
High-precision bilingual (English & Arabic) numbers-to-words currency converter
for professional billing, quotations, and official receipt vouchers (سند قبض).
"""
from decimal import Decimal

# Currency nomenclature lookup
CURRENCIES = {
    'QAR': {
        'en_main_single': 'Qatari Riyal',
        'en_main_plural': 'Qatari Riyals',
        'en_sub_single': 'Dirham',
        'en_sub_plural': 'Dirhams',
        'ar_main': 'ريال قطري',
        'ar_sub': 'درهم',
    },
    'AED': {
        'en_main_single': 'UAE Dirham',
        'en_main_plural': 'UAE Dirhams',
        'en_sub_single': 'Fil',
        'en_sub_plural': 'Fils',
        'ar_main': 'درهم إماراتي',
        'ar_sub': 'فلس',
    },
    'SAR': {
        'en_main_single': 'Saudi Riyal',
        'en_main_plural': 'Saudi Riyals',
        'en_sub_single': 'Halala',
        'en_sub_plural': 'Halalas',
        'ar_main': 'ريال سعودي',
        'ar_sub': 'هللة',
    },
    'KWD': {
        'en_main_single': 'Kuwaiti Dinar',
        'en_main_plural': 'Kuwaiti Dinars',
        'en_sub_single': 'Fil',
        'en_sub_plural': 'Fils',
        'ar_main': 'دينار كويتي',
        'ar_sub': 'فلس',
    },
    'OMR': {
        'en_main_single': 'Omani Rial',
        'en_main_plural': 'Omani Rials',
        'en_sub_single': 'Baisa',
        'en_sub_plural': 'Baisas',
        'ar_main': 'ريال عماني',
        'ar_sub': 'بيسة',
    },
    'BHD': {
        'en_main_single': 'Bahraini Dinar',
        'en_main_plural': 'Bahraini Dinars',
        'en_sub_single': 'Fil',
        'en_sub_plural': 'Fils',
        'ar_main': 'دينار بحريني',
        'ar_sub': 'فلس',
    },
    'INR': {
        'en_main_single': 'Indian Rupee',
        'en_main_plural': 'Indian Rupees',
        'en_sub_single': 'Paisa',
        'en_sub_plural': 'Paise',
        'ar_main': 'روبية هندية',
        'ar_sub': 'بيزة',
    },
    'USD': {
        'en_main_single': 'US Dollar',
        'en_main_plural': 'US Dollars',
        'en_sub_single': 'Cent',
        'en_sub_plural': 'Cents',
        'ar_main': 'دولار أمريكي',
        'ar_sub': 'سنت',
    },
    'EUR': {
        'en_main_single': 'Euro',
        'en_main_plural': 'Euros',
        'en_sub_single': 'Cent',
        'en_sub_plural': 'Cents',
        'ar_main': 'يورو',
        'ar_sub': 'سنت',
    },
    'GBP': {
        'en_main_single': 'British Pound',
        'en_main_plural': 'British Pounds',
        'en_sub_single': 'Penny',
        'en_sub_plural': 'Pence',
        'ar_main': 'جنيه إسترليني',
        'ar_sub': 'بنس',
    },
}

# -------------------------------------------------------------
# English Number-To-Words Engine
# -------------------------------------------------------------
_ONES_EN = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
]
_TENS_EN = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
]

def _int_to_words_en(n: int) -> str:
    if n == 0:
        return 'Zero'
    
    parts = []
    
    billions = n // 1_000_000_000
    n %= 1_000_000_000
    if billions:
        parts.append(f"{_three_digits_en(billions)} Billion")
        
    millions = n // 1_000_000
    n %= 1_000_000
    if millions:
        parts.append(f"{_three_digits_en(millions)} Million")
        
    thousands = n // 1_000
    n %= 1_000
    if thousands:
        parts.append(f"{_three_digits_en(thousands)} Thousand")
        
    if n:
        parts.append(_three_digits_en(n))
        
    return ' '.join(parts).strip()

def _three_digits_en(n: int) -> str:
    res = []
    hundreds = n // 100
    remainder = n % 100
    if hundreds:
        res.append(f"{_ONES_EN[hundreds]} Hundred")
    if remainder < 20:
        if remainder > 0:
            res.append(_ONES_EN[remainder])
    else:
        tens = remainder // 10
        ones = remainder % 10
        if ones:
            res.append(f"{_TENS_EN[tens]}-{_ONES_EN[ones]}")
        else:
            res.append(_TENS_EN[tens])
    return ' '.join(res)

def amount_to_words_en(amount, currency_code='QAR') -> str:
    """Converts a numerical amount into formal English words."""
    try:
        val = Decimal(str(amount))
    except Exception:
        val = Decimal('0.00')

    curr = CURRENCIES.get(currency_code.upper(), CURRENCIES['QAR'])
    integer_part = int(val)
    fraction_part = int(round((val - integer_part) * 100))

    int_words = _int_to_words_en(integer_part)
    main_curr = curr['en_main_single'] if integer_part == 1 else curr['en_main_plural']

    if fraction_part > 0:
        frac_words = _int_to_words_en(fraction_part)
        sub_curr = curr['en_sub_single'] if fraction_part == 1 else curr['en_sub_plural']
        return f"{int_words} {main_curr} and {frac_words} {sub_curr} Only"
    else:
        return f"{int_words} {main_curr} Only"


# -------------------------------------------------------------
# Arabic Number-To-Words Engine (Tafqeet)
# -------------------------------------------------------------
_ONES_AR = ['', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة']
_TENS_AR = ['', 'عشرة', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون']
_TEENS_AR = [
    'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر',
    'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر'
]
_HUNDREDS_AR = ['', 'مائة', 'مئتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة']

def _three_digits_ar(n: int) -> str:
    res = []
    hundreds = n // 100
    rem = n % 100
    if hundreds:
        res.append(_HUNDREDS_AR[hundreds])
    if rem > 0:
        if rem < 10:
            res.append(_ONES_AR[rem])
        elif rem < 20:
            res.append(_TEENS_AR[rem - 10])
        else:
            tens = rem // 10
            ones = rem % 10
            if ones == 0:
                res.append(_TENS_AR[tens])
            else:
                res.append(f"{_ONES_AR[ones]} و{_TENS_AR[tens]}")
    return ' و'.join(res)

def _int_to_words_ar(n: int) -> str:
    if n == 0:
        return 'صفر'

    parts = []

    # Billions
    billions = n // 1_000_000_000
    n %= 1_000_000_000
    if billions == 1:
        parts.append('مليار')
    elif billions == 2:
        parts.append('ملياران')
    elif 3 <= billions <= 10:
        parts.append(f"{_ONES_AR[billions]} مليارات")
    elif billions > 10:
        parts.append(f"{_three_digits_ar(billions)} مليار")

    # Millions
    millions = n // 1_000_000
    n %= 1_000_000
    if millions == 1:
        parts.append('مليون')
    elif millions == 2:
        parts.append('مليونان')
    elif 3 <= millions <= 10:
        parts.append(f"{_ONES_AR[millions]} ملايين")
    elif millions > 10:
        parts.append(f"{_three_digits_ar(millions)} مليون")

    # Thousands
    thousands = n // 1_000
    n %= 1_000
    if thousands == 1:
        parts.append('ألف')
    elif thousands == 2:
        parts.append('ألفان')
    elif 3 <= thousands <= 10:
        parts.append(f"{_ONES_AR[thousands]} آلاف")
    elif thousands > 10:
        parts.append(f"{_three_digits_ar(thousands)} ألف")

    # Hundreds / Tens / Ones
    if n > 0:
        parts.append(_three_digits_ar(n))

    return ' و'.join(parts)

def amount_to_words_ar(amount, currency_code='QAR') -> str:
    """Converts a numerical amount into formal Arabic words (Tafqeet)."""
    try:
        val = Decimal(str(amount))
    except Exception:
        val = Decimal('0.00')

    curr = CURRENCIES.get(currency_code.upper(), CURRENCIES['QAR'])
    integer_part = int(val)
    fraction_part = int(round((val - integer_part) * 100))

    int_words = _int_to_words_ar(integer_part)
    ar_main = curr['ar_main']

    if fraction_part > 0:
        frac_words = _int_to_words_ar(fraction_part)
        ar_sub = curr['ar_sub']
        return f"{int_words} {ar_main} و{frac_words} {ar_sub} فقط لا غير"
    else:
        return f"{int_words} {ar_main} فقط لا غير"


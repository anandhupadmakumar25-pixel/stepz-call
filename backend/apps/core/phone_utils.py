import re
import phonenumbers
from phonenumbers import PhoneNumberFormat, NumberParseException

def normalize_phone_number(raw_phone: str, default_country_code: str = 'IN') -> tuple[str, bool, str]:
    """
    Normalizes a raw phone number into strict E.164 format.
    Returns: (normalized_phone_e164, is_valid, error_message)
    """
    if not raw_phone:
        return "", False, "Phone number is empty"

    cleaned = str(raw_phone).strip()
    # Remove common decorative characters
    cleaned = re.sub(r'[\s\-\(\)\.]', '', cleaned)
    
    # If number starts with 00, replace with +
    if cleaned.startswith('00'):
        cleaned = '+' + cleaned[2:]

    try:
        # Default region: e.g. 'IN', 'US'
        parsed = phonenumbers.parse(cleaned, default_country_code.upper() if default_country_code else None)
        if not phonenumbers.is_possible_number(parsed):
            return cleaned, False, "Number is not a possible phone number"
        
        is_valid = phonenumbers.is_valid_number(parsed)
        formatted = phonenumbers.format_number(parsed, PhoneNumberFormat.E164)
        return formatted, is_valid, "" if is_valid else "Invalid phone number format for region"
    except NumberParseException as e:
        # Try fallback if starts with digits without +
        if not cleaned.startswith('+') and len(cleaned) == 10 and default_country_code.upper() == 'IN':
            try:
                parsed = phonenumbers.parse('+91' + cleaned, 'IN')
                if phonenumbers.is_valid_number(parsed):
                    return phonenumbers.format_number(parsed, PhoneNumberFormat.E164), True, ""
            except Exception:
                pass
        return cleaned, False, str(e)
    except Exception as e:
        return cleaned, False, str(e)

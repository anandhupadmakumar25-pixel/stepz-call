import 'dart:ui' as ui;
import '../services/location_service.dart';

/// Detects the user's current country ISO code from live GPS coordinates
/// (requesting location permission on login) with timezone and locale fallback.
class RegionDetector {
  static String? _cachedIso;

  static void clearCache() {
    _cachedIso = null;
  }

  static const Set<String> supportedIsos = {
    'IN',
    'QA',
    'AE',
    'SA',
    'OM',
    'KW',
    'BH',
    'US',
    'GB',
  };

  /// Maps GPS coordinates to a supported country ISO code.
  static String? countryIsoFromCoordinates(double lat, double lon) {
    // Check smaller Gulf states before Saudi Arabia.
    if (lat >= 24.45 && lat <= 26.25 && lon >= 50.70 && lon <= 51.70) return 'QA';
    if (lat >= 25.55 && lat <= 26.35 && lon >= 50.35 && lon <= 50.85) return 'BH';
    if (lat >= 28.50 && lat <= 30.15 && lon >= 46.50 && lon <= 48.55) return 'KW';
    if (lat >= 22.60 && lat <= 26.15 && lon >= 51.55 && lon <= 56.40) return 'AE';
    if (lat >= 16.60 && lat <= 26.40 && lon >= 52.00 && lon <= 59.90) return 'OM';
    if (lat >= 16.30 && lat <= 32.20 && lon >= 34.50 && lon <= 55.70) return 'SA';
    if (lat >= 6.50 && lat <= 35.70 && lon >= 68.00 && lon <= 97.50) return 'IN';
    if (lat >= 49.90 && lat <= 60.90 && lon >= -8.65 && lon <= 1.80) return 'GB';
    if (lat >= 24.50 && lat <= 49.50 && lon >= -125.00 && lon <= -66.90) return 'US';
    return null;
  }

  /// Requests device/browser location permission and resolves country ISO from
  /// live GPS coordinates, falling back to timezone/locale if denied or unavailable.
  static Future<String?> detectCountryIsoWithLocation() async {
    try {
      final locResult = await LocationService.getCurrentLocation()
          .timeout(const Duration(seconds: 7), onTimeout: () => LocationResult(success: false));
      if (locResult.success && locResult.position != null) {
        final byGps = countryIsoFromCoordinates(
          locResult.position!.latitude,
          locResult.position!.longitude,
        );
        if (byGps != null) {
          _cachedIso = byGps;
          return byGps;
        }
      }
    } catch (_) {}

    final fallback = detectCountryIso();
    if (fallback != null) {
      _cachedIso = fallback;
    }
    return fallback;
  }

  /// Synchronous detection using cached GPS result, then timezone/locale.
  static String? detectCountryIso() {
    if (_cachedIso != null) return _cachedIso;

    final now = DateTime.now();
    final tzName = now.timeZoneName.toLowerCase();
    final offsetMinutes = now.timeZoneOffset.inMinutes;
    final localeCountry =
        (ui.PlatformDispatcher.instance.locale.countryCode ?? '')
            .trim()
            .toUpperCase();

    if (tzName.contains('qatar') || tzName.contains('doha')) return 'QA';
    if (tzName.contains('dubai') ||
        tzName.contains('uae') ||
        tzName.contains('gulf')) {
      return 'AE';
    }
    if (tzName.contains('muscat') || tzName.contains('oman')) return 'OM';
    if (tzName.contains('kuwait')) return 'KW';
    if (tzName.contains('bahrain') || tzName.contains('manama')) return 'BH';
    if (tzName.contains('riyadh') || tzName.contains('saudi')) return 'SA';
    if (tzName.contains('india') ||
        tzName.contains('kolkata') ||
        tzName.contains('calcutta') ||
        (tzName == 'ist' && offsetMinutes == 330)) {
      return 'IN';
    }
    if (tzName.contains('london') || tzName.contains('british')) return 'GB';

    if (offsetMinutes == 330) return 'IN';
    if (offsetMinutes == 240) {
      return localeCountry == 'OM' ? 'OM' : 'AE';
    }
    if (offsetMinutes == 180) {
      if (const {'QA', 'SA', 'KW', 'BH'}.contains(localeCountry)) {
        return localeCountry;
      }
      if (tzName.contains('arab')) return 'QA';
    }

    if (supportedIsos.contains(localeCountry)) {
      return localeCountry;
    }
    return null;
  }

  static const Set<String> _gccIsos = {'QA', 'AE', 'SA', 'OM', 'KW', 'BH'};

  static String _norm(String? iso) => (iso ?? '').trim().toUpperCase();

  static String taxIdLabel(String? countryIso) {
    final iso = _norm(countryIso);
    if (iso == 'IN' || iso.isEmpty) return 'GSTIN';
    if (_gccIsos.contains(iso)) return 'TRN / CR';
    return 'Tax ID';
  }

  static String taxColumnLabel(String? countryIso) {
    final iso = _norm(countryIso);
    if (iso == 'IN' || iso.isEmpty) return 'GST %';
    if (_gccIsos.contains(iso) || iso == 'GB') return 'VAT %';
    return 'Tax %';
  }

  static String taxSummaryLabel(String? countryIso) {
    final iso = _norm(countryIso);
    if (iso == 'IN' || iso.isEmpty) return 'Tax / GST';
    if (_gccIsos.contains(iso) || iso == 'GB') return 'Tax / VAT';
    return 'Tax';
  }

  static String sampleCity(String? countryIso) {
    switch (_norm(countryIso)) {
      case 'QA':
        return 'Doha';
      case 'AE':
        return 'Dubai';
      case 'SA':
        return 'Riyadh';
      case 'OM':
        return 'Muscat';
      case 'KW':
        return 'Kuwait City';
      case 'BH':
        return 'Manama';
      case 'GB':
        return 'London';
      case 'US':
        return 'New York';
      default:
        return 'Mumbai';
    }
  }

  static String sampleSecondaryCity(String? countryIso) {
    switch (_norm(countryIso)) {
      case 'QA':
        return 'Al Wakrah';
      case 'AE':
        return 'Abu Dhabi';
      case 'SA':
        return 'Jeddah';
      case 'OM':
        return 'Salalah';
      case 'KW':
        return 'Hawalli';
      case 'BH':
        return 'Riffa';
      case 'GB':
        return 'Manchester';
      case 'US':
        return 'Chicago';
      default:
        return 'Bangalore';
    }
  }

  static String sampleState(String? countryIso) {
    switch (_norm(countryIso)) {
      case 'QA':
        return 'Doha';
      case 'AE':
        return 'Dubai';
      case 'SA':
        return 'Riyadh';
      case 'OM':
        return 'Muscat';
      case 'KW':
        return 'Al Asimah';
      case 'BH':
        return 'Capital';
      case 'GB':
        return 'Greater London';
      case 'US':
        return 'NY';
      default:
        return 'Maharashtra';
    }
  }

  static String samplePhone(String? countryIso) {
    switch (_norm(countryIso)) {
      case 'QA':
        return '55123456';
      case 'AE':
        return '501234567';
      case 'SA':
        return '501234567';
      case 'OM':
        return '91234567';
      case 'KW':
        return '50123456';
      case 'BH':
        return '36123456';
      case 'GB':
        return '7700900123';
      case 'US':
        return '2125550123';
      default:
        return '9876543210';
    }
  }

  static String sampleAddress(String? countryIso) {
    switch (_norm(countryIso)) {
      case 'QA':
        return 'e.g. Office 402, West Bay Tower, Doha, Qatar';
      case 'AE':
        return 'e.g. Suite 400, Business Bay, Dubai, UAE';
      case 'SA':
        return 'e.g. Office 305, Olaya Street, Riyadh, Saudi Arabia';
      case 'OM':
        return 'e.g. Office 201, Al Khuwair, Muscat, Oman';
      case 'KW':
        return 'e.g. Floor 5, Al Hamra Tower, Kuwait City';
      case 'BH':
        return 'e.g. Office 12, Diplomatic Area, Manama, Bahrain';
      case 'GB':
        return 'e.g. 22 Bishopsgate, London EC2N 4BQ, UK';
      case 'US':
        return 'e.g. 350 Fifth Avenue, Suite 400, New York, NY 10118';
      default:
        return 'e.g. Suite 400, Techno Park, Phase 1, Kochi, Kerala 682030';
    }
  }
}

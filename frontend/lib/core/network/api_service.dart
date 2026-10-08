import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// API Service connecting Grevidea Flutter Frontend to Axum Gateway (port 3000)
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = const String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://localhost:3000');
  String get baseUrl => _baseUrl;
  void setBaseUrl(String url) => _baseUrl = url.replaceFirst(RegExp(r'/$'), '');
  String? _authToken;
  void setAuthToken(String? token) => _authToken = token;
  bool _isBackendReachable = false;
  bool get isBackendReachable => _isBackendReachable;
  final http.Client _client = http.Client();
  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      _isBackendReachable = response.statusCode == 200;
    } catch (_) {
      _isBackendReachable = false;
    }
    return _isBackendReachable;
  }

  Future<dynamic> request(String path, {Map<String, dynamic>? data}) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken'
      };
      final url = Uri.parse('$_baseUrl$path');
      final response = await (data == null
              ? _client.get(url, headers: headers)
              : _client.post(url, headers: headers, body: jsonEncode(data)))
          .timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map && decoded.containsKey('data')
          ? decoded['data']
          : decoded;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _get(String path) => request(path);
  Future<dynamic> _post(String path, Map<String, dynamic> data) =>
      request(path, data: data);

  // ── EPIC 6: Auth & Token Management (T49, T50) ─────────────────────────────
  Future<Map<String, dynamic>?> login(String email, String password) async {
    final res = await _post('/api/v1/auth/login', {
      'email': email,
      'password': password,
    });
    if (res != null && res['token'] != null) {
      _authToken = res['token'];
      return Map<String, dynamic>.from(res);
    }
    return null;
  }

  Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await _post('/api/v1/auth/register', {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    if (res != null && res['token'] != null) {
      _authToken = res['token'];
      return Map<String, dynamic>.from(res);
    }
    return null;
  }

  // ── EPIC 5: Social Feed & Community Actions (T46, T48) ──────────────────────
  Future<List<Map<String, dynamic>>> getFeed(
      {int page = 1, int limit = 20}) async {
    final res = await _get('/api/v1/feed?page=$page&limit=$limit');
    if (res != null && res is List) {
      return List<Map<String, dynamic>>.from(res);
    }
    if (res != null && res['feed'] != null && res['feed'] is List) {
      return List<Map<String, dynamic>>.from(res['feed']);
    }
    return [];
  }

  Future<Map<String, dynamic>?> createPost({
    required String actionType,
    required String description,
    double? co2SavedKg,
  }) async {
    final res = await _post('/api/v1/feed', {
      'action_type': actionType,
      'description': description,
      'co2_saved_kg': co2SavedKg ?? 1.5,
    });
    if (res != null) return Map<String, dynamic>.from(res);
    return null;
  }

  // ── EPIC 1: ClimateGPT AI Chat (T01) ───────────────────────────────────────
  Future<String> askClimateGpt(String question) async {
    final res = await _post('/api/v1/ai/chat', {'message': question});
    if (res != null && res['response'] != null) {
      return res['response'].toString();
    }
    return 'Climate Assistant is unavailable. Check your connection and configured AI provider, then retry.';
  }

  // ── EPIC 1: Dynamic AI Quiz Generator (T57) ───────────────────────────────
  Future<Map<String, dynamic>> generateAiQuiz({String? topic}) async {
    final prompt =
        'Generate 1 high-quality, scientifically accurate multiple-choice climate literacy question about ${topic ?? "urban ecology, renewable energy, waste recycling, or air quality in Mumbai/Thane"}. '
        'Return ONLY valid JSON without markdown fences with these exact keys: '
        '{"title": "...", "category": "...", "fact": "...", "question": "...", "options": ["option 0", "option 1", "option 2", "option 3"], "correct": 0, "explanation": "..."}';

    try {
      final res = await _post('/api/v1/ai/chat', {'message': prompt});
      if (res != null && res['response'] != null) {
        final text = res['response'].toString().trim();
        final cleanJson =
            text.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> parsed = jsonDecode(cleanJson);
        if (parsed.containsKey('question') &&
            parsed.containsKey('options') &&
            parsed.containsKey('correct')) {
          return parsed;
        }
      }
    } catch (_) {}

    // Dynamic bank across diverse regional and global ecological science topics
    final dynamicBank = [
      {
        'title': 'Urban Heat Islands & Microclimates',
        'category': 'Urban Ecology',
        'fact':
            'Thane\'s Yeoor Hills forest canopy lowers ambient air temperatures in neighboring sectors by up to 3.5°C via evapotranspiration.',
        'question':
            'Which phenomenon occurs when concrete and dark asphalt cause cities to be significantly hotter than surrounding green areas?',
        'options': [
          'Urban Heat Island Effect',
          'Atmospheric Inversion',
          'Thermal Runaway',
          'Adiabatic Expansion'
        ],
        'correct': 0,
        'explanation':
            'Urban Heat Island (UHI) occurs when dense surfaces absorb and re-radiate thermal energy, mitigated by tree canopies and cool roofs.',
      },
      {
        'title': 'Rooftop Solar & Carbon Offsets',
        'category': 'Clean Energy',
        'fact':
            'A 3 kW rooftop solar PV installation in Maharashtra generates approximately 360 units (kWh) of clean electricity every month.',
        'question':
            'Approximately how many kg of CO2 are avoided per 1 kWh of solar electricity compared to Indian thermal coal power?',
        'options': ['0.12 kg', '0.45 kg', '0.82 kg', '2.50 kg'],
        'correct': 2,
        'explanation':
            'The Central Electricity Authority (CEA) baseline carbon emission factor for the Indian power grid is ~0.82 kg CO2 per kWh.',
      },
      {
        'title': 'Mangrove Blue Carbon Sinks',
        'category': 'Coastal Resilience',
        'fact':
            'Thane Creek Flamingo Sanctuary mangroves sequester and store up to 4 times more carbon per hectare than terrestrial tropical rainforests.',
        'question':
            'What is carbon captured and sequestered by coastal marine ecosystems like mangroves and tidal salt marshes called?',
        'options': [
          'Green Carbon',
          'Blue Carbon',
          'Black Carbon',
          'Teal Carbon'
        ],
        'correct': 1,
        'explanation':
            'Blue carbon is organic carbon stored in ocean sediment and mangrove roots, remaining sequestered for millennia if undisturbed.',
      },
      {
        'title': 'Ultrafine PM2.5 Inhalation',
        'category': 'Atmospheric Health',
        'fact':
            'PM2.5 particles are under 2.5 microns in width—30 times finer than a human hair—bypassing nasal cilia and entering lung alveoli.',
        'question':
            'What is the largest urban contributor to PM2.5 concentrations along high-density transit corridors like Ghodbunder Road?',
        'options': [
          'Ocean sea salt spray',
          'Vehicular tailpipe exhaust & tyre brake dust',
          'Agricultural paddy burning only',
          'Pollen spores'
        ],
        'correct': 1,
        'explanation':
            'Internal combustion engine exhaust, brake pad friction, and road dust resuspension constitute over 55% of roadside PM2.5.',
      },
      {
        'title': 'Circular Plastics & Polymer Codes',
        'category': 'Circular Economy',
        'fact':
            'Over 8.3 billion metric tons of virgin plastic have been produced globally since 1950, of which less than 9% was ever recycled.',
        'question':
            'What resin identification code (RIC) number represents PET/PETE (commonly used for water bottles and clear containers)?',
        'options': [
          'Code 1 (PET)',
          'Code 2 (HDPE)',
          'Code 4 (LDPE)',
          'Code 7 (OTHER)'
        ],
        'correct': 0,
        'explanation':
            'Polyethylene Terephthalate (PET) is Code 1 and is the most easily and widely recycled clear plastic polymer globally.',
      },
    ];
    return dynamicBank[DateTime.now().microsecond % dynamicBank.length];
  }

  // ── EPIC 2: Carbon Footprint (T09, T10, T11) ──────────────────────────────
  Future<Map<String, dynamic>> calculateCarbon({
    required String mode,
    required double distanceKm,
    int passengers = 1,
  }) async {
    final res = await _post('/api/v1/carbon/calculate', {
      'mode': mode,
      'distance_km': distanceKm,
      'passengers': passengers,
    });
    if (res != null && res['co2_emitted_kg'] != null) {
      return {
        ...Map<String, dynamic>.from(res),
        'co2_kg': res['co2_emitted_kg']
      };
    }
    // Fallback standard emission factors (kg CO2 / km)
    final factors = {
      'car_petrol': 0.192,
      'car_diesel': 0.171,
      'car_ev': 0.053,
      'bus': 0.089,
      'metro': 0.028,
      'train': 0.041,
      'bike': 0.114,
      'flight': 0.255,
      'car': 0.192,
      'ev_car': 0.053,
      'cycle': 0.0,
      'motorbike': 0.114,
      'walk': 0.0,
      'bicycle': 0.0,
    };
    final factor = factors[mode.toLowerCase()] ?? 0.15;
    final co2 = (factor * distanceKm / passengers);
    return {
      'co2_kg': co2,
      'green_points_earned':
          ((distanceKm * .192 - co2).clamp(0.0, double.infinity) * 100).toInt(),
      'estimated_offline': true,
      'mode': mode,
      'distance_km': distanceKm,
    };
  }

  Future<bool> logCarbonTrip({
    required String mode,
    required double distanceKm,
    required double co2Kg,
    int? pointsEarned,
  }) async {
    final res = await _post('/api/v1/carbon/log', {
      'mode': mode,
      'distance_km': distanceKm,
      'co2_kg': co2Kg,
      'points_earned': pointsEarned ?? 15,
    });
    return res != null;
  }

  Future<Map<String, dynamic>> fetchAqi({String city = 'Thane'}) =>
      getAqi(city: city);

  Future<Map<String, dynamic>> getAqi({String city = 'Thane'}) async {
    final res = await _get('/api/v1/aqi?city=$city');
    if (res != null && res['aqi'] != null) {
      return Map<String, dynamic>.from(res);
    }
    return {'city': city, 'category': 'Unavailable', 'isUnavailable': true};
  }

  Future<Map<String, dynamic>> submitPollutionReport({
    required String reportType,
    required String description,
    required double latitude,
    required double longitude,
    String? imageUrl,
  }) async {
    final res = await _post('/api/v1/reports', {
      'report_type': reportType,
      'severity': 3,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'photo_url': imageUrl,
    });
    if (res == null)
      throw StateError(
          'Report not submitted. Sign in and check your connection.');
    return Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> getPollutionReports() async {
    final res = await _get('/api/v1/reports');
    if (res != null && res is List) {
      return List<Map<String, dynamic>>.from(res);
    }
    if (res != null && res['data'] != null && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getDailyChallenges() async {
    final res = await _get('/api/v1/challenges');
    if (res != null && res is List) {
      return List<Map<String, dynamic>>.from(res);
    }
    if (res != null && res['data'] != null && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    }
    return [];
  }

  // ── EPIC 5: Gamification & Leaderboard (T39, T41, T42, T45) ─────────────────
  Future<List<Map<String, dynamic>>> getLeaderboard(
      {String scope = 'city'}) async {
    final res = await _get('/api/v1/leaderboard?scope=$scope');
    if (res is List)
      return List<Map<String, dynamic>>.from((res as List).map((u) =>
          {...Map<String, dynamic>.from(u), 'points': u['total_points']}));
    if (res != null && res['leaderboard'] != null) {
      return List<Map<String, dynamic>>.from(res['leaderboard']);
    }
    // Pure dynamic: Zero fake names. Real database results only.
    return [];
  }

  // ── EPIC 3: Marketplace & Scanner (T19, T20) ───────────────────────────────
  Future<Map<String, dynamic>> scanProductBarcode(String barcode) async {
    final res = await _post('/api/v1/scan/product', {'barcode': barcode});
    if (res != null && res['sustainability_score'] != null) {
      return {
        ...Map<String, dynamic>.from(res),
        'eco_score': res['ecoscore_grade'],
        'co2_kg': res['co2_per_unit_kg'],
        'co2_footprint': res['co2_per_unit_kg'] == null
            ? 'Unavailable'
            : '${res['co2_per_unit_kg']} kg CO₂e/kg (category estimate)',
        'recommendations': res['recommendation'],
        'recyclable': 'See local recycling rules',
        'packaging': res['packaging_score'] == null
            ? 'Packaging score unavailable'
            : 'Packaging score: ${res['packaging_score']}',
        'origin': res['origin_country']
      };
    }
    return {
      'unavailable': true,
      'product_name': 'No verified product found',
      'barcode': barcode
    };
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'config_service.dart';

/// Service for integrating with Walmart's API
/// Documentation: https://developer.walmart.com/
class WalmartService {
  static final WalmartService _instance = WalmartService._internal();
  factory WalmartService() => _instance;
  WalmartService._internal();

  final _configService = ConfigService();
  
  // Walmart API endpoints
  static const String _baseUrlSandbox = 'https://marketplace.walmartapis.com/v3';
  static const String _baseUrlProduction = 'https://marketplace.walmartapis.com/v3';
  
  bool _useSandbox = true; // Start with sandbox
  
  String get _baseUrl => _useSandbox ? _baseUrlSandbox : _baseUrlProduction;

  /// Toggle between sandbox and production environments
  void setEnvironment({required bool useSandbox}) {
    _useSandbox = useSandbox;
  }

  /// Search for products in Walmart catalog
  /// 
  /// [query] - Search term (e.g., "milk", "bread")
  /// [maxResults] - Maximum number of results to return (default: 10)
  Future<List<WalmartProduct>> searchProducts(String query, {int maxResults = 10}) async {
    try {
      final credentials = await _configService.getWalmartCredentials();
      if (credentials == null) {
        throw Exception('Walmart API credentials not configured');
      }

      // For search, we'll use the Items API
      // Note: Actual endpoint may vary based on your Walmart API access level
      final url = Uri.parse('$_baseUrl/items/search')
          .replace(queryParameters: {
        'query': query,
        'numItems': maxResults.toString(),
      });

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final signature = _generateSignature(
        url: url.toString(),
        method: 'GET',
        timestamp: timestamp,
        consumerId: credentials['consumerId']!,
        privateKey: credentials['privateKey']!,
      );

      final response = await http.get(
        url,
        headers: {
          'WM_SEC.AUTH_SIGNATURE': signature,
          'WM_CONSUMER.ID': credentials['consumerId']!,
          'WM_SEC.TIMESTAMP': timestamp,
          'WM_QOS.CORRELATION_ID': _generateCorrelationId(),
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];
        return items.map((item) => WalmartProduct.fromJson(item)).toList();
      } else {
        print('Walmart API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to search products: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching Walmart products: $e');
      rethrow;
    }
  }

  /// Get product details by item ID
  Future<WalmartProduct?> getProductById(String itemId) async {
    try {
      final credentials = await _configService.getWalmartCredentials();
      if (credentials == null) {
        throw Exception('Walmart API credentials not configured');
      }

      final url = Uri.parse('$_baseUrl/items/$itemId');
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final signature = _generateSignature(
        url: url.toString(),
        method: 'GET',
        timestamp: timestamp,
        consumerId: credentials['consumerId']!,
        privateKey: credentials['privateKey']!,
      );

      final response = await http.get(
        url,
        headers: {
          'WM_SEC.AUTH_SIGNATURE': signature,
          'WM_CONSUMER.ID': credentials['consumerId']!,
          'WM_SEC.TIMESTAMP': timestamp,
          'WM_QOS.CORRELATION_ID': _generateCorrelationId(),
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WalmartProduct.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error getting Walmart product: $e');
      return null;
    }
  }

  /// Generate authentication signature for Walmart API
  /// Uses HMAC-SHA256 with your private key
  String _generateSignature({
    required String url,
    required String method,
    required String timestamp,
    required String consumerId,
    required String privateKey,
  }) {
    // Walmart signature format: consumerId\nurl\nmethod\ntimestamp\n
    final message = '$consumerId\n$url\n$method\n$timestamp\n';
    
    // Sign with private key using HMAC-SHA256
    final key = utf8.encode(privateKey);
    final bytes = utf8.encode(message);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    
    return base64.encode(digest.bytes);
  }

  /// Generate unique correlation ID for request tracking
  String _generateCorrelationId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}';
  }

  /// Check if Walmart integration is configured
  Future<bool> isConfigured() async {
    final credentials = await _configService.getWalmartCredentials();
    return credentials != null && 
           credentials['consumerId']?.isNotEmpty == true &&
           credentials['privateKey']?.isNotEmpty == true;
  }
}

/// Model for Walmart product data
class WalmartProduct {
  final String itemId;
  final String name;
  final String? description;
  final double? salePrice;
  final String? thumbnailImage;
  final String? productUrl;
  final String? upc;
  final String? brand;
  final bool? availableOnline;
  final String? category;

  WalmartProduct({
    required this.itemId,
    required this.name,
    this.description,
    this.salePrice,
    this.thumbnailImage,
    this.productUrl,
    this.upc,
    this.brand,
    this.availableOnline,
    this.category,
  });

  factory WalmartProduct.fromJson(Map<String, dynamic> json) {
    return WalmartProduct(
      itemId: json['itemId']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Product',
      description: json['shortDescription'] ?? json['longDescription'],
      salePrice: _parsePrice(json['salePrice']),
      thumbnailImage: json['thumbnailImage'] ?? json['mediumImage'],
      productUrl: json['productUrl'],
      upc: json['upc'],
      brand: json['brandName'],
      availableOnline: json['availableOnline'],
      category: json['categoryPath'],
    );
  }

  static double? _parsePrice(dynamic price) {
    if (price == null) return null;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) return double.tryParse(price);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'description': description,
      'salePrice': salePrice,
      'thumbnailImage': thumbnailImage,
      'productUrl': productUrl,
      'upc': upc,
      'brand': brand,
      'availableOnline': availableOnline,
      'category': category,
    };
  }
}


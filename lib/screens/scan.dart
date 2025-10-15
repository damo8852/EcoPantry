import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../services/parser.dart';
import '../services/llm_service.dart';
import '../services/theme_service.dart';
import '../services/config_service.dart';
import '../models/grocery_type.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  List<ParsedItem> _preview = [];
  bool _busy = false;
  String? _err;
  late final ThemeService _themeService;
  bool _isSelectionMode = false;
  Set<int> _selectedItems = {};

  ExpiryRules? _rules;
  UpcMap? _upc;

  // Real-time camera scanning
  CameraController? _cameraController;
  bool _isCameraMode = false;
  bool _isProcessingFrame = false;
  String _liveText = '';
  String _lastProcessedText = '';
  Timer? _processingTimer;
  final List<ParsedItem> _liveDetectedItems = [];

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService();
    _themeService.addListener(_onThemeChanged);
    // Removed tab controller and barcode scanner initialization
    _loadAssets();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAssets() async {
    _rules ??= await ExpiryRules.load();
    _upc ??= await UpcMap.load();
    if (mounted) setState(() {});
  }


  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _textRecognizer.close();
    _processingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  void _clearPreview() {
    if (mounted) {
      setState(() {
        _preview = [];
        _err = null;
        _isSelectionMode = false;
        _selectedItems.clear();
        _liveText = '';
        _lastProcessedText = '';
        _liveDetectedItems.clear();
      });
    }
  }

  Future<void> _startLiveCamera() async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        setState(() {
          _err = 'Camera permission is required for live scanning';
        });
        return;
      }

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _err = 'No camera found on device';
        });
        return;
      }

      // Initialize camera controller
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      
      if (!mounted) return;

      setState(() {
        _isCameraMode = true;
        _err = null;
      });

      // Start processing frames periodically
      _processingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _processCurrentFrame());
    } catch (e) {
      setState(() {
        _err = 'Failed to initialize camera: $e';
      });
    }
  }

  Future<void> _processCurrentFrame() async {
    if (_isProcessingFrame || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      _isProcessingFrame = true;
      
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          _liveText = recognizedText.text;
        });
        
        // Only process if text has changed significantly
        if (_hasSignificantChange(recognizedText.text, _lastProcessedText)) {
          _lastProcessedText = recognizedText.text;
          _processTextForFoodItems(recognizedText.text);
        }
      }

      // Clean up temp file
      try {
        await File(image.path).delete();
      } catch (_) {}
    } catch (e) {
      print('Error processing frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  bool _hasSignificantChange(String newText, String oldText) {
    if (oldText.isEmpty) return newText.isNotEmpty;
    
    // Calculate simple similarity - if less than 70% similar, it's significant
    final newWords = newText.toLowerCase().split(RegExp(r'\s+'));
    final oldWords = oldText.toLowerCase().split(RegExp(r'\s+'));
    
    final commonWords = newWords.where((word) => oldWords.contains(word)).length;
    final totalWords = (newWords.length + oldWords.length) / 2;
    
    if (totalWords == 0) return false;
    
    final similarity = commonWords / totalWords;
    return similarity < 0.7; // More than 30% change
  }

  Future<void> _processTextForFoodItems(String text) async {
    // Extract just the new lines/content that might be food items
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    for (final line in lines) {
      // Skip if we've already processed a very similar item
      if (_liveDetectedItems.any((item) => 
        item.name.toLowerCase().contains(line.toLowerCase().trim()) ||
        line.toLowerCase().trim().contains(item.name.toLowerCase())
      )) {
        continue;
      }
      
      // Check if this line is a food item using AI
      final foodItem = await _checkIfFoodItem(line);
      if (foodItem != null) {
        // Check if we already have a very similar item
        if (!_isDuplicateItem(foodItem)) {
          if (mounted) {
            setState(() {
              _liveDetectedItems.add(foodItem);
            });
          }
        }
      }
    }
  }

  bool _isDuplicateItem(ParsedItem newItem) {
    final newItemWords = newItem.name.toLowerCase().split(' ').where((w) => w.length > 2).toSet();
    
    for (final existingItem in _liveDetectedItems) {
      final existingWords = existingItem.name.toLowerCase().split(' ').where((w) => w.length > 2).toSet();
      
      // If they share the core food words, it's a duplicate
      // For example: "chicken breast" and "boneless chicken breast" both have "chicken" and "breast"
      final commonWords = newItemWords.intersection(existingWords);
      final maxWords = newItemWords.length > existingWords.length ? newItemWords.length : existingWords.length;
      
      // If more than 60% of words match, it's likely the same item
      if (commonWords.length >= 2 && commonWords.length / maxWords > 0.6) {
        return true;
      }
      
      // Exact core match (like "chicken" matches between items)
      if (newItemWords.contains('chicken') && existingWords.contains('chicken') ||
          newItemWords.contains('beef') && existingWords.contains('beef') ||
          newItemWords.contains('pork') && existingWords.contains('pork') ||
          newItemWords.contains('turkey') && existingWords.contains('turkey')) {
        // If they're both the same type of meat/protein, check if they're similar cuts
        final cuts = {'breast', 'thigh', 'wing', 'leg', 'ground', 'steak', 'chop', 'ribs'};
        final newCuts = newItemWords.intersection(cuts);
        final existingCuts = existingWords.intersection(cuts);
        
        // If they have the same cut, it's a duplicate
        if (newCuts.isNotEmpty && existingCuts.isNotEmpty && newCuts.intersection(existingCuts).isNotEmpty) {
          return true;
        }
      }
    }
    
    return false;
  }

  Future<ParsedItem?> _checkIfFoodItem(String text) async {
    try {
      final prompt = _buildFoodCheckPrompt(text);
      final response = await _callAIForFoodCheck(prompt);
      
      if (response != null && response.trim().isNotEmpty) {
        return _parseFoodCheckResponse(response);
      }
    } catch (e) {
      print('AI food check failed for "$text": $e');
    }
    
    return null;
  }

  String _buildFoodCheckPrompt(String text) {
    return '''Is this a food/grocery item? If yes, return JSON with cleaned name.

RULES:
- KEEP important parts: cuts (breast, thigh, wing), forms (ground, whole, sliced)
- REMOVE descriptors: boneless, skinless, organic, fresh, frozen, raw, etc.
- REMOVE brands UNLESS it's a branded product (Coke, Sprite, Oreos, etc.)

Examples:
- "Boneless Skinless Chicken Breast" → "chicken breast"
- "Fresh Organic Apples" → "apple"
- "Ground Beef 80/20" → "ground beef"
- "Sprite 2L" → "sprite"
- "Raw Chicken Thighs" → "chicken thighs"

Types: meat, poultry, seafood, vegetable, fruit, dairy, grain, beverage, snack, condiment, frozen, other

Text: "$text"

Return: {"name": "...", "quantity": 1, "type": "..."} or null''';
  }

  Future<String?> _callAIForFoodCheck(String prompt) async {
    try {
      final configService = ConfigService();
      final apiKey = await configService.getOpenAiApiKey();
      
      if (apiKey == null) return null;

      final requestBody = {
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.1,
        'max_tokens': 50, // Very small for efficiency
      };

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices']?[0]?['message']?['content']?.toString().trim();
      }
    } catch (e) {
      print('AI call error: $e');
    }
    
    return null;
  }

  ParsedItem? _parseFoodCheckResponse(String response) {
    try {
      final cleaned = response.trim().toLowerCase();
      if (cleaned == 'null' || cleaned.isEmpty) return null;
      
      // Remove any markdown code blocks
      var jsonStr = response.replaceAll(RegExp(r'```json\s*|\s*```'), '').trim();
      
      final data = json.decode(jsonStr);
      
      if (data is Map<String, dynamic>) {
        final name = data['name']?.toString();
        final quantity = data['quantity'];
        final type = data['type']?.toString();
        
        if (name != null && name.isNotEmpty) {
          final qty = quantity is int ? quantity : (int.tryParse(quantity?.toString() ?? '1') ?? 1);
          return ParsedItem(
            name: _titleCase(name),
            quantity: qty,
            type: type != null ? GroceryType.fromString(type) : GroceryType.other,
          );
        }
      }
    } catch (e) {
      print('Failed to parse food check response: $e');
    }
    
    return null;
  }

  String _titleCase(String s) =>
      s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');

  Future<void> _finishLiveScanning() async {
    if (_liveDetectedItems.isEmpty) {
      setState(() {
        _err = 'No food items detected yet. Keep scanning or try manual entry.';
      });
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      // Use the items we've already detected
      if (mounted) {
        setState(() {
          _preview = List.from(_liveDetectedItems);
          _isCameraMode = false;
          _liveDetectedItems.clear();
        });
        _cameraController?.dispose();
        _cameraController = null;
        _processingTimer?.cancel();
      }
    } catch (e) {
      setState(() {
        _err = 'Failed to process items: $e';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  void _exitCameraMode() {
    _processingTimer?.cancel();
    _cameraController?.dispose();
    _cameraController = null;
    setState(() {
      _isCameraMode = false;
      _liveText = '';
      _lastProcessedText = '';
      _liveDetectedItems.clear();
    });
  }


  Future<void> _pickAndProcess(ImageSource source) async {
    setState(() {
      _busy = true;
      _err = null;
      _preview = [];
    });
    
    try {
      // Request appropriate permissions based on source
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          setState(() {
            _err = 'Camera permission is required to take photos';
            _busy = false;
          });
          return;
        }
      } else if (source == ImageSource.gallery) {
        // For Android 13+ (API 33+), we need READ_MEDIA_IMAGES permission
        // For older versions, we need READ_EXTERNAL_STORAGE permission
        Permission permission;
        if (Platform.isAndroid) {
          // Check Android version and request appropriate permission
          permission = Permission.photos; // This handles both cases automatically
        } else {
          permission = Permission.photos;
        }
        
        final galleryStatus = await permission.request();
        if (!galleryStatus.isGranted) {
          setState(() {
            _err = 'Storage permission is required to access photos';
            _busy = false;
          });
          return;
        }
      }
      
      final picker = ImagePicker();
      final x = await picker.pickImage(source: source, imageQuality: 85);
      if (x == null) {
        setState(() => _busy = false);
        return;
      }
      final file = File(x.path);
      final input = InputImage.fromFile(file);
      final result = await _textRecognizer.processImage(input);
      final items = await ReceiptParser.parse(result.text);
      setState(() => _preview = items);
    } catch (e) {
      setState(() => _err = 'OCR failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _saveAll() async {
    if (_preview.isEmpty) return;
    
    setState(() => _busy = true);
    
    try {
      final user = _auth.currentUser!;
      final rules = _rules ?? await ExpiryRules.load();

      final batch = _db.batch();
      final col = _db.collection('users').doc(user.uid).collection('items');
      final now = DateTime.now();

      // Temporarily disabled notifications to prevent crashes
      // final notificationTasks = <Future<void>>[];

      for (final it in _preview) {
        // Use type from parsed item if available, otherwise try LLM prediction
        int days = 5; // Default fallback
        GroceryType itemType = it.type; // Use type from parsed item
        
        try {
          final prediction = await LLMService().predictExpiryAndType(it.name);
          if (prediction != null) {
            days = prediction['days'] as int? ?? rules.guessDays(it.name);
            // Only override type if LLM prediction is more specific than 'other'
            final typeStr = prediction['type'] as String?;
            if (typeStr != null && itemType == GroceryType.other) {
              itemType = GroceryType.fromString(typeStr);
            }
          } else {
            days = rules.guessDays(it.name);
          }
        } catch (e) {
          print('LLM prediction failed for ${it.name}, using rules: $e');
          days = rules.guessDays(it.name);
        }
        
        final expiry = now.add(Duration(days: days));
        final doc = col.doc();
        
        batch.set(doc, {
          'name': it.name,
          'quantity': it.quantity,
          'expiryDate': Timestamp.fromDate(expiry),
          'groceryType': itemType.name,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'source': 'receipt',
        });
        
        // Temporarily disable notifications to prevent crashes
        // Schedule notification (don't await here, collect for later)
        // Use a more stable ID generation to avoid potential hash collisions
        // final notificationId = doc.id.hashCode.abs();
        // notificationTasks.add(
        //   _scheduleNotificationSafely(
        //     id: notificationId,
        //     title: 'Use soon: ${it.name}',
        //     body: 'Expires tomorrow',
        //     when: expiry.subtract(const Duration(days: 1)),
        //   ),
        // );
      }
      
      // Commit the batch first with timeout
      await batch.commit().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Firestore batch commit timed out');
        },
      );
      
      // Then handle notifications (fire and forget, don't block UI)
      // Schedule notifications in the background without blocking
      // Temporarily disable notifications to prevent crashes
      // if (notificationTasks.isNotEmpty) {
      //   unawaited(_handleNotificationsSafely(notificationTasks));
      // }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${_preview.length} items')),
        );
        // Clear the preview and reset state instead of navigating away
        _clearPreview();
      }
    } catch (e) {
      print('Error saving items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save items: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Removed barcode handling methods

  // Removed _confirmAndSave method (was for barcode functionality)

  void _editParsedItem(int index) {
    final it = _preview[index];
    final nameCtrl = TextEditingController(text: it.name);
    final qtyCtrl = TextEditingController(text: it.quantity.toString());

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Edit parsed item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                setState(() {
                  _preview[index] = ParsedItem(
                    name: nameCtrl.text.trim(),
                    quantity: int.tryParse(qtyCtrl.text) ?? it.quantity,
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteParsedItem(int index) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete Item'),
          content: Text('Are you sure you want to delete "${_preview[index].name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _preview.removeAt(index);
                });
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedItems.clear();
    });
  }

  void _toggleItemSelection(int index) {
    setState(() {
      if (_selectedItems.contains(index)) {
        _selectedItems.remove(index);
      } else {
        _selectedItems.add(index);
      }
    });
  }

  void _deleteSelectedItems() {
    if (_selectedItems.isEmpty) return;
    
    final selectedNames = _selectedItems.map((i) => _preview[i].name).join(', ');
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete Selected Items'),
          content: Text('Are you sure you want to delete ${_selectedItems.length} item(s):\n$selectedNames?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  // Sort indices in descending order to avoid index shifting issues
                  final sortedIndices = _selectedItems.toList()..sort((a, b) => b.compareTo(a));
                  for (final index in sortedIndices) {
                    _preview.removeAt(index);
                  }
                  _selectedItems.clear();
                  _isSelectionMode = false;
                });
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _selectAllItems() {
    setState(() {
      _selectedItems = {for (int i = 0; i < _preview.length; i++) i};
    });
  }

  void _deselectAllItems() {
    setState(() {
      _selectedItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.isDarkMode ? ThemeService.darkBackground : ThemeService.lightBackground,
      appBar: AppBar(
        title: _isSelectionMode 
          ? Row(
              children: [
                Text(
                  '${_selectedItems.length} selected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF27AE60),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Smart Scanner',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
                  ),
                ),
              ],
            ),
        backgroundColor: _themeService.isDarkMode ? ThemeService.darkBackground : ThemeService.lightBackground,
        elevation: 0,
        iconTheme: IconThemeData(
          color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
        ),
        actions: _isSelectionMode ? [
          IconButton(
            icon: const Icon(Icons.select_all_rounded, size: 18),
            onPressed: _selectedItems.length == _preview.length ? _deselectAllItems : _selectAllItems,
            tooltip: _selectedItems.length == _preview.length ? 'Deselect All' : 'Select All',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(28, 28),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, size: 18),
            onPressed: _selectedItems.isEmpty ? null : _deleteSelectedItems,
            tooltip: 'Delete Selected',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(28, 28),
            ),
          ),
        ] : _preview.isNotEmpty ? [
          IconButton(
            icon: const Icon(Icons.checklist_rounded, size: 18),
            onPressed: _toggleSelectionMode,
            tooltip: 'Select Items',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(28, 28),
            ),
          ),
        ] : null,
        leading: _isSelectionMode 
          ? IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: _toggleSelectionMode,
              tooltip: 'Cancel Selection',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(6),
                minimumSize: const Size(28, 28),
              ),
            )
          : null,
      ),
      body: _buildReceiptTab(),
    );
  }

  Widget _buildReceiptTab() {
    return Column(
      children: [
        // Header Section
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan Your Receipt',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode 
                      ? ThemeService.darkTextPrimary 
                      : const Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Quickly add items to your fridge by scanning receipts',
                style: TextStyle(
                  fontSize: 16,
                  color: _themeService.isDarkMode 
                      ? ThemeService.darkTextSecondary 
                      : const Color(0xFF7F8C8D),
                ),
              ),
            ],
          ),
        ),

        if (_err != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE74C3C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE74C3C).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFE74C3C),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _err!,
                    style: const TextStyle(
                      color: Color(0xFFE74C3C),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Scan Options Cards
        if (_preview.isEmpty && !_busy && !_isCameraMode) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildScanOptionCard(
                  icon: Icons.videocam_rounded,
                  iconColor: const Color(0xFF27AE60),
                  title: 'Live Camera Scanner',
                  description: 'Real-time text recognition with camera',
                  onTap: _startLiveCamera,
                ),
                const SizedBox(height: 16),
                _buildScanOptionCard(
                  icon: Icons.photo_library_rounded,
                  iconColor: const Color(0xFF9B59B6),
                  title: 'Choose from Gallery',
                  description: 'Select a photo of your receipt',
                  onTap: () => _pickAndProcess(ImageSource.gallery),
                ),
                const SizedBox(height: 16),
                _buildScanOptionCard(
                  icon: Icons.camera_alt_rounded,
                  iconColor: const Color(0xFF3498DB),
                  title: 'Take a Photo',
                  description: 'Capture your receipt with camera',
                  onTap: () => _pickAndProcess(ImageSource.camera),
                ),
              ],
            ),
          ),
        ],
        
        Expanded(
          child: _isCameraMode
              ? _buildCameraView()
              : _busy
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF27AE60).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Processing receipt...',
                            style: TextStyle(
                              color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This may take a few seconds',
                            style: TextStyle(
                              color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : const Color(0xFF7F8C8D),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _preview.isEmpty
                      ? _buildEmptyState()
                      : _buildItemsList(),
        ),
        
        // Action Buttons
        if (_preview.isNotEmpty) 
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: Platform.isAndroid 
                  ? MediaQuery.of(context).viewPadding.bottom > 0 
                      ? MediaQuery.of(context).viewPadding.bottom + 8.0  // Add extra padding if there's a navigation bar
                      : 20.0
                  : 20.0,
            ),
            decoration: BoxDecoration(
              color: _themeService.isDarkMode ? ThemeService.darkCardBackground : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_themeService.isDarkMode ? 0.3 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildModernActionButton(
                        icon: Icons.check_circle_rounded,
                        label: _busy ? 'Saving...' : 'Save All',
                        color: const Color(0xFF27AE60),
                        onPressed: _busy ? null : _saveAll,
                        isLoading: _busy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModernActionButton(
                        icon: Icons.clear_all_rounded,
                        label: 'Clear',
                        color: const Color(0xFFE74C3C),
                        onPressed: _busy ? null : _clearPreview,
                        isSecondary: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildScanOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _themeService.isDarkMode 
                  ? [
                      ThemeService.darkCardBackground, 
                      ThemeService.darkCardBackground.withOpacity(0.8)
                    ]
                  : [Colors.white, iconColor.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: iconColor.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextPrimary 
                            : const Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextSecondary 
                            : const Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 20,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextSecondary 
                    : const Color(0xFFBDC3C7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
    bool isSecondary = false,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: !isSecondary && onPressed != null
            ? LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSecondary
            ? (onPressed != null ? color.withOpacity(0.1) : color.withOpacity(0.05))
            : null,
        borderRadius: BorderRadius.circular(16),
        border: isSecondary
            ? Border.all(color: color.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: !isSecondary && onPressed != null
            ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isSecondary ? color : Colors.white,
                      ),
                    ),
                  )
                else
                  Icon(
                    icon,
                    color: isSecondary ? color : Colors.white,
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSecondary ? color : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox.shrink();
  }

  Widget _buildCameraView() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF27AE60)),
            const SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(
                color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Camera Preview
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CameraPreview(_cameraController!),
          ),
        ),
        
        // Dark overlay with transparent scanning area
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(20),
            child: Stack(
              children: [
                // Semi-transparent overlay
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                // Scanning rectangle cutout
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: MediaQuery.of(context).size.height * 0.3,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF27AE60),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF27AE60).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Stack(
                            children: [
                              // Corner markers
                              Positioned(
                                top: 0,
                                left: 0,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Color(0xFF27AE60), width: 4),
                                      left: BorderSide(color: Color(0xFF27AE60), width: 4),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Color(0xFF27AE60), width: 4),
                                      right: BorderSide(color: Color(0xFF27AE60), width: 4),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: Color(0xFF27AE60), width: 4),
                                      left: BorderSide(color: Color(0xFF27AE60), width: 4),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: Color(0xFF27AE60), width: 4),
                                      right: BorderSide(color: Color(0xFF27AE60), width: 4),
                                    ),
                                  ),
                                ),
                              ),
                              // Scanning line animation
                              if (_isProcessingFrame)
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 1500),
                                  builder: (context, value, child) {
                                    return Positioned(
                                      top: value * (MediaQuery.of(context).size.height * 0.3 - 2),
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 2,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              const Color(0xFF27AE60).withOpacity(0.8),
                                              Colors.transparent,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF27AE60).withOpacity(0.5),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  onEnd: () {
                                    // Loop animation
                                    if (mounted && _isProcessingFrame) {
                                      setState(() {});
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Overlay with instructions and detected items
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Top bar with instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27AE60).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.center_focus_strong, color: Color(0xFF27AE60), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Align items in green frame',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'AI will detect food items automatically',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Bottom bar with detected items
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(17)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _liveDetectedItems.isEmpty 
                                  ? const Color(0xFF3498DB) 
                                  : const Color(0xFF27AE60),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _liveDetectedItems.isEmpty 
                                      ? Icons.search_rounded 
                                      : Icons.check_circle,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _liveDetectedItems.isEmpty 
                                      ? 'SCANNING...' 
                                      : '${_liveDetectedItems.length} FOUND',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (_liveDetectedItems.isNotEmpty)
                            Text(
                              'Tap ✓ when done',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                      if (_liveDetectedItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _liveDetectedItems.length,
                            itemBuilder: (context, index) {
                              final item = _liveDetectedItems[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF27AE60).withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Color(0xFF27AE60),
                                        size: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${item.name} (${item.quantity})',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          _liveText.isNotEmpty
                              ? 'Processing text...'
                              : 'Point camera at food items',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Action buttons
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel button
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE74C3C),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE74C3C).withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: _exitCameraMode,
                  ),
                ),
                
                // Finish button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF27AE60).withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    iconSize: 40,
                    icon: Icon(
                      _liveDetectedItems.isEmpty 
                          ? Icons.hourglass_empty_rounded 
                          : Icons.check_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _liveDetectedItems.isEmpty ? null : _finishLiveScanning,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _preview.length,
      itemBuilder: (_, i) {
        final it = _preview[i];
        final isSelected = _selectedItems.contains(i);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _themeService.isDarkMode 
                    ? [ThemeService.darkCardBackground, ThemeService.darkCardBackground.withOpacity(0.8)]
                    : [Colors.white, const Color(0xFFF8F9FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isSelectionMode && isSelected 
                    ? const Color(0xFF27AE60)
                    : const Color(0xFF27AE60).withOpacity(0.2),
                width: _isSelectionMode && isSelected ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF27AE60).withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _isSelectionMode ? () => _toggleItemSelection(i) : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_isSelectionMode) ...[
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleItemSelection(i),
                        activeColor: const Color(0xFF27AE60),
                      ),
                      const SizedBox(width: 12),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27AE60).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF27AE60),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _themeService.isDarkMode 
                                  ? ThemeService.darkTextPrimary 
                                  : const Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3498DB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF3498DB).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.inventory_2_rounded,
                                  size: 14,
                                  color: Color(0xFF3498DB),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Qty: ${it.quantity}',
                                  style: const TextStyle(
                                    color: Color(0xFF3498DB),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isSelectionMode)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF3498DB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.edit_rounded,
                                color: Color(0xFF3498DB),
                                size: 20,
                              ),
                              onPressed: () => _editParsedItem(i),
                              tooltip: 'Edit',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE74C3C).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.delete_rounded,
                                color: Color(0xFFE74C3C),
                                size: 20,
                              ),
                              onPressed: () => _deleteParsedItem(i),
                              tooltip: 'Delete',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Removed _buildBarcodeTab method
}


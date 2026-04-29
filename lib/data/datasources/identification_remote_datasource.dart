import 'package:dio/dio.dart';
import '../models/bird_species_model.dart';
import '../models/prediction_model.dart';
import '../../core/errors/exceptions.dart';

abstract class IIdentificationRemoteDataSource {
  Future<List<PredictionModel>> identifyFromImage(
    String imagePath, {
    double? latitude,
    double? longitude,
    DateTime? timestamp,
  });

  Future<BirdSpeciesModel> getSpeciesDetails(String speciesId);

  Future<List<BirdSpeciesModel>> getAllSpecies();
}

class IdentificationRemoteDataSource implements IIdentificationRemoteDataSource {
  final Dio localDio;
  final Dio hfDio;

  IdentificationRemoteDataSource({required this.localDio, required this.hfDio});

  @override
  Future<List<PredictionModel>> identifyFromImage(
    String imagePath, {
    double? latitude,
    double? longitude,
    DateTime? timestamp,
  }) async {
    // Fire-and-forget: save picture metadata to local API
    _savePictureMetadata(
      imagePath: imagePath,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
    );

    // Call HuggingFace recognition API
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imagePath),
      });

      final response = await hfDio.post('/predict', data: formData);

      if (response.statusCode == 200) {
        // ignore: avoid_print
        print('[HF] raw response: ${response.data}');
        final predictions = _parseHfResponse(response.data);
        // ignore: avoid_print
        print('[HF] parsed ${predictions.length} prediction(s)');
        return predictions;
      } else {
        throw ServerException('Identification failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Network error');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<BirdSpeciesModel> getSpeciesDetails(String speciesId) async {
    try {
      final response = await localDio.get('/species/$speciesId');
      if (response.statusCode == 200) {
        return BirdSpeciesModel.fromJson(response.data);
      }
      throw ServerException('Failed to get species details: ${response.statusCode}');
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Network error');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<List<BirdSpeciesModel>> getAllSpecies() async {
    try {
      final response = await localDio.get('/species');
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => BirdSpeciesModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw ServerException('Failed to get species list: ${response.statusCode}');
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Network error');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Unexpected error: $e');
    }
  }

  /// Parse various possible HF response shapes into a sorted list of predictions.
  List<PredictionModel> _parseHfResponse(dynamic data) {
    if (data is! Map) return const [];
    final root = Map<String, dynamic>.from(data);
    final prediction = root['prediction'];
    final predMap = prediction is Map ? Map<String, dynamic>.from(prediction) : root;

    final scores = predMap['all_scores'] ?? root['all_scores'] ?? predMap['scores'];

    // Case 1: List<{class, confidence}> or List<{label, score}>
    if (scores is List && scores.isNotEmpty) {
      return scores
          .whereType<Map>()
          .map((m) => PredictionModel.fromHfJson(Map<String, dynamic>.from(m)))
          .toList()
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
    }

    // Case 2: Map<className, score>
    if (scores is Map) {
      return scores.entries
          .map((e) => PredictionModel.fromHfJson({
                'class': e.key.toString(),
                'confidence': (e.value as num).toDouble(),
              }))
          .toList()
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
    }

    // Case 3: just top prediction (class + confidence at predMap level)
    if (predMap['class'] != null && predMap['confidence'] != null) {
      return [PredictionModel.fromHfJson(predMap)];
    }

    return const [];
  }

  Future<void> _savePictureMetadata({
    required String imagePath,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
  }) async {
    try {
      await localDio.post('/pictures', data: {
        'url': imagePath,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
        'date_collected': (timestamp ?? DateTime.now()).toIso8601String().split('T').first,
      });
    } catch (_) {
      // Non-blocking — identification proceeds even if metadata save fails
    }
  }
}

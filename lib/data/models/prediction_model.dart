import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/prediction.dart';

part 'prediction_model.freezed.dart';
part 'prediction_model.g.dart';

@freezed
class PredictionModel with _$PredictionModel {
  const PredictionModel._();

  const factory PredictionModel({
    required String speciesId,
    required String speciesName,
    required String scientificName,
    required double confidence,
    double? geographicWeight,
    double? temporalWeight,
    required double finalScore,
  }) = _PredictionModel;

  factory PredictionModel.fromJson(Map<String, dynamic> json) =>
      _$PredictionModelFromJson(json);

  /// Convert model to entity
  Prediction toEntity() {
    return Prediction(
      speciesId: speciesId,
      speciesName: speciesName,
      scientificName: scientificName,
      confidence: confidence,
      geographicWeight: geographicWeight,
      temporalWeight: temporalWeight,
      finalScore: finalScore,
    );
  }

  /// Create model from HuggingFace all_scores item.
  /// Accepts: { class | label, confidence | score }
  static PredictionModel fromHfJson(Map<String, dynamic> json) {
    final rawClass = (json['class'] ?? json['label'] ?? '').toString().trim();
    final rawScore = json['confidence'] ?? json['score'] ?? 0;
    final raw = (rawScore as num).toDouble();
    final confidence = raw > 1.0 ? raw / 100.0 : raw; // normalise to 0–1
    final pretty = rawClass.replaceAll('_', ' ');
    return PredictionModel(
      speciesId: rawClass,
      speciesName: pretty,
      scientificName: '',
      confidence: confidence,
      finalScore: confidence,
    );
  }

  /// Create model from entity
  factory PredictionModel.fromEntity(Prediction entity) {
    return PredictionModel(
      speciesId: entity.speciesId,
      speciesName: entity.speciesName,
      scientificName: entity.scientificName,
      confidence: entity.confidence,
      geographicWeight: entity.geographicWeight,
      temporalWeight: entity.temporalWeight,
      finalScore: entity.finalScore,
    );
  }
}

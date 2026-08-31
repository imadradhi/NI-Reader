import 'card_data.dart';

enum ApiResponseStatus {
  SUCCESS,
  ERROR;

  String toJson() => name;
  static ApiResponseStatus fromJson(String value) =>
      ApiResponseStatus.values.firstWhere((e) => e.name == value, orElse: () => ApiResponseStatus.ERROR);
}

class ApiCardReadRequest {
  final String deviceId;
  final int readTimestamp;
  final CardData cardData;

  ApiCardReadRequest({
    required this.deviceId,
    required this.readTimestamp,
    required this.cardData,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'readTimestamp': readTimestamp,
    'cardData': cardData.toJson(),
  };
}

class ApiCardReadResponse {
  final ApiResponseStatus status;
  final String message;
  final String? cardId;

  ApiCardReadResponse({
    required this.status,
    required this.message,
    this.cardId,
  });

  factory ApiCardReadResponse.fromJson(Map<String, dynamic> json) => ApiCardReadResponse(
    status: ApiResponseStatus.fromJson(json['status'] ?? 'SUCCESS'),
    message: json['message'] ?? '',
    cardId: json['cardId'],
  );
}

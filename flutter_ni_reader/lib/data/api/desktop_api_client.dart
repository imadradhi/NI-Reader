import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/api_payload.dart';
import '../models/card_data.dart';

/// REST API client communicating with the desktop host application over USB / Local network.
class DesktopApiClient {
  String baseUrl;
  late final Dio _dio;

  DesktopApiClient({this.baseUrl = "http://192.168.42.129:8080"}) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
      ),
    );
  }

  void updateBaseUrl(String newUrl) {
    baseUrl = newUrl.replaceAll(RegExp(r'/+$'), '');
  }

  /// Checks if Desktop API server is reachable.
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/health',
        options: Options(
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Sends the complete CardData payload to Desktop API endpoint POST /api/national-id/read.
  Future<ApiCardReadResponse> sendCardData(CardData cardData, {String deviceId = "Flutter Companion App"}) async {
    try {
      final payload = ApiCardReadRequest(
        deviceId: deviceId,
        readTimestamp: DateTime.now().millisecondsSinceEpoch,
        cardData: cardData,
      );

      final response = await _dio.post(
        '$baseUrl/api/national-id/read',
        data: jsonEncode(payload.toJson()),
      );

      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic>) {
          return ApiCardReadResponse.fromJson(response.data);
        } else if (response.data is String) {
          return ApiCardReadResponse.fromJson(jsonDecode(response.data));
        }
        return ApiCardReadResponse(
          status: ApiResponseStatus.SUCCESS,
          message: "تم استقبال البيانات بنجاح في تطبيق الحاسوب",
        );
      } else {
        throw Exception("Server returned HTTP ${response.statusCode}");
      }
    } catch (e) {
      return ApiCardReadResponse(
        status: ApiResponseStatus.ERROR,
        message: "فشل الإرسال للحاسوب: ${e.toString()}",
      );
    }
  }
}

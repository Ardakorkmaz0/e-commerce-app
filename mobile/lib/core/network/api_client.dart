import 'package:dio/dio.dart';
import 'package:ecommerce_mobile/core/config/app_config.dart';

class ApiClient {
  ApiClient({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: const <String, String>{
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            ),
          );

  final Dio dio;
}

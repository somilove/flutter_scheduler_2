import 'dart:async';
import 'dart:io';
import 'package:calendar_scheduler/model/schedule_model.dart';
import 'package:dio/dio.dart';

class ScheduleRepository {
  final _dio = Dio();
  final _targetUrl = 'http://${Platform.isAndroid ? '10.0.2.2' : 'localhost'}:3000/schedule';  // Android에서는 10.0.0.2가 localhost에 해당됩니다.

  ScheduleRepository() {
    _dio.interceptors.add(CustomInterceptor());
  }

  Future<List<ScheduleModel>> getSchedules({
    required DateTime date,
    //함수를 실행할 때 액세스 토큰을 입력받는다
    required String accessToken,
  }) async {
    final resp = await _dio.get(
      _targetUrl,
      queryParameters: {  // ➊ Query Parameter
        'date':
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}',
      },
      //각 함수에서 보내는 HTTP요청 헤더에 토큰을 포함하는 로직포함(어떤 사용자가 요청 보냈는지 서버가 식별하도록)
      options: Options(
        headers: {
          'authorization': 'Bearer $accessToken',
        },
      ),
    );
    return resp.data  // ➋ 모델 인스턴스로 데이터 매핑하기
        .map<ScheduleModel>(
          (x) => ScheduleModel.fromJson(
        json: x,
      ),
    )
        .toList();
  }

  Future<String> createSchedule({
    required String accessToken,
    required ScheduleModel schedule,
  }) async {
    final json = schedule.toJson();

    final resp = await _dio.post(_targetUrl, data: json,
      options: Options(
        headers: {
          'authorization': 'Bearer $accessToken',
        },
      ),
    );

    return resp.data?['id'];
  }

  Future<String> deleteSchedule({
    required String accessToken,
    required String id,
  }) async {
    final resp = await _dio.delete(_targetUrl, data: {
      'id': id,  // 삭제할 ID값
    },
      options: Options(
        headers: {
          'authorization': 'Bearer $accessToken',
        },
      ),
    );

    return resp.data?['id'];  // 삭제된 ID값 반환
  }
}


class CustomInterceptor extends Interceptor {
  // 1) 요청 보낼때
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('[REQ] [${options.method}] ${options.uri}');

    return super.onRequest(options, handler);
  }

  // 2) 응답을 받을때
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // TODO: implement onResponse
    return super.onResponse(response, handler);
  }

  // 3) 에러가 났을때
  @override
  void onError(DioError err, ErrorInterceptorHandler handler) async {
    // 401 에러가 날때 (status code)
    // 토큰을 재발급 받는 시도를 한다.
    // 토큰이 재발급되면, 다시 새로운 토큰으로 요청을 한다.
    print('[ERR] [${err.requestOptions.method}] ${err.requestOptions.uri}');
    // TODO: implement onError


    return super.onError(err, handler);
  }
}
import 'dart:async';
import 'dart:io';
import 'package:calendar_scheduler/model/schedule_model.dart';
import 'package:dio/dio.dart';

class ScheduleRepository {
  final _dio = Dio();
  final _targetUrl = 'http://${Platform.isAndroid ? '10.0.2.2' : 'localhost'}:3000/schedule';  // Android에서는 10.0.0.2가 localhost에 해당됩니다.

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

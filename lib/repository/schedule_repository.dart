import 'dart:async';
import 'dart:io';
import 'package:calendar_scheduler/model/schedule_model.dart';
import 'package:calendar_scheduler/provider/schedule_provider.dart';
import 'package:calendar_scheduler/repository/auth_repository.dart';
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

//interceptor => HTTP Request, Response, Error 시에 중간에 끼어들어서
//새로운 행동을 추가할 때 사용
class CustomInterceptor extends Interceptor {
  // 1) 요청 보낼때
  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    print('[REQ] [${options.method}] ${options.uri}');

    if(options.headers['accessToken'] =='true') {
      //헤더 삭제 (실제 요청 시 불필요한 HTTP 헤더 없애기)
      options.headers.remove('accessToken');
      final token = await ScheduleProvider.storage.read(key: 'accessTokenKey');

      //실제 토큰으로 대체
      options.headers.addAll({
        'authrization': 'Bearer $token',
      });
    } else if (options.headers['refreshToken'] == 'true') {
      //헤더 삭제
      options.headers.remove('refreshToken');
      final token = await ScheduleProvider.storage.read(key: 'refreshTokenKey');

      //실제 토큰으로 대체
      options.headers.addAll({
        'authorization': 'Bearer $token',
      });
    }
    //마지막으로 요청 전송
    return super.onRequest(options, handler);
  }

  // 2) 응답을 받을때
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    return super.onResponse(response, handler);
  }

  // 3) 에러가 났을때
  @override
  void onError(DioError err, ErrorInterceptorHandler handler ) async {
    // 401 에러가 날때 (status code)
    // 토큰을 재발급 받는 시도를 한다.
    // 토큰이 재발급되면, 다시 새로운 토큰으로 요청을 한다.
    print('******************[ERR] [${err.requestOptions.method}] ${err.requestOptions.uri}**************** ******************');
    print(err.response!.statusCode);
    print(err.requestOptions!.path);
    final refreshToken = await ScheduleProvider.storage.read(key: 'refreshTokenKey');

    //refreshToken이 아예 없으면 에러 던지기
    if(refreshToken == null) {
      return handler.reject(err);
    }

    final isStatus401 = err.response?.statusCode == 401;
    final isPathRefresh = err.requestOptions.path == '/auth/token';

    // token을 refresh하려는 의도가 아니었는데 401 에러가 발생했을 때
    if(isStatus401 && !isPathRefresh) {
      // 기존의 refresh token으로 새로운 accessToken 발급 시도
      // 반드시 새로운 Dio 객체를 생성해야 함 => 기존 Dio 인스턴스 재사용시 다시 onError함수에 빠지는 순환오류 발생하므로
      // rotateAccessToken()함수 참고
      try {
        print('*******************accessToken expeired');
        final dio = Dio();
        //기존의 Dio 인스턴스가 아닌
        //DioInterceptor 안에서 새로운 Dio 인스턴스를 생성하여 HTTP Request를 보내는 이유
        //기존의 Dio 인스턴스에 추가할 Interceptor를 구현했는데 기존의 Dio 인스턴스를 그대로 재사용할 경우 다시 onError에 빠지는 순환오류(무한루프)가 발 ㅡ   생하기 때문!
        // final accessToken = rotateToken(refreshToken: refreshToken, isRefreshToken: isPathRefresh);
        final accessToken = await AuthRepository().rotateAccessToken(refreshToken: refreshToken,dio: dio);
        final options = err.requestOptions;
        await ScheduleProvider.storage.write(key: 'accessTokenKey', value: accessToken);
        //토큰 변경하기
        options.headers.addAll({
          'authorization': 'Bearer $accessToken',
        });

        //요청 재전송
        final response = await dio.fetch(options);

        return handler.resolve(response);

      } on DioError catch(e) {
        //새로운 accessToken임에도 에러가 발생한 경우 refreshToken 마저도 만료된 것
        //로그아웃
        ScheduleProvider(authRepository: AuthRepository(), scheduleRepository: ScheduleRepository()).logout();
        return handler.reject(e);
      }
    }
    return super.onError(err, handler);
  }
}

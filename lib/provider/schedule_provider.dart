import 'dart:async';
import 'package:calendar_scheduler/model/schedule_model.dart';
import 'package:calendar_scheduler/repository/auth_repository.dart';
import 'package:calendar_scheduler/repository/schedule_repository.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ScheduleProvider extends ChangeNotifier {
  final AuthRepository authRepository;
  final ScheduleRepository scheduleRepository; // ➊ API 요청 로직을 담은 클래스
  static final storage = FlutterSecureStorage();// FlutterSecureStorage를 storage로 저장
  static dynamic userInfo  = '';// storage에 있는 유저 정보를 저장

  DateTime selectedDate = DateTime.utc(
    // ➋ 선택한 날짜
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  Map<DateTime, List<ScheduleModel>> cache = {}; // ➌ 일정 정보를 저장해둘 변수

  ScheduleProvider({
    required this.scheduleRepository,
    required this.authRepository,
  }) : super();


  void getSchedules({
    required DateTime date,
  }) async {
    final accessToken = await storage.read(key: 'accessTokenKey');
    print('accessToken');
    final resp = await scheduleRepository.getSchedules(
      date: date,
      //로그인을 해야 사용자와 관련된 일정 정보를 가져오는 getSchedules()함수를
      //실행할 수 있는 화면으로 이동하므로 !를 붙여서 accessToken이 null이 아님을 명시
      accessToken: accessToken!,
    ); // GET 메서드 보내기

    cache.update(date, (value) => resp,
        ifAbsent: () => resp); // ➊ 선택한 날짜의 일정들 업데이트하기

    notifyListeners(); // ➋ Listening 하는 위젯들 업데이트하기
  }

  void createSchedule({
    required ScheduleModel schedule,
  }) async {
    final accessToken = await storage.read(key: 'accessTokenKey');
    final targetDate = schedule.date;
    final uuid = Uuid();

    final tempId = uuid.v4();
    final newSchedule = schedule.copyWith(
      id: tempId,
    );

    cache.update(
      targetDate,
      (value) => [
        ...value,
        newSchedule,
      ]..sort(
          (a, b) => a.startTime.compareTo (
            b.startTime,
          ),
        ),
      ifAbsent: () => [newSchedule],
    );

    notifyListeners(); // 캐시업데이트 반영하기

    try {
      final savedSchedule = await scheduleRepository.createSchedule(
        schedule: schedule,
        accessToken: accessToken!,
      );

      cache.update(
        // ➊ 서버 응답 기반으로 캐시 업데이트
        targetDate,
        (value) => value
            .map((e) => e.id == tempId
                ? e.copyWith(
                    id: savedSchedule,
                  )
                : e)
            .toList(),
      );
    } catch (e) {
      cache.update(
        // ➋ 삭제 실패시 캐시 롤백하기
        targetDate,
        (value) => value.where((e) => e.id != tempId).toList(),
      );
    }
  }

  void deleteSchedule({
    required DateTime date,
    required String id,
  }) async {
    final accessToken = await storage.read(key: 'accessTokenKey');
    final targetSchedule = cache[date]!.firstWhere(
      (e) => e.id == id,
    ); // 삭제할 일정 기억

    cache.update(
      date,
      (value) => value.where((e) => e.id != id).toList(),
      ifAbsent: () => [],
    ); // 긍정적 응답 (응답 전에 캐시 먼저 업데이트)

    notifyListeners(); // 캐시업데이트 반영하기

    try {
      await scheduleRepository.deleteSchedule(
        id: id,
        accessToken: accessToken!,
      ); // ➊ 삭제함수 실행
    } catch (e) {
      cache.update(
        // ➋ 삭제 실패시 캐시 롤백하기
        date,
        (value) => [...value, targetSchedule]..sort(
            (a, b) => a.startTime.compareTo(
              b.startTime,
            ),
          ),
      );
    }

    notifyListeners();
  }

  void changeSelectedDate({
    required DateTime date,
  }) {
    selectedDate = date; // 현재 선택된 날짜를 매개변수로 입력받은 날짜로 변경
    notifyListeners();
  }

  //회원가입 로직
  Future<void> register({
    required String email,
    required String password,
  }) async {
    //AuthRepository에 미리 구현해둔 register() 함수 실행
    final resp = await authRepository.register(
      email: email,
      password: password,
    );

    await storage.write(
        key:'accessTokenKey', value: resp.accessToken
    );
    await storage.write(
        key:'refreshTokenKey', value: resp.refreshToken
    );

  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final resp = await authRepository.login(
      email: email,
      password: password,
    );

    await storage.write(
      key:'accessTokenKey', value: resp.accessToken
    );
    await storage.write(
      key:'refreshTokenKey', value: resp.refreshToken
    );

  }

  logout() async {
    await storage.delete(key: 'accessTokenKey');
    await storage.delete(key: 'refreshTokenKey');
    //로그아웃과 동시에 일정 정보 캐시 모두 삭제
    cache = {};
    notifyListeners();
  }
}



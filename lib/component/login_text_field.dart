import 'package:calendar_scheduler/const/colors.dart';
import 'package:flutter/material.dart';

class LoginTextField extends StatelessWidget {
  final FormFieldSetter<String?> onSaved;
  final FormFieldValidator<String?> validator;
  final String? hintText;
  final bool obscureText;


  const LoginTextField({
    required this.onSaved,
    required this.validator,
    this.obscureText = false,
    this.hintText,
    Key? key,
}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onSaved: onSaved, //사용자가 입력한 데이터 저장
      validator: validator, //사용자가 입력한 데이터의 유효성 검증
      cursorColor: SECONDARY_COLOR,

      //텍스트 필드에 입력된 값으 true일 경우 보이지 않도록 설정
      //비밀번호 텍스트 필드를 만들 때 유용
      obscureText: obscureText,
      decoration: InputDecoration(
        //텍스트 필드에 아무것도 입력하지 않았을 때 보여주는 힌트 문자
        hintText: hintText,
        //활성화된 상태의 보더
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(
            color: TEXT_FIELD_FILL_COLOR,
          ),
        ),
        //포커스된 상태의 보더
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(
            color: SECONDARY_COLOR,
          ),
        ),
        //에러 상태의 보더
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(
            color: ERROR_COLOR,
          ),
        ),
      ),
    );
  }
}
/// [target]はInputFormatterなどで数字とdividerのみになっている必要がある。
String? validateCardNumber(String target, int length) {
  // dividerを削除
  final String cardNumber = target.onlyDigit;
  return cardNumber.length == length ? null : '正しいカード番号を入力してください。';
}

String? validateName(String target) {
  return target.isEmpty ? 'カードに書いてある名前を入力してください。' : null;
}

String? validateDate(String target, DateTime now) {
  final int thisYear = int.parse(now.year.toString().substring(2));

  final RegExp datePattern = RegExp(r'^(\d\d)\D+(\d\d)$');
  final Match? match = datePattern.firstMatch(target);
  if (match == null) {
    return '有効期限を入力してください。';
  }

  final int month = int.parse(match[1]!);
  final int year = int.parse(match[2]!);

  if (month < 1 || month > 12) return '正しい月を入力してください。';
  if (year < thisYear) return '正しい年を入力してください。';

  return null;
}

String? validateCVC(String target) {
  final String cvcNumber = target.onlyDigit;
  return cvcNumber.length >= 3 ? null : '正しいCVCを入力してください。';
}

extension StringEx on String {
  String get onlyDigit =>
      RegExp(r'\d+').allMatches(this).map((e) => e[0]).join();
}

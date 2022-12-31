String? validateCardNumber(String source) {
  final String cardNumber = source.onlyDigit;

  // TODO: カードのブランドごとに分ける
  if (cardNumber.length < 12) return '正しいカード番号を入力してください。';

  return null;
}

String? validateName(String source) {
  return source.isEmpty ? 'カードに書いてある名前を入力してください。' : null;
}

String? validateDate(String source, DateTime now) {
  final int thisYear = int.parse(now.year.toString().substring(2));

  final RegExp datePattern = RegExp(r'(\d\d)\D+(\d\d)');
  final Match? match = datePattern.firstMatch(source);
  if (match == null) {
    return '有効期限を入力してください。';
  }

  final int month = int.parse(match[1]!);
  final int year = int.parse(match[2]!);

  if (month < 1 || month > 12) return '正しい月を入力してください。';
  if (year < thisYear) return '正しい年を入力してください。';

  return null;
}

String? validateCVC(String source) {
  final String cvcNumber = source.onlyDigit;
  // TODO: ブランドごとに変わるのか調べる
  return cvcNumber.length < 3 ? '正しいCVCを入力してください。' : null;
}

extension StringEx on String {
  String get onlyDigit =>
      RegExp(r'\d+').allMatches(this).map((e) => e[0]).join();
}

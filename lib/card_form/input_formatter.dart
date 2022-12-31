import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

extension _TextEditingValueEx on TextEditingValue {
  bool textWasDeletedFrom(TextEditingValue previousValue) {
    return previousValue.selection.isCollapsed
        ? previousValue.selection.baseOffset > selection.baseOffset
        : previousValue.selection.start == selection.baseOffset;
  }

  TextEditingValue textCleared() {
    return replaced(TextRange(start: 0, end: text.length), '');
  }
}

extension _TextRangeEx on TextRange {
  bool doesNotOverlapWith(TextRange other) {
    return !(start == end && end == other.start && other.start == other.end) &&
        (end <= other.start || other.end <= start);
  }
}

class _MutableTextRange {
  _MutableTextRange({required this.base, required this.extent});

  static _MutableTextRange? fromSelection(TextSelection selection) {
    return selection.isValid
        ? _MutableTextRange(
            base: selection.baseOffset, extent: selection.extentOffset)
        : null;
  }

  static _MutableTextRange? fromComposing(TextRange range) {
    return range.isValid && !range.isCollapsed
        ? _MutableTextRange(base: range.start, extent: range.end)
        : null;
  }

  /// [base] is [TextSelection.baseOffset] or [TextRange.start].
  int base;

  /// [extent] is [TextSelection.extentOffset] or [TextRange.end].
  int extent;

  @override
  String toString() {
    return '${objectRuntimeType(this, '_MutableTextRange')}(base: $base, extent: $extent)';
  }
}

class _ReplacementData {
  const _ReplacementData({
    required this.textRange,
    required this.text,
  });

  /// Letters in [textRange] are replaced by the [text].
  final TextRange textRange;

  /// Letters in [textRange] are replaced by the [text].
  final String text;

  @override
  String toString() =>
      '${objectRuntimeType(this, '_ReplacementData')}(textRange: $textRange, text: $text)';
}

/// [TextEditingValue.text]を置換するためのクラス
///
/// [TextEditingValue.replace]との違いは、置換を実行するタイミングとカーソル位置の調整。
/// [TextEditingValue.replace]は置換を即実行する。一方、このクラスは置換を即実行しない。
/// [_TextEditingValueReplacementData.apply]が呼ばれたときに置換を実行する。
/// このクラスはカーソルが置換範囲内にあったとき、置換範囲の末尾に移動させることができる。
///
/// このクラスは、[TextEditingValue.text]に対して複数の置換を実行したいときに使える。
/// [TextEditingValue.replace]で複数の置換を実行する場合、後ろから実行しないとindexがずれてしまう。
class _TextEditingValueReplacementData {
  _TextEditingValueReplacementData(this.formerValue)
      : _selection = _MutableTextRange.fromSelection(formerValue.selection),
        _composing = _MutableTextRange.fromComposing(formerValue.composing);

  final TextEditingValue formerValue;
  final List<_ReplacementData> _registeredReplacements = [];
  final _MutableTextRange? _selection;
  final _MutableTextRange? _composing;

  /// すでに存在する[_ReplacementData.textRange]に被らない場合に[replacementData]を追加する。
  void _addReplacementData(_ReplacementData replacementData) {
    final TextRange newTextRange = replacementData.textRange;

    final bool isValidatedRange = _registeredReplacements
        .map((e) => e.textRange)
        .every((textRange) => textRange.doesNotOverlapWith(newTextRange));
    if (!isValidatedRange) {
      throw ArgumentError("The range overlaps with exist ranges.");
    }

    _registeredReplacements.add(replacementData);
  }

  /// 置き換えを登録する。[start]と[end]は[formerValue]のインデックス。
  ///
  /// 置き換えの実行は[applied]が呼ばれたときに行われる。
  /// 重複した範囲の登録はできない。
  void register(
    /// inclusive
    int start,

    /// exclusive
    int end,
    String replacementString, {
    /// カーソルが[start] ~ [end]にあった場合、[text]の右側にカーソルを移動するかどうか
    bool moveCursorEnd = false,
  }) {
    assert(start <= end);

    final replacementRange = TextRange(start: start, end: end);
    final replacementData =
        _ReplacementData(textRange: replacementRange, text: replacementString);

    _addReplacementData(replacementData);

    if (!moveCursorEnd && replacementString.length == end - start) {
      return;
    }

    int additionalIndex(int currentIndex) {
      if ((moveCursorEnd && currentIndex < start) ||
          (!moveCursorEnd && currentIndex <= start)) {
        return 0;
      }

      final int removedLength = (currentIndex - start).clamp(0, end - start);
      final int additionalLength = replacementString.length;
      return additionalLength - removedLength;
    }

    _selection?.base += additionalIndex(formerValue.selection.baseOffset);
    _selection?.extent += additionalIndex(formerValue.selection.extentOffset);
    _composing?.base += additionalIndex(formerValue.composing.start);
    _composing?.extent += additionalIndex(formerValue.composing.end);
  }

  /// 登録された置換を実行して、置換が完了した[TextEditingValue]を返す。
  TextEditingValue applied() {
    // formerValueから変化がないため
    if (_registeredReplacements.isEmpty) {
      return formerValue;
    }

    // 末尾から置き換えるため、降順にソートする
    // 末尾から置き換えないと、インデックスがずれる。
    _registeredReplacements
        .sort((a, b) => b.textRange.start.compareTo(a.textRange.start));

    // 置き換える処理。selectionとcomposingは[registerReplacement]で登録するときに調整済み
    String newText = formerValue.text;
    for (var replacement in _registeredReplacements) {
      final range = replacement.textRange;
      newText = newText.replaceRange(range.start, range.end, replacement.text);
    }

    return TextEditingValue(
      text: newText,
      selection: _selection == null
          ? const TextSelection.collapsed(offset: -1)
          : TextSelection(
              baseOffset: _selection!.base,
              extentOffset: _selection!.extent,
              affinity: formerValue.selection.affinity,
              isDirectional: formerValue.selection.isDirectional,
            ),
      composing: _composing == null || _composing!.base == _composing!.extent
          ? TextRange.empty
          : TextRange(start: _selection!.base, end: _selection!.extent),
    );
  }
}

// [FilteringTextInputFormatter]を参考にした
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    TextEditingValue value = newValue;
    // 数字のみにする
    value = _cleanUpText(value);
    // 最大16桁にする（card numberは最大16桁）
    value = _clampCardNumberCount(value, 16);
    // 4桁ごとにスペースを入れる。
    value = _insertSpaces(value, newValue.textWasDeletedFrom(oldValue));
    return value;
  }

  /// [_TextEditingValueReplacementData.formerValue.text]を数字のみの文字列にする
  TextEditingValue _cleanUpText(TextEditingValue value) {
    final replacementData = _TextEditingValueReplacementData(value);

    // 一度、dividerを削除して数字のみにする
    final Iterable<Match> noiseMatches = RegExp(r'\D+').allMatches(value.text);
    for (var match in noiseMatches) {
      replacementData.register(match.start, match.end, '');
    }

    return replacementData.applied();
  }

  TextEditingValue _clampCardNumberCount(TextEditingValue value, int max) {
    return value.text.length <= max
        ? value
        : value.replaced(TextRange(start: max, end: value.text.length), '');
  }

  TextEditingValue _insertSpaces(TextEditingValue value, bool textWasDeleted) {
    final replacementData = _TextEditingValueReplacementData(value);

    final Iterable<Match> matches =
        RegExp(r'\d{4}|\d{1,3}').allMatches(value.text);
    for (int i = 0; i < matches.length; i++) {
      final match = matches.elementAt(i);

      // 長さが4未満になりうるのは一番最後のmatchのみ
      if (match[0]!.length < 4) break;
      // 文字が削除されているとき、末尾に空白は入れない。
      if (textWasDeleted && i == matches.length) break;
      // カード番号は 4桁 x 4 = 16桁。最後の4桁の末尾に空白は入れない
      if (i == 3) break;

      replacementData.register(match.end, match.end, ' ',
          moveCursorEnd: !textWasDeleted);
    }

    return replacementData.applied();
  }
}

/// 正規表現のグループを格納するクラス
class _Group {
  const _Group(this.text, {this.start = 0})
      : assert(start >= 0),
        end = start + text.length;

  final String text;

  /// The start of index, inclusive.
  final int start;

  /// The end of index, exclusive.
  final int end;

  /// If true, [start] == [end]. If [text] has only spaces, it returns true.
  bool get isEmpty => start == end;

  /// If false, [start] != [end].
  bool get isNotEmpty => !isEmpty;
}

/// 入力された値を MM / YY 形式にフォーマットする。全角文字には対応していない。
///
/// 月はゼロ詰め二桁にフォーマットする。
///
/// ex1) 935 -> 09 / 35
/// ex2) 1233 -> 12 / 33
/// ex3) 1 23 -> 01 / 23
class DateInputFormatter extends TextInputFormatter {
  /// この正規表現のマッチのグループ -> group1: month, group7: divider, group8 or group9: year
  /// month: 存在する月にのみマッチする。また、ゼロ詰めの数字（03など）にもマッチする。
  /// divider: monthの後にある0文字以上の任意の文字。0文字以上なのはdividerの入力が必須ではないため
  ///          例えば、「9 / 30」という入力は「930」でもOK
  /// year: monthかdividerの後にある1文字か2文字か4文字の数字
  ///
  /// マッチにはmonth、divider、yearしか存在しない。つまり、monthの前には何もないしyearの隣にも何もない
  /// また、monthの隣はdivider、dividerの隣はyearで、その逆も同じ
  static final RegExp _datePattern = RegExp(
      r'((1[0-2])|(0?[1-9])|[0-9])((?<!^0)(?<!\D0)(((\D+)(\d{4}|\d{1,2})?)|(\d{4}|\d{1,2})))?');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final Match? match = _datePattern.firstMatch(newValue.text);
    if (match == null) {
      return newValue.textCleared();
    }

    // month グループのstartが0なのは、マッチした文字列内での位置を表しているから。
    // monthとdividerとyearは隣あっているので、
    //               divider.start == month.end    year.start == divider.end
    final month = _Group(match[1]!, start: 0);
    final divider = _Group(match[7] ?? '', start: month.end);
    final year = _Group(match[8] ?? match[9] ?? '', start: divider.end);

    // TextEditingValue.text はマッチした文字列のみにしたいので、
    // マッチした文字列の前後を消す（''に置き換える）
    final TextEditingValue valueInMatchedRange = newValue
        .replaced(TextRange(start: match.end, end: newValue.text.length), '')
        .replaced(TextRange(start: 0, end: match.start), '');

    final Match? oldMatch = _datePattern.firstMatch(oldValue.text);
    // startとendは使わないので適当な数字
    final _Group oldDivider = _Group(oldMatch?[7] ?? '', start: 0);

    final replacementData =
        _TextEditingValueReplacementData(valueInMatchedRange);
    _formatMonth(replacementData, month, divider, year);
    _formatDivider(replacementData, month, divider, year, oldDivider);
    _formatYear(replacementData, year);
    return replacementData.applied();
  }

  void _formatMonth(
    _TextEditingValueReplacementData replacementData,
    _Group month,
    _Group divider,
    _Group year,
  ) {
    // monthの入力が完了している場合、フォーマットする
    // フォーマット内容：monthをゼロ詰めで二桁にする。ex) 3 -> 03
    // もしmonthがもともと二桁の場合（12など）、この処理に意味はない
    if (_monthIsDecided(month, divider, year)) {
      replacementData.register(
          month.start, month.end, month.text.padLeft(2, '0'));
    }
  }

  void _formatDivider(
    _TextEditingValueReplacementData replacementData,
    _Group month,
    _Group divider,
    _Group year,
    _Group oldDivider,
  ) {
    final bool dividerWasDeleted = divider.text.length < oldDivider.text.length;
    final bool needDivider = year.isNotEmpty ||
        (_monthIsDecided(month, divider, year) && !dividerWasDeleted);

    if (needDivider) {
      // dividerの挿入
      replacementData.register(divider.start, divider.end, ' / ',
          moveCursorEnd: true);
    } else {
      // dividerの削除
      replacementData.register(divider.start, divider.end, '');
    }
  }

  /// 年を4桁で入力した場合に2桁に変換する
  /// ex) 2025 -> 25
  void _formatYear(
      _TextEditingValueReplacementData replacementData, _Group year) {
    if (year.text.length != 4) return;
    replacementData.register(year.start, year.start + 2, '');
  }

  /// monthが確定しているかどうかを判定する。
  bool _monthIsDecided(_Group month, _Group divider, _Group year) =>
      // month == 1 -> 10〜12の可能性がある。そのため、month >= 2
      // month == 1 でもdividerかyearが入力されていたら、「1月」であるとみなす
      int.parse(month.text) >= 2 || divider.isNotEmpty || year.isNotEmpty;
}

/// 全角文字の英数字記号を半角文字に変換する。また、composingは空にする。
///
/// 変換する全角文字はU+FF01からU+FF5E
/// 詳しくはこのページを参照 https://unicode.org/charts/nameslist/n_FF00.html
class HalfWidthFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue, // 使わない
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: _convertToHalfWidth(newValue.text),
      composing: TextRange.empty,
    );
  }

  String _convertToHalfWidth(String text) {
    // 変換する文字の詳細 https://unicode.org/charts/nameslist/n_FF00.html
    return text.replaceAllMapped(RegExp(r'[\uFF01-\uFF5E]'),
        (m) => String.fromCharCode(m[0]!.codeUnits[0] - 0xFEE0));
  }
}

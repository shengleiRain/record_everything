import '../constants/smart_entry_keywords.dart';

/// 文本预处理：全半角统一、中文数字/单位词转阿拉伯数字、去首尾空白。
///
/// 不负责分句（交给 Splitter）。中文数字转换只覆盖高频金额场景，
/// 复杂长串数字交给云端兜底。
class Preprocessor {
  const Preprocessor();

  String normalize(String input) {
    var s = input.trim();
    s = _fullWidthToHalf(s);
    s = _convertChineseNumber(s);
    s = _convertUnitWords(s);
    return s;
  }

  /// 全角字符（含标点）转半角。
  /// CJK 标点（U+3000-303F）不在 FF01-FF5E 段，需单独映射。
  static const _cjkPunct = {
    0x3001: ',', // 、
    0x3002: '.', // 。
    0x300A: '<', // 《
    0x300B: '>', // 》
    0x3010: '[', // 【
    0x3011: ']', // 】
  };

  String _fullWidthToHalf(String s) {
    final buf = StringBuffer();
    for (final code in s.runes) {
      if (code == 0x3000) {
        buf.write(' ');
      } else if (code >= 0xFF01 && code <= 0xFF5E) {
        buf.write(String.fromCharCode(code - 0xFEE0));
      } else if (_cjkPunct.containsKey(code)) {
        buf.write(_cjkPunct[code]);
      } else {
        buf.write(String.fromCharCode(code));
      }
    }
    return buf.toString();
  }

  /// 中文数字（金额高频）转阿拉伯。仅匹配连读的中数字串。
  String _convertChineseNumber(String s) {
    return s.replaceAllMapped(
      RegExp(r'[零一二三四五六七八九十百千万两]+'),
      (m) {
        final n = chineseNumberToArabic(m[0]!);
        return n == null ? m[0]! : n.toString();
      },
    );
  }

  /// 1k/1w/1K/1W → 1000/10000。
  String _convertUnitWords(String s) {
    return s.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*([kKwW])'),
      (m) {
        final num n = double.parse(m[1]!);
        final mul = (m[2]!.toLowerCase() == 'k') ? 1000 : 10000;
        final v = n * mul;
        return v == v.toInt() ? v.toInt().toString() : v.toString();
      },
    );
  }
}

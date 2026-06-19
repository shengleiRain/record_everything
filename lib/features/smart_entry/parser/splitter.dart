/// 按 ，, ；; 。. 换行 将多句输入拆成段。
/// 已假定输入经过 Preprocessor（全角标点已转半角），但正则同时兼容全角形式。
class Splitter {
  const Splitter();

  static final _sep = RegExp(r'[,，;；.。\s]+');

  List<String> split(String input) {
    if (input.trim().isEmpty) return const [];
    return input
        .split(_sep)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}

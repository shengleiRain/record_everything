import 'package:flutter/material.dart';

import 'generated/app_localizations.dart';

/// BuildContext 上访问 [AppLocalizations] 的便捷扩展。
/// 用法：`context.l.common_save`。spec §4.5。
extension L10nContext on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this);
}

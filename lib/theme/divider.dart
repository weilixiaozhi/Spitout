import 'package:flutter/material.dart';

import 'colors.dart';

/// 分割线组件令牌
class SpitoutDivider {
  static Divider thin(BuildContext context, {EdgeInsetsGeometry? padding}) =>
      Divider(
        height: 1,
        thickness: 1,
        color: SpitoutTokens.divider(context),
      );

  static Divider short(BuildContext context,
          {double indent = 0, double endIndent = 0}) =>
      Divider(
        height: 1,
        thickness: 1,
        indent: indent,
        endIndent: endIndent,
        color: SpitoutTokens.divider(context),
      );
}

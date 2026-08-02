import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 应用品牌图标组件
///
/// 设计意图：品牌图以矢量 SVG（ic_launcher_spitout.svg）提供，可无损缩放、
/// 多色配色硬编码在图内，不随主题色变化，因此本组件不接受 color 参数。
/// 使用 [SvgPicture.asset] 渲染矢量源，相较 PNG 在任意 size 下均清晰、且
/// 源文件可直接编辑。注意：本 SVG 实际为「非矢量」（内嵌 base64 位图），
/// 但若后续替换为真正矢量源，此渲染方式同样适用。
/// 若需换回 PNG：把本文件 build 改回 Image.asset 并引用 .png 即可。
class SpitoutIcon extends StatelessWidget {
  final double size;

  const SpitoutIcon({super.key, this.size = 256});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/ic_launcher_spitout.svg',
      width: size,
      height: size,
    );
  }
}

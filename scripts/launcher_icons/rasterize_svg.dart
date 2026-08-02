// 将品牌源文件 ic_launcher_spitout.svg 栅格化为 flutter_launcher_icons 所需的 PNG。
//
// 设计意图：
//   flutter_launcher_icons 内部使用 image 包解码源图，仅支持位图（png/jpg），
//   无法读取 svg。因此这里借助项目已依赖的 flutter_svg 把矢量源图渲染成
//   高分辨率 PNG，作为 flutter_launcher_icons 的输入。svg 始终是唯一的设计源，
//   png 为可再生的中间产物。
//
// 用法（在项目根目录执行）：
//   flutter test scripts/launcher_icons/rasterize_svg.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

// 源 SVG（纯矢量、正方形 viewBox，多色图形 + 透明背景；图形已居中并预留安全留白）。
// 注意：脚本运行时按 SVG 真实尺寸等比缩放铺满输出画布，因此不依赖固定视图大小。
const String _svgPath = 'assets/brand/ic_launcher_spitout.svg';

// 输出目录：flutter_launcher_icons 的 PNG 输入。
const String _outDir = 'assets/flutter_launcher_icons';

// 输出分辨率。自适应图标在不同密度下会被缩放，1024 足够清晰。
const int _size = 1024;

Future<void> main() async {
  // 必须在测试绑定下初始化，dart:ui 的 Canvas/Picture 才能正常工作。
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter test 需要一个 test 用例才会真正执行 main 中的逻辑。
  test('将 SVG 栅格化为 flutter_launcher_icons 所需的 PNG', () async {
    final svgString = await File(_svgPath).readAsString();
    // 用字符串加载器解析 SVG，得到可绘制的 Picture。
    // 注意：flutter_svg 2.x 不再导出顶层 loadPicture，需通过导出的 vg 命名空间调用。
    final pictureInfo = await vg.loadPicture(SvgStringLoader(svgString), null);
    final picture = pictureInfo.picture;
    // 读取 SVG 真实尺寸，避免硬编码视图大小（旧图标 192、新图标 1024）导致缩放错位。
    final svgSize = pictureInfo.size;

    try {
      // 透明背景：自适应前景层与单色层（monochrome）都用它。
      final transparent = await _raster(picture, svgSize, background: null);
      // 白色背景：legacy 整图标，保证在深色桌面上也可见。
      final white = await _raster(picture, svgSize, background: const ui.Color(0xFFFFFFFF));

      Directory(_outDir).createSync(recursive: true);
      File('$_outDir/adaptive_foreground.png').writeAsBytesSync(transparent);
      File('$_outDir/adaptive_monochrome.png').writeAsBytesSync(transparent);
      File('$_outDir/launcher_legacy.png').writeAsBytesSync(white);

      // ignore: avoid_print
      print('已生成图标 PNG -> $_outDir');
    } finally {
      // ui.Picture 持有原生资源，使用完毕需释放。
      picture.dispose();
    }
  });
}

/// 将矢量图等比（contain）缩放铺满 _size×_size 正方形画布并导出 PNG。
///
/// 设计意图：按 [svgSize] 真实尺寸计算缩放系数（取长边铺满、居中），
/// 这样无论源 SVG 是 192 还是 1024，甚至非正方形，都不会再因硬编码而错位或裁切。
Future<Uint8List> _raster(ui.Picture picture, ui.Size svgSize, {required ui.Color? background}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // 先铺底色；background 为 null 时保留透明。
  if (background != null) {
    canvas.drawColor(background, ui.BlendMode.src);
  }
  // 等比 contain：以长边铺满 _size，再居中，避免非正方形时内容偏移或被裁。
  final scale = _size / svgSize.longestSide;
  final dx = (_size - svgSize.width * scale) / 2;
  final dy = (_size - svgSize.height * scale) / 2;
  canvas.translate(dx, dy);
  canvas.scale(scale);
  canvas.drawPicture(picture);
  final rendered = recorder.endRecording();
  final image = await rendered.toImage(_size, _size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

import 'dart:ui';
import 'package:flutter/material.dart';

class CColor {
  static Color primary = fromHex('#7D2582');
  static Color primaryLight = fromHex('#FF2D96');
  static Color primaryELight = fromHex('#FFA3D1');
  static Color red = fromHex('#E30000');
  static Color secondary = fromHex('#3C8DBC');
  static Color secondary2 = fromHex('#368CCC');
  static Color secondary3 = fromHex('#F4A300');
  static Color homeBack = fromHex('#EDF1FD');
  static Color videoBtn = fromHex('#6A78C9');
  static Color background = fromHex('#13181C');
  static Color text1 = fromHex('#212121');
  static Color text2 = fromHex('#757575');
  static Color divider = fromHex('#BDBDBD');
  static LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    transform: const GradientRotation(135 * 3.14159 / 180),
    colors: [const Color(0xFF5F2C82), const Color(0xFF49A09D)],
  );
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

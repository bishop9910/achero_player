import 'package:flutter/foundation.dart';

/// 当前平台是否支持「目录选择器」（file_picker 的 getDirectoryPath）。
///
/// 目录选择器仅在桌面端（Windows / Linux / macOS）可用；移动端与 Web 端
/// 只能选择文件。目录**扫描**（dart:io 递归遍历）则由
/// `PlatformFileSystem.supportsDirectoryScan` 表示，二者能力不同。
bool get supportsDirectoryPicker =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

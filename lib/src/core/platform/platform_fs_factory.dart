import 'platform_filesystem.dart';
import 'platform_filesystem_io.dart'
    if (dart.library.js_interop) 'platform_filesystem_web.dart' as impl;

/// 依据目标平台创建对应的 [PlatformFileSystem] 实现。
///
/// 通过条件导入在编译期选择 `dart:io` 或 Web 实现，避免把
/// `dart:io` 链接进 Web 产物。
PlatformFileSystem createPlatformFileSystem() => impl.createPlatformFileSystem();

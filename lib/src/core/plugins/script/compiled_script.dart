import 'package:dart_eval/dart_eval.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';

/// 已编译的脚本插件句柄（纯 Dart，无 Flutter 依赖，可直接单测）。
///
/// 负责：用 [dart_eval] 编译脚本源码、执行其顶层函数，并在「脚本 ↔ 宿主」
/// 之间做值装箱 / 反装箱。脚本通过一个 [call] 闭包（`$Closure`）回调宿主。
class CompiledScript {
  CompiledScript._(this._runtime, this._entrypoint, this._call);

  final Runtime _runtime;
  final String _entrypoint;
  final $Closure _call;

  /// 编译一段脚本源码。
  ///
  /// [hostCall] 是宿主暴露给脚本的 `call(method, paramsJson) -> resultJson`
  /// 回调；[package] 决定脚本的内部包名（影响 `executeLib` 的 URI）。
  factory CompiledScript.compile(
    String source, {
    required $Closure hostCall,
    String package = 'plugin',
  }) {
    final program = Compiler().compile({
      package: {'main.dart': source},
    });
    final runtime = Runtime.ofProgram(program);
    return CompiledScript._(runtime, 'package:$package/main.dart', hostCall);
  }

  /// 调用脚本中的顶层函数 [function]，传入（`call` 之后的）位置参数。
  ///
  /// 返回反序列化后的 Dart 值：`$Value` → `$reified`，`List` → 逐元素递归。
  dynamic invoke(String function, [List<dynamic> args = const []]) {
    _runtime.args = [_call, ...args.map(_box)];
    final result = _runtime.executeLib(_entrypoint, function);
    return _reify(result);
  }

  static dynamic _box(dynamic value) => value is String ? $String(value) : value;

  static dynamic _reify(dynamic value) {
    if (value is $Value) return value.$reified;
    if (value is List) {
      return value.map(_reify).toList(growable: false);
    }
    return value;
  }
}

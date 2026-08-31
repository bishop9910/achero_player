import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用版本号
const String kAppVersion = '1.0.5';

/// 应用构建号
const int kAppBuild = 2;

/// 完整版本标识，形如 `1.0.4+0`，由 [kAppVersion] 与 [kAppBuild] 推导，
const String kAppVersionWithBuild = '$kAppVersion+$kAppBuild';

/// 当前版本发布日期
const String kAppReleaseDate = '2026/8/31';

/// 应用版本信息与更新日志的单一来源。
class AppInfo {
  AppInfo._();

  /// 应用名称。
  static const String name = 'Achero Player';

  /// 本次版本更新日志，按类别分组，顺序即展示顺序。
  static const List<ChangelogGroup> changelog = [
    ChangelogGroup('新增', Icons.new_releases_outlined, [
      '安卓端后台播放功能',
      'Windows SMTC 与 Linux MPRIS 系统级后台播放联动',
      '桌面端右键进入多选（曲库 / 分类标签 / 播放记录）',
      '播放记录增强：封面预览、直接播放、专辑 / 播放列表聚合统计',
      '新增「更新日志」弹窗（每个新版本自动展示一次，可在设置中查看）',
    ]),
    ChangelogGroup('优化', Icons.auto_awesome_outlined, [
      '修缮桌面歌词独立窗口',
      '修缮 RPC / Subsonic 音乐服务器',
    ]),
    ChangelogGroup('修复', Icons.bug_report_outlined, [
      '修复手机端歌词换行丢行、被省略号截断的问题',
      '修复切换窗口宽度时页面状态与连接数据丢失的问题',
    ]),
  ];

  static const String _changelogSeenKey = 'achero.changelog.seenVersion';

  /// 当前版本是否尚未自动展示过更新日志。
  ///
  /// 首次安装（无记录）或版本升级（记录值与当前版本不同）时返回 true。
  static bool shouldAutoShow(SharedPreferences prefs) =>
      prefs.getString(_changelogSeenKey) != kAppVersionWithBuild;

  /// 标记当前版本已展示过，此后打开不再自动弹出。
  static Future<void> markShown(SharedPreferences prefs) async {
    await prefs.setString(_changelogSeenKey, kAppVersionWithBuild);
  }
}

/// 一组更新日志：类别标题 + 图标 + 若干条目。
class ChangelogGroup {
  const ChangelogGroup(this.title, this.icon, this.items);

  final String title;
  final IconData icon;
  final List<String> items;
}

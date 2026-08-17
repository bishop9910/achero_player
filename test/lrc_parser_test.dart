import 'package:flutter_test/flutter_test.dart';

import 'package:achero_player/src/core/lyrics/lrc_parser.dart';

void main() {
  const parser = LrcParser();

  group('LrcParser', () {
    test('解析标准元数据标签', () {
      const raw = '[ti:标题]\n[ar:艺术家]\n[al:专辑]\n[offset:500]\n'
          '[00:01.00]第一行\n[00:02.50]第二行';
      final doc = parser.parse(raw);

      expect(doc.title, '标题');
      expect(doc.artist, '艺术家');
      expect(doc.album, '专辑');
      expect(doc.offset, const Duration(milliseconds: 500));
      expect(doc.lines.length, 2);
    });

    test('时间戳解析与 offset 校正', () {
      const raw = '[offset:500]\n[00:01.000]歌词';
      final doc = parser.parse(raw);
      expect(doc.lines.single.time, const Duration(milliseconds: 1500));
    });

    test('一行多时间戳展开为多行', () {
      const raw = '[00:01.00][00:03.00]重复段落';
      final doc = parser.parse(raw);
      expect(doc.lines.length, 2);
      expect(doc.lines[0].time, const Duration(seconds: 1));
      expect(doc.lines[1].time, const Duration(seconds: 3));
    });

    test('支持 mm:ss 与 mm:ss.xxx 格式', () {
      const raw = '[01:02]短格式\n[01:02.345]长格式';
      final doc = parser.parse(raw);
      expect(doc.lines[0].time, const Duration(minutes: 1, seconds: 2));
      expect(doc.lines[1].time,
          const Duration(minutes: 1, seconds: 2, milliseconds: 345));
    });

    test('增强型 LRC 逐字时间轴', () {
      const raw = '[00:01.00]<00:01.00>你 <00:01.50>好';
      final doc = parser.parse(raw);
      final line = doc.lines.single;
      expect(line.text, '你 好');
      expect(line.words.length, 2);
      expect(line.words[0].text, '你');
      expect(line.words[1].text, '好');
    });

    test('非法输入返回空文档而不抛异常', () {
      final doc = parser.parse('这不是歌词\n完全无格式');
      expect(doc.isEmpty, isTrue);
    });

    test('activeIndexAt 返回当前高亮行', () {
      const raw = '[00:00.00]A\n[00:05.00]B\n[00:10.00]C';
      final doc = parser.parse(raw);
      expect(doc.activeIndexAt(const Duration(seconds: 0)), 0);
      expect(doc.activeIndexAt(const Duration(seconds: 6)), 1);
      expect(doc.activeIndexAt(const Duration(seconds: 4)), 0);
      expect(doc.activeIndexAt(const Duration(seconds: 99)), 2);
    });
  });
}

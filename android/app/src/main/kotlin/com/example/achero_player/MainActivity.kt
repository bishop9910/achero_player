package com.example.achero_player

import com.ryanheise.audioservice.AudioServiceActivity

/**
 * 继承 audio_service 的 [AudioServiceActivity]，让前台服务与主 Activity
 * 共享同一个 FlutterEngine，从而支持后台播放与通知栏控制。
 */
class MainActivity : AudioServiceActivity()

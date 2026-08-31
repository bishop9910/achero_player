---
icon: lucide/package
---

# 打包与发布

各平台 release 打包命令与注意事项。打包前先确认 `pubspec.yaml` 里的
`version` 与 `description` 已更新。

!!! info "通用前提"

    先 `flutter pub get`。本项目用 media_kit（libmpv/ffmpeg），
    运行时依赖会自动打进产物，无需手动安装。

---

## 1. Windows

```powershell
flutter build windows --release
```

**产物**：`build\windows\x64\runner\Release\` —— **整个文件夹**即为可分发内容
（`achero_player.exe` + DLL + `data\` 目录），打包成 zip 即可分发。

- **图标**：`windows\runner\resources\app_icon.ico`（同名替换）。
- **libmpv 下载**：构建时联网下载（已改成 GitHub 镜像多源下载），缓存在
  `build\windows\x64\` 复用；换机/清缓存需重下。
- **CMake 4 / VS 2026 补丁**：`third_party\media_kit_libs_windows_audio` +
  `pubspec.yaml` 里的 `dependency_overrides` 仍是必需的，待 media_kit 上游
  适配后再删。
- **Rust 工具链（smtc_windows）**：SMTC 系统媒体条由 Rust 插件 `smtc_windows`
  提供，构建前需安装 rustup（含 cargo/rustc），且 `third_party\smtc_windows`
  本地补丁仍是必需的。缺 Rust 会报 `MSB8066`（smtc_windows 自定义生成退出码 -1）。
- 上微软商店需额外打包为 MSIX（可选）。

---

## 2. Linux

```bash
flutter build linux --release
```

**产物**：`build/linux/x64/release/bundle/`。

- media_kit 自带 libmpv（`media_kit_libs_linux`），通常无需额外安装；
  个别精简发行版缺 `libasound` / `libpulse` 等系统库时需补装。
- 若要 `.deb` / AppImage / Flatpak，需用对应工具再包一层。

---

## 3. Android

```bash
flutter build apk --release        # 直接安装/分发
flutter build appbundle --release  # 上架 Google Play
```

**产物**：

- APK：`build\app\outputs\flutter-apk\app-release.apk`
- AAB：`build\app\outputs\bundle\release\app-release.aab`

!!! danger "发布前必须"

    1. 改包名：`android\app\build.gradle.kts` 里的 `applicationId` 与 `namespace`
       （当前为 `com.example.achero_player`）。
    2. 签名：`keytool` 生成 keystore，配到 `android\key.properties`（或 Play App Signing）；
       未签名的 release 包无法安装。

图标：`android\app\src\main\res\mipmap-*\ic_launcher.png`。

---

## 4. Web

```bash
flutter build web --release
```

**产物**：`build\web\`（纯静态文件）。

- 部署到任意静态托管（GitHub Pages / Netlify / Vercel / Nginx…）。
- Web 端 media_kit 走浏览器 HTML5 音频，**格式支持取决于浏览器**
  （Chrome/Edge/Firefox 支持 OGG/Opus，Safari 较弱），不用 ffmpeg。

---

## 发布前检查清单

- [ ] `pubspec.yaml`：版本号 + `description`
- [ ] 各平台图标（Windows `.ico` / Android mipmap / Web favicon）
- [ ] 作者头像 `assets\images\bishop9910.jpg`
- [ ] Android 改包名 + 签名
- [ ] 每平台跑一次 `flutter build <平台> --release` 验证可编过

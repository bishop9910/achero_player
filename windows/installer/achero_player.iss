#define MyAppName "Achero Player"
#define MyAppVersion "1.0.3+9"
#define MyAppPublisher "bishop9910"
#define MyAppExeName "achero_player.exe"

; 如果你把脚本放在 windows/installer/ 目录下
; 那么 Release 目录相对路径是 ../../build/windows/x64/runner/Release
#define MyAppBuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{B7E9C2D4-5A6F-4B3E-9C1D-0F8E7A6B5C4D}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

OutputDir=Output
OutputBaseFilename=AcheroPlayer-Setup-{#MyAppVersion}

; 如果你没有 ico 图标文件，可以先注释掉这一行
SetupIconFile=..\runner\resources\app_icon.ico

Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

PrivilegesRequired=admin

UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

; 如果你安装了简体中文语言文件，可以取消下面注释
; Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#MyAppBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
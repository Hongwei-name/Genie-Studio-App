; ============================================
; 智元标注审核助手 - Inno Setup 7 安装脚本
; ============================================

[Setup]
AppName=智元标注审核助手
AppVersion=1.0.0
AppPublisher=zero_K
DefaultDirName={autopf}\GenieStudio
DefaultGroupName=智元标注审核助手
OutputBaseFilename=GenieStudio_Setup_v1.0.0
OutputDir=..\dist
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\zero_k_genie.exe
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\智元标注审核助手"; Filename: "{app}\zero_k_genie.exe"
Name: "{group}\卸载 智元标注审核助手"; Filename: "{uninstallexe}"
Name: "{autodesktop}\智元标注审核助手"; Filename: "{app}\zero_k_genie.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\zero_k_genie.exe"; Description: "启动 智元标注审核助手"; Flags: nowait postinstall skipifsilent

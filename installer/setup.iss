; ============================================
; zero_K-Genie - Inno Setup 7 安装脚本
; ============================================

[Setup]
AppName=zero_K-Genie
AppVersion=3.0.7
AppPublisher=zero_K
DefaultDirName={localappdata}\Programs\GenieStudio
UsePreviousAppDir=yes
DisableDirPage=no
DefaultGroupName=zero_K-Genie
OutputBaseFilename=GenieStudio_Setup_v3.0.7
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
Source: "..\userscripts\zero-K-Genie.user.js"; DestDir: "{app}\userscripts"; Flags: ignoreversion

[Icons]
Name: "{group}\zero_K-Genie"; Filename: "{app}\zero_k_genie.exe"
Name: "{group}\卸载 zero_K-Genie"; Filename: "{uninstallexe}"
Name: "{autodesktop}\zero_K-Genie"; Filename: "{app}\zero_k_genie.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\zero_k_genie.exe"; Description: "启动 zero_K-Genie"; Flags: nowait postinstall skipifsilent

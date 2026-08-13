; ============================================================
; 智元标注审核助手 - Inno Setup 安装程序脚本
; ============================================================
; 使用方法:
;   1. 安装 Inno Setup 6: https://jrsoftware.org/isinfo.php
;   2. 打开此文件
;   3. 点击 "运行" 或按 F9
; ============================================================

#define MyAppName "智元标注审核助手"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "GenieStudio"
#define MyAppURL "https://github.com/geniestudio"
#define MyAppExeName "genie_review_assistant.exe"
#define MyAppAssocName MyAppName + " 文件"
#define MyAppAssocExt ".gns"
#define MyAppAssocKey StringChange(MyAppAssocName, " ", "") + MyAppAssocExt

[Setup]
; 注意: AppId 的值用于唯一标识此应用程序
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
; "ArchitecturesAllowed=x64compatible" 指定安装程序无法在
; 除了 x64 和 Windows 11 on Arm 以外的任何平台上运行
ArchitecturesAllowed=x64compatible
; "ArchitecturesInstallIn64BitMode=x64compatible" 要求安装程序在
; x64 或 Windows 11 on Arm 上以 64 位模式安装
ArchitecturesInstallIn64BitMode=x64compatible
ChangesAssociations=yes
DefaultGroupName={#MyAppName}
LicenseFile=D:\project\Genie-Studio-App\LICENSE.txt
; 如果您希望安装程序在安装前显示 "准备安装" 对话框，请删除以下行
;PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=D:\project\Genie-Studio-App\installer_output
OutputBaseFilename=genie_review_assistant_setup_{#MyAppVersion}
SetupIconFile=D:\project\Genie-Studio-App\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; 安装程序外观
WizardSizePercent=120
WizardImageFile=D:\project\Genie-Studio-App\installer_assets\wizard_image.bmp
WizardSmallImageFile=D:\project\Genie-Studio-App\installer_assets\wizard_small.bmp
; 安装信息
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} 安装程序
VersionInfoCopyright=Copyright (C) 2024 {#MyAppPublisher}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1

[Files]
; 主程序文件
Source: "D:\project\Genie-Studio-App\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; Flutter 运行时
Source: "D:\project\Genie-Studio-App\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
; 数据目录
Source: "D:\project\Genie-Studio-App\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; WebView2 加载器
Source: "D:\project\Genie-Studio-App\build\windows\x64\runner\Release\WebView2Loader.dll"; DestDir: "{app}"; Flags: ignoreversion
; WebView 插件
Source: "D:\project\Genie-Studio-App\build\windows\x64\runner\Release\webview_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
; 窗口管理插件
Source: "D:\project\Genie-Studio-App\build\windows\x64\runner\Release\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
; 屏幕获取插件
Source: "D:\project\Genie-Studio-App\build\windows\x64\runner\Release\screen_retriever_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
; URL 启动器插件
Source: "D:\project\Genie-Studio-App\build\windows\x64\runner\Release\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
; 许可证文件
Source: "D:\project\Genie-Studio-App\LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion isreadme
; 注意: 不要在任何共享系统文件上使用 "Flags: ignoreversion"

[Registry]
; 文件关联
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocExt}\OpenWithProgids"; ValueType: string; ValueName: "{#MyAppAssocKey}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}"; ValueType: string; ValueName: ""; ValueData: "{#MyAppAssocName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
; 开机自启动（可选）
;Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
; 安装完成后运行
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
; 安装 WebView2 Runtime（如果需要）
;Filename: "https://go.microsoft.com/fwlink/p/?LinkId=2124703"; Description: "安装 WebView2 Runtime"; Flags: shellexec runasoriginaluser postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"

[Code]
// 检查 WebView2 是否已安装
function IsWebView2Installed(): Boolean;
var
  Version: String;
begin
  Result := RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDB-5057A2B865AC}', 'pv', Version);
  if not Result then
    Result := RegQueryStringValue(HKCU, 'Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDB-5057A2B865AC}', 'pv', Version);
end;

// 安装前检查
function InitializeSetup(): Boolean;
begin
  Result := True;
  
  // 检查 WebView2
  if not IsWebView2Installed() then
  begin
    if MsgBox('此应用程序需要 WebView2 Runtime 才能运行。' + #13#10 + 
              '是否现在下载并安装？', 
              mbConfirmation, MB_YESNO) = IDYES then
    begin
      ShellExec('open', 'https://go.microsoft.com/fwlink/p/?LinkId=2124703', '', '', SW_SHOWNORMAL, ewNoWait, Result);
    end;
  end;
end;

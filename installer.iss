#define AppName "Guinée École"
#define AppVersion "1.0.0"
#define AppPublisher "Momo"
#define AppURL "https://github.com/Momo147-labe"
#define AppExeName "guinerschools.exe"
#define AppId "D1A2B3C4-E5F6-4A7B-8C9D-0E1F2A3B4C5D"

[Setup]
ChangesAssociations=yes
AppId={{{#AppId}}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
AppUpdatesURL={#AppURL}/releases
AppCopyright=Copyright © 2026 {#AppPublisher}
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}

DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=Output
OutputBaseFilename=Setup-{#AppName}-{#AppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

DisableProgramGroupPage=yes
DisableReadyPage=no
DisableFinishedPage=no
DisableWelcomePage=no
ShowLanguageDialog=no
UsePreviousAppDir=yes
UsePreviousGroup=yes
UpdateUninstallLogAppName=yes
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le bureau"; GroupDescription: "Raccourcis:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "C:\Windows\System32\vcruntime140.dll"; DestDir: "{app}"; Flags: external skipifsourcedoesntexist
Source: "C:\Windows\System32\msvcp140.dll"; DestDir: "{app}"; Flags: external skipifsourcedoesntexist
Source: "C:\Windows\System32\vcruntime140_1.dll"; DestDir: "{app}"; Flags: external skipifsourcedoesntexist

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{group}\Désinstaller {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
; ✅ RÈGLES FIREWALL (autoriser réseau)
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""{#AppName} - Sortant"" dir=out action=allow program=""{app}\{#AppExeName}"" enable=yes"; Flags: runhidden; StatusMsg: "Configuration du pare-feu..."
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""{#AppName} - Entrant"" dir=in action=allow program=""{app}\{#AppExeName}"" enable=yes"; Flags: runhidden

; ✅ LANCEMENT POST-INSTALLATION
Filename: "{app}\{#AppExeName}"; Description: "Lancer {#AppName}"; Flags: nowait postinstall skipifsilent; WorkingDir: "{app}"

[UninstallRun]
; ✅ NETTOYAGE RÈGLES FIREWALL
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""{#AppName} - Sortant"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""{#AppName} - Entrant"""; Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\{#AppPublisher}\{#AppName}"
Type: filesandordirs; Name: "{localappdata}\{#AppPublisher}\{#AppName}"

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
  if GetWindowsVersion < $0A000000 then begin
    MsgBox('Cette application nécessite Windows 10 ou supérieur.', mbError, MB_OK);
    Result := False;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then begin
    CreateDir(ExpandConstant('{localappdata}\{#AppPublisher}'));
    CreateDir(ExpandConstant('{localappdata}\{#AppPublisher}\{#AppName}'));
  end;
end;

#ifndef ProjectRoot
  #define ProjectRoot "..\.."
#endif
#define AppVersion "1.2.0"
[Setup]
AppId={{B433F317-40E6-4B34-8ABA-2080160E4636}
AppName=StockGo
AppVersion={#AppVersion}
AppPublisher=StockGo
DefaultDirName={localappdata}\Programs\StockGo
DefaultGroupName=StockGo
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#ProjectRoot}\dist
OutputBaseFilename=StockGo-Instalador-Windows
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\StockGo.exe
CloseApplications=yes
DisableProgramGroupPage=yes
[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; Flags: checkedonce
[Files]
Source: "{#ProjectRoot}\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.db,*.db-shm,*.db-wal,.dart_tool\*"
[Icons]
Name: "{group}\StockGo"; Filename: "{app}\StockGo.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\StockGo"; Filename: "{app}\StockGo.exe"; WorkingDir: "{app}"; Tasks: desktopicon
[Run]
Filename: "{app}\StockGo.exe"; Description: "Abrir StockGo"; Flags: nowait postinstall skipifsilent

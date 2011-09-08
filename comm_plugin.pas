unit comm_plugin;

interface

uses Windows,
      comm_info,
      comm_data,
      MyIniFiles, WinInet,
      SysUtils, Classes, Math, ShellAPI,
      mafia, mafia_data,
      libfunc;
  
type
  TCommPlugin = class(ICommPlugin)
  private
  
  public
    constructor Create(dwThisPluginID : DWORD; func1 : TtypeCommFortProcess; func2: TtypeCommFortGetData);
    destructor Destroy; override;
    procedure Error(Sender: TObject; e: Exception; Extratext: String='');
    procedure PublicMessage(Sender: TObject; Name: string; User : TUser; channel: string; regime : integer; bMessage : string);
    procedure BotJoin(Sender: TObject; Name: string; channel : string; theme : string; greeting: string);
    procedure PrivateMessage(Sender: TObject; Name: string; User : TUser; regime : integer; bMessage : string);
    procedure PersonalMessage(Sender: TObject; Name: string; User : TUser; bMessage : string);
    procedure UserJoinChannel(Sender: TObject; Name: string; User : TUser; Channel : string);
    procedure ConStateChange(Sender: TObject; newstate: DWord);
  end;

var
  ThisPlugin: TCommPlugin;
  Loaded: Boolean;
  
implementation

constructor TCommPlugin.Create(dwThisPluginID : DWORD; func1 : TtypeCommFortProcess; func2: TtypeCommFortGetData);
var
  Ini: TIniFile;
  StrList: TStringList;
begin
  inherited;
  config_dir:=CorePlugin.AskPluginTempPath+'Mafia';
  if not DirectoryExists(config_dir) then
    CreateDir(config_dir);

  StrList:=TStringList.Create;
  StrList.Add(';Файл автоматически создан '+DateTimeToStr(Now));

  // Сначала пытаемся загрузить файлы из директории с временными файлами плагинов
  file_config:=config_dir+'\config.ini';
  if not FileExists(file_config) then
    file_config:=ExtractFilePath(ParamStr(0))+'Plugins\Mafia\config.ini';

  file_messages:=config_dir+'\messages.ini';
  if not FileExists(file_messages) then
    file_messages:=ExtractFilePath(ParamStr(0))+'Plugins\Mafia\messages.ini';

  file_gametypes:=config_dir+'\gametypes.ini';
  if not FileExists(file_gametypes) then
    file_gametypes:=ExtractFilePath(ParamStr(0))+'Plugins\Mafia\gametypes.ini';

  file_template:=config_dir+'\stattemplate.html';
  if not FileExists(file_template) then
    file_template:=ExtractFilePath(ParamStr(0))+'Plugins\Mafia\stattemplate.html';

  file_template_greeting:=config_dir+'\greetingtemplate.txt';
  if not FileExists(file_template_greeting) then
    file_template_greeting:=ExtractFilePath(ParamStr(0))+'Plugins\Mafia\greetingtemplate.txt';

  file_users:=config_dir+'\users.ini';
  if not FileExists(file_users) then
    StrList.SaveToFile(file_users, TEncoding.Unicode);

  file_data:=config_dir+'\data.ini';
  if not FileExists(file_data) then
    StrList.SaveToFile(file_data, TEncoding.Unicode);

  file_log:=config_dir+'\error.log';
  if not FileExists(file_log) then
    StrList.SaveToFile(file_log, TEncoding.Unicode);

  PCorePlugin:= @CorePlugin;

  // Указываем метод, который будет вызываться при ошибке
  CorePlugin.onError                      := Error;

  // Указываем метод, который будет вызываться при сообщении в канале
  CorePlugin.onPublicMessage              := PublicMessage;

  // Указываем метод, который будет вызываться при подключении бота
  CorePlugin.onBotJoin                    := BotJoin;

  // Указываем метод, который будет вызываться при получении приватного сообщения
  CorePlugin.onPrivateMessage             := PrivateMessage;

  // Указываем метод, который будет вызываться при получении персонального сообщения
  CorePlugin.onPersonalMessage            := PersonalMessage;


  // Указываем метод, который будет вызываться при подключении пользователя к каналу
  CorePlugin.onUserJoinChannel            := UserJoinChannel;

  CorePlugin.onConStChg                   := ConStateChange;

  // Создаем виртуального пользователя
  PROG_TYPE:=CorePlugin.AskProgramType();
  Loaded:=False;
  if not FileExists(file_config) or not FileExists(file_gametypes) or not FileExists(file_messages) then
  begin
    MessageBox(0, 'Отсутствуют один или несколько файлов, необходимых для работы плагина.', 'Ошибка при запуске плагина "Мафия"', MB_ICONEXCLAMATION);
    CorePlugin.StopPlugin;
  end
  else
    case PROG_TYPE of
    0: //Сервер
      begin
        Ini := TIniFile.Create(file_config);
        BOT_NAME:= Ini.ReadString('Mafia', 'BotName', 'Mafiozi');
        BOT_PASS:= Ini.ReadString('Mafia', 'BotPass', 'mafiarulez');
        BOT_IP := Ini.ReadString('Mafia', 'BotIP', 'N/A');
        if Ini.ReadString('Mafia', 'BotIsFemale', '1')='1' then
          BOT_ISFEMALE:=1
        else
          BOT_ISFEMALE:=0;
        Ini.Free;
        if (BOT_PASS='mafiarulez') then
        begin
          MessageBox(0, 'Смените пароль учётной записи плагина в настройках! (Кнопка "Настроить" в меню плагинов или параметр BotPass в файле "\Plugins\Mafia\config.ini")', 'Ошибка при запуске плагина "Мафия"', MB_ICONEXCLAMATION);
          CorePlugin.StopPlugin;
        end
        else
          CorePlugin.JoinVirtualUser(BOT_NAME, BOT_IP, 0, BOT_PASS, BOT_ISFEMALE);
      end;
    1: //Клиент
      ConStateChange(CorePlugin, CorePlugin.ClientAskConState());
    end;
end;

destructor TCommPlugin.Destroy;
begin
  //данная функция вызывается при завершении работы программы
  if Loaded then
    Mafia.Destroy();
  inherited;
end;

// Метод, вызываемый при ошибке
procedure TCommPlugin.Error(Sender: TObject; e: Exception; Extratext: String='');
var
  Msg, Stack: String;
  Inner: Exception;
begin
  Inner := E;
  Msg := '';
  while Inner <> nil do
  begin
    if Msg <> '' then
      Msg := Msg + sLineBreak;
    Msg := Msg + Inner.Message;
    if (Msg <> '') and (Msg[Length(Msg)] > '.') then
      Msg := Msg + '.';

    Stack := Inner.StackTrace;
    if Stack <> '' then
    begin
      if Msg <> '' then
        Msg := Msg + sLineBreak + sLineBreak;
      Msg := Msg + Stack + sLineBreak;
    end;

    Inner := Inner.InnerException;
  end;
  CorePlugin.WriteLog(file_log, Msg + Extratext + sLineBreak);
end;

// Метод, вызываемый при сообщении в канал
{
  Name - имя виртуального пользователя
  User - пользователь(Name, IP, sex)
  channel - канал
  regime - режим сообщения[0-обычно, 1-как состояние]
  bMessage - текст сообщения
}
procedure TCommPlugin.PublicMessage(Sender: TObject; Name: String; User : TUser; channel: string; regime : integer; bMessage : string);
var
  Str:String;
begin
  if User.Name=BOT_NAME then exit;
  try
    Str:='----onMsg Exception----'+Chr(13)+Chr(10)+'State='+IntToStr(State);
    Mafia.OnMsg(User, Channel, bMessage);
  except
    on e: exception do
    begin
      Str:=Str+'/'+IntToStr(State)+Mafia.MafiaDump()+Chr(13)+Chr(10);
      CorePlugin.onError(CorePlugin, e, Str);
    end;
  end;
end;

// Метод, вызываемый при подключении виртуального пользователя к каналу
{
  Name - имя виртуального пользователя
  channel - канал
  theme - тема канала
  greeting - приветствие канала
}
procedure TCommPlugin.BotJoin(Sender: TObject; Name: String; channel : string; theme : string; greeting: string);
begin
  if not Loaded then begin
    Loaded:=True;
    Mafia.Init();
  end;
end;

// Метод, вызываемый при получении приватного сообщения
{
  Name - имя виртуального пользователя, который присутствует в данном канале
  User - пользователь(Name, IP, sex)
  regime - режим сообщения[0-обычно, 1-как состояние]
  bMessage - текст сообщения
}
procedure TCommPlugin.PrivateMessage(Sender: TObject; Name: String; User : TUser; regime : integer; bMessage : string);
var
  Str: String;
begin
  try
    Str:='----onPrivate Exception----'+Chr(13)+Chr(10)+'State='+IntToStr(State);
    Mafia.onPrivate(User, bMessage);
  except
    on e: exception do
    begin
      Str:=Str+'/'+IntToStr(State)+Mafia.MafiaDump()+Chr(13)+Chr(10);
      CorePlugin.onError(CorePlugin, e, Str);
    end;
  end;
end;

procedure TCommPlugin.PersonalMessage(Sender: TObject; Name: string; User : TUser; bMessage : string);
var
  Str: String;
begin
  try
    Str:='----onPrivate Exception----'+Chr(13)+Chr(10)+'State='+IntToStr(State);
    Mafia.onPrivate(User, bMessage);
  except
    on e: exception do
    begin
      Str:=Str+'/'+IntToStr(State)+Mafia.MafiaDump()+Chr(13)+Chr(10);
      CorePlugin.onError(CorePlugin, e, Str);
    end;
  end;
end;

procedure TCommPlugin.UserJoinChannel(Sender: TObject; Name: string; User : TUser; Channel : string);
begin
  Mafia.onUserJoinChannel(User, Channel);
end;

procedure TCommPlugin.ConStateChange(Sender: TObject; newstate: DWord);
var
  User: TUser;
begin
  if (newstate=2) then
  begin
    User:=CorePlugin.ClientAskCurrentUser();
    BOT_NAME:=User.Name;
    if not Loaded then begin
      Mafia.Init();
      Loaded:=True;
    end;
  end;
end;

end.

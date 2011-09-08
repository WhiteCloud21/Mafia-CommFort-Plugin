unit settings;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Tabs, StdCtrls,  ShellAPI,
  comm_info, mafia, mafia_data, comm_data, MyIniFiles, ComCtrls, Spin;

type
  TfrmSettings = class(TForm)
    btnApply: TButton;
    PageCtrl: TPageControl;
    TabSheetMain: TTabSheet;
    TabSheetTime: TTabSheet;
    TabSheetPoints: TTabSheet;
    TabSheetStatistic: TTabSheet;
    TabSheetGametype: TTabSheet;
    ScrollBoxGametype: TScrollBox;
    ScrollBoxStatistic: TScrollBox;
    ScrollBoxPoints: TScrollBox;
    ScrollBoxTime: TScrollBox;
    ScrollBoxMain: TScrollBox;
    TabSheetGamettypeRoles: TTabSheet;
    ScrollBoxGametypeRoles: TScrollBox;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure NumEditChange (Sender : TObject);
    procedure FloatEditChange (Sender : TObject);
    procedure btnApplyClick(Sender: TObject);
    procedure FormHide(Sender: TObject);
  private
    procedure AddParameterEdit(TabIndex: Integer; ParCaption: String; Ini: TIniFile; Section, Ident, Default: String; InputType:Byte=0; TopInterval:Integer=1);
    procedure AddParameterNumEdit(TabIndex: Integer; ParCaption: String; Ini: TIniFile; Section, Ident: String; Default:Integer=0; Min: Integer=0; Max: Integer=32000; Increment:Word=1; TopInterval:Integer=1);
    procedure AddParameterCombo(TabIndex: Integer; ParCaption: String; Ini: TIniFile; Section, Ident: String; Default: Word; ItemList: TStringList; TopInterval:Integer=1);
    procedure AddParameterYesNo(TabIndex: Integer; ParCaption: String; Ini: TIniFile; Section, Ident: String; Default: Word; TopInterval:Integer=1);
  public
    { Public declarations }
  end;

  TLabelList = array of TLabel;
  TEditList = array of TComponent;

var
  frmSettings: TfrmSettings;
  lblList: array of TLabelList;
  edtList: array of TEditList;
  updownList: array of TUpDown;
  updownListCount: Byte;
  prntList: Array of TWinControl;
  RoleText2: TRoleText;

implementation

{$R *.dfm}

procedure TfrmSettings.AddParameterEdit(TabIndex: Integer; ParCaption: String; Ini: TIniFile; Section, Ident, Default: String; InputType:Byte=0; TopInterval:Integer=1);
{
  InputType:
    1 - только числа
}
var
  I, Top: Integer;
begin
  I:=prntList[TabIndex].Tag;
  if I=0 then
    Top:=10
  else
    if (lblList[TabIndex][I-1].Height<20) then
      Top:=lblList[TabIndex][I-1].Top+22+TopInterval
    else
      Top:=lblList[TabIndex][I-1].Top+lblList[TabIndex][I-1].Height+TopInterval;
  lblList[TabIndex][I]:=TLabel.Create(Self);
  lblList[TabIndex][I].Anchors := [akLeft, akTop, akBottom];
  lblList[TabIndex][I].WordWrap:=True;
  lblList[TabIndex][I].AutoSize:=True;
  lblList[TabIndex][I].Caption:=ParCaption;
  lblList[TabIndex][I].Top:=Top;
  lblList[TabIndex][I].Left:=5;
  lblList[TabIndex][I].Width:=250;
  lblList[TabIndex][I].Height:=20;
  lblList[TabIndex][I].Parent:=prntList[TabIndex];

  edtList[TabIndex][I]:=TEdit.Create(Self);
  if InputType>0 then
     TEdit(edtList[TabIndex][I]).Tag:=StrToIntDef(Ini.ReadString(Section, Ident, Default), 0);
  TEdit(edtList[TabIndex][I]).Text:=Ini.ReadString(Section, Ident, Default);
  TEdit(edtList[TabIndex][I]).Top:=Top;
  TEdit(edtList[TabIndex][I]).Left:=305;
  TEdit(edtList[TabIndex][I]).Width:=200;
  TEdit(edtList[TabIndex][I]).Height:=20;
  TEdit(edtList[TabIndex][I]).ShowHint:=True;
  TEdit(edtList[TabIndex][I]).Hint:=ParCaption;
  TEdit(edtList[TabIndex][I]).Parent:=prntList[TabIndex];
  if InputType=1 then
    TEdit(edtList[TabIndex][I]).NumbersOnly:=True
  else
    if InputType=2 then
        TEdit(edtList[TabIndex][I]).OnExit:=NumEditChange;
  if InputType=3 then
     TEdit(edtList[TabIndex][I]).OnExit:=FloatEditChange;
  Inc(I);
  prntList[TabIndex].Tag:=I;
end;


procedure TfrmSettings.AddParameterNumEdit(TabIndex: Integer; ParCaption: String; Ini: TIniFile; Section, Ident: String; Default:Integer=0; Min: Integer=0; Max: Integer=32000; Increment:Word=1; TopInterval:Integer=1);
var
  I, Top: Integer;
begin
  I:=prntList[TabIndex].Tag;
  if I=0 then
    Top:=10
  else
    if (lblList[TabIndex][I-1].Height<20) then
      Top:=lblList[TabIndex][I-1].Top+22+TopInterval
    else
      Top:=lblList[TabIndex][I-1].Top+lblList[TabIndex][I-1].Height+TopInterval;
  lblList[TabIndex][I]:=TLabel.Create(Self);
  lblList[TabIndex][I].Anchors := [akLeft, akTop, akBottom];
  lblList[TabIndex][I].WordWrap:=True;
  lblList[TabIndex][I].AutoSize:=True;
  lblList[TabIndex][I].Caption:=ParCaption;
  lblList[TabIndex][I].Top:=Top;
  lblList[TabIndex][I].Left:=5;
  lblList[TabIndex][I].Width:=250;
  lblList[TabIndex][I].Height:=20;
  lblList[TabIndex][I].Parent:=prntList[TabIndex];

  edtList[TabIndex][I]:=TSpinEdit.Create(Self);
  TSpinEdit(edtList[TabIndex][I]).Increment:=Increment;
  TSpinEdit(edtList[TabIndex][I]).MinValue:=Min;
  TSpinEdit(edtList[TabIndex][I]).MaxValue:=Max;
  TSpinEdit(edtList[TabIndex][I]).Value:=Ini.ReadInteger(Section, Ident, Default);
  TSpinEdit(edtList[TabIndex][I]).Tag:=Ini.ReadInteger(Section, Ident, Default);
  TSpinEdit(edtList[TabIndex][I]).Top:=Top;
  TSpinEdit(edtList[TabIndex][I]).Left:=305;
  TSpinEdit(edtList[TabIndex][I]).Width:=200;
  TSpinEdit(edtList[TabIndex][I]).Height:=20;
  TSpinEdit(edtList[TabIndex][I]).ShowHint:=True;
  TSpinEdit(edtList[TabIndex][I]).Hint:=ParCaption;
  TSpinEdit(edtList[TabIndex][I]).Parent:=prntList[TabIndex];
  TSpinEdit(edtList[TabIndex][I]).OnExit:=NumEditChange;
  Inc(I);
  prntList[TabIndex].Tag:=I;
end;

procedure TfrmSettings.AddParameterCombo(TabIndex: Integer; ParCaption: String; Ini: TIniFile; Section, Ident: String; Default: Word; ItemList: TStringList; TopInterval:Integer=1);
var
  I, Top, Value: Integer;
begin
  I:=prntList[TabIndex].Tag;
  if I=0 then
    Top:=10
  else
    if (lblList[TabIndex][I-1].Height<20) then
      Top:=lblList[TabIndex][I-1].Top+22+TopInterval
    else
      Top:=lblList[TabIndex][I-1].Top+lblList[TabIndex][I-1].Height+TopInterval;
  lblList[TabIndex][I]:=TLabel.Create(Self);
  lblList[TabIndex][I].WordWrap:=True;
  lblList[TabIndex][I].AutoSize:=True;
  lblList[TabIndex][I].Caption:=ParCaption;
  lblList[TabIndex][I].Top:=Top;
  lblList[TabIndex][I].Left:=5;
  lblList[TabIndex][I].Width:=250;
  lblList[TabIndex][I].Height:=20;
  lblList[TabIndex][I].Parent:=prntList[TabIndex];

  edtList[TabIndex][I]:=TComboBox.Create(Self);
  TComboBox(edtList[TabIndex][I]).Parent:=prntList[TabIndex];
  TComboBox(edtList[TabIndex][I]).Style:=csDropDownList;
  TComboBox(edtList[TabIndex][I]).Items:=ItemList;
  Value:=Ini.ReadInteger(Section, Ident, Default);
  if (Value < TComboBox(edtList[TabIndex][I]).Items.Count) and (Value>=0)  then
    TComboBox(edtList[TabIndex][I]).ItemIndex:=Value
  else
    TComboBox(edtList[TabIndex][I]).ItemIndex:=TComboBox(edtList[TabIndex][I]).Items.Count-1;
  TComboBox(edtList[TabIndex][I]).Top:=Top;
  TComboBox(edtList[TabIndex][I]).Left:=305;
  TComboBox(edtList[TabIndex][I]).Width:=200;
  TComboBox(edtList[TabIndex][I]).Height:=20;
  TComboBox(edtList[TabIndex][I]).ShowHint:=True;
  TComboBox(edtList[TabIndex][I]).Hint:=ParCaption;
  Inc(I);
  prntList[TabIndex].Tag:=I;
end;

procedure TfrmSettings.AddParameterYesNo(TabIndex: Integer; ParCaption: String; Ini: TIniFile; Section, Ident: String; Default: Word; TopInterval:Integer=1);
var
  Strings: TStringList;
begin
  Strings:=TStringList.Create();
  Strings.Add('Нет');
  Strings.Add('Да');
  AddParameterCombo(TabIndex, ParCaption, Ini, Section, Ident, Default, Strings, TopInterval);
  Strings.Free;
end;

// Сохранение настроек
procedure TfrmSettings.btnApplyClick(Sender: TObject);
var
  Ini: TIniFile;
  I,K,J: Integer;
  SecName: String;
begin

  Ini:=TIniFile.Create(file_config);
  //---------------------------------------------------------------------------
  // Первая вкладка - основные настройки
  Ini.WriteString('Mafia', 'Channel', TEdit(edtList[0][0]).Text);
  Ini.WriteString('Mafia', 'ChannelHelp', TEdit(edtList[0][1]).Text);
  Ini.WriteString('Mafia', 'ChannelMain1', TEdit(edtList[0][2]).Text);
  Ini.WriteInteger('Mafia', 'ReloadSettingsOnStart', TComboBox(edtList[0][3]).ItemIndex);
  Ini.WriteInteger('Mafia', 'IPFilter', TComboBox(edtList[0][4]).ItemIndex);
  Ini.WriteInteger('Mafia', 'IDFilter', TComboBox(edtList[0][5]).ItemIndex);
  Ini.WriteString('Mafia', 'BotName', TEdit(edtList[0][6]).Text);
  Ini.WriteString('Mafia', 'BotPass', TEdit(edtList[0][7]).Text);
  Ini.WriteInteger('Mafia', 'BotIsFemale', TComboBox(edtList[0][8]).ItemIndex);
  Ini.WriteString('Mafia', 'BotIP', TEdit(edtList[0][9]).Text);
  Ini.WriteString('Mafia', 'BotState', TEdit(edtList[0][10]).Text);
  Ini.WriteInteger('Mafia', 'BanOnDeath', TComboBox(edtList[0][11]).ItemIndex);
  Ini.WriteInteger('Mafia', 'BanPrivateOnDeath', TComboBox(edtList[0][12]).ItemIndex);
  Ini.WriteString('Mafia', 'BanReason', TEdit(edtList[0][13]).Text);
  Ini.WriteString('Mafia', 'UnbanReason', TEdit(edtList[0][14]).Text);
  Ini.WriteInteger('Mafia', 'StatToPrivate', TComboBox(edtList[0][15]).ItemIndex);
  Ini.WriteInteger('Mafia',  'MaskPrice', TSpinEdit(edtList[0][16]).Value);
  Ini.WriteInteger('Mafia',  'RadioPrice', TSpinEdit(edtList[0][17]).Value);
  Ini.WriteInteger('Mafia',  'RadioNights', TSpinEdit(edtList[0][18]).Value);
  Ini.WriteInteger('Mafia', 'FastGame', TComboBox(edtList[0][19]).ItemIndex);
  Ini.WriteInteger('Mafia', 'StartFromNight', TComboBox(edtList[0][20]).ItemIndex);
  Ini.WriteInteger('Mafia', 'ShowNightActions', TComboBox(edtList[0][21]).ItemIndex);
  Ini.WriteInteger('Mafia', 'MessagesType', TComboBox(edtList[0][22]).ItemIndex);
  Ini.WriteInteger('Mafia', 'ChangeGametypeNotify', TComboBox(edtList[0][23]).ItemIndex);
  Ini.WriteInteger('Mafia',  'ChangeGametypeGamesCount', TSpinEdit(edtList[0][24]).Value);
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // Вторая вкладка - время
  Ini.WriteInteger('Mafia',  'TimeStart', TSpinEdit(edtList[1][0]).Value);
  Ini.WriteInteger('Mafia',  'TimeAccept', TSpinEdit(edtList[1][1]).Value);
  Ini.WriteInteger('Mafia',  'TimeNight', TSpinEdit(edtList[1][2]).Value);
  Ini.WriteInteger('Mafia',  'TimeMorning', TSpinEdit(edtList[1][3]).Value);
  Ini.WriteInteger('Mafia',  'TimeDay', TSpinEdit(edtList[1][4]).Value);
  Ini.WriteInteger('Mafia',  'TimeLastWord', TSpinEdit(edtList[1][5]).Value);
  Ini.WriteInteger('Mafia',  'TimeEvening', TSpinEdit(edtList[1][6]).Value);
  Ini.WriteInteger('Mafia',  'TimePause', TSpinEdit(edtList[1][7]).Value);
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // Третья вкладка - очки
  K:=0;
  for I:=1 to 255 do
    if I in [1..18, 151..158] then
    begin
      Ini.WriteInteger('MafiaPoints', IntToStr(I), TSpinEdit(edtList[2][K]).Value);
      Inc(K);
    end;
  //---------------------------------------------------------------------------


  //---------------------------------------------------------------------------
  // Четвертая вкладка - статистика
  Ini.WriteInteger('Stats', 'UpdateGreeting', TComboBox(edtList[3][0]).ItemIndex);
  Ini.WriteInteger('Stats', 'Export', TComboBox(edtList[3][1]).ItemIndex);
  Ini.WriteString('Stats',  'File', TEdit(edtList[3][2]).Text);
  //---------------------------------------------------------------------------
  SecName:=Ini.ReadString('Mafia', 'DefaultGametype', 'Gametype_0');
  Ini.Free;

  Ini:=TIniFile.Create(file_gametypes);
  //---------------------------------------------------------------------------
  // Пятая вкладка - тип игры
  Ini.WriteString(SecName, 'Name', TEdit(edtList[4][0]).Text);
  Ini.WriteString(SecName, 'Command', TEdit(edtList[4][1]).Text);
  Ini.WriteInteger(SecName, 'MinPlayers', TSpinEdit(edtList[4][2]).Value);
  Ini.WriteInteger(SecName, 'ShowNightComments', TComboBox(edtList[4][3]).ItemIndex);
  Ini.WriteInteger(SecName, 'ShowRolesOnStart', TComboBox(edtList[4][4]).ItemIndex);
  Ini.WriteInteger(SecName, 'UseShop', TComboBox(edtList[4][5]).ItemIndex);
  Ini.WriteInteger(SecName, 'UseYakuza', TComboBox(edtList[4][6]).ItemIndex);
  Ini.WriteInteger(SecName, 'UseNeutral', TComboBox(edtList[4][7]).ItemIndex);
  Ini.WriteInteger(SecName, 'PlayersForNeutral', TSpinEdit(edtList[4][8]).Value);
  Ini.WriteInteger(SecName, 'NeutralCanWin', TComboBox(edtList[4][9]).ItemIndex);
  Ini.WriteString(SecName, 'MafCount', TEdit(edtList[4][10]).Text);
  Ini.WriteInteger(SecName, 'UseSpecialMaf', TComboBox(edtList[4][11]).ItemIndex);
  Ini.WriteInteger(SecName, 'PlayersForSpecialMaf', TSpinEdit(edtList[4][12]).Value);
  Ini.WriteInteger(SecName, 'ComType', TComboBox(edtList[4][13]).ItemIndex);
  Ini.WriteInteger(SecName, 'ComKillManiac', TComboBox(edtList[4][14]).ItemIndex);
  Ini.WriteInteger(SecName, 'ManiacCanUseCurse', TComboBox(edtList[4][15]).ItemIndex);
  Ini.WriteInteger(SecName, 'InfectionChance', TSpinEdit(edtList[4][16]).Value);
  Ini.WriteInteger(SecName, 'InstantCheck', TComboBox(edtList[4][17]).ItemIndex);
  Ini.WriteInteger(SecName, 'ComHelpers', TSpinEdit(edtList[4][18]).Value);
  //---------------------------------------------------------------------------
  // Шестая вкладка - тип игры - роли
  J:=0;
  for K := 3 to 99 do
    if K in setRoles then
    begin
      Ini.WriteInteger(SecName, 'UseRole_'+IntToStr(K), TComboBox(edtList[5][J]).ItemIndex);
      Ini.WriteInteger(SecName, 'RoleMinPlayers_'+IntToStr(K), TSpinEdit(edtList[5][J+1]).Value);
      Ini.WriteInteger(SecName, 'RoleKnowCom_'+IntToStr(K), TComboBox(edtList[5][J+2]).ItemIndex);
      Inc(J, 3);
    end;
  for K:=102 to 255 do
    if (K in setRoles) and not (K in [101,151]) then
    begin
      Ini.WriteInteger(SecName, 'UseRole_'+IntToStr(K), TComboBox(edtList[5][J]).ItemIndex);
      Inc(J);
    end;
  //---------------------------------------------------------------------------
  Ini.Free;
end;

procedure TfrmSettings.NumEditChange (Sender : TObject);
begin
  TEdit(Sender).Text:=IntToStr(StrToIntDef(TEdit(Sender).Text, TEdit(Sender).Tag));
end;

procedure TfrmSettings.FloatEditChange (Sender : TObject);
begin
  TEdit(Sender).Text:=FloatToStr(StrToFloatDef(TEdit(Sender).Text, TEdit(Sender).Tag));
end;

procedure TfrmSettings.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action:=caFree;
  PageCtrl.Free;
  btnApply.Free;
  frmSettings:=nil;
end;

procedure TfrmSettings.FormHide(Sender: TObject);
var I, K: Integer;
begin
  for I := 0 to PageCtrl.PageCount - 1 do
  begin
    for K := 0 to PageCtrl.Pages[I].Tag - 1 do
    begin
      lblList[I][K].Free;
      edtList[I][K].Free;
    end;
    lblList[I]:=nil;
    edtList[I]:=nil;
  end;
  lblList:=nil;
  edtList:=nil;
end;

procedure TfrmSettings.FormShow(Sender: TObject);
var
  I, K: Integer;
  Ini: TIniFile;
  Strings: TStringList;
  SecName: String;
  ErrFlag: Boolean;
begin
  ErrFlag:=False;
  try
    //config_dir:=PCorePlugin^.AskPluginTempPath+'\Mafia';

    file_config:=ExtractFilePath(ParamStr(0))+'Plugins\Mafia\config.ini';
    file_messages:=ExtractFilePath(ParamStr(0))+'Plugins\Mafia\messages.ini';
    file_gametypes:=ExtractFilePath(ParamStr(0))+'Plugins\Mafia\gametypes.ini';
    //file_users:=config_dir+'\users.ini';

  except
    ErrFlag:=True;
  end;
  if ErrFlag then
  begin
    MessageBox(0, 'Запустите плагин для настройки.', 'Ошибка', MB_ICONEXCLAMATION);
    Self.Close();
  end
  else if not FileExists(file_config) or not FileExists(file_gametypes) or not FileExists(file_messages) then
  begin
    MessageBox(0, 'Отсутствуют один или несколько файлов, необходимых для работы плагина.', 'Ошибка', MB_ICONEXCLAMATION);
    //ShellExecute(0, 'open', PChar('"'+PCorePlugin^.AskPluginTempPath+'\Mafia"'), nil, nil, SW_SHOWNORMAL);
    Self.Close();
  end
  else
  begin
  RoleText2:=LoadRoles();

  updownListCount:=0;

  SetLength(PrntList, PageCtrl.PageCount);
  SetLength(lblList, PageCtrl.PageCount);
  SetLength(edtList, PageCtrl.PageCount);
  SetLength(UpDownList, 20);

  for I := 0 to PageCtrl.PageCount - 1 do
   PrntList[I]:=PageCtrl.Pages[I];

  PrntList[0]:=ScrollBoxMain;
  PrntList[1]:=ScrollBoxTime;
  PrntList[2]:=ScrollBoxPoints;
  PrntList[3]:=ScrollBoxStatistic;
  PrntList[4]:=ScrollBoxGametype;
  PrntList[5]:=ScrollBoxGametypeRoles;


  for I := 0 to PageCtrl.PageCount - 1 do
   PrntList[I].Tag:=0;

  Ini:=TIniFile.Create(file_config);

  //---------------------------------------------------------------------------
  // Первая вкладка - основные настройки
  SetLength(lblList[0], 32);
  SetLength(edtList[0], 32);

  AddParameterEdit(0, 'Канал игры', Ini, 'Mafia', 'Channel', 'мафия');
  AddParameterEdit(0, 'Канал помощи', Ini, 'Mafia', 'ChannelHelp', 'мафия(описание и правила)');
  AddParameterEdit(0, 'Основной канал чата', Ini, 'Mafia', 'ChannelMain1', 'main');
  AddParameterYesNo(0, 'Загрузка настроек при старте игры', Ini, 'Mafia', 'ReloadSettingsOnStart', 1);
  AddParameterYesNo(0, 'Фильтр по IP', Ini, 'Mafia', 'IPFilter', 0);
  AddParameterYesNo(0, 'Фильтр по ID', Ini, 'Mafia', 'IDFilter', 0);
  AddParameterEdit(0, 'Имя бота', Ini, 'Mafia', 'BotName', 'Mafiozi');
  AddParameterEdit(0, 'Пароль бота', Ini, 'Mafia', 'BotPass', 'mafiarulez');
  Strings:=TStringList.Create();
  Strings.Add('Мужской');
  Strings.Add('Женский');
  AddParameterCombo(0, 'Пол бота', Ini, 'Mafia', 'BotIsFemale', 1, Strings);
  Strings.Free;
  AddParameterEdit(0, 'IP бота', Ini, 'Mafia', 'BotIP', 'N/A');
  AddParameterEdit(0, 'Состояние бота', Ini, 'Mafia', 'BotState', 'Бот игры Мафия');
  AddParameterYesNo(0, 'Запрещать публикацию сообщений трупам', Ini, 'Mafia', 'BanOnDeath', 1);
  AddParameterYesNo(0, 'Запрещать приватную переписку трупам', Ini, 'Mafia', 'BanPrivateOnDeath', 0);
  AddParameterEdit(0, 'Причина запрета публикации сообщений', Ini, 'Mafia', 'BanReason', 'Выбывание из игры');
  AddParameterEdit(0, 'Причина отмены ограничения', Ini, 'Mafia', 'UnbanReason', 'Окончание игры');
  AddParameterYesNo(0, 'Отправлять статистику в приват', Ini, 'Mafia', 'StatToPrivate', 0);
  AddParameterNumEdit(0, 'Цена маскировочного комплекта', Ini, 'Mafia', 'MaskPrice', 20, 0, 500, 5);
  AddParameterNumEdit(0, 'Цена рации', Ini, 'Mafia', 'RadioPrice', 15, 0, 500, 5);
  AddParameterNumEdit(0, 'Время действия рации (ночей)', Ini, 'Mafia', 'RadioNights', 1, 1, 50, 1);
  AddParameterYesNo(0, 'Переход на следующую контрольную точку, когда сходили все игроки', Ini, 'Mafia', 'FastGame', 1);
  Strings:=TStringList.Create();
  Strings.Add('С утра');
  Strings.Add('С ночи');
  AddParameterCombo(0, 'Начало игры', Ini, 'Mafia', 'StartFromNight', 1, Strings);
  Strings.Free;
  AddParameterYesNo(0, 'Показывать активность игроков ночью', Ini, 'Mafia', 'ShowNightActions', 0);
  Strings:=TStringList.Create();
  Strings.Add('По умолчанию');
  Strings.Add('Отправлять всегда сообщениями');
  Strings.Add('Отправлять всегда состояниями (F9)');
  AddParameterCombo(0, 'Тип сообщений', Ini, 'Mafia', 'MessagesType', 0, Strings);
  Strings.Free;

  Strings:=TStringList.Create();
  Strings.Add('Нет действия');
  Strings.Add('Изменить тему');
  Strings.Add('Сообщение в канал');
  Strings.Add('Изменить тему и написать сообщение в канал');
  AddParameterCombo(0, 'Тип действия при смене игрового режима', Ini, 'Mafia', 'ChangeGametypeNotify', 1, Strings);
  Strings.Free;

  AddParameterNumEdit(0, 'Автоматически менять режим игры после X игр', Ini, 'Mafia', 'ChangeGametypeGamesCount', 0, 0, 500, 5);
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // Вторая вкладка - время
  SetLength(lblList[1], 8);
  SetLength(edtList[1], 8);

  AddParameterNumEdit(1, 'Время на набор игроков (с)', Ini, 'Mafia', 'TimeStart', 60, 20, 600, 10);
  AddParameterNumEdit(1, 'Время на подтверждение роли (с)', Ini, 'Mafia', 'TimeAccept', 30, 0, 180, 10);
  AddParameterNumEdit(1, 'Продолжительность ночи (с)', Ini, 'Mafia', 'TimeNight', 60, 30, 600, 10);
  AddParameterNumEdit(1, 'Продолжительность утра (с)', Ini, 'Mafia', 'TimeMorning', 25, 10, 600, 10);
  AddParameterNumEdit(1, 'Продолжительность дня (с)', Ini, 'Mafia', 'TimeDay', 60, 20, 600, 10);
  AddParameterNumEdit(1, 'Время на последнее слово (с)', Ini, 'Mafia', 'TimeLastWord', 15, 0, 600, 10);
  AddParameterNumEdit(1, 'Продолжительность вечера (с)', Ini, 'Mafia', 'TimeEvening', 20, 0, 600, 10);
  AddParameterNumEdit(1, 'Время паузы между сообщениями бота (мс)', Ini, 'Mafia', 'TimePause', 1000, 1, 15000, 500);
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // Третья вкладка - очки
  SetLength(lblList[2], 255);
  SetLength(edtList[2], 255);

  for I:=1 to 255 do
    if I in [1..18, 151..158] then
      AddParameterNumEdit(2, Ini.ReadString('MafiaPoints', 'Help_'+IntToStr(i), ''), Ini, 'MafiaPoints', IntToStr(i), 0, -100,100,1);
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // Четвёртая вкладка - статистика
  SetLength(lblList[3], 3);
  SetLength(edtList[3], 3);

  AddParameterYesNo(3, 'Обновлять приветствие', Ini, 'Stats', 'UpdateGreeting', 0);
  AddParameterYesNo(3, 'Экспорт статистики во внешний файл', Ini, 'Stats', 'Export', 0);
  AddParameterEdit(3, 'Имя файла для экспорта статистики', Ini, 'Stats', 'File', 'C:\MafStats.html');

  //---------------------------------------------------------------------------
  SecName:=Ini.ReadString('Mafia', 'DefaultGametype', 'Gametype_0');
  Ini.Free;

  Ini:=TIniFile.Create(file_gametypes);
  //---------------------------------------------------------------------------
  // Пятая вкладка - тип игры
  SetLength(lblList[4], 50);
  SetLength(edtList[4], 50);
  PageCtrl.Pages[4].Caption:='"'+SecName+'" - основное';
  AddParameterEdit(4, 'Название игры', Ini, SecName, 'Name', 'Обычная игра');
  AddParameterEdit(4, 'Команда для смены режима: !игра ', Ini, SecName, 'Command', 'по умолчанию');
  AddParameterNumEdit(4, 'Минимальное количество игроков', Ini, SecName, 'MinPlayers', 6, 5, 100, 1);
  AddParameterYesNo(4, 'Комментирование игроками ночных действий', Ini, SecName, 'ShowNightComments', 0);
  AddParameterYesNo(4, 'Показывать роли в начале игры', Ini, SecName, 'ShowRolesOnStart', 0);
  AddParameterYesNo(4, 'Использовать магазин', Ini, SecName, 'UseShop', 1);
  Strings:=TStringList.Create();
  Strings.Add('Не в игре');
  Strings.Add('В игре');
  AddParameterCombo(4, 'Японская мафия', Ini, SecName, 'UseYakuza', 0, Strings);
  Strings.Free;
  Strings:=TStringList.Create();
  Strings.Add('Не в игре');
  Strings.Add('В игре');
  AddParameterCombo(4, 'Нейтральный персонаж', Ini, SecName, 'UseNeutral', 1, Strings);
  Strings.Free;
  AddParameterNumEdit(4, 'Минимальное количество игроков для появления нейтрального персонажа', Ini, SecName, 'PlayersForNeutral', 8, 0, 254, 1);
  Strings:=TStringList.Create();
  Strings.Add('Остановить игру, победа команды');
  Strings.Add('Продолжать игру');
  AddParameterCombo(4, 'Нейтральный персонаж остается в живых против ОДНОЙ команды', Ini, SecName, 'NeutralCanWin', 0, Strings);
  Strings.Free;
  AddParameterEdit(4, 'Количество_мафиози = количество_игроков /', Ini, SecName, 'MafCount', '3', 3);
  Strings:=TStringList.Create();
  Strings.Add('Не в игре');
  Strings.Add('В игре');
  AddParameterCombo(4, 'Особый маф', Ini, SecName, 'UseSpecialMaf', 1, Strings);
  Strings.Free;
  AddParameterNumEdit(4, 'Минимальное количество игроков для появления особого мафа', Ini, SecName, 'PlayersForSpecialMaf', 12, 0, 254, 1);
  Strings:=TStringList.Create();
  Strings.Add('Стреляющий');
  Strings.Add('Проверяющий');
  Strings.Add('Детектив');
  AddParameterCombo(4, 'Тип комиссара', Ini, SecName, 'ComType', 0, Strings);
  Strings.Free;
  AddParameterYesNo(4, 'Стреляющий комиссар убьет маньяка при проверке', Ini, SecName, 'ComKillManiac', 1);
  AddParameterYesNo(4, 'Маньяк может использовать проклятие', Ini, SecName, 'ManiacCanUseCurse', 1);
  AddParameterNumEdit(4, 'Вероятность заражения путаной (%)', Ini, SecName, 'InfectionChance', 50, 0, 100, 10);
  AddParameterYesNo(4, 'Моментальная проверка комиссаром, адвокатом и бомжом', Ini, SecName, 'InstantCheck', 0);
  AddParameterNumEdit(4, 'Количество случайных помощников комиссара', Ini, SecName, 'ComHelpers', 2, 0, 8, 1);
  //---------------------------------------------------------------------------
  // Шестая вкладка - тип игры - роли
  SetLength(lblList[5], 255);
  SetLength(edtList[5], 255);
  PageCtrl.Pages[5].Caption:='"'+SecName+'" - роли';
  for K := 3 to 99 do
    if K in setRoles then
    begin
      Strings:=TStringList.Create();
      Strings.Add('Не в игре');
      Strings.Add('Один из случайных помощников');
      Strings.Add('В игре');
      AddParameterCombo(5, RoleText2[K, 0], Ini, SecName, 'UseRole_'+IntToStr(K), 1, Strings, 15);
      Strings.Free;
      AddParameterNumEdit(5, 'Минимальное значение игроков для появления '+RoleText2[K, 3]+' (если значение предыдущего параметра "В игре")', Ini, SecName, 'RoleMinPlayers_'+IntToStr(K), 0, 0, 100, 1);
      AddParameterYesNo(5, RoleText2[K, 0]+' и '+RoleText2[2,0]+' знают друг друга', Ini, SecName, 'RoleKnowCom_'+IntToStr(K), 0);
    end;
  for K:=102 to 255 do
    if (K in setRoles) and not (K in [101,151]) then
    begin
      Strings:=TStringList.Create();
      Strings.Add('Не в игре');
      Strings.Add('В игре');
      AddParameterCombo(5, RoleText2[K, 0], Ini, SecName, 'UseRole_'+IntToStr(K), 2, Strings, 5);
      Strings.Free;
    end;
  //---------------------------------------------------------------------------
  Ini.Free;
  end;
end;

end.
unit mafia;

interface

uses
  MyIniFiles,
  Windows, WinInet, SysUtils, Classes, SyncObjs, DateUtils,
  Math, Controls, StdCtrls, ExtCtrls, ComCtrls, Buttons,
  comm_info, comm_data, mafia_data, libfunc, libqueue, libstat;

type

  TTimerUpdater = class
    class procedure RefreshTimer (Sender : TObject);
  end;

  function GetMoreData(userdata : MafUser): MafUser;
  
  procedure onMsg(User: TUser; Channel, Text: String);
  procedure onPrivate(User: TUser; Text: String);
  procedure onPersonalMsg(User: TUser; Text: String);
  procedure onUserJoinChannel(User: TUser; Channel: String);

  function LoadRoles():TRoleText;
  procedure LoadMessages();
  procedure LoadSettings(LoadAll: Boolean=true);
  procedure LoadGametype(GametypeName: String ='');
  procedure ClearOldUsers();
  procedure ChangeGametype();

  function Init():Integer;
  procedure Destroy();
  procedure ResetTimer();
  procedure ResetTimerQ();
  procedure NextCP();
  procedure CheckNextCP();

  //--------------------------------------------------

  function  MafiaDump():String;                     // Необходимая информация о текущем состоянии
  function  UserInGame(Name: String):Byte;          // В игре ли пользователь, возвращает его номер
  function  IPInGame(IP: String):Byte;              // В игре ли IP, возвращает его номер
  function  IDInGame(ID: String):Byte;              // В игре ли ID, возвращает его номер
  function  IsUserModer(Name: String):Boolean;      // Модератор ли пользователь
  function  GetPlayerTeam(id: Byte):Byte;           // Команда пользователя
  function  GetAlivePlayers(outtype: Byte):String;  // Получение списка живых
  function  VoteResult(): TwoByte;                  // Получение результата голосования
  function  Vote2Result(): TwoByte;                 // Получение результата голосования
  function  CancelActivity(id: Byte; announce: Boolean=True): Boolean;      // Отмена голоса/блокировка
  procedure KillPlayer2(id: Byte);                  // Убить игрока
  procedure ApplyBans();                            // Применить ограничения
  procedure ApplyKills();                           // Применить убийства:)
  procedure KillPlayer(id: Byte);                   // Подготовка убийтсва
  procedure AddPoints(id: Byte; points: Integer);   // Добавление очков
  function  GetRandomTextReplaceRole(TextId: String;
                            Player: Byte): String;  // Получение случайного текста
  procedure NightAction(id: Byte);                  // Вывод текста о действии роли ночью
  procedure NightActionCancel(id: Byte);            // Вывод текста об отмене действия роли ночью
  function  NightComment(id: Byte; Text: String): String; // Комментарий игрока
  function  RoleHelp(id: Byte): String;             // Пояснительный текст для роли
  procedure StartPlayerGetting(Time: Word);         // Старт набора игроков
  procedure StopPlayerGetting();                    // Конец набора игроков
  procedure JoinPlayer(User: TUser);                // Присоединение игрока
  procedure LeavePlayer(User: TUser);               // Выход игрока(при наборе)
  function  AddRole(Role: Byte): Byte;              // Выдача роли(Random)
  procedure RandomRole(peacePlayerCount: Byte);     // Получение ролей помощников
  procedure AddRandomRole(Role: Byte);              // Применение роли, установка необходимых переменных
  function  CheckWin(State: Byte):Boolean;          // Проверка условий победы
  procedure Win(Team: Byte);                        // Победа
  procedure StartNight();                           // Начало ночи
  procedure EndNight();                             // Конец ночи
  procedure StartMorning();                         // Утро
  procedure StartDay();                             // Начало дня
  procedure EndDay();                               // Конец дня
  procedure StartEvening();                         // Начало вечера
  procedure EndEvening();                           // Конец вечера

var
  MafTimer: TTimer;

  PlayerCount : Byte; //Количество игроков
  PlayersArr: array[1..255] of PMafUser; //Игроки
  Voting: array[1..255] of Byte;         //Голоса: днем все, ночью мафы.
  Voting2: array[1..255] of Byte;        //Для якудз.
  VotingYesNo: array [0..1] of ShortInt;     // Да-нет (вечер)
  RoleAccept: array[1..255] of Byte;     //Принятие ролей

  RoleText: TRoleText; //Текст

implementation

  function  MafiaDump():String;
  var
    I: Byte;
  begin
    try
      Result:=Chr(13)+Chr(10)+'Players ('+IntToStr(PlayerCount)+'): ';
      for I := 1 to PlayerCount do
        Result:=Result+'[gs:'+IntToStr(PlayersArr[i]^.gamestate)+',ac:'+IntToStr(PlayersArr[i]^.activity)+']';
    except
      on e: exception do
        Result:=Chr(13)+Chr(10)+'Error while dumping plugin state: '+e.Message;
    end;
  end;

  function GetMoreData(userdata : MafUser): MafUser;
  var
    SafeName : String;
    Ini: TIniFile;
  begin
    Result := userdata;
    SafeName:=CheckStr(userdata.name);
    Ini:=TIniFile.Create(file_users);
    Result.points:=Ini.ReadInteger(SafeName,'points',0);
    Result.wins:=Ini.ReadInteger(SafeName,'wins',0);
    Result.plays:=Ini.ReadInteger(SafeName,'plays',0);
    Result.draws:=Ini.ReadInteger(SafeName,'draws',0);
    if (Result.plays-Result.wins-Result.draws)>0 then
      Result.rate:=FloatToStrF(Result.wins*Result.plays/(Result.plays-Result.wins-Result.draws), ffFixed, 20, 4)
    else
      Result.rate:='INF';
    Ini.Free;
  end;

  function GetPlayerTeam(id: Byte):Byte;
  begin
    if (PlayersArr[id]^.gamestate=0) then
      Result:=0     //Труп
    else
      if (PlayersArr[id]^.gamestate>100) then
        if (PlayersArr[id]^.gamestate<150) then
          Result:=2 //Мафф
        else
          if (PlayersArr[id]^.gamestate<200) then
            Result:=4 //Якудза
          else
            Result:=3 //Нейтрал
      else
        Result:=1;  //Мирный
  end;

  function GetAlivePlayers(outtype: Byte):String;
  var
    i: Byte;
  begin
    Result:='';
    if outtype=2 then
      StatusToChannel(game_chan, Messages.Values['RemainingPlayers']);
    for i:=1 to playerCount do
      if (PlayersArr[i]^.gamestate>0) then
        Result:=Result+IntToStr(i)+' - '+PlayersArr[i]^.name+Chr(13)+Chr(10);
    Result:='[code]'+Result+'[/code]';
    if outtype>0 then
      StatusToChannel(game_chan, Chr(13)+Chr(10)+Result);
  end;

  procedure AddPoints(id: Byte; points: Integer);
  begin
    PlayersArr[id]^.gamepoints:=PlayersArr[id]^.gamepoints+points;
  end;

  function GetRandomTextReplaceRole(TextId: String; Player: Byte): String;
  var
    Str: String;
  begin
    Str:=GetRandomTextFromIni(file_messages, TextId+'_'+IntToStr(PlayersArr[Player]^.pol));
    if Str='' then
      Str:=GetRandomTextFromIni(file_messages, TextId);
    Str:=StringReplace(Str,'%role0%','[b]'+RoleText[PlayersArr[Player]^.gamestate, 0]+'[/b]',[rfReplaceAll]);
    Str:=StringReplace(Str,'%role1%','[b]'+RoleText[PlayersArr[Player]^.gamestate, 1]+'[/b]',[rfReplaceAll]);
    Str:=StringReplace(Str,'%role2%','[b]'+RoleText[PlayersArr[Player]^.gamestate, 2]+'[/b]',[rfReplaceAll]);
    Str:=StringReplace(Str,'%role3%','[b]'+RoleText[PlayersArr[Player]^.gamestate, 3]+'[/b]',[rfReplaceAll]);
    Str:=StringReplace(Str,'%name%', FormatNick(PlayersArr[Player]^.Name),[rfReplaceAll]);
    Result:=Str;
  end;

  function GetRandomTextReplacePlayerList(TextId: String; PlayerList: array of Byte; Count: Byte): String;
  var
    i: Byte;
    Str: String;
    PlStr: String;
  begin
    Result:='';
    if Count>0 then
    begin
      if Count=1 then
        Str:=GetRandomTextFromIni(file_messages, TextId+'_'+IntToStr(PlayersArr[PlayerList[0]]^.pol));
      if Str='' then
        Str:=GetRandomTextFromIni(file_messages, TextId+'_Count'+IntToStr(Count));
      if Str='' then
        Str:=GetRandomTextFromIni(file_messages, TextId);
      if Pos('%playerlist0%',Str) > 0 then
      begin
        PlStr:='';
        for i := 0 to Count - 1 do
          PlStr:=PlStr+FormatNick(PlayersArr[PlayerList[i]]^.Name)+' ([b]'+RoleText[PlayersArr[PlayerList[i]]^.gamestate, 0] + '[/b]), ';
        Delete(PlStr, Length(PlStr)-1, 2);
        Str:=StringReplace(Str,'%playerlist0%',PlStr,[rfReplaceAll]);
      end;
      if Pos('%playerlist1%',Str) > 0 then
      begin
        PlStr:='';
        for i := 0 to Count - 1 do
          PlStr:=PlStr+FormatNick(PlayersArr[PlayerList[i]]^.Name)+' ([b]'+RoleText[PlayersArr[PlayerList[i]]^.gamestate, 1] + '[/b]), ';
        Delete(PlStr, Length(PlStr)-1, 2);
        Str:=StringReplace(Str,'%playerlist1%',PlStr,[rfReplaceAll]);
      end;
      if Pos('%playerlist2%',Str) > 0 then
      begin
        PlStr:='';
        for i := 0 to Count - 1 do
          PlStr:=PlStr+FormatNick(PlayersArr[PlayerList[i]]^.Name)+' ([b]'+RoleText[PlayersArr[PlayerList[i]]^.gamestate, 2] + '[/b]), ';
        Delete(PlStr, Length(PlStr)-1, 2);
        Str:=StringReplace(Str,'%playerlist2%',PlStr,[rfReplaceAll]);
      end;
      if Pos('%playerlist3%',Str) > 0 then
      begin
        PlStr:='';
        for i := 0 to Count - 1 do
          PlStr:=PlStr+FormatNick(PlayersArr[PlayerList[i]]^.Name)+' ([b]'+RoleText[PlayersArr[PlayerList[i]]^.gamestate, 3] + '[/b]), ';
        Delete(PlStr, Length(PlStr)-1, 2);
        Str:=StringReplace(Str,'%playerlist3%',PlStr,[rfReplaceAll]);
      end;
      if Pos('%playerlist_column%',Str) > 0 then
      begin
        PlStr:='';
        for i := 0 to Count - 1 do
          PlStr:=PlStr+Chr(13)+Chr(10)+'[code]'+IntToStr(i+1)+'.[/code] '+FormatNick(PlayersArr[PlayerList[i]]^.Name)+' ([b]'+RoleText[PlayersArr[PlayerList[i]]^.gamestate, 0] + '[/b])';
        Str:=StringReplace(Str,'%playerlist_column%',PlStr,[rfReplaceAll]);
      end;
      Result:=Str;
    end;
  end;

  procedure NightAction(id: Byte);
  var
    Section: String;
  begin
    if show_night_actions then
    begin
      case id of
        2: Section:='ComAction';
        3: Section:='WenchAction';
        5: Section:='DocAction';
        8: Section:='ChiefAction';
        9: Section:='HomelessAction';
        51: Section:='SgtAction';
        101: Section:='MafAction';
        102: Section:='KillerAction';
        103: Section:='LawyerAction';
        104: Section:='DemolitionAction';
        151: Section:='YakuzaAction';
        201: Section:='ManiacAction';
        202: Section:='RobinAction';
        203: Section:='RobberAction';
      else
        Section:='';
      end;
      if Section<>'' then
        MsgToChannel(game_chan, getRandomTextFromIni(file_messages, Section));
    end;
  end;

  procedure NightActionCancel(id: Byte);
  var
    Section: String;
  begin
    if show_night_actions then
    begin
      case id of
        2: Section:='ComActionCancel';
        3: Section:='WenchActionCancel';
        5: Section:='DocActionCancel';
        8: Section:='ChiefActionCancel';
        9: Section:='HomelessActionCancel';
        51: Section:='SgtActionCancel';
        //101: Section:='MafActionCancel';
        102: Section:='KillerActionCancel';
        103: Section:='LawyerActionCancel';
        104: Section:='DemolitionActionCancel';
        //151: Section:='YakuzaActionCancel';
        201: Section:='ManiacActionCancel';
        202: Section:='RobinActionCancel';
        203: Section:='RobberActionCancel';
      else
        Section:='';
      end;
      if Section<>'' then
        MsgToChannel(game_chan, getRandomTextFromIni(file_messages, Section));
    end;
  end;

  function  NightComment(id: Byte; Text: String): String;
  var
    Section: String;
  begin
    Result:='';
    if not Gametype.ShowNightComments then Exit;
    if (Text<>'') and (Text<>' ') and (Text<>'  ') then
    begin
      case id of
        2,51: Section:='ComComment';
        3: Section:='WenchComment';
        4: Section:='JudgeComment';
        7: Section:='HighlanderComment';
        8: Section:='ChiefComment';
        9: Section:='HomelessComment';
        101: Section:='MafComment';
        102: Section:='KillerComment';
        104: Section:='DemolitionComment';
        151: Section:='YakuzaComment';
        201: Section:='ManiacComment';
        202: Section:='RobinComment';
        203: Section:='RobberComment';
      else
        Section:='';
      end;
      if Section<>'' then
      begin
        Result:=' '+StringReplace(getRandomTextFromIni(file_messages, Section),'%role0%',RoleText[id, 0],[rfReplaceAll]);
        Result:=' '+StringReplace(Result,'%role1%',RoleText[id, 1],[rfReplaceAll]);
        Result:=' '+StringReplace(Result,'%role2%',RoleText[id, 2],[rfReplaceAll]);
        Result:=' '+StringReplace(Result,'%role3%',RoleText[id, 3],[rfReplaceAll]);
        Result:=' '+StringReplace(Result,'%text%',Text,[rfReplaceAll]);
      end;
    end;
  end;


  function RoleHelp(id: Byte): String;
  var
    Ini: TIniFile;
  begin
    Result:='';
    Ini:=TIniFile.Create(file_messages);
    if id=2 then
      Result:=Ini.ReadString('RoleHelp', 'Role_2_start', '')+' '+Ini.ReadString('RoleHelp', 'Role_2_'+IntToStr(Gametype.ComType), '')
    else
      Result:=Ini.ReadString('RoleHelp', 'Role_'+IntToStr(id), '');
    Ini.Free;
  end;

  procedure onMsg(User: TUser; Channel, Text: String);
  var
    member: MafUser;
    i,k,j: Integer;
    StrList: TStringList;
    Str: String;
    Ini : TIniFile;

    Sections: TStrings;
    Points: Integer;
    Wins, Plays, Draws : Word;
    Rate: Single;
    StopLoop: Boolean;
    TopLimit: Byte;

    target: TwoByte;
  begin
    if Channel=game_chan then
    begin
      member.name :=User.Name;
      member.IP :=User.IP;

      if Copy(Text,1,4)='!топ' then
      begin
        TopLimit:=StrToIntDef(Copy(Text,6,Length(Text)-5), top_default);
        if (TopLimit<1) or (TopLimit>TopMaxPlayers) then
           TopLimit:=TopMaxPlayers;

        StrList:=TStringList.Create;
        UpdateTopCriticalSection.Enter;
        try
          //----------------------------------------------------------------------
          StrList.Add('');
          StrList.Add(StringReplace(Messages.Values['TopPoints'],'%toplimit%',IntToStr(TopLimit),[rfReplaceAll]));
          for i:=1 to TopLimit do
          begin
            if TopPoints[i].Name<>'' then
            begin
              Str:='_';
              for k:=1 to (MAX_NAME+1-Length(TopPoints[I].Name)) do
                Str:=Str+'_';

              Str:=Str+IntToStr(TopPoints[I].Points);

              StrList.Add(IntToStr(i)+'. '+TopPoints[I].Name+Str);
            end;
          end;
          //----------------------------------------------------------------------

          StrList.Add('');
          StrList.Add(StringReplace(Messages.Values['TopRate'],'%toplimit%',IntToStr(TopLimit),[rfReplaceAll]));
          for i:=1 to TopLimit do
          begin
            if TopRate[i].Name<>'' then
            begin
              Str:='_';
              for k:=1 to (MAX_NAME+1-Length(TopRate[I].Name)) do
                Str:=Str+'_';

              Str:=Str+FloatToStrF(TopRate[I].Rate, ffFixed, 20, 4);

              StrList.Add(IntToStr(i)+'. '+TopRate[I].Name+Str);
            end;
          end;
          //----------------------------------------------------------------------


          //--------------По ролям--------------------------
          if State<2 then
          begin
            StrList.Add('');
            StrList.Add(Messages.Values['TopRoles']);
            for i:=1 to 255 do
              if TopRole[i].Name<>'' then
                StrList.Add(roleText[i, 0]+': [url=/message: '+TopRole[i].Name+']'+TopRole[i].Name+'[/url] - '+IntToStr(TopRole[i].Plays)+' игр');
          end;
          //----------------------------------------------------------------------
        finally
          UpdateTopCriticalSection.Leave;
        end;

        if stat_to_private then
          PrivateMsg(User.Name, StrList.Text)
        else
          MsgToChannel(game_chan, StrList.Text);
        StrList.Free;
      end;

      if (Copy(Text,1,5) ='!стоп') then           //Остановка игры
      begin
        if isUserModer(User.Name) and (State=1) and (SubState<3) then
          StopPlayerGetting()
        else
          if isUserModer(User.Name) and (State>1) and (State<>255) then
            Win(0);
        exit;
      end;

      if (Copy(Text,1,5)='!игра') then           //Смена типа игры
      begin
        if isUserModer(User.Name) and (State=0) then
        begin
          Str:=Copy(Text, 7, Length(Text)-6);

          Ini:=TIniFile.Create(file_gametypes);
          Sections:=TStringList.Create();
          Sections.Clear();
          Ini.ReadSections(Sections);
          for I:=0 to Sections.Count-1 do
            if Ini.ReadString(Sections.Strings[I], 'Command', '')=Str then
            begin
              LoadGametype(Sections.Strings[I]);
            end;
          Ini.Free;
          Sections.Free;
          ChangeGametype();
        end;
        exit;
      end;

      if (Copy(Text,1,6) ='!старт') then           //Начало набора игроков
      begin
        StartPlayerGetting(time_start);
        exit;
      end;

      if (Copy(Text,1,2) ='!я') or (Copy(Text,1,2) ='!z') or (Copy(Text,1,2) ='!Я') or (Copy(Text,1,2) ='!Z') then           //Присоединение к игре
      begin
        JoinPlayer(User);
        exit;
      end;

      if (Copy(Text,1,4) ='!нея') then           //Выход из игры
      begin
        LeavePlayer(User);
        exit;
      end;

      if (Copy(Text,1,7) ='!отмена') then           //Отмена голоса
      begin
        if CancelActivity(UserInGame(User.Name)) then
          MsgToChannel(game_chan, StringReplace(Messages.Values['VoteCancel'],'%name%',User.Name,[rfReplaceAll]));
        exit;
      end;

      if (Copy(Text,1,10) = '!посадить ') and (State=4) and (SubState = 0) then
      begin
        i:=UserInGame(User.Name);
        if (i>0) and (PlayersArr[i]^.gamestate>0) and (PlayersArr[i]^.activity=0) then
        begin
          Text:=Copy(Text,11,Length(Text)-10);
          if (StrToIntDef(Text, 0)>0) and (StrToIntDef(Text, 0)<=PlayerCount) and (PlayersArr[StrToIntDef(Text, 0)]^.gamestate>0) then
          begin
            PlayersArr[i]^.activity:=StrToIntDef(Text, 0);
            Inc(Voting[StrToIntDef(Text, 0)]);
            MsgToChannel(game_chan,
              StringReplace(
                StringReplace(
                  StringReplace(Messages.Values['VotePutAccepted'],'%name%',User.Name,[rfReplaceAll]),
                  '%name2%',PlayersArr[StrToIntDef(Text, 0)]^.Name,[rfReplaceAll]
                ), '%count%',IntToStr(Voting[StrToIntDef(Text, 0)]),[rfReplaceAll]
              )
            );
            if fast_game then
              CheckNextCP();
          end;
        end;
        exit;
      end;

      if (Copy(Text,1,3) ='!да') then           //Голос за посадку
      begin
        i:=UserInGame(User.Name);
        if (State=5) and (i>0) and (PlayersArr[i]^.gamestate>0) and (PlayersArr[i]^.voting=-1) then
        begin
          target:=VoteResult();
          if (target[0]>0) and (target[1]<>i) then
          begin
            PlayersArr[i]^.voting:=1;
            Inc(VotingYesNo[1]);
            MsgToChannel(game_chan,
              StringReplace(
                StringReplace(Messages.Values['VoteNooseAccepted'],'%name%',User.Name,[rfReplaceAll]),
                '%count%',IntToStr(VotingYesNo[1]),[rfReplaceAll]
              )
            );
            if fast_game then
              CheckNextCP();
          end
          else
            MsgToChannel(game_chan, StringReplace(Messages.Values['VoteNooseYourself'],'%name%',User.Name,[rfReplaceAll]));
        end;
        exit;
      end;

      if Copy(Text,1,4) ='!нет' then           //Голос за посадку
      begin
        i:=UserInGame(User.Name);
        if (State=5) and (i>0) and (PlayersArr[i]^.gamestate>0) and (PlayersArr[i]^.voting=-1) then
        begin
          target:=VoteResult();
          if (target[0]>0) and (target[1]<>i) then
          begin
            PlayersArr[i]^.voting:=0;
            Inc(VotingYesNo[0]);
            MsgToChannel(game_chan,
              StringReplace(
                StringReplace(Messages.Values['VoteNotNooseAccepted'],'%name%',User.Name,[rfReplaceAll]),
                '%count%',IntToStr(VotingYesNo[0]),[rfReplaceAll]
              )
            );
            if fast_game then
              CheckNextCP();
          end
          else
            MsgToChannel(game_chan, StringReplace(Messages.Values['VoteNooseYourself'],'%name%',User.Name,[rfReplaceAll]));
        end;
        exit;
      end;

      if (Copy(Text,1,5)='!help') or (Copy(Text,1,5)='!хелп') or (Copy(Text,1,7)='!помощь') then
      begin
        onPrivate(User, Text);
        exit;
      end;
      
    end;

    if Channel=maf_chan then
    begin
      if (Copy(Text,1,7) = '!убить ') and (State=2) then
      begin
        i:=UserInGame(User.Name);
        if (i>0) and (PlayersArr[i]^.gamestate=101) and (PlayersArr[i]^.activity=0) then
        begin
          StrList:=TStringList.Create;
          StrList.Delimiter:=' ';
          StrList.DelimitedText:=Copy(Text,8,Length(Text)-7);
          if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
          begin
            if maf_state=0 then
              NightAction(101);
            maf_state:=1;
            PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
            MsgToChannel(maf_chan, StringReplace(Messages.Values['VoteAccepted'],'%name%',User.Name,[rfReplaceAll]));
            Inc(Voting[StrToIntDef(StrList.Strings[0], 0)]);
            if fast_game then
              CheckNextCP();
          end;
          StrList.Free;
        end
        else
          if (i>0) and (i=killer_player) and (PlayersArr[i]^.activity=0) then
          begin
            StrList:=TStringList.Create;
            StrList.Delimiter:=' ';
            StrList.DelimitedText:=Copy(Text,8,Length(Text)-7);
            if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
            begin
              NightAction(102);
              PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
              killer_target:=StrToIntDef(StrList.Strings[0], 0);
              StrList.Delete(0);
              killer_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
              if (PlayersArr[killer_target]^.gamestate=7) then //Горец
                killer_state:=3
              else
                killer_state:=2;
              MsgToChannel(maf_chan,
                StringReplace(
                  StringReplace(Messages.Values['KillerActivityAccepted'],'%name%',User.Name,[rfReplaceAll]),
                  '%name2%',PlayersArr[killer_target]^.Name,[rfReplaceAll]
                )
              );
              if fast_game then
                CheckNextCP();
            end;
            StrList.Free;
          end;
        exit;
      end;

      if (Copy(Text,1,6) = '!пров ') and (State=2) then
      begin
        i:=UserInGame(User.Name);
        if (i>0) and (lawyer_player=i) and (PlayersArr[i]^.activity=0) and
          not (Gametype.InstantCheck and (SubState<>1)) then // Последовательные ходы
        begin
          StrList:=TStringList.Create;
          StrList.Delimiter:=' ';
          StrList.DelimitedText:=Copy(Text,7,Length(Text)-6);
          if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
          begin
            PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
            NightAction(103);
            lawyer_state:=2;
            lawyer_target:=StrToIntDef(StrList.Strings[0], 0);
            if Gametype.InstantCheck then
              if putana_target=i then
                MsgToChannel(maf_chan,  StringReplace(Messages.Values['YouBlocked'],'%name%',User.Name,[rfReplaceAll]))
              else
                MsgToChannel(maf_chan, 'Результат проверки '+RoleText[PlayersArr[lawyer_player]^.gamestate, 1]+': Статус ' + FormatNick(PlayersArr[lawyer_target]^.name)
                  + ' - [b]' + RoleText[PlayersArr[lawyer_target]^.gamestate,0]+'[/b]')
            else
              MsgToChannel(maf_chan, StringReplace(Messages.Values['VoteAccepted'],'%name%',User.Name,[rfReplaceAll]));
            if fast_game then
              CheckNextCP();
          end;
          StrList.Free;
        end;
        exit;
      end;

      if (Copy(Text,1,11) = '!подорвать ') and (State=2) then
      begin
        i:=UserInGame(User.Name);
        if (i>0) and (podrivnik_player=i) and (podrivnik_state=4) then
        begin
          StrList:=TStringList.Create;
          StrList.Delimiter:=' ';
          StrList.DelimitedText:=Copy(Text,12,Length(Text)-11);
          if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>=0) and (StrToIntDef(StrList.Strings[0], 0)<=2) then
          begin
            PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
            NightAction(104);
            podrivnik_target:=StrToIntDef(StrList.Strings[0], 0);
            StrList.Delete(0);
            podrivnik_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
            MsgToChannel(maf_chan, StringReplace(Messages.Values['DemolitionActivityAccepted'],'%text%',NightPlaces[podrivnik_target],[rfReplaceAll]));
          end;
          StrList.Free;
        end;
        exit;
      end;

      if Copy(Text,1,7)='!отмена' then           //Отмена голоса
      begin
        if CancelActivity(UserInGame(User.Name)) then
          MsgToChannel(maf_chan, StringReplace(Messages.Values['VoteCancel'],'%name%',User.Name,[rfReplaceAll]));
        exit;
      end;

      for i:=1 to PlayerCount do
        if (PlayersArr[i]^.use_radio>1) and (State=2) then
          PrivateMsg(PlayersArr[i]^.Name, 'Перехвачено сообщение мафов: [i]'+Text+'[/i]');

    end;

    if Channel=y_chan then
    begin
      if (Copy(Text,1,7) = '!убить ') and (State=2) then
      begin
        i:=UserInGame(User.Name);
        if (i>0) and (PlayersArr[i]^.gamestate=151) and (PlayersArr[i]^.activity=0) then
        begin
          StrList:=TStringList.Create;
          StrList.Delimiter:=' ';
          StrList.DelimitedText:=Copy(Text,8,Length(Text)-7);
          if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
          begin
            if y_state=0 then
              NightAction(151);
            y_state:=1;
            PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
            MsgToChannel(y_chan, StringReplace(Messages.Values['VoteAccepted'],'%name%',User.Name,[rfReplaceAll]));
            Inc(Voting2[StrToIntDef(StrList.Strings[0], 0)]);
            if fast_game then
              CheckNextCP();
          end;
          StrList.Free;
        end;
        exit;
      end;

      if Copy(Text,1,7)='!отмена' then           //Отмена голоса
      begin
        if CancelActivity(UserInGame(User.Name)) then
          MsgToChannel(y_chan, StringReplace(Messages.Values['VoteCancel'],'%name%',User.Name,[rfReplaceAll]));
        exit;
      end;

      for i:=1 to PlayerCount do
        if (PlayersArr[i]^.use_radio>1) and (State=2) then
          PrivateMsg(PlayersArr[i]^.Name, 'Перехвачено сообщение якудз: [i]'+Text+'[/i]');

    end;

  end;

  procedure onPrivate(User: TUser; Text: String);
  var
    member: MafUser;
    Str: String;
    StrList: TStringList;
    k: Byte;
    I: integer;
    index: Integer;
    Ini: TIniFile;
  begin
    //------------------------- Индивидуальные настройки -----------------------
    if Text='отстань' then
    begin
      Ini:=TIniFile.Create(file_users);
      Ini.WriteInteger(CheckStr(User.Name), 'announce', 0);
      PrivateMsg(User.Name, Messages.Values['StopAnnouncePM']);
      Ini.Free;
    end;

    if Text='предупреждай' then
    begin
      Ini:=TIniFile.Create(file_users);
      Ini.WriteInteger(CheckStr(User.Name), 'announce', 1);
      PrivateMsg(User.Name, Messages.Values['StartAnnouncePM']);
      Ini.Free;
    end;

    if Text='не предупреждай о смерти' then
    begin
      Ini:=TIniFile.Create(file_users);
      Ini.WriteInteger(CheckStr(User.Name), 'dmess', 0);
      PrivateMsg(User.Name, Messages.Values['StopAnnounceDeath']);
      Ini.Free;
    end;

    if Text='предупреждай о смерти' then
    begin
      Ini:=TIniFile.Create(file_users);
      Ini.WriteInteger(CheckStr(User.Name), 'dmess', 1);
      PrivateMsg(User.Name, Messages.Values['StartAnnounceDeath']);
      Ini.Free;
    end;

    if Copy(Text,1,9)='настройки' then
    begin
      Ini:=TIniFile.Create(file_users);
      Str:='[b]Текущее состояние настроек:[/b]'+Chr(13)+Chr(10);

      Str:=Str+ 'ЛС при начале набора игроков: ';
      i:=Ini.ReadInteger(CheckStr(User.Name), 'announce', 0);
      case i of
        0: Str:=Str+ '[b]отключены[/b]. Используйте команду [i]предупреждай[/i] для включения.';
        else
          Str:=Str+ '[b]включены[/b]. Используйте команду [i]отстань[/i] для отключения.';
      end;
      Str:=Str+Chr(13)+Chr(10);

      Str:=Str+ 'Сообщения о смерти: ';
      i:=Ini.ReadInteger(CheckStr(User.Name), 'dmess', 1);
      case i of
        0: Str:=Str+ '[b]отключены[/b]. Используйте команду [i]предупреждай о смерти[/i] для включения.';
        else
          Str:=Str+ '[b]включены[/b]. Используйте команду [i]не предупреждай о смерти[/i] для отключения.';
      end;
      Str:=Str+Chr(13)+Chr(10);

      PrivateMsg(User.Name, Str);
      Ini.Free;
    end;
    //--------------------------------------------------------------------------

    if (Copy(Text,1,15)='написать в main') and isUserModer(User.Name) then
      MsgToChannel(main_chan[1], Copy(Text,17,Length(Text)-16));
    if (Copy(Text,1,13)='создать канал') and isUserModer(User.Name) then
      CreateChannel(Copy(Text,15,Length(Text)-14),0,0);
    if (Copy(Text,1,15)='выйти из канала') and isUserModer(User.Name) then
      QuitChannel(Copy(Text,17,Length(Text)-16));

    if (Copy(Text,1,2)='!я') or (Copy(Text,1,2)='!z') or (Copy(Text,1,2)='!Я') or (Copy(Text,1,2)='!Z') then           //Присоединение к игре
    begin
      JoinPlayer(User);
      exit;
    end;

    if (Copy(Text,1,8)='!принять') and (State=1) and (time_accept>0) and (SubState=5) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (RoleAccept[i]=0) and (playersArr[i]^.gamestate>1) then
      begin
        RoleAccept[i]:=1;
        PrivateMsg(User.Name, StringReplace(Messages.Values['RoleAccepted'],'%text%',RoleText[playersArr[i]^.gamestate, 0],[rfReplaceAll]));
        if Gametype.ShowRolesOnStart then
          MsgToChannel(game_chan, GetRandomTextFromIni(file_messages, 'AcceptRole_'+intToStr(playersArr[i]^.gamestate)));
      end;

    end;
    
    if Copy(Text,1,9) = '!мой стат' then
    begin
      member.name:=User.Name;
      member.IP:=User.IP;
      member:=getMoreData(member);
      Str:='Ваша статистика:'+Chr(13)+Chr(10);
      Str:=Str+'Всего игр: '+IntToStr(member.plays)+Chr(13)+Chr(10);      
      Str:=Str+'Побед: '+IntToStr(member.wins)+Chr(13)+Chr(10);
      Str:=Str+Messages.Values['Points_Stat']+IntToStr(member.points)+Chr(13)+Chr(10);
      Str:=Str+Messages.Values['Rate_Stat']+member.rate+Chr(13)+Chr(10);

      Str:=Str+Messages.Values['StatRoles']+Chr(13)+Chr(10);

      Ini:=TIniFile.Create(file_users);
      for i:=1 to 255 do
        if (i in setRoles) and (Ini.ReadInteger(CheckStr(User.Name), 'role_'+intToStr(i), 0)>0) then
          Str:=Str+roleText[i, 0]+' - '+Ini.ReadString(CheckStr(User.Name), 'role_'+intToStr(i), '0')+' игр'+Chr(13)+Chr(10);
      Ini.Free;

      PrivateMsg(User.Name, Str);
      exit;
    end;

    if (Copy(Text,1,7) = '!пойти ') and (State=2) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (podrivnik_state=4) and (GetPlayerTeam(i)<>2) then
      begin
        StrList:=TStringList.Create;
        StrList.Delimiter:=' ';
        StrList.DelimitedText:=Copy(Text,8,Length(Text)-7);
        if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>=0) and (StrToIntDef(StrList.Strings[0], 0)<=2) then
        begin
          PlayersArr[i]^.night_place:=StrToIntDef(StrList.Strings[0], 0);
          PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
        end;
        StrList.Free;
      end;
      exit;
    end;

    if (Copy(Text,1,6) = '!пров ') and (State=2) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (com_player=i) and (PlayersArr[i]^.activity=0) and
        not (Gametype.InstantCheck and (SubState<>1)) then
      begin
        StrList:=TStringList.Create;
        StrList.Delimiter:=' ';
        StrList.DelimitedText:=Copy(Text,7,Length(Text)-6);
        if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
        begin
          PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
          if (getPlayerTeam(StrToIntDef(StrList.Strings[0], 0))=2) or (getPlayerTeam(StrToIntDef(StrList.Strings[0], 0))=4) then
            com_state:=3
          else
            if (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate=201) and Gametype.ComKillManiac then
              com_state:=4
            else
              com_state:=2;
          NightAction(PlayersArr[i]^.gamestate);
          com_target:=StrToIntDef(StrList.Strings[0], 0);
          StrList.Delete(0);
          com_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
          if Gametype.InstantCheck then
            if putana_target=i then
                 PrivateMsg(User.Name, StringReplace(Messages.Values['YouBlocked'],'%name%',User.Name,[rfReplaceAll]))
            else
              PrivateMsg(User.Name, 'Статус '+ FormatNick(PlayersArr[com_target]^.name)+' - [b]' + RoleText[PlayersArr[com_target]^.gamestate,0]+'[/b]')
          else
            PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
          if fast_game then
            CheckNextCP();
        end;
        StrList.Free;
      end
      else if (i>0) and (lawyer_player=i) and (PlayersArr[i]^.activity=0) and
          not (Gametype.InstantCheck and (SubState<>1)) then
        begin
          StrList:=TStringList.Create;
          StrList.Delimiter:=' ';
          StrList.DelimitedText:=Copy(Text,7,Length(Text)-6);
          if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
          begin
            PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
            NightAction(103);
            lawyer_state:=2;
            lawyer_target:=StrToIntDef(StrList.Strings[0], 0);
            if Gametype.InstantCheck then
            begin
              if putana_target=i then
                PrivateMsg(User.Name, StringReplace(Messages.Values['YouBlocked'],'%name%',User.Name,[rfReplaceAll]))
              else
              begin
                PrivateMsg(User.Name, 'Статус '+ FormatNick(PlayersArr[lawyer_target]^.name)
                  + ' - [b]' + RoleText[PlayersArr[lawyer_target]^.gamestate,0]+'[/b]');
                MsgToChannel(maf_chan, 'Результат проверки '+RoleText[PlayersArr[lawyer_player]^.gamestate, 1]+': Статус ' + FormatNick(PlayersArr[lawyer_target]^.name)
                  + ' - [b]' + RoleText[PlayersArr[lawyer_target]^.gamestate,0]+'[/b]');
              end;
            end
            else
              PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
            if fast_game then
              CheckNextCP();
          end;
          StrList.Free;
        end
      else if (i>0) and (homeless_player=i) and (PlayersArr[i]^.activity=0) and
          not (Gametype.InstantCheck and (SubState<>1)) then
        begin
          StrList:=TStringList.Create;
          StrList.Delimiter:=' ';
          StrList.DelimitedText:=Copy(Text,7,Length(Text)-6);
          if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
          begin
            PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
            NightAction(9);
            homeless_state:=2;
            homeless_target:=StrToIntDef(StrList.Strings[0], 0);
            StrList.Delete(0);
            homeless_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
            if Gametype.InstantCheck then
              if putana_target=i then
                PrivateMsg(User.Name, StringReplace(Messages.Values['YouBlocked'],'%name%',User.Name,[rfReplaceAll]))
              else
                PrivateMsg(User.Name, 'Статус '+ FormatNick(PlayersArr[homeless_target]^.name)
                  + ' - [b]' + RoleText[PlayersArr[homeless_target]^.gamestate,0]+'[/b]')
            else
              PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
            if fast_game then
              CheckNextCP();
          end;
          StrList.Free;
        end;
      exit;
    end;

    if (Copy(Text,1,7) = '!спать ') and (State=2) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (putana_player=i) and (PlayersArr[i]^.activity=0) and
        not (Gametype.InstantCheck and (SubState<>0)) then
      begin
        StrList:=TStringList.Create;
        StrList.Delimiter:=' ';
        StrList.DelimitedText:=Copy(Text,8,Length(Text)-7);
        if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
        begin
          if (PlayersArr[i]^.lastactivity<>StrToIntDef(StrList.Strings[0], 0)) then
            if (putana_player<>StrToIntDef(StrList.Strings[0], 0)) then
            begin
              NightAction(3);
              PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
              putana_target:=StrToIntDef(StrList.Strings[0], 0);
              putana_state:=2;
              StrList.Delete(0);
              putana_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
              PrivateMsg(User.Name, StringReplace(Messages.Values['WenchActivityAcceptedPM'],'%name2%',PlayersArr[putana_target]^.Name,[rfReplaceAll]));
              if fast_game then
                CheckNextCP();
            end
            else
              PrivateMsg(User.Name, Messages.Values['WenchActivityYourself'])
          else
            PrivateMsg(User.Name, Messages.Values['WenchActivityTwice']);
        end;
        StrList.Free;
      end;
      exit;
    end;

    if (Copy(Text,1,11) = '!оправдать ') and (State=4) and (SubState = 0) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (judge_player=i) and (PlayersArr[i]^.activity2=0) then
      begin
        StrList:=TStringList.Create;
        StrList.Delimiter:=' ';
        StrList.DelimitedText:=Copy(Text,12,Length(Text)-11);
        if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
        begin
          if (PlayersArr[i]^.lastactivity<>StrToIntDef(StrList.Strings[0], 0)) then
          begin
            if (StrToIntDef(StrList.Strings[0], 0)=judge_player) then
              PrivateMsg(User.Name, Messages.Values['JudgeActivityYourself'])
            else
            begin
              PlayersArr[i]^.activity2:=StrToIntDef(StrList.Strings[0], 0);
              judge_target:=StrToIntDef(StrList.Strings[0], 0);
              judge_state:=2;
              StrList.Delete(0);
              judge_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
              PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
              if fast_game then
                CheckNextCP();
            end;
          end
          else
            PrivateMsg(User.Name, Messages.Values['JudgeActivityTwice']);
        end;
        StrList.Free;
      end;
      exit;
    end;

    if (Copy(Text,1,10) = '!посадить ') and (State=4) and (SubState = 0) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (PlayersArr[i]^.gamestate=6) and (PlayersArr[i]^.activity2=0) then
      begin
        Text:=Copy(Text,11,Length(Text)-10);
        if (StrToIntDef(Text, 0)>0) and (StrToIntDef(Text, 0)<=PlayerCount) and (PlayersArr[StrToIntDef(Text, 0)]^.gamestate>0) then
        begin
          if (StrToIntDef(Text, 0)=i) then
              PrivateMsg(User.Name, Messages.Values['ElderActivityYourself'])
          else
          begin
            PlayersArr[i]^.activity2:=StrToIntDef(Text, 0);
            PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
            if fast_game then
              CheckNextCP();
          end;
        end;
      end;
      exit;
    end;

    if (Copy(Text,1,8) = '!лечить ') and (State=2) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (doctor_player=i) and (PlayersArr[i]^.activity=0) then
      begin
        Text:=Copy(Text,9,Length(Text)-8);
        if (StrToIntDef(Text, 0)>0) and (StrToIntDef(Text, 0)<=PlayerCount) and (PlayersArr[StrToIntDef(Text, 0)]^.gamestate>0) then
        begin
          if (PlayersArr[i]^.lastactivity<>StrToIntDef(Text, 0)) then
          begin
            if (doctor_heals_himself=1) and (StrToIntDef(Text, 0)=doctor_player) then
              PrivateMsg(User.Name, Messages.Values['DoctorActivityYourself'])
            else
            begin
              NightAction(5);
              PlayersArr[i]^.activity:=StrToIntDef(Text, 0);
              doctor_target:=StrToIntDef(Text, 0);
              doctor_state:=2;
              PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
              if fast_game then
                CheckNextCP();
            end;
          end
          else
            PrivateMsg(User.Name, Messages.Values['DoctorActivityTwice']);
        end;
      end;
      exit;
    end;

    if (Copy(Text,1,13) = '!подстрелить ') and (State=2) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (sherif_player=i) and (PlayersArr[i]^.activity=0) then
      begin
        StrList:=TStringList.Create;
        StrList.Delimiter:=' ';
        StrList.DelimitedText:=Copy(Text,14,Length(Text)-13);
        if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
        begin
          PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
          sherif_target:=StrToIntDef(StrList.Strings[0], 0);
          StrList.Delete(0);
          sherif_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
          PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
          if (PlayersArr[sherif_target]^.gamestate=7) then //Горец
            sherif_state:=3
          else
            sherif_state:=2;
          NightAction(8);
          if fast_game then
            CheckNextCP();
        end;
        StrList.Free;
      end
      else if (i>0) and (com_player=i) and (PlayersArr[i]^.activity=0) and (Gametype.ComType=2) then
      begin
        StrList:=TStringList.Create;
        StrList.Delimiter:=' ';
        StrList.DelimitedText:=Copy(Text,14,Length(Text)-13);
        if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
        begin
          PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
          com_target:=StrToIntDef(StrList.Strings[0], 0);
          PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
          com_state:=5;
          StrList.Delete(0);
          com_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
          NightAction(PlayersArr[i]^.gamestate);
          if fast_game then
            CheckNextCP();
        end;
        StrList.Free;
      end
      else if (i>0) and (PlayersArr[i]^.gamestate=7) and (PlayersArr[i]^.activity=0) then
      begin
        StrList:=TStringList.Create;
        StrList.Delimiter:=' ';
        StrList.DelimitedText:=Copy(Text,14,Length(Text)-13);
        if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
        begin
          if (StrToIntDef(StrList.Strings[0], 0)=i) then
              PrivateMsg(User.Name, Messages.Values['HighlanderACtivityYourself'])
          else
          begin
            PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
            PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
            StrList.Delete(0);
            highlander_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
            if fast_game then
              CheckNextCP();
          end;
        end;
      end;
      exit;
      exit;
    end;

    if (Copy(Text,1,7) = '!убить ') and (State=2) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and ((PlayersArr[i]^.gamestate=101) or (PlayersArr[i]^.gamestate=151)) and (PlayersArr[i]^.activity=0) then
      begin
        StrList:=TStringList.Create;
        StrList.Delimiter:=' ';
        StrList.DelimitedText:=Copy(Text,8,Length(Text)-7);
        if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
        begin
          if (maf_state=0) and (PlayersArr[i]^.gamestate=101) then
          begin
            NightAction(101);
            maf_state:=1;
          end
          else
            if (y_state=0) and (PlayersArr[i]^.gamestate=151) then
            begin
              NightAction(151);
              y_state:=1;
            end;
          PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
          PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
          if (PlayersArr[i]^.gamestate=101) then
            Inc(Voting[StrToIntDef(StrList.Strings[0], 0)])
          else
            if (PlayersArr[i]^.gamestate=151) then
              Inc(Voting2[StrToIntDef(StrList.Strings[0], 0)]);
          if fast_game then
            CheckNextCP();
        end;
        StrList.Free;
      end
      else
        if (i>0) and (i=killer_player) and (PlayersArr[i]^.activity=0) then
        begin
          StrList:=TStringList.Create;
          StrList.Delimiter:=' ';
          StrList.DelimitedText:=Copy(Text,8,Length(Text)-7);
          if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
          begin
            PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
            killer_target:=StrToIntDef(StrList.Strings[0], 0);
            if (PlayersArr[killer_target]^.gamestate=7) then //Горец
              killer_state:=3
            else
              killer_state:=2;
            NightAction(102);
            StrList.Delete(0);
            killer_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
            PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
            if fast_game then
              CheckNextCP();
          end;
          StrList.Free;
        end;
      exit;
    end;

    if (Copy(Text,1,11) = '!подорвать ') and (State=2) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (podrivnik_player=i) and (podrivnik_state=4) then
      begin
        StrList:=TStringList.Create;
        StrList.Delimiter:=' ';
        StrList.DelimitedText:=Copy(Text,12,Length(Text)-11);
        if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>=0) and (StrToIntDef(StrList.Strings[0], 0)<=2) then
        begin
          PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
          NightAction(104);
          podrivnik_target:=StrToIntDef(StrList.Strings[0], 0);
          PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
          StrList.Delete(0);
          podrivnik_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
          MsgToChannel(maf_chan, StringReplace(Messages.Values['DemolitionActivityAccepted'],'%text%',NightPlaces[podrivnik_target],[rfReplaceAll]));
        end;
        StrList.Free;
      end;
      exit;
    end;

    if (Copy(Text,1,10) = '!завалить ') and (State=2) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (maniac_player=i) and (PlayersArr[i]^.activity=0) then
      begin
        StrList:=TStringList.Create;
        StrList.Delimiter:=' ';
        StrList.DelimitedText:=Copy(Text,11,Length(Text)-10);
        if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
        begin
          PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
          maniac_target:=StrToIntDef(StrList.Strings[0], 0);
          if (PlayersArr[maniac_target]^.gamestate=7) then //Горец
            maniac_state:=3
          else
            maniac_state:=2;
          NightAction(201);
          StrList.Delete(0);
          maniac_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
          PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
          if fast_game then
            CheckNextCP();
        end;
        StrList.Free;
      end;
      if (i>0) and (robin_player=i) and (PlayersArr[i]^.activity=0) then
      begin
        StrList:=TStringList.Create;
        StrList.Delimiter:=' ';
        StrList.DelimitedText:=Copy(Text,11,Length(Text)-10);
        if (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
        begin
          PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
          robin_target:=StrToIntDef(StrList.Strings[0], 0);
          if (PlayersArr[robin_target]^.gamestate=1) or (PlayersArr[robin_target]^.gamestate=7) then
            robin_state:=2
          else
            robin_state:=3;
          NightAction(202);
          StrList.Delete(0);
          robin_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
          PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
          if fast_game then
            CheckNextCP();
        end;
        StrList.Free;
      end;
      exit;
    end;

    if (Copy(Text,1,10) = '!ограбить ') and (State=2) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (robber_player=i) and (PlayersArr[i]^.activity=0) then
      begin
        StrList:=TStringList.Create;
        StrList.Delimiter:=' ';
        StrList.DelimitedText:=Copy(Text,11,Length(Text)-10);
        if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
        begin
          PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
          robber_target:=StrToIntDef(StrList.Strings[0], 0);
          robber_state:=2;
          NightAction(203);
          StrList.Delete(0);
          robber_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
          PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
          if fast_game then
            CheckNextCP();
        end;
        StrList.Free;
      end;
    end;

    if (Copy(Text,1,11) = '!проклясть ') and (State=2) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (maniac_player=i) and Gametype.ManiacCanUseCurse and (PlayersArr[i]^.activity=0) then
      begin
        if (maniac_use_curse=0) then
        begin
          StrList:=TStringList.Create;
          StrList.Delimiter:=' ';
          StrList.DelimitedText:=Copy(Text,12,Length(Text)-11);
          if (StrList.Count>0) and (StrToIntDef(StrList.Strings[0], 0)>0) and (StrToIntDef(StrList.Strings[0], 0)<=PlayerCount) and (PlayersArr[StrToIntDef(StrList.Strings[0], 0)]^.gamestate>0) then
          begin
            PlayersArr[i]^.activity:=StrToIntDef(StrList.Strings[0], 0);
            maniac_target:=StrToIntDef(StrList.Strings[0], 0);
            maniac_state:=10;
            NightAction(201);
            StrList.Delete(0);
            maniac_phrase:=StringReplace(StrList.Text,Chr(13)+Chr(10),' ',[rfReplaceAll]);
            PrivateMsg(User.Name, Messages.Values['VoteAcceptedPM']);
            if fast_game then
              CheckNextCP();
          end;
          StrList.Free;
        end
        else
          PrivateMsg(User.Name, Messages.Values['ManiacAlreadyUsedCurse']);
      end;
    end;

    if Copy(Text,1,7)='!отмена' then           //Отмена голоса
    begin
      i:=UserinGame(User.Name);
      if (i>0) and (i=judge_player) and (State=4) and (judge_target>0) then //Судья
      begin
        judge_state:=1;
        judge_target:=0;
        judge_phrase:='';
        PlayersArr[i]^.activity2:=0;
        PrivateMsg(User.Name, Messages.Values['VoteCancelPM']);
        exit;
      end;

      if (i>0) and (PlayersArr[i]^.gamestate=6) and (State=4) and (SubState = 0) and (PlayersArr[i]^.activity2>0) then //Старейшина
      begin
        PlayersArr[i]^.activity2:=0;
        PrivateMsg(User.Name, Messages.Values['VoteCancelPM']);
        exit;
      end;

      if CancelActivity(UserinGame(User.Name)) then
        PrivateMsg(User.Name, Messages.Values['VoteCancelPM']);
      exit;
    end;

    if (Copy(Text,1,5)='!help') or (Copy(Text,1,5)='!хелп') or (Copy(Text,1,7)='!помощь') then
    begin
      i:=UserInGame(User.Name);
      StrList:=TStringList.Create;
      StrList.Clear();
      StrList.Add('');
      StrList.Add('============Игровые команды============');
      StrList.Add('[i]!help[/i], [i]!хелп[/i], [i]!помощь[/i] - вывод этой справки(в приват боту);');
      StrList.Add('[i]!старт[/i] - начало набора игроков(старт игры);');
      StrList.Add('[i]!я[/i] - регистрация в игре;');
      StrList.Add('[i]!нея[/i] - выход из игры(во время набора игроков);');
      StrList.Add('[i]!мой стат[/i] - ваша статистика(в приват боту);');
      StrList.Add('[i]!топ[/i] - лучшие игроки.');
      StrList.Add('[i]!магазин[/i] - посмотреть доступные вещи для покупки(только во время игры, в приват боту).');
      StrList.Add('[i]предупреждай[/i] - сообщать о начале игры(в приват боту).');
      StrList.Add('[i]отстань[/i] - больше не сообщать о начале игры(в приват боту).');
      if (State>1) and (i>0) then
      begin
        StrList.Add('');
        StrList.Add('===========Помощь по статусу===========');
        StrList.Add('Ваш статус - [b]'+RoleText[PlayersArr[i]^.gamestate, 0]+'[/b]');
        case getPlayerTeam(i) of
          1: StrList.Add('Вы играете за команду мирных жителей');
          2: StrList.Add('Вы играете за команду мафов');
          3: StrList.Add('Вы играете сами за себя');
          4: StrList.Add('Вы играете за команду якудз');
        end;
        StrList.Add(RoleHelp(PlayersArr[i]^.gamestate));
      end;

      StrList.Add('');
      StrList.Add('======Помощь по начислению очков======');
      Ini := TIniFile.Create(file_config);
      for i:=1 to 255 do
        if (points_cost[i]<>0) and (Ini.ReadString('MafiaPoints', 'Help_'+IntToStr(i), '')<>'') then
          StrList.Add(Ini.ReadString('MafiaPoints', 'Help_'+IntToStr(i), '')+': '+ IntToStr(points_cost[i]));
      Ini.Free;

      StrList.Add('');
      StrList.Add('======Помощь по игровому режиму=======');
      StrList.Add('Название: '+Gametype.Name);
      StrList.Add('Минимальное количество игроков: '+IntToStr(Gametype.MinPlayers));
      if Gametype.UseYakuza then
        StrList.Add('Вторая мафиозная группировка: включена')
      else
        StrList.Add('Вторая мафиозная группировка: отключена');
      if Gametype.UseSpecialMaf then
      begin
        StrList.Add('Специальный мафиози: включен');
        StrList.Add('Минимальное количество игроков для появления в игре специального мафиози: '+IntToStr(Gametype.PlayersForSpecialMaf));
      end
      else
        StrList.Add('Специальный мафиози: отключен');
      if Gametype.UseNeutral then
      begin
        StrList.Add('Нейтральный персонаж: включен');
        StrList.Add('Минимальное количество игроков для появления в игре нейтрального персонажа: '+IntToStr(Gametype.PlayersForNeutral));
      end
      else
        StrList.Add('Нейтральный персонаж: отключен');

      Str:=RoleText[2, 0]+': ';
      case Gametype.ComType of
        0: Str:=Str+'стреляющий';
        1: Str:=Str+'проверяющий';
        2: Str:=Str+'Детектив';
      end;
      StrList.Add(Str);
      if Gametype.ComKillManiac then
        StrList.Add(RoleText[2, 0]+' убивает маньяка при проверке: да')
      else
        StrList.Add(RoleText[2, 0]+' убивает маньяка при проверке: нет');

      if Gametype.UseShop then
        StrList.Add('Магазин: включен')
      else
        StrList.Add('Магазин: отключен');
      StrList.Add('Мафов (и якудз): '+FloatToStrF(1/Gametype.MafCount*100, ffFixed,2,0)+'%');
      if Gametype.RandomHelpers>0 then
      begin
        k:=0;
        Str := ', выбираются из следующих ролей:';
        for i := 3 to 99 do
          if (i in setRoles) and (Gametype.UseRole[i]=1) then
          begin
            Inc(k);
            Str:=Str+' '+RoleText[i, 0]+',';
          end;
        if (Gametype.RandomHelpers <= k) then
          StrList.Add('Случайных мирных жителей с особенностями: '+IntToStr(Gametype.RandomHelpers)+Str+' кто из них в игре - заранее неизвестно.')
        else
          if k>0 then
            StrList.Add('Случайных мирных жителей с особенностями: '+IntToStr(k)+Str+' кто из них в игре - заранее неизвестно.');
      end;
      Str:='';
      for i := 3 to 99 do
          if (i in setRoles) and (Gametype.UseRole[i]=2) then
          begin
            Str:=Str+' '+RoleText[i, 0]+' (при '+IntToStr(Gametype.RoleMinPlayers[i])+' и более игроках),';
          end;
      StrList.Add('Всегда в игре: '+Str+' '+RoleText[2, 0]+', мафы и мирные, конечно:)');

      StrList.Add('');
      StrList.Add('=======Дополнительная информация=======');
      StrList.Add('Полностью описание и правила игры можно посмотреть [url=/channel:'+help_chan+']здесь[/url]');
      PrivateMsg(User.Name, StrList.Text);
      StrList.Free;
      exit;
    end;

    if (Copy(Text,1,8) = '!магазин') and (State>1) and (State<>255) then
    begin
      if Gametype.UseShop then begin
        i:=UserInGame(User.Name);
        if (i>0) and (PlayersArr[i]^.gamestate>0) then
        begin
          Str:='Доступные вещи:'+Chr(13)+Chr(10);

          //-------------------------------------------------------------------
          if Gametype.ShopItemAllowed[SHOP_ITEM_MASK] then
          begin
          	Str:=Str+'1. [b]'+Messages.Values['ItemMask']+'[/b] (Цена:'+IntToStr(mask_price)+') - предмет';
          	if (PlayersArr[i]^.use_mask=0) then
            	Str:=Str+'доступен для покупки'
          	else
            	if (PlayersArr[i]^.use_mask=1) then
              	Str:=Str+'будет использован этой ночью'
            	else
              	Str:=Str+'уже использован';
          	Str:=Str+Chr(13)+Chr(10);
          	Str:=Str+Messages.Values['ItemMaskDesc'];
          	Str:=Str+Chr(13)+Chr(10);
          	Str:=Str+Chr(13)+Chr(10);
          end;
          //-------------------------------------------------------------------

          //-------------------------------------------------------------------
          if Gametype.ShopItemAllowed[SHOP_ITEM_RADIO] then
          begin
          	Str:=Str+'2. [b]'+Messages.Values['ItemRadio']+'[/b] (Цена:'+IntToStr(radio_price)+') - предмет';
          	if (PlayersArr[i]^.use_mask=0) then
            	Str:=Str+'доступен для покупки'
          	else
            	if (PlayersArr[i]^.use_mask=1) then
              	Str:=Str+'будет использован этой ночью'
            	else
              	Str:=Str+'уже использован';
          	Str:=Str+Chr(13)+Chr(10);
          	Str:=Str+Messages.Values['ItemRadioDesc'];
          	Str:=Str+Chr(13)+Chr(10);
          	Str:=Str+Chr(13)+Chr(10);
          end;
          //-------------------------------------------------------------------

          Str:=Str+Messages.Values['ShopText'];
          PrivateMsg(User.Name, Str);
        end;
      end
      else
        PrivateMsg(User.Name, Messages.Values['ShopDisabled']);
      exit;
    end;

    if (Copy(Text,1,8) = '!купить ') and (State>1) and (State<>255) and (Gametype.UseShop) then
    begin
      i:=UserInGame(User.Name);
      if (i>0) and (PlayersArr[i]^.gamestate>0) then
      begin
        Text:=Copy(Text,9,Length(Text)-8);
        index := StrToIntDef(Text, 0);

        // Выход, если предмет неразрешен
        if (index > SHOP_ITEMS_COUNT) or (index < 0) or not Gametype.ShopItemAllowed[index] then
        	exit;

        case StrToIntDef(Text, 0) of
          SHOP_ITEM_MASK: begin
                if (PlayersArr[i]^.use_mask=0) then
                begin
                  if (PlayersArr[i]^.points>=mask_price) then
                  begin
                    PrivateMsg(User.Name,Messages.Values['ItemMaskBought']);
                    PlayersArr[i]^.use_mask:=1;
                    AddPoints(i, -mask_price);
                  end
                  else
                    PrivateMsg(User.Name,Messages.Values['ItemNotEnoughPoints']);
                end
                else
                  if (PlayersArr[i]^.use_mask=1) then
                    PrivateMsg(User.Name,Messages.Values['ItemAlreadyBought'])
                  else
                    PrivateMsg(User.Name,Messages.Values['ItemBoughtTwice']);
             end;

          SHOP_ITEM_RADIO: begin
                if (PlayersArr[i]^.use_radio=0) then
                begin
                  if (PlayersArr[i]^.points>=radio_price) then
                  begin
                    PrivateMsg(User.Name,Messages.Values['ItemRadioBought']);
                    PlayersArr[i]^.use_radio:=radio_nights+1;
                    AddPoints(i, -radio_price);
                  end
                  else
                    PrivateMsg(User.Name,Messages.Values['ItemNotEnoughPoints']);
                end
                else
                  if (PlayersArr[i]^.use_radio>1) then
                    PrivateMsg(User.Name,Messages.Values['ItemAlreadyBought'])
                  else
                    PrivateMsg(User.Name,Messages.Values['ItemBoughtTwice']);
             end;
        end;
      end;
      Exit;
    end;

  end;

  procedure onPersonalMsg(User: TUser; Text: String);
  begin
  end;

  procedure onUserJoinChannel(User: TUser; Channel: String);
  var
    b: Boolean;
  begin
    if State>0 then
    begin
      b:=(UserInGame(User.Name) > 0);
      if Channel=maf_chan then
      begin
        if b then
          b:=b and (GetPlayerTeam(UserInGame(User.Name)) = 2);
        if not b then
          PCorePlugin^.AddRestriction(BOT_NAME, 2, 3, 0, 0.003, User.Name, maf_chan, 'Не маф.');
      end;
      if Channel=y_chan then
      begin
        if b then
          b:=b and (GetPlayerTeam(UserInGame(User.Name)) = 4);
        if not b then
          PCorePlugin^.AddRestriction(BOT_NAME, 2, 3, 0, 0.003, User.Name, y_chan, 'Не якудза.');
      end;
    end;
  end;

  function LoadRoles():TRoleText;
  var
    I: Byte;
    Ini: TIniFile;
  begin
    Result[0,0]:='Труп'; Result[0,1]:='трупом'; Result[0,2]:='трупа'; Result[0,3]:='трупа';
    Result[1,0]:='Мирный гражданин'; Result[1,1]:='мирным гражданином'; Result[1,2]:='мирного гражданина'; Result[1,3]:='мирного гражданина';
    Result[2,0]:='Комиссар Каттани'; Result[2,1]:='комиссаром'; Result[2,2]:='комиссара'; Result[2,3]:='комиссара';
    Result[3,0]:='Путана'; Result[3,1]:='путаной'; Result[3,2]:='путану'; Result[3,3]:='путаны';
    Result[4,0]:='Судья'; Result[4,1]:='судьёй'; Result[4,2]:='судью'; Result[4,3]:='судьи';
    Result[5,0]:='Доктор'; Result[5,1]:='доктором'; Result[5,2]:='доктора'; Result[5,3]:='доктора';
    Result[6,0]:='Старейшина'; Result[6,1]:='старейшиной'; Result[6,2]:='старейшину'; Result[6,3]:='старейшины';
    Result[7,0]:='Горец'; Result[7,1]:='горцем'; Result[7,2]:='горца'; Result[7,3]:='горца';
    Result[8,0]:='Шериф'; Result[8,1]:='шерифом'; Result[8,2]:='шерифа'; Result[8,3]:='шерифа';
    Result[9,0]:='Бомж'; Result[9,1]:='бомжом'; Result[9,2]:='бомжа'; Result[9,3]:='бомжа';
    Result[51,0]:='Сержант'; Result[51,1]:='сержантом'; Result[51,2]:='сержанта'; Result[51,3]:='сержанта';

    Result[101,0]:='Маф'; Result[101,1]:='мафом'; Result[101,2]:='мафа'; Result[101,3]:='мафа';
    Result[102,0]:='Киллер'; Result[102,1]:='киллером'; Result[102,2]:='киллера'; Result[102,3]:='киллера';
    Result[103,0]:='Адвокат'; Result[103,1]:='адвокатом'; Result[103,2]:='адвоката'; Result[103,3]:='адвоката';
    Result[104,0]:='Подрывник'; Result[104,1]:='подрывником'; Result[104,2]:='подрывника'; Result[104,3]:='подрывника';

    Result[151,0]:='Якудза'; Result[151,1]:='якудзой'; Result[151,2]:='якудзу'; Result[151,3]:='якудзы';

    Result[201,0]:='Маньяк'; Result[201,1]:='маньяком'; Result[201,2]:='маньяка'; Result[201,3]:='маньяка';
    Result[202,0]:='Робин Гуд'; Result[202,1]:='Робин Гудом'; Result[202,2]:='Робин Гуда'; Result[202,3]:='Робин Гуда';
    Result[203,0]:='Грабитель'; Result[203,1]:='грабителем'; Result[203,2]:='грабителя'; Result[203,3]:='грабителя';
    Ini := TIniFile.Create(file_config);
    for i:=1 to 255 do
      if (i in setRoles) then
      begin
        Result[i,0]:=Ini.ReadString('MafiaRoles', 'Role_'+IntToStr(i)+'_0', Result[i,0]);
        Result[i,1]:=Ini.ReadString('MafiaRoles', 'Role_'+IntToStr(i)+'_1', Result[i,1]);
        Result[i,2]:=Ini.ReadString('MafiaRoles', 'Role_'+IntToStr(i)+'_2', Result[i,2]);
        Result[i,3]:=Ini.ReadString('MafiaRoles', 'Role_'+IntToStr(i)+'_3', Result[i,3]);
      end;
    Ini.Free;
  end;

  procedure LoadMessages();
  var
    Ini: TIniFile;
    I: Integer;
  begin
    Ini := TIniFile.Create(file_messages);
    Messages.Clear;
    Ini.ReadSectionValues('General',Messages);
    for I := 0 to Messages.Count - 1 do
      Messages.Strings[I]:=StringReplace(Messages.Strings[I], '%gamechan%', game_chan, [rfReplaceAll]);
    Ini.Free;
  end;

  procedure LoadSettings(LoadAll: Boolean=true);
  var
    Ini: TIniFile;
    i: Integer;
  begin
    // Заполнение текста
    RoleText:=LoadRoles();
		
    // Загрузка сообщений
    LoadMessages();

    Ini := TIniFile.Create(file_config);
    game_chan := Ini.ReadString('Mafia', 'Channel', 'мафия');
    help_chan := Ini.ReadString('Mafia', 'ChannelHelp', 'мафия (описание и правила)');
    for I := 1 to 8 do
      main_chan[I] := Ini.ReadString('Mafia', 'ChannelMain'+IntToStr(I), '');
    mask_price := Ini.ReadInteger('Mafia', 'MaskPrice', 20);
    radio_price := Ini.ReadInteger('Mafia', 'RadioPrice', 15);
    radio_nights := Ini.ReadInteger('Mafia', 'RadioNights', 1);
    if radio_nights>200 then
      radio_nights:=200;
    fast_game:= (Ini.ReadInteger('Mafia', 'FastGame', 1)>0);
    top_default:= Ini.ReadInteger('Mafia', 'TopDefault', 15);
    time_start := GetTimeFromStr(Ini.ReadString('Mafia', 'TimeStart', '60'));
    time_night := GetTimeFromStr(Ini.ReadString('Mafia', 'TimeNight', '60'));
    time_morning := GetTimeFromStr(Ini.ReadString('Mafia', 'TimeMorning', '25'));
    time_accept := GetTimeFromStr(Ini.ReadString('Mafia', 'TimeAccept', '30'));
    time_pause := Ini.ReadInteger('Mafia', 'TimePause', 1000);
    time_day := GetTimeFromStr(Ini.ReadString('Mafia', 'TimeDay', '60'));
    time_evening := GetTimeFromStr(Ini.ReadString('Mafia', 'TimeEvening', '20'));
    time_lastWord := GetTimeFromStr(Ini.ReadString('Mafia', 'TimeLastWord', '10'));
    time_ban:=Ini.ReadFloat('Mafia', 'TimeBan', 1.0);

    ip_filter:=(Ini.ReadInteger('Mafia', 'IPFilter', 0)>0);
    id_filter:=(PROG_TYPE=0) and (Ini.ReadInteger('Mafia', 'IDFilter', 0)>0);
    start_night:=(Ini.ReadInteger('Mafia', 'StartFromNight', 1)>0);
    show_night_actions:=(Ini.ReadInteger('Mafia', 'ShowNightActions', 1)>0);
    ban_on_death:=(PROG_TYPE=0) and (Ini.ReadInteger('Mafia', 'BanOnDeath', 1)>0);
    ban_private_on_death:=ban_on_death and (Ini.ReadInteger('Mafia', 'BanPrivateOnDeath', 0)>0);
    ban_reason:=Ini.ReadString('Mafia', 'BanReason', 'Выбывание из игры');
    ban_private_reason:=Ini.ReadString('Mafia', 'BanPrivateReason', 'Выбывание из игры');
    unban_reason:=Ini.ReadString('Mafia', 'UnbanReason', 'Окончание игры');

    topic_wait:=Ini.ReadString('Mafia', 'TopicWait', '');
    topic_play:=Ini.ReadString('Mafia', 'TopicPlay', '');
    topic_playergetting:=Ini.ReadString('Mafia', 'TopicPlayerGetting', '');

    stat_to_private:=(Ini.ReadInteger('Mafia', 'StatToPrivate', 0)>0);
    msg_send_type := Ini.ReadInteger('Mafia', 'MessagesType', 0);
    show_votepoints:=(Ini.ReadInteger('Mafia', 'ShowVotePoints', 0)>0);
    if msg_send_type>2 then
      msg_send_type:=0;

    changegametype_notify:= Ini.ReadInteger('Mafia', 'ChangeGametypeNotify', 1);
    changegametype_games:=Ini.ReadInteger('Mafia', 'ChangeGametypeGamesCount', 0);

    load_settings_on_start:=(Ini.ReadInteger('Mafia', 'ReloadSettingsOnStart', 1)>0);
    update_greeting:=(Ini.ReadInteger('Stats', 'UpdateGreeting', 0)=1);
    export_stats:=(Ini.ReadInteger('Stats', 'Export', 0)=1);
    file_export_stats:=Ini.ReadString('Stats', 'File', 'C:\MafStats.html');

    time_removeUsers := Ini.ReadInteger('Mafia', 'TimeRemoveUsers', 0);
    if (time_removeUsers < 1) then
    	time_removeUsers := 0;


    msg_format_begin:=Ini.ReadString('Mafia', 'MsgFormatBegin', '');
    msg_format_end:=Ini.ReadString('Mafia', 'MsgFormatEnd', '');
    if LoadAll then
      LoadGametype(Ini.ReadString('Mafia', 'DefaultGametype', 'Gametype_0'));

    i:=Ini.ReadInteger('Mafia', 'KillForNoActivity', 0);
    if (i>0) and (i<255) then
      kill_for_no_activity:=i
    else
      kill_for_no_activity:=255;
    
    for i:=1 to 255 do
    begin
      // Загрузка количества очков
      if Ini.ReadInteger('MafiaPoints', IntToStr(i), 0) > 255 then
        points_cost[i]:=255
      else
        if Ini.ReadInteger('MafiaPoints', IntToStr(i), 0) < -255 then
          points_cost[i]:=-255
        else
          points_cost[i]:=Ini.ReadInteger('MafiaPoints', IntToStr(i), 0);
    end;

    CreateChannel(game_chan, 1, 0);
    for I := 1 to 8 do
      if main_chan[I]<>'' then
         CreateChannel(main_chan[I], 1, 0);
    if PROG_TYPE=0 then
      ChangeState(Ini.ReadString('Mafia', 'BotState', 'Бот игры Мафия'));
    if LoadAll then
      ChangeGametype();
    Ini.Free;


  end;

  procedure ChangeGametype();
  begin
    if (changegametype_notify and 1) > 0 then
      ChangeTopic(game_chan, Gametype.Name);
    if (changegametype_notify and 2) > 0 then
      MsgToChannel(game_chan, StringReplace(Messages.Values['GametypeChanged'],'%text%',Gametype.Name,[rfReplaceAll]));
  end;

  procedure LoadGametype(GametypeName: String);
  var
    Ini: TIniFile;
    Sections: TStringList;
    I: Byte;
  begin
    Ini := TIniFile.Create(file_gametypes);
    if GametypeName='' then
    begin
      Sections:=TStringList.Create();
      Sections.Clear();
      Ini.ReadSections(Sections);

      I:=0;
      while I<Sections.Count-1 do
        if Ini.ReadString(Sections.Strings[I], 'Name', 'Обычная игра')=Gametype.Name then
          Sections.Delete(I)
        else
          Inc(I);

      GametypeName := Sections.Strings[Random(Sections.Count)];
      Sections.Free;
    end;

    Gametype.Name:=Ini.ReadString(GametypeName, 'Name', 'Обычная игра');

    Gametype.MinPlayers:=Ini.ReadInteger(GametypeName, 'MinPlayers', 6);
    if Gametype.MinPlayers<5 then
      Gametype.MinPlayers:=5;
    if Gametype.MinPlayers>100 then
      Gametype.MinPlayers:=100;

    Gametype.ShowRolesOnStart:=(Ini.ReadInteger(GametypeName, 'ShowRolesOnStart', 0)=1);
    Gametype.ShowNightComments:=(Ini.ReadInteger(GametypeName, 'ShowNightComments', 0)=1);
    Gametype.UseShop:=(Ini.ReadInteger(GametypeName, 'UseShop', 1)=1);
    Gametype.UseYakuza:=(Ini.ReadInteger(GametypeName, 'UseYakuza', 0)=1);
    Gametype.UseNeutral:=(Ini.ReadInteger(GametypeName, 'UseNeutral', 1)=1);
    Gametype.NeutralCanWin:=Gametype.UseNeutral and (Ini.ReadInteger(GametypeName, 'NeutralCanWin', 0)=1);
    Gametype.InstantCheck:=(Ini.ReadInteger(GametypeName, 'InstantCheck', 0)=1);
    Gametype.UseSpecialMaf:=not Gametype.UseYakuza and (Ini.ReadInteger(GametypeName, 'UseSpecialMaf', 1)=1);
    Gametype.PlayersForNeutral:=Ini.ReadInteger(GametypeName, 'PlayersForNeutral', 8);
    Gametype.ManiacCanUseCurse:=(Ini.ReadInteger(GametypeName, 'ManiacCanUseCurse', 1)=1);
    Gametype.InfectionChance:=Ini.ReadInteger(GametypeName, 'InfectionChance', 50);

    Gametype.MafCount:=Ini.ReadFloat(GametypeName, 'MafCount', 3);
    if Gametype.UseYakuza then
    begin
      if Gametype.MafCount<4 then
        Gametype.MafCount:=4;
    end
    else
      if Gametype.MafCount<2.5 then
        Gametype.MafCount:=2.5;

    Gametype.ComType:=Ini.ReadInteger(GametypeName, 'ComType', 0);
    if Gametype.ComType>2 then
      Gametype.ComType:=0;

    Gametype.ComKillManiac:=(Gametype.ComType=0) and (Ini.ReadInteger(GametypeName, 'ComKillManiac', 1)=1);

    Gametype.RandomHelpers:=Ini.ReadInteger(GametypeName, 'ComHelpers', 2);

    for i:=3 to 99 do
      if i in setRoles then
      begin
        Gametype.UseRole[i]:=Ini.ReadInteger(GametypeName, 'UseRole_'+IntToStr(i), 2);
        if Gametype.UseRole[i]>2 then
          Gametype.UseRole[i]:=1;
        Gametype.RoleMinPlayers[i]:=Ini.ReadInteger(GametypeName, 'RoleMinPlayers_'+IntToStr(i), 0);
        Gametype.RoleKnowCom[i]:=(Ini.ReadInteger(GametypeName, 'RoleKnowCom_'+IntToStr(i), 0)=1);
      end;

    for i:=102 to 255 do
      if (i in setRoles) and not (i in [101,151]) then
        Gametype.UseRole[i]:=Ini.ReadInteger(GametypeName, 'UseRole_'+IntToStr(i), 2);

    for i := 1 to SHOP_ITEMS_COUNT do
      Gametype.ShopItemAllowed[i] := (Ini.ReadInteger(GametypeName, 'ShopItemAllowed_'+IntToStr(i), 1)=1);

    Gametype.PlayersForSpecialMaf:=Ini.ReadInteger(GametypeName, 'PlayersForSpecialMaf', 12);
    if (Gametype.PlayersForSpecialMaf/Gametype.MafCount < 3) then
      Gametype.PlayersForSpecialMaf:=Trunc(Gametype.PlayersForSpecialMaf)+1;

    NightPlaces[0]:='Дом'; NightPlaces[1]:='Супермаркет'; NightPlaces[2]:='Стадион';

    Ini.Free;

    changegametype_current_games:=changegametype_games;
  end;

	procedure ClearOldUsers();
  var
    ini: TIniFile;
    sections: TStringList;
    i: Integer;
	begin
  	if time_removeUsers > 0 then
    begin
    	ini := TIniFile.Create(file_users);
      sections := TStringList.Create;
      ini.ReadSections(sections);
      for i := 0 to Sections.Count - 1 do
      begin
      	if (IncDay(ini.ReadDateTime(sections.Strings[i], 'LastPlay', 0), time_removeUsers) < Now) then
  				ini.EraseSection(sections.Strings[i]);
      end;
    	sections.Free;
      ini.Free;
    end;
	end;

  function Init():Integer;
  begin
    Result:=0;
    UpdateTopCriticalSection := TCriticalSection.Create;
    MafTimer:=TTimer.Create(nil);
    MafTimer.OnTimer:=TTimerUpdater.RefreshTimer;
    Messages := TStringList.Create;
    State:=0;
    PlayerCount:=0;
    LoadSettings();
    if (PROG_TYPE>0) and (PCorePlugin^.ClientAskRight(5, game_chan)=0) then
    begin
      MessageBox(0, PChar('У Вашей учётной записи нет прав на модерирование канала "'+game_chan+'". Для работы плагина необходимо получить эти права у администратора.'), '', 0);
      PCorePlugin^.StopPlugin();
    end;
    ClearOldUsers();
    UpdateStats();
  end;

  procedure Destroy();
  var
    i: Byte;
    Restrictions: TRestrictions;
    k, Count: DWord;
  begin
    while not UpdateTopCriticalSection.TryEnter do ;
    UpdateTopCriticalSection.Free;

    MafTimer.Enabled:=False;
    MafTimer.Free;
    Messages.Free;

    //MsgToChannel(game_chan, 'Мне пора в отпуск. Надеюсь, что ещё увидимся!');
    //ChangeTopic(game_chan, 'Бот оффлайн');
    if (State>0) then
      for i := 1 to PlayerCount do
      begin
        if PROG_TYPE=1 then
          PCorePlugin^.ClientLeavePrivate(PlayersArr[i]^.Name);
        Dispose(PlayersArr[i]);
      end;
    if (State>1) then
    begin
      QuitChannel(maf_chan);
      QuitChannel(y_chan);
      if PROG_TYPE=0 then
      begin
        CloseChannel(maf_chan);
        CloseChannel(y_chan);
      end;

      // Снятие ограничений
      if ban_on_death then
      begin
        Count:=PCorePlugin^.AskRestrictions(Restrictions);
        for k := 1 to Count do
        begin
          if Restrictions[k].moder=BOT_NAME then
            PCorePlugin^.RemoveRestriction(BOT_NAME, Restrictions[k].restID, unban_reason);
        end;
      end;
    end;

  end;

  procedure ResetTimer();
  begin
    MafTimer.Enabled := False;
    MafTimer.Enabled := True;
  end;

  procedure ResetTimerQ();
  var
    Ptr: Pointer;
    Buf: TBytes;
  begin
    SetLength(Buf, 4);
    Ptr:=@ResetTimer;
    CopyMemory(@Buf[0], @Ptr, 4);
    MsgQueue.InsertMsg(QUEUE_MSGTYPE_CALL, @Buf[0], 4);
    Buf:=nil;
  end;

  procedure NextCP();
  begin
    if (MafTimer.Enabled = True) then
    begin
      MafTimer.Enabled := False;
      TTimerUpdater.RefreshTimer(MafTimer);
    end;
  end;

  procedure CheckNextCP();
  var
    Flag: Boolean;
    i: Byte;
    target: TwoByte;
  begin
    Flag:=True;
    case State of
      2:  begin
        if not Gametype.InstantCheck or (SubState=1) then
        begin
          for i := 1 to PlayerCount do
            if ((i in [com_player,putana_player,doctor_player,sherif_player,homeless_player]) or (PlayersArr[i]^.gamestate in [7, 101..103, 151, 201..203])) and (PlayersArr[i]^.activity=0) then
              Flag:=False;
        end
        else
          if (putana_player>0) and (putana_state=0) then
            Flag:=False;
        if podrivnik_state=4 then
            Flag:=False;
      end;
      4:  begin
        for i := 1 to PlayerCount do
          if (PlayersArr[i]^.gamestate>0) and (PlayersArr[i]^.activity=0) or (PlayersArr[i]^.gamestate in [4,6]) and (PlayersArr[i]^.activity2=0) then
            Flag:=False;
      end;
      5:  begin
        target:=VoteResult();
        for i := 1 to PlayerCount do
          if (target[1]<>i) and (PlayersArr[i]^.gamestate>0) and (PlayersArr[i]^.voting=-1) then
            Flag:=False;
      end;
      else
        Flag:=False;
    end;
    if Flag then
      NextCP();
  end;

  class procedure TTimerUpdater.RefreshTimer(Sender : TObject);
  var
    Str: String;
  begin
    try
      Str:='----onTimer Exception----'+Chr(13)+Chr(10)+'State='+IntToStr(State);
      case State of
        0:  MafTimer.Enabled := False; //Мафия выключена
        1:  StopPlayerGetting();       //Закончился набор игроков
        2:  EndNight();                //Конец ночи
        3:  StartDay();                //Начало дня
        4:  EndDay();                  //Конец дня
        5:  EndEvening();              //Конец вечера
        else
          MafTimer.Enabled := False; //WTF
      end;
    except
      on e: exception do
      begin
        Str:=Str+'/'+IntToStr(State)+' SubState='+IntToStr(SubState)+MafiaDump()+Chr(13)+Chr(10);
        PCorePlugin^.onError(PCorePlugin^, e, Str);
      end;
    end;
  end;


  function UserInGame(Name: String):Byte;
  var i: byte;
  begin
    Result:=0;
    i:=1;
    while (Result=0) and (i<=PlayerCount) do
    begin
       if PlayersArr[i]^.Name=Name then Result:=i;
       i:=i+1;
    end;
  end;

  function IPInGame(IP: String):Byte;
  var i: byte;
  begin
    Result:=0;
    i:=1;
    while (Result=0) and (i<=PlayerCount) do
    begin
       if (PlayersArr[i]^.IP=IP) then Result:=i;
       i:=i+1;
    end;
  end;

  function IDInGame(ID: String):Byte;
  var i: byte;
  begin
    Result:=0;
    i:=1;
    while (Result=0) and (i<=PlayerCount) do
    begin
       if (PlayersArr[i]^.compID=ID) then Result:=i;
       i:=i+1;
    end;
  end;

  function IsUserModer(Name: String):Boolean;
  var
    Ini: TIniFile;
  begin
    Ini := TIniFile.Create(file_config);
    Result := (Ini.ReadInteger('Admins', Name, 0) > 0);
    Ini.Free;
  end;

  function VoteResult(): TwoByte;
  var
    i: Byte;
  begin
    Result[0]:=0;
    Result[1]:=0;
    for i:=1 to PlayerCount do
    begin
      if Voting[i]>Result[0] then
      begin
        Result[1]:=i;
        Result[0]:=Voting[i];
      end
      else
        if Voting[i]=Result[0] then
          Result[1]:=0;
    end;
  end;

  function Vote2Result(): TwoByte;
  var
    i: Byte;
  begin
    Result[0]:=0;
    Result[1]:=0;
    for i:=1 to PlayerCount do
    begin
      if Voting2[i]>Result[0] then
      begin
        Result[1]:=i;
        Result[0]:=Voting2[i];
      end
      else
        if Voting2[i]=Result[0] then
          Result[1]:=0;
    end;
  end;

  function CancelActivity(id: Byte; announce: Boolean=True): Boolean;
  begin
    Result:=False;

    if (id>0) and (PlayersArr[id]^.gamestate>0) and (PlayersArr[id]^.activity>0) then
    begin
      //-------------------------Ночь---------------------------------------
      if (State=2) then
      begin

        if announce and Gametype.InstantCheck and (
            (PlayersArr[id]^.gamestate in [9,103]) or (PlayersArr[id]^.gamestate in [2,51]) and (com_state<>5)
          )
        then
          Exit;
        if announce then
           NightActionCancel(PlayersArr[id]^.gamestate);
        //-------------------------Комиссар--------------------------------
        if (com_player=id) and not(Gametype.InstantCheck and (SubState<>1) and (SubState<>2)) then
        begin
          com_state:=1;
          com_target:=0;
          com_phrase:='';
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

        //-------------------------Путана----------------------------------
        if (putana_player=id) and not(Gametype.InstantCheck and (SubState<>0) and (SubState<>2)) then
        begin
          putana_state:=1;
          putana_target:=0;
          putana_phrase:='';
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

        //-------------------------Доктор----------------------------------
        if doctor_player=id then
        begin
          doctor_state:=1;
          doctor_target:=0;
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

        //-------------------------Горец----------------------------------
        if PlayersArr[id]^.gamestate=7 then
        begin
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

        //-------------------------Шериф----------------------------------
        if sherif_player=id then
        begin
          sherif_state:=1;
          sherif_target:=0;
          sherif_phrase:='';
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

        //-------------------------Бомж------------------------------------
        if (homeless_player=id) and not(Gametype.InstantCheck and (SubState<>1) and (SubState<>2)) then
        begin
          homeless_state:=1;
          homeless_target:=0;
          homeless_phrase:='';
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

        //-------------------------Мафф------------------------------------
        if PlayersArr[id]^.gamestate=101 then
        begin
          Dec(Voting[PlayersArr[id]^.activity]);
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

        //-------------------------Киллер----------------------------------
        if killer_player=id then
        begin
          killer_state:=1;
          killer_target:=0;
          killer_phrase:='';
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

        //-------------------------Адвокат-----------------------------------
        if (lawyer_player=id) and not(Gametype.InstantCheck and (SubState<>1) and (SubState<>2)) then
        begin
          lawyer_state:=1;
          lawyer_target:=0;
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

        //-------------------------Якудза----------------------------------
        if PlayersArr[id]^.gamestate=151 then
        begin
          Dec(Voting2[PlayersArr[id]^.activity]);
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

        //-------------------------Маньяк----------------------------------
        if maniac_player=id then
        begin
          maniac_state:=1;
          maniac_target:=0;
          maniac_phrase:='';
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

        //-------------------------Робин Гуд-------------------------------
        if robin_player=id then
        begin
          robin_state:=1;
          robin_target:=0;
          robin_phrase:='';
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

        //-------------------------Грабитель-------------------------------
        if robber_player=id then
        begin
          robber_state:=1;
          robber_target:=0;
          robber_phrase:='';
          PlayersArr[id]^.activity:=0;
          Result:=True;
          exit;
        end;
        //-----------------------------------------------------------------

      end;
      //--------------------------------------------------------------------

      //----------------------Голосование днем------------------------------
      if (State=4) and (SubState = 0) then
      begin
        Dec(Voting[PlayersArr[id]^.activity]);
        PlayersArr[id]^.activity:=0;
        Result:=True;
      end;
      //--------------------------------------------------------------------

    end;
  end;

  procedure StartPlayerGetting(Time: Word);
  var
    Ini: TIniFile;
    i, Count: Dword;
    k: Byte;
    Flag: Boolean;
    Users: TUsers;
    Channels: TChannels;
  begin
    if State<>0 then exit;
    if load_settings_on_start then
       LoadSettings(false);
    if (changegametype_games > 0) then
    begin
      if (changegametype_current_games = 0) then
      begin
        LoadGametype();
        ChangeGametype();
      end;
      if (changegametype_notify and 1) >0 then
        ChangeTopic(game_chan, Gametype.Name+' Осталось '+IntToStr(changegametype_current_games)+' игр до смены режима игры.');
      if (changegametype_notify and 2) > 0 then
        MsgToChannel(game_chan, 'Осталось '+IntToStr(changegametype_current_games)+' игр до смены режима игры.');
    end;
    for I := 1 to 8 do
      if main_chan[I]<>'' then
         MsgToChannel(main_chan[I], Messages.Values['AnnounceText']);
    if PROG_TYPE=0 then
    begin
      Ini:=TIniFile.Create(file_config);
      ChangeState(Ini.ReadString('Mafia', 'BotStatePlayerGetting', Ini.ReadString('Mafia', 'BotState', 'Бот игры Мафия')));
      Ini.Free;
    end;
    if topic_playergetting<>'' then
      ChangeTopic(game_chan, topic_playergetting);
    MsgToChannel(game_chan, Messages.Values['GameStart']);
    MafTimer.Interval:=Cardinal(Time)*1000;
    ResetTimerQ();
    State:=1;
    PlayerCount:=0;
    SubState:=1;

    // Выход из лишних каналов
    if PROG_TYPE=0 then
    begin
      Count := PCorePlugin^.AskUserChannels(BOT_NAME, Channels);
      for i := 1 to Count do
      begin
        Flag:=False;
        for k := 1 to 8 do
          if Channels[i].Name = main_chan[k] then
            Flag:=True;
        if not ((Channels[i].Name = game_chan) or Flag) then
          QuitChannel(Channels[i].Name);
      end;
    end;

    // Отправка ЛС
    Ini:=TIniFile.Create(file_users);
    Count := PCorePlugin^.AskUsersInChannel(BOT_NAME,game_chan, Users);
    k:=40;  // Ограничиваем количество отправляемых сообщений (нагрузка на сервер)
    i:=1;
    while (i <= Count) and (k > 0) do
    begin
      if (Ini.ReadInteger(CheckStr(Users[i].Name), 'announce', 0)=1) then
      begin
        Dec(k);
        PersonalMsg(Users[i].Name, Messages.Values['AnnounceTextPM']+Chr(13)+Chr(10)+'Если не хотите получать это сообщение в дальнейшем, ответьте на это сообщение словом "отстань" (без кавычек).');
      end;
      Inc(i);
    end;
    Users:=nil;
    Ini.Free;
  end;

  procedure KillPlayer2(id: Byte);
  begin
    if id=com_player then
    begin
      com_state:=0;
      com_player:=0;
      if (serj_player>0) then
        if PlayersArr[serj_player]^.gamestate>0 then
        begin
          com_state:=1;
          com_player:=serj_player;
          serj_player:=0;
          PrivateMsg(PlayersArr[com_player]^.Name, StringReplace(Messages.Values['SgtComKilled'],'%text%',RoleText[2, 0],[rfReplaceAll]));
        end;
    end;

    if id=putana_player then
    begin
      putana_state:=0;
      putana_player:=0;
    end;

    if id=judge_player then
    begin
      judge_state:=0;
      judge_player:=0;
    end;

    if id=serj_player then
      serj_player:=0;

    if id=doctor_player then
    begin
      doctor_player:=0;
      doctor_state:=0;
    end;

    if id=sherif_player then
    begin
      sherif_player:=0;
      sherif_state:=0;
    end;

    if id=homeless_player then
    begin
      homeless_player:=0;
      homeless_state:=0;
    end;

    if id=killer_player then
    begin
      killer_player:=0;
      killer_state:=0;
    end;

    if id=lawyer_player then
    begin
      lawyer_player:=0;
      lawyer_state:=0;
    end;

    if id=podrivnik_player then
    begin
      podrivnik_player:=0;
      podrivnik_state:=0;
    end;

    if id=maniac_player then
    begin
      maniac_player:=0;
      maniac_state:=0;
    end;

    if id=robin_player then
    begin
      robin_player:=0;
      robin_state:=0;
    end;

    if id=robber_player then
    begin
      robber_player:=0;
      robber_state:=0;
    end;

    PlayersArr[id]^.gamestate:=0;
  end;

  procedure ApplyBans();
  var
    i: Byte;
    BanType: Byte;
    Ini: TIniFile;
  begin
    Ini:=TIniFile.Create(file_users);

    // --- Страшный алгоритм рассчета типа идентификатора, не прикасайтесь------
    BanType:=1;
    if ip_filter then
      BanType:=BanType or 2;
    if id_filter then
      BanType:=BanType or 4;
    if BanType in [3,4] then
      BanType:= 7 - BanType;
    BanType:=BanType+2;
    // -------------------------------------------------------------------------

    for i:=1 to PlayerCount do
      if PlayersArr[i]^.died=1 then
      begin
        PlayersArr[i]^.died:=0;
        if ban_on_death then
        begin
          PCorePlugin^.AddRestriction(BOT_NAME, 3, BanType, 0, time_ban, PlayersArr[i]^.Name, game_chan, ban_reason);
          PCorePlugin^.AddRestriction(BOT_NAME, 3, BanType, 0, time_ban, PlayersArr[i]^.Name, maf_chan, ban_reason);
          if Gametype.UseYakuza then
            PCorePlugin^.AddRestriction(BOT_NAME, 3, BanType, 0, time_ban, PlayersArr[i]^.Name, y_chan, ban_reason);
          if ban_private_on_death then
            PCorePlugin^.AddRestriction(BOT_NAME, 1, 3, 0, time_ban, PlayersArr[i]^.Name, '', ban_private_reason);
        end;

        // Отправка сообщения о смерти
        if Ini.ReadInteger(CheckStr(PlayersArr[i]^.Name), 'dmess', 1)=1 then
          PrivateMsg(PlayersArr[i]^.Name, Messages.Values['YouKilled']);
      end;
    Ini.Free;

  end;

  procedure ApplyKills();
  var
    i: byte;
  begin
    for i:=1 to PlayerCount do
      if (PlayersArr[i]^.died=1) and (PlayersArr[i]^.gamestate>0) then
        KillPlayer2(i)
      else                    // Уже был убит
        PlayersArr[i]^.died:=0
  end;

  procedure KillPlayer(id: Byte);
  begin
    PlayersArr[id]^.died:=1;
  end;

  procedure StopPlayerGetting();
  var
    RoleArr: array [1..255] of Byte;
    i, j, k, mafCount: byte;
    Str, Str1: String;
    Ini: TIniFile;
  begin
    if State<>1 then exit;
    if PlayerCount<Gametype.MinPlayers then //Недостаточно игроков
    begin
      Inc(SubState);
      MsgToChannel(game_chan,
        StringReplace(
          StringReplace(Messages.Values['NotEnoughPlayers'],'%current%',IntToStr(PlayerCount), [rfReplaceAll]),
          '%need%',IntToStr(Gametype.MinPlayers), [rfReplaceAll]
        )
      );
      if (SubState<3) and (PlayerCount>Gametype.MinPlayers-3) then
        MsgToChannel(game_chan, GetRandomTextFromIni(file_messages, 'NotEnoughPlayers')+' Соберите '+IntToStr(Gametype.MinPlayers)+' человек:)')
      else
      begin
        for i:=1 to PlayerCount do
          Dispose(PlayersArr[i]);
        PlayerCount:=0;
        State:=0;
        if PROG_TYPE=0 then
        begin
          Ini:=TIniFile.Create(file_config);
          ChangeState(Ini.ReadString('Mafia', 'BotState', 'Бот игры Мафия'));
          Ini.Free;
        end;
        if topic_wait<>'' then
          ChangeTopic(game_chan, topic_wait);
      end;
    end
    else
     begin
      if SubState<3 then
      begin
        MafTimer.Enabled:=False;
        State:=255;
        SubState:=4;
        if PROG_TYPE=0 then
        begin
          Ini:=TIniFile.Create(file_config);
          ChangeState(Ini.ReadString('Mafia', 'BotStatePlay', Ini.ReadString('Mafia', 'BotState', 'Бот игры Мафия')));
          Ini.Free;
        end;
        if topic_play<>'' then
          ChangeTopic(game_chan, topic_play);
        MsgToChannel(game_chan, Messages.Values['RegistrationFinished']);
        Pause(time_pause);
        Ini:=TIniFile.Create(file_data);
        if (Ini.ReadInteger('Global','MaxPlayers',0)<PlayerCount) then
        begin
          Ini.WriteInteger('Global','MaxPlayers',PlayerCount);
          Ini.WriteDateTime('Global','MaxPlayersDateTime',Now);					
        end;
        Ini.Free;

        com_phrase:='';
        maf_phrase:=''; y_phrase:='';

        putana_player:=0;
        putana_state:=0;
        putana_phrase:='';

        judge_player:=0;
        judge_state:=0;
        judge_phrase:='';

        serj_player:=0;

        doctor_player:=0;
        doctor_state:=0;
        doctor_heals_himself:=0;

        sherif_player:=0;
        sherif_state:=0;
        sherif_phrase:='';

        homeless_player:=0;
        homeless_state:=0;
        homeless_phrase:='';

        killer_player:=0;
        killer_state:=0;
        killer_phrase:='';

        lawyer_player:=0;
        lawyer_state:=0;

        podrivnik_player:=0;
        podrivnik_state:=0;

        maniac_player:=0;
        maniac_state:=0;
        maniac_use_curse:=0;
        maniac_phrase:='';

        robin_player:=0;
        robin_state:=0;
        robin_phrase:='';

        robber_player:=0;
        robber_state:=0;
        robber_phrase:='';

        Randomize();
        maf_chan:='логово-'+IntToStr(Random(15531));
        y_chan:='логово_я-'+IntToStr(Random(15531));
        CreateChannel(maf_chan, 0, 0);
        if Gametype.UseYakuza then
          CreateChannel(y_chan, 0, 0);

        mafCount:=Trunc(PlayerCount / Gametype.MafCount);

        if Gametype.UseYakuza then
          i:=PlayerCount-2*mafCount-1
        else
          i:=PlayerCount-mafCount-1;

        if Gametype.UseNeutral and (PlayerCount>=Gametype.PlayersForNeutral) then
          Dec(i);

        if Gametype.UseSpecialMaf and (PlayerCount>=Gametype.PlayersForSpecialMaf) and not Gametype.UseYakuza then
          mafCount:=mafCount-1;


        com_player:=AddRole(2); //Комиссар
        com_state:=1;

        RandomRole(i);       //Второстепенные роли

        for i:=1 to mafCount do
          AddRole(101); //Мафы

        if Gametype.UseYakuza then
          for i:=1 to mafCount do
            AddRole(151); //Яки

      end;
      if (time_accept>0) and (SubState=4) then
      begin
        MafTimer.Enabled:=False;
        SubState:=5;
        for i:=1 to PlayerCount do
        begin
          PrivateMsg(PlayersArr[i]^.Name, StringReplace(Messages.Values['YourPreStatus'],'%text%',RoleText[PlayersArr[i]^.gamestate,0], [rfReplaceAll]));
          RoleAccept[i]:=0;
        end;
        Pause(time_pause);
        for i:=1 to PlayerCount do
          if PlayersArr[i]^.gamestate>1 then
            PrivateMsg(PlayersArr[i]^.Name, Messages.Values['RoleAcceptText'])
          else
            PrivateMsg(PlayersArr[i]^.Name, Messages.Values['RoleAcceptNotReq']);

        MsgToChannel(game_chan, StringReplace(Messages.Values['RoleAcceptTime'],'%text%',IntToStr(time_accept),[rfReplaceAll]));
        State:=1;
        MafTimer.Interval:=time_accept*1000;
        ResetTimerQ();
      end
      else if (time_accept=0) or (SubState=5) then
      begin
        MafTimer.Enabled:=False;
        SubState:=6;
        // Перераспределение неподтверждённых ролей
        if (time_accept>0) then
        begin
          mafCount:=0; // Здесь используется как счетчик мирных
          k:=0;
          for i:=1 to PlayerCount do
            if PlayersArr[i]^.gamestate=1 then
            begin
              Inc(mafCount);
              RoleAccept[i]:=1;
            end
            else if RoleAccept[i]=0 then
            begin
              Inc(k);
              RoleArr[k]:=i;
            end;

          i:=k;
          while i > 0 do
          begin
            k:=Random(i)+1;
            if Gametype.ShowRolesOnStart then
            begin
              MsgToChannel(game_chan, GetRandomTextFromIni(file_messages, 'RejectRole_'+IntToStr(playersArr[RoleArr[k]]^.gamestate)));
              Pause(time_pause);
            end;
            for j := k to i-1 do
              RoleArr[j]:=RoleArr[j+1];
            Dec(i);
          end;


          // Отдаём роли "спящих" мирным
          i:=1;
          while (i<=PlayerCount) and (MafCount>0) do
          begin
            if RoleAccept[i]=0 then
            begin
              Dec(mafCount);
              AddRandomRole(PlayersArr[i]^.gamestate);
              if Gametype.ShowRolesOnStart then
              begin
                MsgToChannel(game_chan, GetRandomTextFromIni(file_messages, 'AcceptRole_'+intToStr(playersArr[i]^.gamestate)));
                Pause(time_pause);
              end;
              PlayersArr[i]^.gamestate:=1;
            end;
            Inc(i);
          end;
        end;

        Ini:=TIniFile.Create(file_users);
        for i:=1 to PlayerCount do
        begin
          PlayersArr[i]^.gamestate_start:=PlayersArr[i]^.gamestate;

          Str:=GetRandomTextReplaceRole('GameStart_Role_'+IntToStr(PlayersArr[i]^.gamestate), i);
          if Str='' then
            PrivateMsg(PlayersArr[i]^.Name, 'Ваш статус [b]'+RoleText[PlayersArr[i]^.gamestate,0]+'[/b]')
          else
            PrivateMsg(PlayersArr[i]^.Name, Str);
          Ini.WriteInteger(CheckStr(PlayersArr[i]^.name), 'role_'+IntToStr(PlayersArr[i]^.gamestate), Ini.ReadInteger(CheckStr(PlayersArr[i]^.name), 'role_'+IntToStr(PlayersArr[i]^.gamestate), 0)+1);
          Ini.WriteDateTime(CheckStr(PlayersArr[i]^.name), 'LastPlay', Now);
          Ini.DeleteKey(CheckStr(PlayersArr[i]^.name), 'LeaveCount');
        end;
        Ini.Free;
        Pause(time_pause);

        //-----------------Для мафов------------------------------
        Str:='Состав мафии:'+Chr(13)+Chr(10);
        for i:=1 to PlayerCount do
          if getPlayerTeam(i)=2 then
            Str:=Str+FormatNick(PlayersArr[i]^.Name)+' - [b]'+RoleText[PlayersArr[i]^.gamestate,0]+'[/b]'+Chr(13)+Chr(10);
        Str:=Str+'Можете обсуждать свои действия в привате или логове.';
        Str:=Str+' [url=/channel:'+maf_chan+']Ваше логово[/url]';
        //--------------------------------------------------------

        //-----------------Для яков------------------------------
        if Gametype.UseYakuza then
        begin
          Str1:='Состав якудзы:'+Chr(13)+Chr(10);
          for i:=1 to PlayerCount do
            if getPlayerTeam(i)=4 then
              Str1:=Str1+FormatNick(PlayersArr[i]^.Name)+' - [b]'+RoleText[PlayersArr[i]^.gamestate,0]+'[/b]'+Chr(13)+Chr(10);
          Str1:=Str1+'Можете обсуждать свои действия в привате или логове.';
          Str1:=Str1+' [url=/channel:'+y_chan+']Ваше логово[/url]';
        end;
        //--------------------------------------------------------

        //-----------------Отправка приватов----------------------
        for i:=1 to PlayerCount do
          if getPlayerTeam(i)=2 then
            PrivateMsg(PlayersArr[i]^.Name, Str)
          else
            if getPlayerTeam(i)=4 then
              PrivateMsg(PlayersArr[i]^.Name, Str1)
            else
              if (PlayersArr[i]^.gamestate>2) and (PlayersArr[i]^.gamestate<100) and
                Gametype.RoleKnowCom[PlayersArr[i]^.gamestate] then
                begin
                  PrivateMsg(PlayersArr[i]^.Name, 'Статус '+ FormatNick(PlayersArr[com_player]^.Name)
                                            +' - [b]'+ RoleText[2,0]+'[/b]');
                  PrivateMsg(PlayersArr[com_player]^.Name, 'Статус '+ FormatNick(PlayersArr[i]^.Name)
                                            +' - [b]'+ RoleText[PlayersArr[i]^.gamestate,0]+'[/b]');
                end;
        //--------------------------------------------------------
        Pause(time_pause);

        //----------------Вывод начальной статистики--------------
        if Gametype.ShowRolesOnStart then
        begin
          Str:='Сегодня в нашем городе замечены:';
          fillChar(RoleArr, 255, 0);
          for i:=1 to PlayerCount do
            Inc(RoleArr[PlayersArr[i]^.gamestate]);
          for i := 1 to 255 do
            if RoleArr[i]>1 then
              Str:=Str+' [url]'+RoleText[i, 0]+'[/url] ('+IntToStr(RoleArr[i])+' человек) ,'
            else
              if RoleArr[i]=1 then
                Str:=Str+' [url]'+RoleText[i, 0]+'[/url],';
          Str[Length(Str)]:='.';
          Pause(time_pause);
          StatusToChannel(game_chan, Str);
        end;
        //--------------------------------------------------------

        if start_night then
          StartNight()
        else
          StartMorning();
      end;
    end;
end;

  procedure JoinPlayer(User: TUser);
  var
    Str: String;
  begin
    if (State=1) and (SubState<3) then
      if (UserInGame(User.Name)=0) and
        not (ip_filter and (User.IP<>'N/A') and (IPInGame(User.IP)>0)) and
        not (id_filter and (IDInGame(PCorePlugin^.AskID(User.Name))>0))
      then
      begin
        if PlayerCount>254 then
          Exit;
        Inc(PlayerCount);
        New(PlayersArr[PlayerCount]);
        PlayersArr[PlayerCount]^.name:=User.Name;
        PlayersArr[PlayerCount]^.IP:=User.IP;
        PlayersArr[PlayerCount]^.compID:=PCorePlugin^.AskID(User.Name);
        PlayersArr[PlayerCount]^:=GetMoreData(PlayersArr[PlayerCount]^);
        PlayersArr[PlayerCount]^.pol:=User.sex;
        PlayersArr[PlayerCount]^.gamestate:=1;
        PlayersArr[PlayerCount]^.gamepoints:=0;
        PlayersArr[PlayerCount]^.activity2:=0;
        PlayersArr[PlayerCount]^.lastactivity:=0;
        PlayersArr[PlayerCount]^.use_mask:=0;
        PlayersArr[PlayerCount]^.use_radio:=0;
        PlayersArr[PlayerCount]^.died:=0;
        PlayersArr[PlayerCount]^.delayedDeath:=0;
        PlayersArr[PlayerCount]^.no_activity_days:=kill_for_no_activity;
        if User.sex=0 then
          Str:=' присоединился '
        else
          Str:=' присоединилась ';
        MsgToChannel(game_chan, '[b]'+User.Name+'[/b]'+Str+' к игре ('+IntToStr(PlayerCount)+')');
      end;
  end;

  procedure LeavePlayer(User: TUser);
  var
    Str: String;
    i  : Byte;
    UserNum: Byte;
    LeaveCount: Byte;
    Ini: TIniFile;
  begin
    if (State=1) and (SubState<3) then
    begin
      UserNum:=UserInGame(User.Name);
      if UserNum>0 then
      begin
        Ini:=TIniFile.Create(file_users);
        LeaveCount:=Ini.ReadInteger(CheckStr(User.Name), 'LeaveCount', 0);
        Inc(LeaveCount);
        if LeaveCount<=2 then
        begin
          for i:=UserNum+1 to PlayerCount do
            PlayersArr[i-1]^:=PlayersArr[i]^;
          Dispose(PlayersArr[PlayerCount]);
          Dec(PlayerCount);

          if User.sex=0 then
            Str:=' вышел '
          else
            Str:=' вышла ';
          MsgToChannel(game_chan, '[b]'+User.Name+'[/b]'+Str+' из игры ('+IntToStr(PlayerCount)+')');
          Ini.WriteInteger(CheckStr(User.Name), 'LeaveCount', LeaveCount);
        end;
        Ini.Free;
      end;
    end;
  end;

  function AddRole(Role: Byte): Byte;
  var
    i,k: Byte;
  begin
    Result:=0;
    k:=1+Random(254);
    i:=0;
    while k>0 do
    begin
      i:=i mod PlayerCount + 1;
      while PlayersArr[i]^.gamestate>1 do
        i:=i mod PlayerCount + 1;
      k:=k-1;
      if k=0 then
      begin
        PlayersArr[i]^.gamestate:=Role;
        Result:=i;
      end
    end;
  end;

  procedure RandomRole(peacePlayerCount: Byte);
  var
    i, k, j, role: Byte;
    RandomRoles: array[1..96] of Byte;
  begin
    //------------Мирные-------------
    k:=0;
    for i:=3 to 99 do
      if (i in setRoles) and (peacePlayerCount>0) then
        if (Gametype.UseRole[i]=2) and (PlayerCount>=Gametype.RoleMinPlayers[i]) then
        begin
          AddRandomRole(i);
          peacePlayerCount:=peacePlayerCount-1;
        end
        else
          if (Gametype.UseRole[i]=1) and (PlayerCount>=Gametype.RoleMinPlayers[i]) then
          begin
            Inc(k);
            RandomRoles[k]:=i;
          end;

    //-----Случайные роли------------
    i:=0;
    while (peacePlayerCount > 0) and (i<Gametype.RandomHelpers) and (k>0) do
    begin
      role:=Random(k)+1;
      Inc(i);
      Dec(k);
      Dec(peacePlayerCount);
      AddRandomRole(RandomRoles[role]);
      for j:=role to k do
        RandomRoles[j]:=RandomRoles[j+1];
    end;

    //------------Нейтрал------------
    k:=0;
    if Gametype.UseNeutral and (PlayerCount>=Gametype.PlayersForNeutral) then
    begin
      for i:=201 to 255 do
        if (i in setRoles) and (Gametype.UseRole[i]>0) then
        begin
          Inc(k);
          RandomRoles[k]:=i;
        end;
      if (k>0) then
        AddRandomRole(RandomRoles[Random(k)+1]);
    end;
    //-------------------------------

    //------------Спецмаф------------
    k:=0;
    if Gametype.UseSpecialMaf and (PlayerCount>=Gametype.PlayersForSpecialMaf) and not Gametype.UseYakuza then
    begin
      for i:=102 to 149 do
        if (i in setRoles) and (Gametype.UseRole[i]>0) then
        begin
          Inc(k);
          RandomRoles[k]:=i;
        end;
      if (k>0) then
        AddRandomRole(RandomRoles[Random(k)+1]);
    end;
    //-------------------------------
  end;

  procedure AddRandomRole(Role: Byte);
  begin
    case Role of

      2:begin
          com_player:=AddRole(2);
          com_state :=1;
        end;

      3:begin
          putana_player:=AddRole(3);
          putana_state :=1;
        end;

      4:begin
          judge_player:=AddRole(4);
          judge_state :=1;
        end;

      5:begin
          doctor_player:=AddRole(5);
          doctor_state :=1;
        end;

      1, 6, 7, 101, 151:AddRole(Role);

      8:begin
          sherif_player:=AddRole(8);
          sherif_state :=1;
        end;

      9:begin
          homeless_player:=AddRole(9);
          homeless_state :=1;
        end;

      51:serj_player:=AddRole(51);

      102:begin
          killer_player:=AddRole(102);
          killer_state :=1;
        end;

      103:begin
          lawyer_player:=AddRole(103);
          lawyer_state :=1;
        end;

      104:begin
          podrivnik_player:=AddRole(104);
          podrivnik_state :=1;
        end;


      201:begin
          maniac_player:=AddRole(201);
          maniac_state :=1;
        end;

      202:begin
          robin_player:=AddRole(202);
          robin_state :=1;
        end;

      203:begin
          robber_player:=AddRole(203);
          robber_state :=1;
        end;

    end;
  end;

  procedure Win(Team: Byte);
  {
    0: Ничья
    1: Мирные
    2: Мафы
    3: Нейтральный
    4: Якудза
  }
  var
    i: Byte;
    wintext, Str: String;
    Ini: TIniFile;
    Restrictions: TRestrictions;
    k, Count: Dword;
  begin
    State:=0;
    Ini:=TIniFile.Create(file_users);
    //-------------------Начисление очков--------------
    if Team<>0 then
    begin
      for i:=1 to PlayerCount do
        if getPlayerTeam(i)=Team then
        begin
          AddPoints(i, points_cost[1]);
          Ini.WriteInteger(CheckStr(PlayersArr[i]^.name), 'wins', Ini.ReadInteger(CheckStr(PlayersArr[i]^.name), 'wins', 0)+1);
        end;
    end
    else
      for i:=1 to PlayerCount do
        if PlayersArr[i]^.gamestate>0 then
        begin
          AddPoints(i, points_cost[2]);
          Ini.WriteInteger(CheckStr(PlayersArr[i]^.name), 'draws', Ini.ReadInteger(CheckStr(PlayersArr[i]^.name), 'draws', 0)+1);
        end;

    //-------------------Подведение итогов-------------
    case Team of
      0,1,2,4: wintext:='Win_'+IntToStr(Team);
      3: if (maniac_state>0) then
           wintext:='Win_Maniac'
         else
          if (robin_state>0) then
            wintext:='Win_Robin'
          else
            wintext:='Win_3';
    end;
    MsgToChannel(game_chan,'[b]'+Messages.Values[wintext]+'[/b]');
    MsgToChannel(game_chan,Messages.Values['PointsForGame']);

    for i:=1 to PlayerCount do
    begin
      PlayersArr[i]^.points:=PlayersArr[i]^.points+PlayersArr[i]^.gamepoints;
      Str:=PlayersArr[i]^.name+' '
             +IntToStr(PlayersArr[i]^.gamepoints)
             +' ('+IntToStr(PlayersArr[i]^.points)+') - [b]'+RoleText[PlayersArr[i]^.gamestate_start,0]+'[/b]';
      if (PlayersArr[i]^.gamestate = 0) then
        Str:=Str+' ('+RoleText[PlayersArr[i]^.gamestate,0]+')';
      MsgToChannel(game_chan, Str);
      //------------------Запись в БД----------------------------------------
      Ini.WriteInteger(CheckStr(PlayersArr[i]^.name), 'plays', Ini.ReadInteger(CheckStr(PlayersArr[i]^.name), 'plays', 0)+1);
      Ini.WriteInteger(CheckStr(PlayersArr[i]^.name), 'points', Ini.ReadInteger(CheckStr(PlayersArr[i]^.name), 'points', 0)+PlayersArr[i]^.gamepoints);
      //---------------------------------------------------------------------
    end;
    for i:=1 to PlayerCount do
    begin
      if PROG_TYPE=1 then
        PCorePlugin^.ClientLeavePrivate(PlayersArr[i]^.Name);
      Dispose(PlayersArr[i]);
    end;
    PlayerCount:=0;
    QuitChannel(maf_chan);
    QuitChannel(y_chan);
    if PROG_TYPE=0 then
    begin
      CloseChannel(maf_chan);
      CloseChannel(y_chan);
    end;

    // Снятие ограничений
    if ban_on_death then
    begin
      Count:=PCorePlugin^.AskRestrictions(Restrictions);
      for k := 1 to Count do
      begin
        if Restrictions[k].moder=BOT_NAME then
          PCorePlugin^.RemoveRestriction(BOT_NAME, Restrictions[k].restID, unban_reason);
      end;
    end;

    // Уменьшение количества оставшихся игр для текущего режима
    if changegametype_games>0 then
      Dec(changegametype_current_games);

    if PROG_TYPE=0 then
    begin
      Ini:=TIniFile.Create(file_config);
      ChangeState(Ini.ReadString('Mafia', 'BotState', 'Бот игры Мафия'));
      Ini.Free;
    end;
    if topic_wait<>'' then
      ChangeTopic(game_chan, topic_wait);

    UpdateStats();
  end;

  function CheckWin(State:Byte):Boolean;
  var
    Flag, Flag2, Flag3: Boolean;
    i: byte;
  begin
    Result:=True;

    //-----------------Ничья (0 игроков) ----------------------
    Flag:=True;
    for i:=1 to PlayerCount do
      if (getPlayerTeam(i)<>0) then
        Flag:=False;
    if Flag then
    begin
      Win(0);
      exit;
    end;
    //-----------------------------------------------------

    //-----------------Победа нейтрала----------------------
    Flag:=True;
    for i:=1 to PlayerCount do
      if (getPlayerTeam(i)<>0) and (getPlayerTeam(i)<>3) then
        Flag:=False;
    if Flag then
    begin
      Win(3);
      exit;
    end;
    //-----------------------------------------------------

    //-----------------Победа мафов------------------------
    Flag:=True;
    for i:=1 to PlayerCount do
      if (getPlayerTeam(i)=1) or (getPlayerTeam(i)=4) or (Gametype.NeutralCanWin and (getPlayerTeam(i)=3)) then
        Flag:=False;
    if Flag then
    begin
      Win(2);
      exit;
    end;
    //-----------------------------------------------------

    //-----------------Победа якудз------------------------
    Flag:=True;
    for i:=1 to PlayerCount do
      if (getPlayerTeam(i)=1) or (getPlayerTeam(i)=2) or (Gametype.NeutralCanWin and (getPlayerTeam(i)=3)) then
        Flag:=False;
    if Flag then
    begin
      Win(4);
      exit;
    end;
    //-----------------------------------------------------

    //-----------------Победа мирных-----------------------
    Flag:=True;
    for i:=1 to PlayerCount do
      if (getPlayerTeam(i)=2) or (getPlayerTeam(i)=4) or (Gametype.NeutralCanWin and (getPlayerTeam(i)=3)) then
        Flag:=False;
    if Flag then
    begin
      Win(1);
      exit;
    end;
    //-----------------------------------------------------


    if State = 2 then
    begin
      //-----------------Ничья (маф vs мир) (НОЧЬ)------------------
      Flag:=True;
      Flag2:=False;

      for i:=1 to PlayerCount do
      if (getPlayerTeam(i)=2) then
        if not Flag2 then
          Flag2:=True
        else
          Flag:=False;

      if Flag and Flag2 then
      begin
        Flag2:=False;
        for i:=1 to PlayerCount do
          if (getPlayerTeam(i)<>2) and (getPlayerTeam(i)<>4) and (getPlayerTeam(i)<>0) then
            if not Flag2 then
              Flag2:=True
            else
              Flag:=False;
      end;

      Flag3:=True;
      if Flag and Flag2 then
      begin
        for i:=1 to PlayerCount do
          if (getPlayerTeam(i)=3) or (getPlayerTeam(i)=4) then
            Flag3:=False;
      end;

      if Flag and Flag2 and Flag3 then
      begin
        Win(0);
        exit;
      end;
      //----------------------------------------------------

      //------------------Ничья (як vs мир) (НОЧЬ)------------------
      Flag:=True;
      Flag2:=False;
      for i:=1 to PlayerCount do
        if (getPlayerTeam(i)=4) then
          if not Flag2 then
            Flag2:=True
          else
            Flag:=False;

      if Flag and Flag2 then
      begin
        Flag2:=False;
        for i:=1 to PlayerCount do
          if (getPlayerTeam(i)<>2) and (getPlayerTeam(i)<>4) and (getPlayerTeam(i)<>0) then
            if not Flag2 then
              Flag2:=True
            else
              Flag:=False;
      end;

      Flag3:=True;
      if Flag and Flag2 then
      begin
        for i:=1 to PlayerCount do
          if (getPlayerTeam(i)=2) or (getPlayerTeam(i)=3) then
            Flag3:=False;
      end;
      if Flag and Flag2 and Flag3 then
      begin
        Win(0);
        exit;
      end;
      //-----------------------------------------------------

      //-----------------Ничья (нейтрал vs горец) (НОЧЬ)------------------
      Flag:=False;
      Flag2:=False;

      for i:=1 to PlayerCount do
      if (getPlayerTeam(i)=3) then
        Flag:=True;

      Flag3:=True;
      if Flag and Flag2 then
      begin
        for i:=1 to PlayerCount do
          if (getPlayerTeam(i)>0) and (getPlayerTeam(i)<>3) then
            if (PlayersArr[i]^.gamestate=7) then
              Flag2:=True
            else
              Flag3:=False;
      end;

      if Flag and Flag2 and Flag3 then
      begin
        Win(0);
        exit;
      end;
      //----------------------------------------------------
    end
    else
    begin
      //-----------------Ничья (маф vs ком) (ДЕНЬ)------------------
      Flag:=True;
      Flag2:=False;

      for i:=1 to PlayerCount do
      if (getPlayerTeam(i)=2) then
        if not Flag2 then
          Flag2:=True
        else
          Flag:=False;

      if Flag and Flag2 then
      begin
        Flag2:=False;
        for i:=1 to PlayerCount do
          if (getPlayerTeam(i)<>2) and (getPlayerTeam(i)<>4) and (getPlayerTeam(i)<>0) then //COM
            if (not Flag2) and (PlayersArr[i]^.gamestate = 2 ) then
              Flag2:=True
            else
              Flag:=False;
      end;

      Flag3:=True;
      if Flag and Flag2 then
      begin
        for i:=1 to PlayerCount do
          if (getPlayerTeam(i)=3) or (getPlayerTeam(i)=4) then
            Flag3:=False;
      end;

      if Flag and Flag2 and Flag3 then
      begin
        Win(0);
        exit;
      end;
      //----------------------------------------------------

      //------------------Ничья (як vs ком) (ДЕНЬ)------------------
      Flag:=True;
      Flag2:=False;
      for i:=1 to PlayerCount do
        if (getPlayerTeam(i)=4) then
          if not Flag2 then
            Flag2:=True
          else
            Flag:=False;

      if Flag and Flag2 then
      begin
        Flag2:=False;
        for i:=1 to PlayerCount do
          if (getPlayerTeam(i)<>2) and (getPlayerTeam(i)<>4) and (getPlayerTeam(i)<>0) then //COM
            if (not Flag2) and (PlayersArr[i]^.gamestate = 2 ) then
              Flag2:=True
            else
              Flag:=False;
      end;

      if Flag and Flag2 then
      begin
        Flag3:=True;
        for i:=1 to PlayerCount do
          if (getPlayerTeam(i)=2) or (getPlayerTeam(i)=3) then
            Flag3:=False;
      end;
      if Flag and Flag2 and Flag3 then
      begin
        Win(0);
        exit;
      end;
      //-----------------------------------------------------
    end;

    //------------------Ничья (як vs маф)------------------
    Flag:=True;
    Flag2:=False;
    for i:=1 to PlayerCount do
      if (getPlayerTeam(i)=2) then
        if not Flag2 then
          Flag2:=True
        else
          Flag:=False;

    if Flag and Flag2 then
    begin
      Flag2:=False;
      for i:=1 to PlayerCount do
        if (getPlayerTeam(i)=4) then
          if not Flag2 then
            Flag2:=True
          else
            Flag:=False;
    end;

    if Flag and Flag2 then
    begin
      Flag3:=True;
      for i:=1 to PlayerCount do
        if (getPlayerTeam(i)=3) or (getPlayerTeam(i)=1) then
          Flag3:=False;
    end;

    if Flag and Flag2 and Flag3 then
    begin
      Win(0);
      exit;
    end;
    //------------------------------------------------------

  Result:=False;
  end;

  procedure StartNight();
  var
    i: Byte;
    Str: String;
  begin
    MsgToChannel(game_chan, GetRandomTextFromIni(file_messages,'StartNight'));

    //-------------Бездействие игроков---------------------
    if com_state>0 then
      com_state:=1;
    com_target:=0;

    if putana_state>0 then
      putana_state:=1;
    putana_target:=0;

    if doctor_state>0 then
      doctor_state:=1;
    doctor_target:=0;

    if sherif_state>0 then
      sherif_state:=1;
    sherif_target:=0;

    if homeless_state>0 then
      homeless_state:=1;
    homeless_target:=0;

    if killer_state>0 then
      killer_state:=1;
    killer_target:=0;

    if lawyer_state>0 then
      lawyer_state:=1;
    lawyer_target:=0;

    if podrivnik_state>0 then
      Inc(podrivnik_state);
    if podrivnik_state>4 then
      podrivnik_state:=2;
    podrivnik_target:=0;

    if maniac_state>0 then
      maniac_state:=1;
    maniac_target:=0;

    if robin_state>0 then
      robin_state:=1;
    robin_target:=0;

    if robber_state>0 then
      robber_state:=1;
    robber_target:=0;

    maf_state:=0;
    y_state:=0;

    com_phrase:='';
    maf_phrase:=''; y_phrase:='';
    putana_phrase:='';
    judge_phrase:='';
    sherif_phrase:='';
    homeless_phrase:='';
    killer_phrase:='';
    podrivnik_phrase:='';
    maniac_phrase:='';
    robin_phrase:='';
    robber_phrase:='';
    //-----------------------------------------------------

    //-------Отправка необходимых приватов-----------------

    //---------------------Мафам----------------------------
    Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
    Str:=Str+getAlivePlayers(0);
    StatusToChannel(maf_chan, Str);
    ChangeGreeting(maf_chan, Str);
    if Gametype.UseYakuza then
    begin
      StatusToChannel(y_chan, Str);
      ChangeGreeting(y_chan, Str);
    end;
    //------------------------------------------------------
    for i:=1 to PlayerCount do
    begin
      PlayersArr[i]^.activity:=0;           //ОБНУЛИТЬ АКТИВНОСТЬ!
      Voting[i]:=0;                         //ОБНУЛИТЬ КОЛИЧЕСТВО ГОЛОСОВ!
      Voting2[i]:=0;                         //ОБНУЛИТЬ КОЛИЧЕСТВО ГОЛОСОВ!
      if (PlayersArr[i]^.gamestate=51) and   //Временно сделать сержанта комиссаром,
         (com_player=i) then                //если ком труп
          begin
            serj_player:=com_player;
            PlayersArr[i]^.gamestate:=2;
          end;

      case PlayersArr[i]^.gamestate of

        2: begin
            Str:=Messages.Values['NightInfoComType_'+IntToStr(Gametype.ComType)]+Chr(13)+Chr(10);
            if Gametype.ShowNightComments then
              Str:=Str+Messages.Values['NightInfoCom_wComments']
            else
              Str:=Str+Messages.Values['NightInfoCom'];
            if (Gametype.ComType=2) then
              if Gametype.ShowNightComments then
                Str:=Str+' '+Messages.Values['NightInfoComShoot_wComments']
              else
                Str:=Str+' '+Messages.Values['NightInfoComShoot'];
            PrivateMsg(PlayersArr[i]^.name, Str);
            Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
            Str:=Str+getAlivePlayers(0);
            PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        3: begin
             if Gametype.ShowNightComments then
               Str:=Messages.Values['NightInfoWench_wComments']
             else
               Str:=Messages.Values['NightInfoWench'];
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        5: begin
             Str:=Messages.Values['NightInfoDoctor'];
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        7: begin
             Str:=Messages.Values['NightInfoHighlander'];
             Str:=Str+Chr(13)+Chr(10);
             if Gametype.ShowNightComments then
               Str:=Str+Messages.Values['NightInfoHighlanderShoot_wComments']
             else
               Str:=Str+Messages.Values['NightInfoHighlanderShoot'];
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        8: begin
             if Gametype.ShowNightComments then
               Str:=Messages.Values['NightInfoChiefShoot_wComments']
             else
               Str:=Messages.Values['NightInfoChiefShoot'];
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        9: begin
             if Gametype.ShowNightComments then
               Str:=Messages.Values['NightInfoHomeless_wComments']
             else
               Str:=Messages.Values['NightInfoHomeless'];
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        101: begin
             Str:=Messages.Values['NightInfoMaf'];
             Str:=Str+Chr(13)+Chr(10);
             Str:=Str+Messages.Values['NightInfoMafShoot'];
             Str:=Str+Chr(13)+Chr(10);
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        102: begin
             Str:=Messages.Values['NightInfoKiller'];
             Str:=Str+Chr(13)+Chr(10);
             if Gametype.ShowNightComments then
               Str:=Str+Messages.Values['NightInfoKillerShoot_wComments']
             else
               Str:=Str+Messages.Values['NightInfoKillerShoot'];
             Str:=Str+Chr(13)+Chr(10);
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        103: begin
             if Gametype.ShowNightComments then
               Str:=Messages.Values['NightInfoLawyer_wComments']
             else
               Str:=Messages.Values['NightInfoLawyer'];
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        151: begin
             Str:=Messages.Values['NightInfoYak'];
             Str:=Str+Chr(13)+Chr(10);
             Str:=Str+Messages.Values['NightInfoYakShoot'];
             Str:=Str+Chr(13)+Chr(10);
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        201: begin
             if Gametype.ShowNightComments then
               Str:=Messages.Values['NightInfoManiac_wComments']
             else
               Str:=Messages.Values['NightInfoManiac'];
             if Gametype.ManiacCanUseCurse then
               Str:=Str+' '+Messages.Values['NightInfoManiacCurse'];
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        202: begin
             if Gametype.ShowNightComments then
               Str:=Messages.Values['NightInfoRobin_wComments']
             else
               Str:=Messages.Values['NightInfoRobin'];
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        203: begin
             if Gametype.ShowNightComments then
               Str:=Messages.Values['NightInfoRobber_wComments']
             else
               Str:=Messages.Values['NightInfoRobber'];
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

      end;
      if (serj_player=com_player) and (serj_player<>0) then          //Вернуть сержанта на место
      begin
        serj_player:=0;
        PlayersArr[i]^.gamestate:=51;
      end;

    end;

    if podrivnik_state=4 then
    begin
      if Gametype.ShowNightComments then
        Str:=StringReplace(Messages.Values['NightInfoDemolition_wComments'], '%text%','0 - '+NightPlaces[0]+', 1 - '+NightPlaces[1]+', 2 - '+NightPlaces[2], [rfReplaceAll])
      else
        Str:=StringReplace(Messages.Values['NightInfoDemolition'], '%text%','0 - '+NightPlaces[0]+', 1 - '+NightPlaces[1]+', 2 - '+NightPlaces[2], [rfReplaceAll]);
      PrivateMsg(PlayersArr[podrivnik_player]^.name, Str);
      Pause(time_pause);
      Str:= StringReplace(Messages.Values['NightInfoDemolitionForPlayers'], '%text%','0 - '+NightPlaces[0]+', 1 - '+NightPlaces[1]+', 2 - '+NightPlaces[2], [rfReplaceAll]);
      for i:=1 to PlayerCount do
        if (GetPlayerTeam(i)<>2) and (GetPlayerTeam(i)<>0) then
          PrivateMsg(PlayersArr[i]^.name, Str);
    end;

    //-----------------------------------------------------
    MafTimer.Interval:=Cardinal(time_night)*1000;
    SubState:=0;
    Pause(time_pause);
    if Gametype.InstantCheck and (putana_player=0) then // Нет блокирующих персонажей
    begin
      SubState:=1;
      for i := 1 to PlayerCount do
        if PlayersArr[i]^.gamestate in [2, 9, 51, 103] then
          PrivateMsg(PlayersArr[i]^.Name, Messages.Values['NightInfoNoBlocker']);
    end;
    ResetTimerQ();
    State:=2;
  end;

  procedure EndNight();
  var
      maf_target: TwoByte;
      i,k: Byte;
      Str: String;
  begin
    MafTimer.Enabled:=False;
    if Gametype.InstantCheck then
    begin
      Inc(SubState);
      if SubState=1 then
        for i := 1 to PlayerCount do
          if PlayersArr[i]^.gamestate in [2, 9, 51, 103] then
            PrivateMsg(PlayersArr[i]^.Name, Messages.Values['NightInfoBlockerAccepted']);
      if SubState<2 then
      begin
        MafTimer.Interval:=Cardinal(time_night)*500;
        ResetTimerQ();
        Exit;
      end;
    end;

    highlander_under_attack := False;

    MsgToChannel(game_chan, GetRandomTextFromIni(file_messages,'EndNight'));
    Pause(time_pause*2);
    //--------------------------Предметы-------------------
    for i:=1 to playerCount do
    begin
      //------------------------Маска----------------------
      if (PlayersArr[i]^.use_mask=1) then
      begin
        PlayersArr[i]^.use_mask:=2;
        for k:=1 to playerCount do
          if (PlayersArr[k]^.activity=i) then
            CancelActivity(k, false);
      end;
      //---------------------------------------------------

      //------------------------Рация----------------------
      if (PlayersArr[i]^.use_radio > 1) then
        Dec(PlayersArr[i]^.use_radio);
      //---------------------------------------------------
    end;
    //-----------------------------------------------------

    //--------------------------Путана---------------------
    if (putana_state = 2) and (putana_target > 0) then
    begin
      if putana_target<>putana_player then
        CancelActivity(putana_target, false);      //Отменяем активность "Жертвы"
      PlayersArr[putana_player]^.lastactivity:=putana_target;

      if (putana_target=com_player) then
        AddPoints(putana_player, points_cost[14])
      else
        if (getPlayerTeam(putana_target)=2) or (getPlayerTeam(putana_target)=4) then
          AddPoints(putana_player, points_cost[15]);

      if (Random(100) < Gametype.InfectionChance) and (PlayersArr[putana_target]^.delayedDeath = 0) then
        PlayersArr[putana_target]^.delayedDeath := 2;
      MsgToChannel(game_chan, GetRandomTextReplaceRole('WenchActive', putana_target)+NightComment(3,putana_phrase));
      Pause(time_pause);
    end;
    //-----------------------------------------------------

    //--------------------------Маньяк-------------------

    if (maniac_state=2) and (maniac_target>0) then
    begin
      //-----------------Спас доктор--------------------
      if (doctor_state=2) and (maniac_target=doctor_target) then
      begin
        if getPlayerTeam(maniac_target)=1 then
        begin
          if (com_player=maniac_target) then
            AddPoints(doctor_player, points_cost[4]);
          AddPoints(doctor_player, points_cost[3]);
        end
        else
          if (getPlayerTeam(maniac_target)=2) or (getPlayerTeam(maniac_target)=4)  then
            AddPoints(doctor_player, points_cost[5]);
        MsgToChannel(game_chan, GetRandomTextReplaceRole('ManiacHelpDoc', maniac_target)+NightComment(201,maniac_phrase));
      end
      //------------------------------------------------
      
      else
      begin
        AddPoints(maniac_player, points_cost[6]);
        KillPlayer(maniac_target);
        MsgToChannel(game_chan, GetRandomTextReplaceRole('ManiacKill', maniac_target)+NightComment(201,maniac_phrase));
      end;
      Pause(time_pause);
    end
    else
      if maniac_state=3 then
      begin
        MsgToChannel(game_chan, GetRandomTextReplaceRole('ManiacKillHighlander', maniac_target)+NightComment(201,maniac_phrase));
        highlander_under_attack := True;
        Pause(time_pause);
      end;
    //-----------------------------------------------------

   //--------------------------Робин Гуд-------------------

    if robin_state=3 then
    begin
      //-----------------Спас доктор--------------------
      if (doctor_state=2) and (robin_target=doctor_target) then
      begin
        if getPlayerTeam(robin_target)=1 then
        begin
          if (com_player=robin_target) then
            AddPoints(doctor_player, points_cost[4]);
          AddPoints(doctor_player, points_cost[3]);
        end
        else
          if (getPlayerTeam(robin_target)=2) or (getPlayerTeam(robin_target)=4) then
            AddPoints(doctor_player, points_cost[5]);
        MsgToChannel(game_chan, GetRandomTextReplaceRole('RobinHoodHelpDoc', robin_target)+NightComment(202,robin_phrase));
      end
      //------------------------------------------------

      else
      begin
        AddPoints(robin_player, points_cost[6]);
        KillPlayer(robin_target);
        MsgToChannel(game_chan, GetRandomTextReplaceRole('RobinHoodKill', robin_target)+NightComment(202,robin_phrase));
      end;
      Pause(time_pause);
    end
    else
      if robin_state=2 then
      begin
        MsgToChannel(game_chan, GetRandomTextReplaceRole('RobinHoodKillVictim', robin_target)+NightComment(202,robin_phrase));
        Pause(time_pause);
      end;
    //-----------------------------------------------------

   //--------------------------Грабитель-------------------

    if robber_state=2 then
    begin
      // Случайное количество очков
      i:=Random(points_cost[18]-points_cost[17]+1)+points_cost[17];
      AddPoints(robber_player, i);
      AddPoints(robber_target, -i);
      MsgToChannel(game_chan, GetRandomTextReplaceRole('RobberActive', robber_target)+NightComment(203,robber_phrase));
      Pause(time_pause);
    end;
    //-----------------------------------------------------

    //--------------------------Адвокат--------------------
    if lawyer_state>1 then
    begin
      if not Gametype.InstantCheck then
      begin
        PrivateMsg(PlayersArr[lawyer_player]^.name, 'Статус '+ FormatNick(PlayersArr[lawyer_target]^.name)
                  + ' - [b]' + RoleText[PlayersArr[lawyer_target]^.gamestate,0]+'[/b]');
        MsgToChannel(maf_chan, 'Результат проверки '+RoleText[PlayersArr[lawyer_player]^.gamestate, 0]+': Статус '+ FormatNick(PlayersArr[lawyer_target]^.name)
                  + ' - [b]' + RoleText[PlayersArr[lawyer_target]^.gamestate,0]+'[/b]');
      end;
      if lawyer_target=com_player then
        AddPoints(lawyer_player, points_cost[13]);
    end;
    //-----------------------------------------------------

    //--------------------------Бомж--------------------
    if homeless_state>1 then
    begin
      if not Gametype.InstantCheck then
        PrivateMsg(PlayersArr[homeless_player]^.name, 'Статус ' + FormatNick(PlayersArr[homeless_target]^.name)
                  + ' - [b]' + RoleText[PlayersArr[homeless_target]^.gamestate,0]+'[/b]');
      MsgToChannel(game_chan, GetRandomTextReplaceRole('HomelessCheck', homeless_target)+NightComment(9,homeless_phrase));
      if (GetPlayerTeam(homeless_target)=2) or (GetPlayerTeam(homeless_target)=4) then
        AddPoints(homeless_player, points_cost[7]);
    end;
    //-----------------------------------------------------

    //--------------------------Комиссар-------------------
    if (com_state>1) and (com_state<5) then
    begin
      if not Gametype.InstantCheck then
        PrivateMsg(PlayersArr[com_player]^.name, 'Статус '+ FormatNick(PlayersArr[com_target]^.name)
                  + ' - [b]' + RoleText[PlayersArr[com_target]^.gamestate,0]+'[/b]');
      if (serj_player>0) then
        PrivateMsg(PlayersArr[serj_player]^.name, 'Информация от комиссара: Статус '+ FormatNick(PlayersArr[com_target]^.name)
                  + ' - [b]' + RoleText[PlayersArr[com_target]^.gamestate,0]+'[/b]');
    end;
	  case com_state of
		// Сон
		1: begin
		  if PlayersArr[com_player]^.gamestate=51 then
			  MsgToChannel(game_chan, GetRandomTextReplaceRole('SgtSleep', 1))
		  else
			  MsgToChannel(game_chan, GetRandomTextReplaceRole('ComSleep', 1));
		end;

		// Проверка мирного
		2: begin
		  if PlayersArr[com_player]^.gamestate=51 then
			  MsgToChannel(game_chan, GetRandomTextReplaceRole('SgtCheckVictim', com_target)+NightComment(51,com_phrase))
		  else
			  MsgToChannel(game_chan, GetRandomTextReplaceRole('ComCheckVictim', com_target)+NightComment(2,com_phrase));
		end;

		// Проверка мафа
		3: begin
		  if (GameType.ComType = 0) then // Стреляющий комиссар
		  begin
			  //-----------------Спас доктор--------------------
			  if (doctor_state=2) and (com_target=doctor_target) then
			  begin
			    AddPoints(doctor_player, points_cost[5]);
			    if PlayersArr[com_player]^.gamestate=51 then
				    MsgToChannel(game_chan, GetRandomTextReplaceRole('SgtKillMafHelpDoc', com_target)+NightComment(51,com_phrase))
			    else
				  MsgToChannel(game_chan, GetRandomTextReplaceRole('ComKillMafHelpDoc', com_target)+NightComment(2,com_phrase));
			  end
			  //------------------------------------------------

			  else
			  begin
			    AddPoints(com_player, points_cost[7]);
			    PrivateMsg(PlayersArr[com_player]^.name, Messages.Values['EndNightInfoMafKilled']);
			    KillPlayer(com_target);
			    if PlayersArr[com_player]^.gamestate=51 then
				    MsgToChannel(game_chan, GetRandomTextReplaceRole('SgtKill', com_target)+NightComment(51,com_phrase))
			    else
				    MsgToChannel(game_chan, GetRandomTextReplaceRole('ComKill', com_target)+NightComment(2,com_phrase));
			  end;
		  end
		  else
			if (GameType.ComType = 1) or (GameType.ComType = 2) then // Проверяющий комиссар или детектив
			begin
			  if PlayersArr[com_player]^.gamestate=51 then
				  MsgToChannel(game_chan, GetRandomTextReplaceRole('SgtCheckMaf', com_target)+NightComment(51,com_phrase))
			  else
				  MsgToChannel(game_chan, GetRandomTextReplaceRole('ComCheckMaf', com_target)+NightComment(2,com_phrase));
			  AddPoints(com_player, points_cost[7]);
			end;
		end;

		// Проверка маньяка
		4: begin
		  //-----------------Спас доктор--------------------
		  if (doctor_state=2) and (com_target=doctor_target) then
		  begin
			AddPoints(doctor_player, points_cost[5]);
			if PlayersArr[com_player]^.gamestate=51 then
			  MsgToChannel(game_chan, GetRandomTextReplaceRole('SgtKillManiacHelpDoc', com_target)+NightComment(51,com_phrase))
			else
			  MsgToChannel(game_chan, GetRandomTextReplaceRole('ComKillManiacHelpDoc', com_target)+NightComment(2,com_phrase));
		  end
		  //------------------------------------------------
		  else
		  begin
			KillPlayer(com_target);
			if PlayersArr[com_player]^.gamestate=51 then
			  MsgToChannel(game_chan, GetRandomTextReplaceRole('SgtKillManiac', com_target)+NightComment(51,com_phrase))
			else
			  MsgToChannel(game_chan, GetRandomTextReplaceRole('ComKillManiac', com_target)+NightComment(2,com_phrase));
			AddPoints(com_player, points_cost[7]);
		  end;
		end;

		// Убийство (!подстрелить)
		5: begin
		  //-----------------Спас доктор--------------------
		  if (doctor_state=2) and (com_target=doctor_target) then
		  begin
			  i:=getPlayerTeam(doctor_target);
			  if (i=2) or (i=4) then
			    AddPoints(doctor_player, points_cost[5])
			  else if (i=1) then
			    AddPoints(doctor_player, points_cost[3]);
			  if PlayersArr[com_player]^.gamestate=51 then
			    MsgToChannel(game_chan, GetRandomTextReplaceRole('SgtHelpDoc', com_target)+NightComment(51,com_phrase))
			  else
			    MsgToChannel(game_chan, GetRandomTextReplaceRole('ComHelpDoc', com_target)+NightComment(2,com_phrase));
		  end
		  else
		  //------------------------------------------------
		  begin
			  if (GetPlayerTeam(com_target)=2) or (GetPlayerTeam(com_target)=4) then
			  begin
			    AddPoints(com_player, points_cost[7]);
			    PrivateMsg(PlayersArr[com_player]^.name, Messages.Values['EndNightInfoMafKilled']);
			    KillPlayer(com_target);
			    if PlayersArr[com_player]^.gamestate=51 then
				    MsgToChannel(game_chan, GetRandomTextReplaceRole('SgtKill', com_target)+NightComment(51,com_phrase))
			    else
				    MsgToChannel(game_chan, GetRandomTextReplaceRole('ComKill', com_target)+NightComment(2,com_phrase));
			  end
			  else if (PlayersArr[com_target]^.gamestate=201) then
			  begin
			    KillPlayer(com_target);
			    if PlayersArr[com_player]^.gamestate=51 then
				    MsgToChannel(game_chan, GetRandomTextReplaceRole('SgtKillManiac', com_target)+NightComment(51,com_phrase))
			    else
				    MsgToChannel(game_chan, GetRandomTextReplaceRole('ComKillManiac', com_target)+NightComment(2,com_phrase));
			    if Gametype.ComKillManiac then
				    AddPoints(com_player, points_cost[7]);
			  end
			  else if (GetPlayerTeam(com_target)=1) then
		  	begin
          if PlayersArr[com_target]^.gamestate=7 then //Горец
          begin
            highlander_under_attack := True;
			      if PlayersArr[com_player]^.gamestate=51 then
              MsgToChannel(game_chan, GetRandomTextReplaceRole('SgtKillHighlander', com_target)+NightComment(51,com_phrase))
			      else
				      MsgToChannel(game_chan, GetRandomTextReplaceRole('ComKillHighlander', com_target)+NightComment(2,com_phrase));
          end
          else
          begin
			      AddPoints(com_player, points_cost[9]);
			      KillPlayer(com_target);
			      if PlayersArr[com_player]^.gamestate=51 then
              MsgToChannel(game_chan, GetRandomTextReplaceRole('SgtKillVictim', com_target)+NightComment(51,com_phrase))
			      else
				      MsgToChannel(game_chan, GetRandomTextReplaceRole('ComKillVictim', com_target)+NightComment(2,com_phrase));
          end;
			  end;
		  end;
		end;
	  end;
	  Pause(time_pause);
    //-----------------------------------------------------

    //--------------------Шериф----------------------------
    if sherif_state=2 then
    begin
      //-----------------Спас доктор--------------------
      if (doctor_state=2) and (sherif_target=doctor_target) then
      begin
        i:=getPlayerTeam(doctor_target);
        if (i=2) or (i=4) then
          AddPoints(doctor_player, points_cost[5])
        else
          if (i=1) then
            begin
              AddPoints(doctor_player, points_cost[3]);
              if (doctor_target=com_player) then
                AddPoints(doctor_player, points_cost[4]);
            end;

        MsgToChannel(game_chan, GetRandomTextReplaceRole('ChiefHelpDoc', sherif_target)+NightComment(8,sherif_phrase));
      end
      //------------------------------------------------

      else
      begin
        i:=getPlayerTeam(sherif_target);
        if (i=2) or (i=4) then
          AddPoints(sherif_player, points_cost[8])
        else
          if (i=1) then
            begin
              AddPoints(sherif_player, points_cost[9]);
              if (sherif_target=com_player) then
                AddPoints(sherif_player, points_cost[10]);
            end;
        KillPlayer(sherif_target);
        MsgToChannel(game_chan, GetRandomTextReplaceRole('ChiefKill', sherif_target)+NightComment(8,sherif_phrase));
      end;
      Pause(time_pause);
    end
    else
      if sherif_state=3 then
      begin
        MsgToChannel(game_chan, GetRandomTextReplaceRole('ChiefKillHighlander', sherif_target)+NightComment(8,sherif_phrase));
        highlander_under_attack := True;
        Pause(time_pause);
      end;
    //-----------------------------------------------------

    //---------------------------Мафы----------------------
    maf_target:=VoteResult();
    if maf_target[0]>0 then   //Max
    begin
      if maf_target[1]>0 then //Номер
      begin
        if (PlayersArr[maf_target[1]]^.gamestate=7) then
        begin
          MsgToChannel(game_chan, GetRandomTextReplaceRole('MafKillHighlander', maf_target[1])+NightComment(101,maf_phrase));
          highlander_under_attack := True;
        end
        else
          //-----------------Спас доктор--------------------
          if (doctor_state=2) and (maf_target[1]=doctor_target) then
          begin
            AddPoints(doctor_player, points_cost[3]);
            if (doctor_target=com_player) then
              AddPoints(doctor_player, points_cost[4]);
            MsgToChannel(game_chan, GetRandomTextReplaceRole('MafHelpDoc', maf_target[1])+NightComment(101,maf_phrase));
          end
          //------------------------------------------------

          else
          begin
            //-----------------Убийство комиссара-------------
            if maf_target[1]=com_player then
              for i:=1 to PlayerCount do
                if (getPlayerTeam(i)=2) and (PlayersArr[i]^.activity=com_player) then
                  AddPoints(i, points_cost[11]);
            //------------------------------------------------

            //-----------------Убийство якудзы-------------
            if getPlayerTeam(maf_target[1])=4 then
              for i:=1 to PlayerCount do
                if (getPlayerTeam(i)=2) and (PlayersArr[i]^.activity=maf_target[1]) then
                  AddPoints(i, points_cost[11]);
            //------------------------------------------------

            for i:=1 to PlayerCount do
              if (getPlayerTeam(i)=2) and (PlayersArr[i]^.activity=maf_target[1]) then
                AddPoints(i, points_cost[16]);

            MsgToChannel(game_chan, GetRandomTextReplaceRole('MafKill', maf_target[1])+NightComment(101,maf_phrase));
            KillPlayer(maf_target[1]);
          end;
        Pause(time_pause);
      end
      else
      begin
        MsgToChannel(game_chan, GetRandomTextFromIni(file_messages,'MafNoChoice'));
        Pause(time_pause);
      end;
     end
     else
     begin
       maf_ingame:=0;
       for i:=1 to PlayerCount do
         if getPlayerTeam(i)=2 then
           Inc(maf_ingame);
       if (maf_ingame>0) then
         MsgToChannel(game_chan, GetRandomTextFromIni(file_messages,'MafSleep'));
     end;
    //-----------------------------------------------------

    //---------------------------Яки----------------------
    maf_target:=Vote2Result();
    if maf_target[0]>0 then   //Max
    begin
      if maf_target[1]>0 then //Номер
      begin
        if (PlayersArr[maf_target[1]]^.gamestate=7) then
        begin
          MsgToChannel(game_chan, GetRandomTextReplaceRole('YakuzaKillHighlander', maf_target[1])+NightComment(151,y_phrase));
          highlander_under_attack := True;
        end
        else
          //-----------------Спас доктор--------------------
          if (doctor_state=2) and (maf_target[1]=doctor_target) then
          begin
            AddPoints(doctor_player, points_cost[3]);
            if (doctor_target=com_player) then
              AddPoints(doctor_player, points_cost[4]);
            MsgToChannel(game_chan, GetRandomTextReplaceRole('YakuzaHelpDoc', maf_target[1])+NightComment(151,y_phrase));
          end
          //------------------------------------------------

          else
          begin
        
            //-----------------Убийство комиссара-------------
            if maf_target[1]=com_player then
              for i:=1 to PlayerCount do
                if (getPlayerTeam(i)=4) and (PlayersArr[i]^.activity=com_player) then
                  AddPoints(i, points_cost[11]);
            //------------------------------------------------

            //-----------------Убийство мафа-------------
            if getPlayerTeam(maf_target[1])=2 then
              for i:=1 to PlayerCount do
                if (getPlayerTeam(i)=4) and (PlayersArr[i]^.activity=maf_target[1]) then
                  AddPoints(i, points_cost[12]);
            //------------------------------------------------

            for i:=1 to PlayerCount do
              if (getPlayerTeam(i)=4) and (PlayersArr[i]^.activity=maf_target[1]) then
                AddPoints(i, points_cost[16]);

            MsgToChannel(game_chan, GetRandomTextReplaceRole('YakuzaKill', maf_target[1])+NightComment(151,y_phrase));
            KillPlayer(maf_target[1]);
          end;
        Pause(time_pause);
      end
      else
      begin
        MsgToChannel(game_chan, GetRandomTextFromIni(file_messages,'YakuzaNoChoice'));
        Pause(time_pause);
      end;
     end
     else
     begin
       maf_ingame:=0;
       for i:=1 to PlayerCount do
       begin
         if getPlayerTeam(i)=4 then
           Inc(maf_ingame);
       end;
       if (maf_ingame>0) then
         MsgToChannel(game_chan, GetRandomTextFromIni(file_messages,'YakuzaSleep'));
     end;
    //-----------------------------------------------------


    //---------------------------Киллер----------------------
    if killer_state=2 then
    begin
      //-----------------Спас доктор--------------------
      if (doctor_state=2) and (killer_target=doctor_target) then
      begin
        AddPoints(doctor_player, points_cost[3]);
          if (doctor_target=com_player) then
            AddPoints(doctor_player, points_cost[4]);
          MsgToChannel(game_chan, GetRandomTextReplaceRole('KillerHelpDoc', killer_target)+NightComment(102,killer_phrase));
      end
      //------------------------------------------------

      else
      begin
        
        //-----------------Убийство комиссара-------------
        if killer_target=com_player then
          AddPoints(killer_player, points_cost[11]);
        //------------------------------------------------

        MsgToChannel(game_chan, GetRandomTextReplaceRole('KillerKill', killer_target)+NightComment(102,killer_phrase));
        KillPlayer(killer_target);
      end;
      Pause(time_pause);
    end
    else
      if killer_state=3 then
      begin
        MsgToChannel(game_chan, GetRandomTextReplaceRole('KillerKillHighlander', killer_target)+NightComment(102,killer_phrase));
        highlander_under_attack := True;
        Pause(time_pause);
      end;
    //-----------------------------------------------------


    //--------------------------------Доктор---------------
    if (doctor_target=doctor_player) then
      doctor_heals_himself:=1;
    if (doctor_state=2) then
      PlayersArr[doctor_player]^.lastactivity:=doctor_target;
    //-----------------------------------------------------

    if maniac_state=10 then
    begin
      maniac_use_curse:=1;
      k:=0;
      Str:='';
      for i := 1 to PlayerCount do
        if (PlayersArr[i]^.activity=PlayersArr[maniac_player]^.activity) and (maniac_player<>i) then
        begin
          Inc(k);
          KillPlayer(i);
          Str:=Str+' '+ FormatNick(PlayersArr[i]^.Name)+' ([b]'+RoleText[PlayersArr[i]^.gamestate, 3]+'[/b]),';
        end;
      if (k>0) then
      begin
        AddPoints(maniac_player, points_cost[6]*k);
        Str[Length(Str)]:=' ';
        MsgToChannel(game_chan, 'Неудачно сегодня закончилась ночь для'+Str+'- не надо было трогать проклятого '+RoleText[201, 1]+' игрока...'+NightComment(201,maniac_phrase));
      end;
    end;

    if podrivnik_state=4 then
    begin
      k:=0;
      Str:='';
      for i := 1 to PlayerCount do
        if (PlayersArr[i]^.night_place=podrivnik_target) and (GetPlayerTeam(i)<>0) and (GetPlayerTeam(i)<>2) then
        begin
          Inc(k);
          KillPlayer(i);
          Str:=Str+' [b]'+RoleText[PlayersArr[i]^.gamestate, 2]+'[/b] '+ FormatNick(PlayersArr[i]^.Name)+',';
        end;
      if (k>0) then
      begin
        AddPoints(podrivnik_player, points_cost[6]*k);
        Str[Length(Str)]:=' ';
        MsgToChannel(game_chan, 'Сегодня был взорван '+NightPlaces[podrivnik_target]+'.'+Str+'убило взрывом:( '+NightComment(104,podrivnik_phrase));
      end
      else
        MsgToChannel(game_chan, 'Сегодня был взорван '+NightPlaces[podrivnik_target]+'. К счастью, никто не погиб.');
    end;

    for i:=1 to PlayerCount do
    begin
      if PlayersArr[i]^.delayedDeath > 1 then
        Dec(PlayersArr[i]^.delayedDeath)
      else
        if (PlayersArr[i]^.delayedDeath = 1) and (PlayersArr[i]^.gamestate > 0) then
        begin
          PlayersArr[i]^.delayedDeath := 0;
          killPlayer(i);
          MsgToChannel(game_chan, GetRandomTextReplaceRole('AIDSKill', i));
          Pause(time_pause);
        end;

      //------ Горец ----------------
      if highlander_under_attack and (PlayersArr[i]^.gamestate=7) and (PlayersArr[i]^.activity > 0) then
      begin
        KillPlayer(PlayersArr[i]^.activity);
        MsgToChannel(game_chan, GetRandomTextReplaceRole('HighLanderKill', PlayersArr[i]^.activity)+NightComment(7,highlander_phrase));
      end;
      //-----------------------------
    end;
    
    ApplyKills();
    Pause(time_pause);
    GetAlivePlayers(2);
    if not CheckWin(2) then
    begin
      ApplyBans();
      Pause(time_pause);
      StartMorning();
    end;
  end;

  procedure StartMorning();
  begin
    MsgToChannel(game_chan, Messages.Values['StartMorningInfo']);

    MafTimer.Interval:=Cardinal(time_morning)*1000;
    State:=3;
    ResetTimerQ();
  end;

  procedure StartDay();
  var
    i: Byte;
    Str: String;
  begin
    MafTimer.Enabled:=False;
    //-------------Бездействие игроков---------------------
    if judge_state>0 then
      judge_state:=1;
    judge_target:=0;
    //-----------------------------------------------------

    //-------Отправка необходимых приватов-----------------
    for i:=1 to PlayerCount do
    begin
      PlayersArr[i]^.activity:=0;           //ОБНУЛИТЬ АКТИВНОСТЬ!
      PlayersArr[i]^.activity2:=0;           //ОБНУЛИТЬ АКТИВНОСТЬ!
      Voting[i]:=0;                         //ОБНУЛИТЬ КОЛИЧЕСТВО ГОЛОСОВ!

      case PlayersArr[i]^.gamestate of

        4: begin
             Str:=Messages.Values['DayInfoJudge'];
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

        6: begin
             Str:=Messages.Values['DayInfoElder'];
             PrivateMsg(PlayersArr[i]^.name, Str);
             Str:=Chr(13)+Chr(10)+Messages.Values['RemainingPlayers']+Chr(13)+Chr(10);
             Str:=Str+getAlivePlayers(0);
             PrivateMsg(PlayersArr[i]^.name, Str);
           end;

      end;
    end;
    //-----------------------------------------------------
    MsgToChannel(game_chan, GetRandomTextFromIni(file_messages, 'StartDay'));
    Pause(time_pause);
    MsgToChannel(game_chan, Messages.Values['StartDayInfo']);
    GetAlivePlayers(2);

    MafTimer.Interval:=Cardinal(time_day)*1000;
    ResetTimerQ();
    State:=4;
    SubState := 0;
  end;

  // SubState:
  // 0 - окончание голосования
  // 1 - окончание последнего слова
	procedure EndDay();
  var
    target: TwoByte;
	begin
		Inc(SubState);
    target:=VoteResult();

    // Пропуск последнего слова
    if (target[0] <= 0) or (target[1] <= 0) or (time_lastWord <= 0) then
    	Inc(SubState);

		case SubState - 1 of
    	0: begin
        if (target[0] > 0) and (target[1] > 0) and (time_lastWord > 0) then
        begin
					MsgToChannel(game_chan, StringReplace(Messages.Values['YouHaveTheLastWord'],'%name%',FormatNick(PlayersArr[target[1]]^.name),[rfReplaceAll]));
					MafTimer.Interval:=Cardinal(time_lastWord)*1000;
					ResetTimerQ();
        end
      end
			else StartEvening();
    end;
	end;

	procedure StartEvening();
	var
		I: Byte;
		target: TwoByte;
  begin
		State:=255;
		if time_evening>0 then
		begin
			VotingYesNo[0]:=0; // Не сажать
			VotingYesNo[1]:=0; // Посадить

			for I := 1 to PlayerCount do
				PlayersArr[I]^.voting:=-1;

			MsgToChannel(game_chan, GetRandomTextFromIni(file_messages, 'StartEvening'));
			Pause(time_pause);
			target:=VoteResult();
			if (target[0]>0) and (target[1]>0) then
			begin
				MsgToChannel(game_chan, StringReplace(Messages.Values['EveningVoteInfo'],'%name%',FormatNick(PlayersArr[target[1]]^.name),[rfReplaceAll]));
				MafTimer.Interval:=Cardinal(time_evening)*1000;
				ResetTimerQ();
				State:=5;
        //SubState:=0;
			end
			else
			begin
				EndEvening();
			end;
    end
    else
    begin
    	EndEvening();
    end;
  end;

  procedure EndEvening();
  var target: TwoByte;
      i, k: Byte;
      Str: String;
      Points: array [1..4] of Integer;
      KilledPlayers: array[0..254] of Byte;
  begin
    MafTimer.Enabled:=False;
    State:=255;

    for i := 1 to 4 do
      Points[i]:=0;
      
    //-----------------------Голоса----------------------
    target:=VoteResult();

    if target[0]>0 then   //Max
    begin
      if ((time_evening=0) or (time_evening>0) and (VotingYesNo[1]>VotingYesNo[0])) and (target[1]>0) then //Номер
      begin
        //----------------------Судья------------------------
        if judge_state=2 then
        begin
          PlayersArr[judge_player]^.lastactivity:=judge_target;
          if (judge_target=target[1]) then
          begin
            MsgToChannel(game_chan, GetRandomTextReplaceRole('JudgeActive', judge_target)+NightComment(4,judge_phrase));
            if getPlayerTeam(judge_target)=1 then
            begin
              AddPoints(judge_player, points_cost[151]);
              if (judge_target=com_player) then
                AddPoints(judge_player, points_cost[152]);
            end
            else
              if (getPlayerTeam(judge_target)=2) or (getPlayerTeam(judge_target)=4) then
                AddPoints(judge_player, points_cost[153])
          end;
        end;
        //---------------------------------------------------

        if (judge_state<2) or (judge_target<>target[1]) then
          //-----------Попытались посадить старейшину----------
          if (PlayersArr[target[1]]^.gamestate=6) then
          begin
            MsgToChannel(game_chan, GetRandomTextReplaceRole('DayKillElder', target[1]));
            if PlayersArr[target[1]]^.activity2>0 then
            begin
              i:=PlayersArr[target[1]]^.activity2;
              if i=com_player then
                AddPoints(target[1], points_cost[155]);
              if (GetPlayerTeam(i)=2) or (GetPlayerTeam(i)=4) then
                AddPoints(target[1], points_cost[157])
              else
                if (GetPlayerTeam(i)=1) then
                  AddPoints(target[1], points_cost[154]);
              Pause(time_pause);
              MsgToChannel(game_chan, GetRandomTextReplaceRole('ElderKill', i));
              KillPlayer(i);
            end;

          end
          //------------------------------------------------
          else
          begin
            //-----------------Посадили комиссара-------------
            if target[1]=com_player then
            begin
              for i:=1 to PlayerCount do
                if (getPlayerTeam(i)=1) and (PlayersArr[i]^.activity=com_player) then
                  AddPoints(i, points_cost[155])
                else
                  if ((getPlayerTeam(i)=2) or (getPlayerTeam(i)=4)) and (PlayersArr[i]^.activity=com_player) then
                    AddPoints(i,points_cost[156]);
              Points[1]:=points_cost[155];
              Points[2]:=points_cost[156];
              Points[4]:=points_cost[156];
            end;
            //------------------------------------------------

            //-----------------Посадили мафа------------------
            if GetPlayerTeam(target[1])=2 then
            begin
              for i:=1 to PlayerCount do
                if ((getPlayerTeam(i)=1) or (getPlayerTeam(i)=4)) and (PlayersArr[i]^.activity=target[1]) then
                  AddPoints(i, points_cost[157]);
              Points[1]:=points_cost[157];
              Points[4]:=points_cost[157];
            end;
            //------------------------------------------------

            //-----------------Посадили яка------------------
            if GetPlayerTeam(target[1])=4 then
            begin
              for i:=1 to PlayerCount do
                if (getPlayerTeam(i)=1) or (getPlayerTeam(i)=2) and (PlayersArr[i]^.activity=target[1]) then
                  AddPoints(i, points_cost[157]);
              Points[1]:=points_cost[157];
              Points[2]:=points_cost[157];
            end;
            //------------------------------------------------

            //-----------------Посадили мирного---------------
            if (GetPlayerTeam(target[1])=1) then
            begin
              for i:=1 to PlayerCount do
                if (getPlayerTeam(i)=1) and (PlayersArr[i]^.activity=target[1]) then
                  AddPoints(i, points_cost[154])
                else
                  if ((getPlayerTeam(i)=2) or (getPlayerTeam(i)=4)) and (PlayersArr[i]^.activity=target[1]) then
                    AddPoints(i,points_cost[158]);
              Points[1]:=Points[1]+points_cost[154];
              Points[2]:=Points[2]+points_cost[158];
              Points[4]:=Points[4]+points_cost[158];
            end;
            //------------------------------------------------

            MsgToChannel(game_chan, GetRandomTextReplaceRole('DayKill', target[1]));
            KillPlayer(target[1]);
          end;
      end
      else
        MsgToChannel(game_chan, GetRandomTextReplaceRole('DayKillNoChoice', 1));
    end
    else
      MsgToChannel(game_chan, GetRandomTextReplaceRole('DayKillNoActive', 1));
    //-----------------------------------------------------
    if show_votepoints then
    begin
      Pause(time_pause);
      Str:='[b]Мирные[/b] [i]';
      if Points[1]>=0 then
        Str:=Str+'+';
      Str:=Str+IntToStr(Points[1])+'[/i], [b]Мафия[/b] [i]';
      if Points[2]>=0 then
        Str:=Str+'+';
      Str:=Str+IntToStr(Points[2])+'[/i]';
      if Gametype.UseYakuza then
      begin
        Str:=Str+', [b]Якудза[/b] [i]';
        if Points[4]>=0 then
          Str:=Str+'+';
        Str:=Str+IntToStr(Points[4])+'[/i]';
      end;
      MsgToChannel(game_chan, StringReplace(GetRandomTextFromIni(file_messages, 'VoteResultPoints'), '%result%', Str,  [rfReplaceAll]));
    end;
    Pause(time_pause);


    // Убийство бездействующих игроков.
    k:=0; // количество убитых
    for i:=1 to playerCount do
      if (PlayersArr[i]^.activity > 0) then
        PlayersArr[i]^.no_activity_days:=kill_for_no_activity
      else if (PlayersArr[i]^.gamestate > 0) then
      begin
        Dec(PlayersArr[i]^.no_activity_days);
        if (PlayersArr[i]^.no_activity_days = 0) then
        begin
          KillPlayer(i);
          KilledPlayers[k]:=i;
          Inc(k);
        end;
      end;
    // Вывод убитых игроков
    if k > 0 then
      MsgToChannel(game_chan, GetRandomTextReplacePlayerList('KillInactivePlayers', KilledPlayers, k));
    Pause(time_pause);


    ApplyKills();
    GetAlivePlayers(2);
    if not CheckWin(4) then
    begin
      ApplyBans();
      Pause(time_pause);
      StartNight();
    end;
  end;

end.
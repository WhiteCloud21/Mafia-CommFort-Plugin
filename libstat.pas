unit libstat;

interface

uses
  Windows, Classes, MyIniFiles, comm_info, comm_data, mafia_data, libfunc, SysUtils;

  procedure SortStats_QuickSort(l, r: Integer);

  procedure LoadStatsFile();
  procedure SortStats();
  function  ParseTemplate(InFileName:String; PlayerCount: Integer):TStringList;

  procedure UpdateStats();

implementation
  type
    TStat = record
      Name: String;
      Rate: Single;
    end;

    TUpdateStatThread=class(TThread)
      protected
        procedure Execute; override;
    end;

  var
    UserStats: array of TStat;
    UsersCount: Integer;
    TopPointsCopy : array [1..TopMaxPlayers] of record
      Name: String;
      Points: Integer;
    end;
    TopRoleCopy : array [1..255] of record
      Name: String;
      Plays: Integer;
    end;

  procedure SortStats_QuickSort(l, r: Integer);
  var
    i,j,m: integer;
    x1: Single;
    temp: TStat;
  begin
    i:=l;
    j:=r;
    m:=round ((l+r)/2);
    x1:=UserStats[m].Rate;
    repeat
      while UserStats[i].Rate>x1 do inc(i);
      while UserStats[j].Rate<x1 do dec(j);
      if i<=j then
      begin
        temp:=UserStats[i];
        UserStats[i]:=UserStats[j];
        UserStats[j]:=temp;
        inc(i);
        dec(j);
      end;
    until i>j;
    if l<j then SortStats_QuickSort(l,j);
    if i<r then SortStats_QuickSort(i,r);
  end;


  procedure LoadStatsFile();
  var
    Ini : TIniFile;
    Sections: TStringList;
    I, K, J: Integer;
    Wins, Plays, Draws, Points: Integer;
    StopLoop:Boolean;
  begin
    Ini := TIniFile.Create(file_users);
    Sections:=TStringList.Create();
    Sections.Clear();
    Ini.ReadSections(Sections);
    UsersCount:=Sections.Count;
    SetLength(UserStats, UsersCount);

    for I:=1 to TopMaxPlayers do
    begin
      TopPointsCopy[I].Name:='';
      TopPointsCopy[I].Points:=0;
    end;

    for I:=1 to 255 do
    begin
      TopRoleCopy[I].Name:='';
      TopRoleCopy[I].Plays:=0;
    end;

    for I := 0 to UsersCount - 1 do
    begin
      UserStats[I].Name:=UnCheckStr(Sections.Strings[I]);
      UserStats[I].Name:=StringReplace(UserStats[I].Name, '<', '&lt;', [rfReplaceAll]);
      UserStats[I].Name:=StringReplace(UserStats[I].Name, '>', '&gt;', [rfReplaceAll]);
      Wins:=Ini.ReadInteger(Sections.Strings[I],'wins',0);
      Plays:=Ini.ReadInteger(Sections.Strings[I],'plays',0);
      Draws:=Ini.ReadInteger(Sections.Strings[I],'draws',0);
      Points:=Ini.ReadInteger(Sections.Strings[I], 'points', 0);
      if (Plays-Wins-Draws) > 0 then
        UserStats[I].Rate:=Wins*Plays/(Plays-Wins-Draws)
      else
        UserStats[I].Rate:=0;

      // Топ по очкам
      StopLoop:=False;
      k:=1;
      while (k<=TopMaxPlayers) and not StopLoop do
      begin
        if TopPointsCopy[k].Points<Points then
        begin
          j:=TopMaxPlayers;
          while j>=k+1 do
          begin
            TopPointsCopy[j].Points:=TopPointsCopy[j-1].Points;
            TopPointsCopy[j].Name:=TopPointsCopy[j-1].Name;
            Dec(j);
          end;
          StopLoop:=True;
          TopPointsCopy[k].Points:=Points;
          TopPointsCopy[k].Name:=UnCheckStr(Sections.Strings[I]);
        end;
        Inc(k);
      end;

      // Топ по ролям
      for k:=1 to 255 do
        if (k in SetRoles) and (Ini.ReadInteger(Sections.Strings[I],'role_'+IntToStr(k),0)>TopRoleCopy[k].Plays) then
        begin
          TopRoleCopy[k].Plays:=Ini.ReadInteger(Sections.Strings[I],'role_'+IntToStr(k),0);
          TopRoleCopy[k].Name:=UnCheckStr(Sections.Strings[I]);
        end;
    end;
    Sections.Free;
    Ini.Free;
  end;

  procedure SortStats();
  begin
    SortStats_QuickSort(0,UsersCount-1);
  end;

  function ParseTemplate(InFileName:String; PlayerCount: Integer):TStringList;
  var
    Ini, IniData : TIniFile;
    Str, Str2: String;
    InList: TStringList;
    I, K: Integer;
    J: Byte;
    EvenOdd: Boolean;
  begin
    if PlayerCount>UsersCount then
      PlayerCount:=UsersCount;

    Ini := TIniFile.Create(file_users);
    IniData := TIniFile.Create(file_data);
    InList:=TStringList.Create();
    InList.Clear();
    InList.LoadFromFile(InFileName, TEncoding.UTF8);

    Result:=TStringList.Create();
    Result.Clear();
    for K := 0 to InList.Count - 1 do
    begin
      Str:=InList.Strings[K];
      //----------------- Замена переменных шаблона---------------------------
      Str:=StringReplace(Str,  '%timestamp%', DateTimeToStr(Now), [rfReplaceAll]+[rfIgnoreCase]);
      Str:=StringReplace(Str,  '%maxplayers%', IniData.ReadString('Global','MaxPlayers','0'), [rfReplaceAll]+[rfIgnoreCase]);
      Str:=StringReplace(Str, '%maxplayersdatetime%', DateTimeToStr(IniData.ReadDateTime('Global','MaxPlayersDateTime', 0)), [rfReplaceAll]+[rfIgnoreCase]);
      Str:=StringReplace(Str,  '%totalplayers%', IntToStr(UsersCount), [rfReplaceAll]+[rfIgnoreCase]);
      //----------------------------------------------------------------------
      if (Pos('<userrow />', Str)>0) then // Строка заменяется для каждого пользователя
      begin
        EvenOdd:=False;
        Str:=StringReplace(Str, '<userrow />', '', [rfReplaceAll]);
        for I := 0 to PlayerCount - 1 do
        begin
          EvenOdd:=not EvenOdd;
          //--------------- Замена переменных шаблона-------------------------
          Str2:=StringReplace(Str,  '%position%', IntToStr(I+1), [rfReplaceAll]+[rfIgnoreCase]);
          Str2:=StringReplace(Str2, '%name%', UserStats[I].Name, [rfReplaceAll]+[rfIgnoreCase]);
          Str2:=StringReplace(Str2, '%rate%', FloatToStrF(UserStats[I].Rate, ffFixed, 20, 4), [rfReplaceAll]+[rfIgnoreCase]);
          Str2:=StringReplace(Str2, '%points%', Ini.ReadString(CheckStr(UserStats[I].Name),'points','0'), [rfReplaceAll]+[rfIgnoreCase]);
          Str2:=StringReplace(Str2, '%plays%', Ini.ReadString(CheckStr(UserStats[I].Name),'plays','0'), [rfReplaceAll]+[rfIgnoreCase]);
          Str2:=StringReplace(Str2, '%draws%', Ini.ReadString(CheckStr(UserStats[I].Name),'draws','0'), [rfReplaceAll]+[rfIgnoreCase]);
          Str2:=StringReplace(Str2, '%wins%', Ini.ReadString(CheckStr(UserStats[I].Name),'wins','0'), [rfReplaceAll]+[rfIgnoreCase]);
          Str2:=StringReplace(Str2, '%lastplay%',DateTimeToStr(Ini.ReadDateTime(CheckStr(UserStats[I].Name),'LastPlay', 0)), [rfReplaceAll]+[rfIgnoreCase]);
          for J := 1 to 255 do
            if J in setRoles then
              Str2:=StringReplace(Str2, '%role_'+IntToStr(J)+'%', Ini.ReadString(CheckStr(UserStats[I].Name),'role_'+IntToStr(J),'0'), [rfReplaceAll]+[rfIgnoreCase]);

          if EvenOdd then
            Str2:=StringReplace(Str2, '%evenodd%', 'odd', [rfReplaceAll]+[rfIgnoreCase])
          else
            Str2:=StringReplace(Str2, '%evenodd%', 'even', [rfReplaceAll]+[rfIgnoreCase]);
            //------------------------------------------------------------------
          Result.Add(Str2);
        end;
      end
      else
        Result.Add(Str);
    end;
    IniData.Free;
    Ini.Free;
  end;

  procedure TUpdateStatThread.Execute;
  var
    OutList: TStringList;
    I: Integer;
  begin
    try
      LoadStatsFile();
      UpdateTopCriticalSection.Enter;
      if UsersCount>0 then
        SortStats();
      try
        for I := 1 to TopMaxPlayers do
        begin
          TopPoints[I].Name:=TopPointsCopy[I].Name;
          TopPoints[I].Points:=TopPointsCopy[I].Points;
          TopRate[I].Name:='';
          TopRate[I].Rate:=0;
          if I<=UsersCount then
          begin
            TopRate[I].Rate:=UserStats[I-1].Rate;
            TopRate[I].Name:=CheckStr(UserStats[I-1].Name);
            TopRate[I].Name:=StringReplace(TopRate[I].Name, '&lt;', '<', [rfReplaceAll]);
            TopRate[I].Name:=StringReplace(TopRate[I].Name, '&gt;', '>', [rfReplaceAll]);
          end;
        end;

        for i := 1 to 255 do
        begin
          TopRole[I].Name:=TopRoleCopy[I].Name;
          TopRole[I].Plays:=TopRoleCopy[I].Plays;
        end;
      finally
        UpdateTopCriticalSection.Leave;
      end;
      if update_greeting then
      begin
        OutList:=ParseTemplate(file_template_greeting, top_default);
        try
        	ChangeGreeting(game_chan, OutList.Text);
        finally
        	OutList.Free;
        end;
      end;
      if export_stats then
      begin
        OutList:=ParseTemplate(file_template, UsersCount);
        try
        	OutList.SaveToFile(file_export_stats, TEncoding.UTF8);
        finally
        	OutList.Free;
        end;
      end;
    except
      on e: exception do
        PCorePlugin^.onError(PCorePlugin^, e, '-------------Exception while exporting stats---------');
    end;
    UserStats:=nil;
  end;

  procedure UpdateStats();
  var
    NewThread: TUpdateStatThread;
  begin
    NewThread:=TUpdateStatThread.Create(true);
    NewThread.FreeOnTerminate:=true;
    NewThread.Resume();
  end;

end.

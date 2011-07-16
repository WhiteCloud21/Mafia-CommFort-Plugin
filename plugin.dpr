{
  ! Прочитайте и не удаляйте этот комментарий, проявите уважение к его автору :)
  Mafia CommFort 5 Plugin
  Вы можете использовать данный исходный код в любых законных целях, но не забывайте указывать оригинального автора :)
  Следите за обновлениями тут: http://commfort.com/ru/forum/viewtopic.php?f=28&t=6386
  Если Вы исправили ошибку или добавили полезную функцию, лучше поделиться решением со всеми, пишите сюда: http://commfort.com/ru/forum/ucp.php?i=pm&mode=compose&u=14755

  Вклад в создание и развитие плагина внесли:
    Автор скелета плагина для CommFort 4 - sonic
    Превращение скелета в мафию и портирование под CommFort 5 - KGB
    Советы по возможностям плагина - DENS, sasha
    Советы по улучшению кода - -=SJ=-
    Терпение - Maxim Mirgorodsky
    И, конечно, все пользователи, тестирующие плагин и сообщающие об ошибках:)
}
// JCL_DEBUG_EXPERT_GENERATEJDBG ON
// JCL_DEBUG_EXPERT_INSERTJDBG ON
library mafia_plugin;

uses
  Windows,
  SysUtils,
  Classes,
  comm_info in 'comm_info.pas',
  comm_plugin in 'comm_plugin.pas',
  comm_data in 'comm_data.pas',
  mafia in 'mafia.pas',
  libfunc in 'libfunc.pas',
  libstat in 'libstat.pas',
  libqueue in 'libqueue.pas',
  settings in 'settings.pas' {frmSettings},
  mafia_data in 'mafia_data.pas',
  about in 'about.pas' {frmAbout};

{$E cfplug}

function PluginStart(dwThisPluginID : DWORD; func1 : TtypeCommFortProcess; func2: TtypeCommFortGetData) : Boolean; stdcall;
begin
  ThisPlugin := TCommPlugin.Create(dwThisPluginID, @func1, @func2);
  result                       := true;
end;

function PluginStop : Byte; stdcall;
begin
  ThisPlugin.Free;
  Result :=1;
end;

procedure PluginProcess(dwMessageID : DWORD; bMessage : TBytes; dwMessageLength : DWORD); stdcall;
begin
  ThisPlugin.CorePlugin.Process(dwMessageID, bMessage, dwMessageLength);
end;

function PluginGetData(dwMessageID : DWORD; bInBuffer : PString; inBufferLength : DWORD; bOutBuffer : PAnsiChar; outBufferLength : DWORD): DWORD; stdcall;
var
  name: string;
  i: DWORD;
begin
  Result:=0;
  case dwMessageID of
    GD_PLUGIN_SERVER_OR_CLIENT:
    begin
      if outBufferLength>0 then
      begin
        I:=0;
        CopyMemory(bOutBuffer, @I, 4);
      end;
    end;

    GD_PLUGIN_NAME:
    begin
      Result:=Length(PLU_NAME)*2+4;
      if outBufferLength>0 then
      begin
        I:=Length(PLU_NAME);
        name:= PLU_NAME;
        CopyMemory(bOutBuffer, @I, 4);
        CopyMemory(bOutBuffer+4, @name[1], I*2);
      end;
    end;
  end;
end;

procedure PluginShowOptions();
begin
  if not Assigned(frmSettings) then
  begin
    frmSettings:=TfrmSettings.Create(nil);
    frmSettings.Show;
  end;
  
end;

procedure PluginShowAbout();
begin
  if not Assigned(frmAbout) then
  begin
    frmAbout:=TFrmAbout.Create(nil);
    frmAbout.Show;
  end;
end;

//function PluginPremoderation(dwMessageID : DWORD; bMessage : PCHAR; dwMessageLength : PDWORD) : boolean; stdcall;
//begin
//  result := ThisPlugin.CorePlugin.Premoderation(dwMessageID, bMessage, dwMessageLength);
//end;

exports PluginStart, PluginStop, PluginProcess, PluginGetData, PluginShowOptions, PluginShowAbout;

end.

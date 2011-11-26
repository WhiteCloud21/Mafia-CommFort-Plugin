unit libuserdata;
// TODO: «десь должен быть описан класс дл€ работы с базой пользователей дл€ дальнейшего более простого перехода на sqlite

interface
  // ќчистка базы пользователей от старых записей
	procedure Cleanup;

implementation
uses
  Windows, Classes, MyIniFiles, comm_data, mafia_data, libfunc, SysUtils, DateUtils;

type
  TCleanupThread=class(TThread)
  	protected
    	procedure Execute; override;
  end;

procedure Cleanup;
var
	thread: TCleanupThread;
begin
	if time_removeUsers > 0 then
  begin
    thread := TCleanupThread.Create(true);
    thread.FreeOnTerminate := true;
    thread.Resume;
  end
  else
  	IsCleanupStatsFinished := True;
end;

procedure TCleanupThread.Execute;
var
	ini: TIniFile;
  sections: TStringList;
  i: Integer;
begin
	// Ѕлокировка параллельного доступа к файлу
	UpdateTopCriticalSection.Enter;

  // Ќепосредственное удаление старых записей
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
  IsCleanupStatsFinished := True;

  // –азблокировка
  UpdateTopCriticalSection.Leave;
end;

end.

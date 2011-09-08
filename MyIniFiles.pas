unit MyIniFiles;

interface

	uses SysUtils, Classes, IniFiles;
  type

	TIniFile = class(IniFiles.TIniFile)
	public
		//function ReadString(const Section, Ident, Default: string): string; override;
		procedure ReadSection(const Section: string; Strings: TStrings); override;
		procedure ReadSections(Strings: TStrings); override;
  end;

implementation
	uses RTLConsts, Windows;

function MyGetFileSize(const FileName:string): Int64;
var
	SearchRec:TSearchRec;
begin
	if SysUtils.FindFirst(ExpandFileName(FileName), faAnyFile,SearchRec)=0 then
  	Result:=SearchRec.Size
	else
  	Result:=0;
	SysUtils.FindClose(SearchRec);
end;

procedure TIniFile.ReadSections(Strings: TStrings);
var
  Buffer, P: PChar;
  BufSize: Integer;
begin
	try
  	BufSize := MyGetFileSize(FileName);
  except
  	BufSize := 1024*1024;
  end;
  GetMem(Buffer, BufSize);
  try
    Strings.BeginUpdate;
    try
      Strings.Clear;
      if GetPrivateProfileString(nil, nil, nil, Buffer, BufSize,
        PChar(FileName)) <> 0 then
      begin
        P := Buffer;
        while P^ <> #0 do
        begin
          Strings.Add(P);
          Inc(P, StrLen(P) + 1);
        end;
      end;
    finally
      Strings.EndUpdate;
    end;
  finally
    FreeMem(Buffer, BufSize);
  end;
end;

procedure TIniFile.ReadSection(const Section: string; Strings: TStrings);
var
  Buffer, P: PChar;
  CharCount: Integer;
  BufSize: Integer;

  procedure ReadStringData;
  begin
    Strings.BeginUpdate;
    try
      Strings.Clear;
      if CharCount <> 0 then
      begin
        P := Buffer;
        while P^ <> #0 do
        begin
          Strings.Add(P);
          Inc(P, StrLen(P) + 1);
        end;
      end;
    finally
      Strings.EndUpdate;
    end;
  end;

begin
  BufSize := 1024*1024*64;

  while True do
  begin
    GetMem(Buffer, BufSize * SizeOf(Char));
    try
      CharCount := GetPrivateProfileString(PChar(Section), nil, nil, Buffer, BufSize, PChar(FileName));
      if CharCount < BufSize - 2 then
      begin
        ReadStringData;
        Break;
      end;
    finally
      FreeMem(Buffer, BufSize);
    end;
    BufSize := BufSize * 4;
  end;
end;

end.

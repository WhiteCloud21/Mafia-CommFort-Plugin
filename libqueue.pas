unit libqueue;

interface

uses
  Windows, Classes, ExtCtrls, comm_data, SysUtils, SyncObjs;

type

  PMsgList = ^TMsgList;
  TMsgList=record
    MsgType: DWord;
    {
      0      - Пауза
      1      - Вызов функции
      другое - CommFortProcess
    }
    Value: TBytes;
    BufLength: DWord;
    Next: PMsgList;
  end;

  TMsgQueue = class
    private
      Timer: TTimer;
      Msg: PMsgList;
      CommFortProcess: TtypeCommFortProcess;
      dwPluginID: DWord;
      DataAccessCriticalSection: TCriticalSection;
    public
      constructor Create(dwThisPluginID : DWORD; func : TtypeCommFortProcess);
      destructor Destroy; override;
      procedure InsertMsg(MsgType: DWord; Value: TBytes; BufLength: DWord);
      procedure RefreshTimer(Sender: TObject);
  end;

  TProc = procedure();

const
  QUEUE_MSGTYPE_PAUSE = 0;
  QUEUE_MSGTYPE_CALL = 1;

implementation
  constructor TMsgQueue.Create(dwThisPluginID : DWORD; func : TtypeCommFortProcess);
  begin
    dwPluginID := dwThisPluginID;
    CommFortProcess := func;
    Msg:=nil;
    DataAccessCriticalSection:=TCriticalSection.Create;
    Timer:=TTimer.Create(nil);
    Timer.Enabled:=False;
    Timer.Interval:=0;
    Timer.OnTimer:=RefreshTimer;
  end;

  destructor TMsgQueue.Destroy;
  var
    P : PMsgList;
  begin
    Timer.Free;
    while not DataAccessCriticalSection.TryEnter do ;
    DataAccessCriticalSection.Free;
    while (Msg<>nil) do
    begin
      P:=Msg;
      Msg:=Msg^.Next;
      P^.Value:=nil;
      Dispose(P);
    end;
    inherited;
  end;

  procedure TMsgQueue.InsertMsg(MsgType: DWord; Value: TBytes; BufLength: DWord);
  var
    P, NewItem : PMsgList;
  begin
    //-----Создание элемента-------------
    New(NewItem);
    NewItem^.MsgType:=MsgType;
    SetLength(NewItem^.Value, BufLength);
    NewItem^.Value:=Value;
    NewItem^.BufLength:=BufLength;
    NewItem^.Next:=nil;
    //-----------------------------------

    DataAccessCriticalSection.Enter;
    try
      if Msg=nil then
        Msg:=NewItem
      else
      begin
        P:=Msg;
        while (P^.Next<>nil) do
          P:=P^.Next;
        P^.Next:=NewItem;
      end;
      if not Timer.Enabled then
      begin
        Timer.Interval:=1;
        Timer.Enabled:=True;
      end;
    finally
      DataAccessCriticalSection.Leave;
    end;
  end;

  procedure TMsgQueue.RefreshTimer(Sender: TObject);
  var
    P : PMsgList;
    Flag, Flag2: Boolean;
    PauseTime: DWord;

    Proc: {procedure()} DWord;
  begin
    DataAccessCriticalSection.Enter;
    try
      Timer.Enabled:=False;
      Flag2:=False;
      Flag:=(Msg<>nil);
      if Flag then
        Flag2:=(Msg^.MsgType<>QUEUE_MSGTYPE_PAUSE);

      //-------------Вывод сообщений--------------
      while Flag and Flag2 do
      begin
        case Msg^.MsgType of
          QUEUE_MSGTYPE_CALL: begin
            CopyMemory(@Proc, @Msg^.Value[0], 4);
            TProc(Proc)();
          end;
          else
            CommFortProcess(dwPluginID, Msg^.MsgType,@Msg^.Value[0], Msg^.BufLength);
        end;
        Msg^.Value:=nil;
        P:=Msg;
        Msg:=Msg^.Next;
        Dispose(P);

        Flag:=(Msg<>nil);
        if Flag then
          Flag2:=(Msg^.MsgType<>QUEUE_MSGTYPE_PAUSE);
      end;
      //------------------------------------------

      //--------------Спец. события---------------
      if Flag then
      begin
        CopyMemory(@PauseTime, @Msg^.Value[0], 4);
        Timer.Interval:=PauseTime;
        Timer.Enabled:=True;
        Msg^.Value:=nil;
        P:=Msg;
        Msg:=Msg^.Next;
        Dispose(P);
      end;
      //------------------------------------------
    finally
      DataAccessCriticalSection.Leave;
    end;
  end;

end.

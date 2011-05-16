unit comm_info;

interface

uses Windows, Classes, Sysutils, comm_data, libqueue;

type

  TCommPluginC = class
    private
      dwPluginID      : DWORD;
      CommFortProcess : TtypeCommFortProcess;
      CommFortGetData : TtypeCommFortGetData;
      FonError        : TError;
      FonAuthFail     : TAuthFail;
      FonJoinChannelFail : TJoinChannelFail;
      FonPrivMsg      : TPrivMsg;
      FonPMsg         : TPMsg;
      FonJoinBot      : TJoinBot;
      FonUserJoinChannel: TUsrJoin;
      FonPubMsg       : TPubMsg;
      FonConStChg     : TonConStChg;
    public
      constructor Create(dwThisPluginID : DWORD; func1 : TtypeCommFortProcess; func2: TtypeCommFortGetData);
      destructor Destroy; override;

      procedure WriteLog(fileName: String; Text: String);

      procedure Process(dwMessageID : DWORD; bMessage : TBytes; dwMessageLength : DWORD);
      procedure JoinVirtualUser(Name, IP: String; PassType: DWord; Pass: String; Icon: DWord);
      procedure LeaveVirtualUser(Name: String);
      procedure AddMessageToChannel(Name, channel : string; regime : DWord; text : string);
      procedure AddPrivateMessage(Name: String; regime : DWord; User : string; text : string);
      procedure AddPersonalMessage(Name: String; Importance: DWord; User, Text : string);
      procedure AddTheme(Name:String; channel : string; newtheme : string);
      procedure AddGreeting(Name:String; channel : string; Text : string);
      procedure AddState(Name, newstate : string);
      procedure AddChannel(Name, channel : string; visibility, regime : DWord);
      procedure LeaveChannel(Name, channel : string);
      procedure ClientLeavePrivate(User : string);
      procedure AddRestriction(Name: String; restrictiontype, identificationtype, anonymitytype : DWord; time : Double; ident : string; Channel : string; reason : string);
      procedure RemoveRestriction(Name: String; restrictionid : DWORD; reason : string);
      procedure RemoveChannel(Name, channel : string);
      procedure StopPlugin();

      function AskProgramType():DWord;
      function AskProgramVersion():String;
      function AskPluginTempPath():String;
      function AskUserChannels(Name: String; var ChannelList: TChannels):DWord;
      function AskUsersInChannel(Name, Channel: String; var UserList: TUsers):DWord;
      function AskRestrictions(var RestList: TRestrictions):DWord;
      function AskIPState(Name: String):DWord;
      function AskIP(Name: String):String;
      function AskID(Name: String):String;

      function ClientAskCurrentUser():TUser;
      function ClientAskConState():DWord;
      function ClientAskRight(RightType: DWord; Channel: String):DWord;

      property PluginID: DWORD read dwPluginID;
      property onError: TError read FonError write FonError;
      property onJoinChannelFail: TJoinChannelFail read FonJoinChannelFail write FonJoinChannelFail;
      property onPrivateMessage: TPrivMsg read FonPrivMsg write FonPrivMsg;
      property onPersonalMessage: TPMsg read FonPMsg write FonPMsg;
      property onBotJoin: TJoinBot read FonJoinBot write FonJoinBot;
      property onPublicMessage: TPubMsg read FonPubMsg write FonPubMsg;
      property onUserJoinChannel: TUsrJoin read FonUserJoinChannel write FonUserJoinChannel;
      property onConStChg: TonConStChg read FonConStChg write FonConStChg;
    end;
  PCommPluginC = ^TCommPluginC;

  ICommPlugin = class
    public
      CorePlugin: TCommPluginC;
      constructor Create(dwThisPluginID : DWORD; func1 : TtypeCommFortProcess; func2: TtypeCommFortGetData);
      destructor Destroy; override;
  end;

var
  PCorePlugin: PCommPluginC;
  MsgQueue: TMsgQueue;

implementation

constructor ICommPlugin.Create(dwThisPluginID : DWORD;func1 : TtypeCommFortProcess; func2: TtypeCommFortGetData);
begin
  CorePlugin := TCommPluginC.Create(dwThisPluginID, @func1, @func2);
end;

destructor ICommPlugin.Destroy;
begin
  CorePlugin.Free;
  inherited;
end;

constructor TCommPluginC.Create(dwThisPluginID : DWORD; func1 : TtypeCommFortProcess; func2: TtypeCommFortGetData);
begin
  dwPluginID := dwThisPluginID;
  CommFortProcess := func1;
  CommFortGetData := func2;
  MsgQueue:=TMsgQueue.Create(dwPluginID, CommFortProcess);
end;

destructor TCommPluginC.Destroy;
begin
  MsgQueue.Free;
  inherited;
end;

procedure TCommPluginC.WriteLog(fileName: String; Text: String);
var
  LogFile: TStringList;
begin
  LogFile:=TStringList.Create;
  LogFile.LoadFromFile(fileName, TEncoding.Unicode);
  LogFile.Add(DateTimeToStr(Now)+': '+Text);
  LogFile.SaveToFile(fileName, TEncoding.Unicode);
  LogFile.Free;
end;

procedure TCommPluginC.Process(dwMessageID : DWORD; bMessage : TBytes; dwMessageLength : DWORD);
var
    user: TUser;
    name, text, channel, theme: string;
    regime: integer;
    I, K: Cardinal;
begin
  case dwMessageID of
    PM_PLUGIN_AUTH_FAIL:
    if Assigned(FonAuthFail) then try
      begin
        CopyMemory(@K, @bMessage[0], 4);
        Name :=TEncoding.Unicode.GetString(bMessage, 4, K*2);
        I:=K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        FonAuthFail(Self, Name, K);
      end except
      on e: exception do
        if Assigned(FOnError) then
          FOnError(Self, e);
      end;

    PM_PLUGIN_JOINCHANNEL_FAIL:
    if Assigned(FonJoinChannelFail) then try
      begin
        CopyMemory(@K, @bMessage[0], 4);
        Name :=TEncoding.Unicode.GetString(bMessage, 4, K*2);
        I:=K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        Channel :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        FonJoinChannelFail(Self, name, channel, K);
      end except
      on e: exception do
        if Assigned(FOnError) then
          FOnError(Self, e);
      end;
    PM_PLUGIN_MSG_PRIV:
    if Assigned(FonPrivMsg) then try
      begin
        CopyMemory(@K, @bMessage[0], 4);
        Name :=TEncoding.Unicode.GetString(bMessage, 4, K*2);
        I:=K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.Name :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.IP :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.sex := K;
        I:=I+4;
        CopyMemory(@K, @bMessage[I], 4);
        regime := K;
        I:=I+4;
        CopyMemory(@K, @bMessage[I], 4);
        Text :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        FonPrivMsg(Self, name, user, regime, text);
      end except
      on e: exception do
        if Assigned(FOnError) then
          FOnError(Self, e);
      end;
    PM_PLUGIN_MSG_PM:
      if Assigned(FonPMsg) then try
      begin
        CopyMemory(@K, @bMessage[0], 4);
        Name :=TEncoding.Unicode.GetString(bMessage, 4, K*2);
        I:=K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.Name :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.IP :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.sex := K;
        I:=I+4;
        CopyMemory(@K, @bMessage[I], 4);
        Text :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        FonPMsg(Self, name, user, text);
      end except
      on e: exception do
        if Assigned(FOnError) then
          FOnError(Self, e);
      end;
    PM_PLUGIN_JOIN_BOT:
      if Assigned(FonJoinBot) then try
      begin
        CopyMemory(@K, @bMessage[0], 4);
        Name :=TEncoding.Unicode.GetString(bMessage, 4, K*2);
        I:=K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        channel :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        theme :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        text :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        FonJoinBot(Self, Name, channel, theme, text);
      end except
      on e: exception do
        if Assigned(FOnError) then
          FOnError(Self, e);
      end;
    PM_PLUGIN_MSG_PUB:
    if Assigned(FonPubMsg) then try
      begin
        CopyMemory(@K, @bMessage[0], 4);
        Name :=TEncoding.Unicode.GetString(bMessage, 4, K*2);
        I:=K*2+4;
        if Name<>BOT_NAME then Exit;

        CopyMemory(@K, @bMessage[I], 4);
        user.Name :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.IP :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.sex:= K;
        I:=I+4;
        CopyMemory(@K, @bMessage[I], 4);
        Channel :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        regime := K;
        I:=I+4;
        CopyMemory(@K, @bMessage[I], 4);
        Text :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        FonPubMsg(Self, name, user, channel, regime, text);
      end except
      on e: exception do
        if Assigned(FOnError) then
          FOnError(Self, e);
      end;

    PM_PLUGIN_USER_JOINEDCHANNEL:
    if Assigned(FonUserJoinChannel) then try
      begin
        CopyMemory(@K, @bMessage[0], 4);
        Name :=TEncoding.Unicode.GetString(bMessage, 4, K*2);
        I:=K*2+4;
        if Name<>BOT_NAME then Exit;

        CopyMemory(@K, @bMessage[I], 4);
        Channel :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.Name :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.IP :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.sex:= K;
        FonUserJoinChannel(Self, name, user, channel);
      end except
      on e: exception do
        if Assigned(FOnError) then
          FOnError(Self, e);
      end;

    PM_CLIENT_MSG_PRIV:
    if Assigned(FonPrivMsg) then try
      begin
        CopyMemory(@K, @bMessage[0], 4);
        user.Name :=TEncoding.Unicode.GetString(bMessage, 4, K*2);
        I:=K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.IP :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.sex := K;
        I:=I+4;
        CopyMemory(@K, @bMessage[I], 4);
        regime := K;
        I:=I+4;
        CopyMemory(@K, @bMessage[I], 4);
        Text :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        FonPrivMsg(Self, BOT_NAME, user, regime, text);
      end except
      on e: exception do
        if Assigned(FOnError) then
          FOnError(Self, e);
      end;

    PM_CLIENT_MSG_PUB:
    if Assigned(FonPubMsg) then try
      begin
        CopyMemory(@K, @bMessage[0], 4);
        user.Name :=TEncoding.Unicode.GetString(bMessage, 4, K*2);
        I:=K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.IP :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        user.sex:= K;
        I:=I+4;
        CopyMemory(@K, @bMessage[I], 4);
        Channel :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        I:=I+K*2+4;
        CopyMemory(@K, @bMessage[I], 4);
        regime := K;
        I:=I+4;
        CopyMemory(@K, @bMessage[I], 4);
        Text :=TEncoding.Unicode.GetString(bMessage, I+4, K*2);
        FonPubMsg(Self, BOT_NAME, user, channel, regime, text);
      end except
      on e: exception do
        if Assigned(FOnError) then
          FOnError(Self, e);
      end;

    PM_CLIENT_CONSTATUS_CHANGED:
    if Assigned(FonConStChg) then try
      begin
        CopyMemory(@regime, @bMessage[0], 4);
        FonConStChg(Self, regime);
      end except
      on e: exception do
        if Assigned(FOnError) then
          FOnError(Self, e);
      end;
  end;
end;

//--------------------------------------------- CommfortProcess-----------------

procedure TCommPluginC.JoinVirtualUser(Name, IP: String; PassType: DWord; Pass: String; Icon: DWord);
var
  msg: TBytes;
  i, len: DWord;
begin
  len:=Length(Name)*2+Length(IP)*2+Length(Pass)*2+20;
  SetLength(msg, len);
  len:=Length(Name);
  CopyMemory(@msg[0], @len, 4);
  CopyMemory(@msg[4], @Name[1], len*2);
  i:=4+len*2;
  len:=Length(IP);
  CopyMemory(@msg[i], @len, 4);
  CopyMemory(@msg[i+4], @IP[1], len*2);
  i:=i+len*2+4;
  CopyMemory(@msg[i], @PassType, 4);
  i:=i+4;
  len:=Length(Pass);
  CopyMemory(@msg[i], @len, 4);
  CopyMemory(@msg[i+4], @Pass[1], len*2);
  i:=i+len*2+4;
  CopyMemory(@msg[i], @Icon, 4);
  i:=i+4;
  //CommFortProcess(dwPluginID, PM_PLUGIN_JOIN_VIRTUAL_USER, @msg[0], i);
  MsgQueue.InsertMsg(PM_PLUGIN_JOIN_VIRTUAL_USER, msg, i);
end;

procedure TCommPluginC.LeaveVirtualUser(Name: String);
var
  msg: TBytes;
  i, len: DWord;
begin
  len:=Length(Name)*2+4;
  SetLength(msg, len);
  len:=Length(Name);
  CopyMemory(@msg[0], @len, 4);
  CopyMemory(@msg[4], @Name[1], len*2);
  i:=4+len*2;
  //CommFortProcess(dwPluginID, PM_PLUGIN_LEAVE_VIRTUAL_USER, @msg[0], i);
  MsgQueue.InsertMsg(PM_PLUGIN_LEAVE_VIRTUAL_USER, msg, i);
end;

procedure TCommPluginC.AddMessageToChannel(Name, channel : string; regime : DWord; text : string);
var
  msg: TBytes;
  i, len: DWord;
begin
  case PROG_TYPE of
    0:
      begin
        len:=Length(Name)*2+Length(Channel)*2+Length(Text)*2+16;
        SetLength(msg, len);
        len:=Length(Name);
        CopyMemory(@msg[0], @len, 4);
        CopyMemory(@msg[4], @Name[1], len*2);
        i:=4+len*2;
        CopyMemory(@msg[i], @regime, 4);
        i:=i+4;
        len:=Length(Channel);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @Channel[1], len*2);
        i:=i+len*2+4;
        len:=Length(Text);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @Text[1], len*2);
        i:=i+len*2+4;
        //CommfortProcess(dwPluginID, PM_PLUGIN_SNDMSG_PUB, @msg[0], i);
        MsgQueue.InsertMsg(PM_PLUGIN_SNDMSG_PUB, msg, i);
      end;
    1:
      begin
        len:=Length(Channel)*2+Length(Text)*2+12;
        SetLength(msg, len);
        len:=Length(Channel);
        CopyMemory(@msg[0], @len, 4);
        CopyMemory(@msg[4], @Channel[1], len*2);
        i:=4+len*2;
        CopyMemory(@msg[i], @regime, 4);
        i:=i+4;
        len:=Length(Text);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @Text[1], len*2);
        i:=i+len*2+4;
        //CommfortProcess(dwPluginID, PM_CLIENT_SNDMSG_PUB, @msg[0], i);
        MsgQueue.InsertMsg(PM_CLIENT_SNDMSG_PUB, msg, i);
      end;
  end;
end;

procedure TCommPluginC.AddPrivateMessage(Name: String; regime : DWord; user : string; text : string);
var
  msg: TBytes;
  i, len: DWord;
begin
  case PROG_TYPE of
    0:
      begin
        len:=Length(Name)*2+Length(User)*2+Length(Text)*2+16;
        SetLength(msg, len);
        len:=Length(Name);
        CopyMemory(@msg[0], @len, 4);
        CopyMemory(@msg[4], @Name[1], len*2);
        i:=4+len*2;
        CopyMemory(@msg[i], @regime, 4);
        i:=i+4;
        len:=Length(User);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @User[1], len*2);
        i:=i+len*2+4;
        len:=Length(Text);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @Text[1], len*2);
        i:=i+len*2+4;
        //CommfortProcess(dwPluginID, PM_PLUGIN_SNDMSG_PRIV, @msg[0], i);
        MsgQueue.InsertMsg(PM_PLUGIN_SNDMSG_PRIV, msg, i);
      end;
    1:
      begin
        len:=Length(User)*2+Length(Text)*2+12;
        SetLength(msg, len);
        len:=Length(User);
        CopyMemory(@msg[0], @len, 4);
        CopyMemory(@msg[4], @User[1], len*2);
        i:=4+len*2;
        CopyMemory(@msg[i], @regime, 4);
        i:=i+4;
        len:=Length(Text);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @Text[1], len*2);
        i:=i+len*2+4;
        //CommfortProcess(dwPluginID, PM_CLIENT_SNDMSG_PRIV, @msg[0], i);
        MsgQueue.InsertMsg(PM_CLIENT_SNDMSG_PRIV, msg, i);
      end;
  end;
end;

procedure TCommPluginC.AddPersonalMessage(Name: String; Importance: DWord; User, Text : string);
var
  msg: TBytes;
  i, len: DWord;
begin
  case PROG_TYPE of
  0: begin
      len:=Length(Name)*2+Length(User)*2+Length(Text)*2+16;
      SetLength(msg, len);
      len:=Length(Name);
      CopyMemory(@msg[0], @len, 4);
      CopyMemory(@msg[4], @Name[1], len*2);
      i:=4+len*2;
      CopyMemory(@msg[i], @Importance, 4);
      i:=i+4;
      len:=Length(User);
      CopyMemory(@msg[i], @len, 4);
      CopyMemory(@msg[i+4], @User[1], len*2);
      i:=i+len*2+4;
      len:=Length(Text);
      CopyMemory(@msg[i], @len, 4);
      CopyMemory(@msg[i+4], @Text[1], len*2);
      i:=i+len*2+4;
      //CommfortProcess(dwPluginID, PM_PLUGIN_SNDMSG_PM, @msg[0], i);
      MsgQueue.InsertMsg(PM_PLUGIN_SNDMSG_PM, msg, i);
    end;
  1: begin
      len:=Length(User)*2+Length(Text)*2+12;
      SetLength(msg, len);
      len:=Length(User);
      CopyMemory(@msg[0], @len, 4);
      CopyMemory(@msg[4], @User[1], len*2);
      i:=4+len*2;
      CopyMemory(@msg[i], @Importance, 4);
      i:=i+4;
      len:=Length(Text);
      CopyMemory(@msg[i], @len, 4);
      CopyMemory(@msg[i+4], @Text[1], len*2);
      i:=i+len*2+4;
      //CommfortProcess(dwPluginID, PM_CLIENT_SNDMSG_PM, @msg[0], i);
      MsgQueue.InsertMsg(PM_CLIENT_SNDMSG_PM, msg, i);
    end;
  end;
end;

procedure TCommPluginC.AddTheme(Name:String; channel : string; newtheme : string);
var
  msg: TBytes;
  i, len: DWord;
begin
  case PROG_TYPE of
    0:
      begin
        len:=Length(Name)*2+Length(Channel)*2+Length(newtheme)*2+12;
        SetLength(msg, len);
        len:=Length(Name);
        CopyMemory(@msg[0], @len, 4);
        CopyMemory(@msg[4], @Name[1], len*2);
        i:=4+len*2;
        len:=Length(Channel);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @Channel[1], len*2);
        i:=i+len*2+4;
        len:=Length(newtheme);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @newtheme[1], len*2);
        i:=i+len*2+4;
        //CommfortProcess(dwPluginID, PM_PLUGIN_THEME_CHANGE, @msg[0], i);
        MsgQueue.InsertMsg(PM_PLUGIN_THEME_CHANGE, msg, i);
      end;
    1:
      begin
        len:=Length(Channel)*2+Length(newtheme)*2+12;
        SetLength(msg, len);
        len:=Length(Channel);
        CopyMemory(@msg[0], @len, 4);
        CopyMemory(@msg[4], @Channel[1], len*2);
        i:=len*2+4;
        len:=Length(newtheme);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @newtheme[1], len*2);
        i:=i+len*2+4;
        //CommfortProcess(dwPluginID, PM_CLIENT_THEME_CHANGE, @msg[0], i);
        MsgQueue.InsertMsg(PM_CLIENT_THEME_CHANGE, msg, i);
      end;
  end;
end;

procedure TCommPluginC.AddGreeting(Name:String; channel : string; Text : string);
var
  msg: TBytes;
  i, len: DWord;
begin
  case PROG_TYPE of
    0:
      begin
        len:=Length(Name)*2+Length(Channel)*2+Length(Text)*2+12;
        SetLength(msg, len);
        len:=Length(Name);
        CopyMemory(@msg[0], @len, 4);
        CopyMemory(@msg[4], @Name[1], len*2);
        i:=4+len*2;
        len:=Length(Channel);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @Channel[1], len*2);
        i:=i+len*2+4;
        len:=Length(Text);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @Text[1], len*2);
        i:=i+len*2+4;
        //CommfortProcess(dwPluginID, PM_PLUGIN_THEME_CHANGE, @msg[0], i);
        MsgQueue.InsertMsg(PM_PLUGIN_GREETING_CHANGE, msg, i);
      end;
    1:
      begin
        len:=Length(Channel)*2+Length(Text)*2+12;
        SetLength(msg, len);
        len:=Length(Channel);
        CopyMemory(@msg[0], @len, 4);
        CopyMemory(@msg[4], @Channel[1], len*2);
        i:=len*2+4;
        len:=Length(Text);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @Text[1], len*2);
        i:=i+len*2+4;
        //CommfortProcess(dwPluginID, PM_CLIENT_THEME_CHANGE, @msg[0], i);
        MsgQueue.InsertMsg(PM_CLIENT_GREETING_CHANGE, msg, i);
      end;
  end;
end;

procedure TCommPluginC.AddState(Name, newstate : String);
var
  msg: TBytes;
  i, len: DWord;
begin
  len:=Length(Name)*2+Length(newstate)*2+8;
  SetLength(msg, len);
  len:=Length(Name);
  CopyMemory(@msg[0], @len, 4);
  CopyMemory(@msg[4], @Name[1], len*2);
  i:=4+len*2;
  len:=Length(newstate);
  CopyMemory(@msg[i], @len, 4);
  CopyMemory(@msg[i+4], @newstate[1], len*2);
  i:=i+len*2+4;
  //CommfortProcess(dwPluginID, PM_PLUGIN_STATUS_CHANGE, @msg[0], i);
  MsgQueue.InsertMsg(PM_PLUGIN_STATUS_CHANGE, msg, i);
end;

procedure TCommPluginC.AddChannel(Name, channel : string; visibility, regime : DWord);
var
  msg: TBytes;
  i, len: DWord;
begin
  case PROG_TYPE of
    0: begin
      len:=Length(Name)*2+Length(Channel)*2+16;
      SetLength(msg, len);
      len:=Length(Name);
      CopyMemory(@msg[0], @len, 4);
      CopyMemory(@msg[4], @Name[1], len*2);
      i:=4+len*2;
      len:=Length(Channel);
      CopyMemory(@msg[i], @len, 4);
      CopyMemory(@msg[i+4], @Channel[1], len*2);
      i:=i+len*2+4;
      CopyMemory(@msg[i], @visibility, 4);
      i:=i+4;
      CopyMemory(@msg[i], @regime, 4);
      i:=i+4;
      //CommfortProcess(dwPluginID, PM_PLUGIN_CHANNEL_JOIN, @msg[0], i);
      MsgQueue.InsertMsg(PM_PLUGIN_CHANNEL_JOIN, msg, i);
    end;

    1: begin
      len:=Length(Channel)*2+8;
      SetLength(msg, len);
      regime:=regime*2+visibility;
      CopyMemory(@msg[0], @regime, 4);
      i:=4;
      len:=Length(Channel);
      CopyMemory(@msg[i], @len, 4);
      CopyMemory(@msg[i+4], @Channel[1], len*2);
      i:=i+len*2+4;
      //CommfortProcess(dwPluginID, PM_CLIENT_CHANNEL_JOIN, @msg[0], i);
      MsgQueue.InsertMsg(PM_CLIENT_CHANNEL_JOIN, msg, i);
    end;
  end;
end;

procedure TCommPluginC.LeaveChannel(Name, channel : string);
var
  msg: TBytes;
  i, len: DWord;
begin
  case PROG_TYPE of
    0:
      begin
        len:=Length(Name)*2+Length(Channel)*2+8;
        SetLength(msg, len);
        len:=Length(Name);
        CopyMemory(@msg[0], @len, 4);
        CopyMemory(@msg[4], @Name[1], len*2);
        i:=4+len*2;
        len:=Length(Channel);
        CopyMemory(@msg[i], @len, 4);
        CopyMemory(@msg[i+4], @Channel[1], len*2);
        i:=i+len*2+4;
        //CommfortProcess(dwPluginID, PM_PLUGIN_CHANNEL_LEAVE, @msg[0], i);
        MsgQueue.InsertMsg(PM_PLUGIN_CHANNEL_LEAVE, msg, i);
      end;
    1:
      begin
        len:=Length(Channel)*2+4;
        SetLength(msg, len);
        len:=Length(Channel);
        CopyMemory(@msg[0], @len, 4);
        CopyMemory(@msg[4], @Channel[1], len*2);
        i:=len*2+4;
        //CommfortProcess(dwPluginID, PM_CLIENT_CHANNEL_LEAVE, @msg[0], i);
        MsgQueue.InsertMsg(PM_CLIENT_CHANNEL_LEAVE, msg, i);
      end;
  end;
end;

procedure TCommPluginC.ClientLeavePrivate(User : string);
var
  msg: TBytes;
  i, len: DWord;
begin
  len:=Length(User)*2+4;
  SetLength(msg, len);
  len:=Length(User);
  CopyMemory(@msg[0], @len, 4);
  CopyMemory(@msg[4], @User[1], len*2);
  i:=len*2+4;
  //CommfortProcess(dwPluginID, PM_CLIENT_PRIVATE_LEAVE, @msg[0], i);
  MsgQueue.InsertMsg(PM_CLIENT_PRIVATE_LEAVE, msg, i);
end;

procedure TCommPluginC.AddRestriction(Name: String; restrictiontype, identificationtype, anonymitytype : DWord; time : Double; ident : string; Channel : string; reason : string);
var
  msg: TBytes;
  i, len: DWord;
begin
  len:=Length(Name)*2+Length(Channel)*2+Length(ident)*2+Length(Reason)*2+36;
  SetLength(msg, len);
  len:=Length(Name);
  CopyMemory(@msg[0], @len, 4);
  CopyMemory(@msg[4], @Name[1], len*2);
  i:=4+len*2;
  CopyMemory(@msg[i], @identificationtype, 4);
  i:=i+4;
  len:=Length(ident);
  CopyMemory(@msg[i], @len, 4);
  CopyMemory(@msg[i+4], @ident[1], len*2);
  i:=i+4+len*2;
  CopyMemory(@msg[i], @restrictiontype, 4);
  i:=i+4;
  len:=Length(Channel);
  CopyMemory(@msg[i], @len, 4);
  CopyMemory(@msg[i+4], @Channel[1], len*2);
  i:=i+len*2+4;
  CopyMemory(@msg[i], @time, 8);
  i:=i+8;
  len:=Length(Reason);
  CopyMemory(@msg[i], @len, 4);
  CopyMemory(@msg[i+4], @Reason[1], len*2);
  i:=i+len*2+4;
  CopyMemory(@msg[i], @anonymitytype, 4);
  i:=i+4;
  //CommfortProcess(dwPluginID, PM_PLUGIN_RESTRICT_SET, @msg[0], i);
  MsgQueue.InsertMsg(PM_PLUGIN_RESTRICT_SET, msg, i);
end;

procedure TCommPluginC.RemoveRestriction(Name: String; restrictionid : DWORD; reason : string);
var
  msg: TBytes;
  i, len: DWord;
begin
  len:=Length(Name)*2+Length(Reason)*2+12;
  SetLength(msg, len);
  len:=Length(Name);
  CopyMemory(@msg[0], @len, 4);
  CopyMemory(@msg[4], @Name[1], len*2);
  i:=4+len*2;
  CopyMemory(@msg[i], @restrictionid, 4);
  i:=i+4;
  len:=Length(Reason);
  CopyMemory(@msg[i], @len, 4);
  CopyMemory(@msg[i+4], @Reason[1], len*2);
  i:=i+len*2+4;
  //CommfortProcess(dwPluginID, PM_PLUGIN_RESTRICT_DEL, @msg[0], i);
  MsgQueue.InsertMsg(PM_PLUGIN_RESTRICT_DEL, msg, i);
end;

procedure TCommPluginC.RemoveChannel(Name, channel : string);
var
  msg: TBytes;
  i, len: DWord;
begin
  len:=Length(Name)*2+Length(Channel)*2+8;
  SetLength(msg, len);
  len:=Length(Name);
  CopyMemory(@msg[0], @len, 4);
  CopyMemory(@msg[4], @Name[1], len*2);
  i:=4+len*2;
  len:=Length(Channel);
  CopyMemory(@msg[i], @len, 4);
  CopyMemory(@msg[i+4], @Channel[1], len*2);
  i:=i+len*2+4;
  //CommfortProcess(dwPluginID, PM_PLUGIN_CHANNEL_DEL, @msg[0], i);
  MsgQueue.InsertMsg(PM_PLUGIN_CHANNEL_DEL, msg, i);
end;

procedure TCommPluginC.StopPlugin;
begin
  CommFortProcess(dwPluginID, PM_PLUGIN_STOP, '', 0);
end;

//--------------------------------------------- CommfortGetData-----------------

function TCommPluginC.AskProgramType():DWord;
var
  Buf: TBytes;
  iSize: DWord;
begin
  iSize:=CommFortGetData(dwPluginID, GD_PROGRAM_TYPE, nil, 0, nil, 0);
  SetLength(Buf, iSize);
  CommFortGetData(dwPluginID, GD_PROGRAM_TYPE, Buf, iSize, nil, 0);
  CopyMemory(@Result, @Buf[0], 4);
end;

function TCommPluginC.AskProgramVersion():String;
var
  Buf: TBytes;
  iSize: DWord;
begin
  iSize := CommFortGetData(dwPluginID, GD_PROGRAM_VERSION, nil, 0, nil, 0);
  SetLength(Buf, iSize);
  CommFortGetData(dwPluginID, GD_PROGRAM_VERSION, Buf, iSize, nil, 0);
  CopyMemory(@iSize, @Buf[0], 4);
  Result:=TEncoding.Unicode.GetString(Buf, 4, iSize*2);
end;

function TCommPluginC.AskPluginTempPath():String;
var
  Buf: TBytes;
  iSize: DWord;
begin
  iSize := CommFortGetData(dwPluginID, GD_PLUGIN_TEMPPATH, nil, 0, nil, 0);
  SetLength(Buf, iSize);
  CommFortGetData(dwPluginID, GD_PLUGIN_TEMPPATH, Buf, iSize, nil, 0);
  CopyMemory(@iSize, @Buf[0], 4);
  Result:=TEncoding.Unicode.GetString(Buf, 4, iSize*2);
end;

function TCommPluginC.AskUserChannels(Name: String; var ChannelList: TChannels):DWord;
var
  Buf, msg: TBytes;
  iSize, len: DWord;
  I: DWord;
  J: Word;
  //F: File of Byte;
begin
  case PROG_TYPE of
  0:
    begin
      len:=Length(Name)*2+4;
      SetLength(msg, len);
      len:=Length(Name);
      CopyMemory(@msg[0], @len, 4);
      CopyMemory(@msg[4], @Name[1], len*2);
      i:=4+len*2;
      iSize := CommFortGetData(dwPluginID, GD_USERCHANNELS_GET, nil, 0, @msg[0], i);
      SetLength(Buf, iSize);
      if iSize=0 then
      begin
        Result:=0;
        Exit;
      end;
      CommFortGetData(dwPluginID, GD_USERCHANNELS_GET, Buf, iSize, @msg[0], i);
    end;
  1:
    begin
      //TODO
      Result:=0;
      Exit;
    end;
  end;
  {AssignFile(F, 'test.dat');
  Rewrite(F);
  for I := 0 to iSize do
    Write(F, Buf[I]);
  Close(F);}
  CopyMemory(@Result, @Buf[0], 4);
  I:=4;
  setLength(ChannelList, Result + 1);
  for J := 1 to Result do
  begin
    CopyMemory(@iSize, @Buf[I],4);
    ChannelList[J].Name:=TEncoding.Unicode.GetString(Buf, I+4, iSize*2);
    I:=I+iSize*2+4;
    CopyMemory(@ChannelList[J].Users, @Buf[I],4);
    I:=I+4;
    CopyMemory(@iSize, @Buf[I],4);
    ChannelList[J].Theme:=TEncoding.Unicode.GetString(Buf, I+4, iSize*2);
    I:=I+iSize*2+4;
  end;
end;

function TCommPluginC.AskUsersInChannel(Name, Channel: String; var UserList: TUsers):DWord;
var
  Buf, msg: TBytes;
  iSize, len: DWord;
  I: DWord;
  J: Word;
begin
  case PROG_TYPE of
  0:
    begin
      len:=Length(Name)*2+Length(Channel)*2+8;
      SetLength(msg, len);
      len:=Length(Name);
      CopyMemory(@msg[0], @len, 4);
      CopyMemory(@msg[4], @Name[1], len*2);
      i:=4+len*2;
      len:=Length(Channel);
      CopyMemory(@msg[i], @len, 4);
      CopyMemory(@msg[i+4], @Channel[1], len*2);
      i:=i+len*2+4;
      iSize := CommFortGetData(dwPluginID, GD_CHANNELUSERS_GET, nil, 0, @msg[0], i);
      SetLength(Buf, iSize);
      if iSize=0 then
      begin
        Result:=0;
        Exit;
      end;
      CommFortGetData(dwPluginID, GD_CHANNELUSERS_GET, Buf, iSize, @msg[0], i);
    end;
  1:
    begin
      len:=Length(Channel)*2+4;
      SetLength(msg, len);
      len:=Length(Channel);
      CopyMemory(@msg[0], @len, 4);
      CopyMemory(@msg[4], @Channel[1], len*2);
      i:=len*2+4;
      iSize := CommFortGetData(dwPluginID, GD_CLIENT_CHANNELUSERS_GET, nil, 0, @msg[0], i);
      SetLength(Buf, iSize);
      if iSize=0 then
      begin
        Result:=0;
        Exit;
      end;
      CommFortGetData(dwPluginID, GD_CLIENT_CHANNELUSERS_GET, Buf, iSize, @msg[0], i);
    end;
  end;
  CopyMemory(@Result, @Buf[0], 4);
  I:=4;
  setLength(UserList, Result + 1);
  for J := 1 to Result do
  begin
    CopyMemory(@iSize, @Buf[I],4);
    UserList[J].Name:=TEncoding.Unicode.GetString(Buf, I+4, iSize*2);
    I:=I+iSize*2+4;
    CopyMemory(@iSize, @Buf[I],4);
    UserList[J].IP:=TEncoding.Unicode.GetString(Buf, I+4, iSize*2);
    I:=I+iSize*2+4;
    CopyMemory(@UserList[J].sex, @Buf[I],4);
    I:=I+4;
  end;
end;

function TCommPluginC.AskRestrictions(var RestList: TRestrictions):DWord;
var
  Buf: TBytes;
  iSize: DWord;
  I: DWord;
  J: Word;
begin
  iSize := CommFortGetData(dwPluginID, GD_RESTRICTIONS_GET, nil, 0, nil, 0);
  SetLength(Buf, iSize);
  CommFortGetData(dwPluginID, GD_RESTRICTIONS_GET, Buf, iSize, nil, 0);
  CopyMemory(@Result, @Buf[0], 4);
  I:=4;
  setLength(RestList, Result + 1);
  for J := 1 to Result do
  begin
    CopyMemory(@RestList[J].restID, @Buf[I], 4);
    I:=I+4;
    CopyMemory(@RestList[J].Date, @Buf[I], 8);
    I:=I+8;
    CopyMemory(@RestList[J].Remain, @Buf[I], 8);
    I:=I+8;
    CopyMemory(@RestList[J].ident, @Buf[I], 4);
    I:=I+4;
    CopyMemory(@iSize, @Buf[I], 4);
    RestList[J].Name:=TEncoding.Unicode.GetString(Buf, I+4, iSize*2);
    I:=I+iSize*2+4;
    CopyMemory(@iSize, @Buf[I], 4);
    RestList[J].IP:=TEncoding.Unicode.GetString(Buf, I+4, iSize*2);
    I:=I+iSize*2+4;
    CopyMemory(@iSize, @Buf[I], 4);
    RestList[J].IPRange:=TEncoding.Unicode.GetString(Buf, I+4, iSize*2);
    I:=I+iSize*2+4;
    CopyMemory(@iSize, @Buf[I], 4);
    RestList[J].compID:=TEncoding.Unicode.GetString(Buf, I+4, iSize*2);
    I:=I+iSize*2+4;
    CopyMemory(@RestList[J].banType, @Buf[I], 4);
    I:=I+4;
    CopyMemory(@iSize, @Buf[I], 4);
    RestList[J].channel:=TEncoding.Unicode.GetString(Buf, I+4, iSize*2);
    I:=I+iSize*2+4;
    CopyMemory(@iSize, @Buf[I], 4);
    RestList[J].moder:=TEncoding.Unicode.GetString(Buf, I+4, iSize*2);
    I:=I+iSize*2+4;
    CopyMemory(@iSize, @Buf[I], 4);
    RestList[J].reason:=TEncoding.Unicode.GetString(Buf, I+4, iSize*2);
    I:=I+iSize*2+4;
  end;
end;

function TCommPluginC.AskIPState(Name: String):DWord;
var
  Buf: TBytes;
  iSize: DWord;
begin
  iSize := CommFortGetData(dwPluginID, GD_RESTRICTIONS_GET, nil, 0, nil, 0);
  SetLength(Buf, iSize);
  CommFortGetData(dwPluginID, GD_RESTRICTIONS_GET, Buf, iSize, nil, 0);
  CopyMemory(@Result, @Buf[0], 4);
end;

function TCommPluginC.AskIP(Name: String):String;
var
  msg: TStringStream;
  Buf: TBytes;
  iSize: DWord;
begin
  msg := TStringStream.Create('', TEncoding.Unicode);
  msg.Position := 0;
  iSize:= Length (Name);
  msg.Write(iSize, 4);
  msg.WriteString(Name);
  iSize := CommFortGetData(dwPluginID, GD_IP_GET, nil, 0, PChar(msg.DataString), 4+Length(Name)*2);
  SetLength(Buf, iSize);
  CommFortGetData(dwPluginID, GD_IP_GET, Buf, iSize, PChar(msg.DataString), 4+Length(Name)*2);
  CopyMemory(@iSize, @Buf[0], 4);
  Result:=TEncoding.Unicode.GetString(Buf, 4, iSize*2);
  msg.Free;
end;

function TCommPluginC.AskID(Name: String):String;
var
  msg: TStringStream;
  Buf: TBytes;
  iSize: DWord;
begin
  if PROG_TYPE=1 then
  begin
    Result:='Client_version';
    Exit;
  end;
  msg := TStringStream.Create('', TEncoding.Unicode);
  msg.Position := 0;
  iSize:= Length (Name);
  msg.Write(iSize, 4);
  msg.WriteString(Name);
  iSize := CommFortGetData(dwPluginID, GD_ID_GET, nil, 0, PChar(msg.DataString), 4+Length(Name)*2);
  SetLength(Buf, iSize);
  CommFortGetData(dwPluginID, GD_ID_GET, Buf, iSize, PChar(msg.DataString), 4+Length(Name)*2);
  CopyMemory(@iSize, @Buf[0], 4);
  Result:=TEncoding.Unicode.GetString(Buf, 4, iSize*2);
  msg.Free;
end;

//---------------------------- Клиент ------------------------------------------
function TCommPluginC.ClientAskCurrentUser():TUser;
var
  Buf: TBytes;
  iSize, i: DWord;
begin
  iSize := CommFortGetData(dwPluginID, GD_CLIENT_CURRENT_USER_GET, nil, 0, nil, 0);
  SetLength(Buf, iSize);
  CommFortGetData(dwPluginID, GD_CLIENT_CURRENT_USER_GET, Buf, iSize, nil, 0);
  CopyMemory(@iSize, @Buf[0], 4);
  Result.Name:=TEncoding.Unicode.GetString(Buf, 4, iSize*2);
  i:=iSize*2+4;
  CopyMemory(@iSize, @Buf[i], 4);
  Result.IP:=TEncoding.Unicode.GetString(Buf, i+4, iSize*2);
  i:=i+iSize*2+4;
  CopyMemory(@iSize, @Buf[i], 4);
  Result.sex:=iSize;
end;

function TCommPluginC.ClientAskConState():DWord;
var
  Buf: TBytes;
  iSize: DWord;
begin
  iSize := CommFortGetData(dwPluginID, GD_CLIENT_CONSTATE_GET, nil, 0, nil, 0);
  SetLength(Buf, iSize);
  CommFortGetData(dwPluginID, GD_CLIENT_CONSTATE_GET, Buf, iSize, nil, 0);
  CopyMemory(@Result, @Buf[0], 4);
end;

function TCommPluginC.ClientAskRight(RightType: DWord; Channel: String):DWord;
var
  msg: TBytes;
  Buf: TBytes;
  iSize, i, len: DWord;
begin
  len:=Length(Channel)*2+8;
  SetLength(msg, len);
  CopyMemory(@msg[0], @RightType, 4);
  i:=4;
  len:=Length(Channel);
  CopyMemory(@msg[i], @len, 4);
  CopyMemory(@msg[i+4], @Channel[1], len*2);
  i:=i+4+len*2;
  iSize := CommFortGetData(dwPluginID, GD_CLIENT_RIGHT_GET, nil, 0, @msg[0], i);
  SetLength(Buf, iSize);
  CommFortGetData(dwPluginID, GD_CLIENT_RIGHT_GET, Buf, iSize, @msg[0], i);
  CopyMemory(@Result, @Buf[0], 4);
end;

end.

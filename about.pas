unit about;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Tabs, StdCtrls,  ShellAPI,
  comm_info, mafia, mafia_data, comm_data, ComCtrls;

type
  TfrmAbout = class(TForm)
    LabelInfo: TLabel;
    Label1: TLabel;
    EditPath: TEdit;
    ButtonOpenPath: TButton;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure ButtonOpenPathClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmAbout: TfrmAbout;

implementation

{$R *.dfm}

procedure TfrmAbout.ButtonOpenPathClick(Sender: TObject);
begin
  ShellExecute(0, 'open', PChar('"'+EditPath.Text+'"'), nil, nil, SW_SHOWNORMAL);
end;

procedure TfrmAbout.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action:=caFree;
  frmAbout:=nil;
end;

procedure TfrmAbout.FormCreate(Sender: TObject);
begin
  LabelInfo.Caption:='Игровой плагин "Мафия" v.'+PLU_VER+Chr(13)+Chr(10);
  LabelInfo.Caption:=LabelInfo.Caption+'KGB, Чебоксары 2010-2011 :)'+Chr(13)+Chr(10);
  LabelInfo.Caption:=LabelInfo.Caption+'Тут будет еще информация...'+Chr(13)+Chr(10);
  try

    EditPath.Text:=PCorePlugin^.AskPluginTempPath+'Mafia';
    if not DirectoryExists(EditPath.Text) then
      CreateDir(EditPath.Text);
  except
    EditPath.Text:='Плагин должен быть запущен для получения информации!';
    ButtonOpenPath.Enabled:=False;
  end;

end;

end.

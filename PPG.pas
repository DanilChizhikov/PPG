unit PPG;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, sSkinManager, Vcl.StdCtrls, sListBox,
  Vcl.ExtCtrls, sPanel, acPNG, acImage, sButton, sCheckBox, synaip, httpsend,
  ssl_openssl, blcksock, RegExpr, sRadioButton, sEdit, sDialogs, sSpinEdit,
  sMemo, Winapi.ShellAPI;

type
  TMainForm = class(TForm)
    FPanel: TsPanel;
    logList: TsListBox;
    sSkinManager1: TsSkinManager;
    gbtn: TsButton;
    LogoIm: TsImage;
    dbtn: TsButton;
    GenKeyBtn: TsButton;
    CheckKeyBtn: TsButton;
    hidemeEdit: TsEdit;
    httpbrn: TsRadioButton;
    socks4btn: TsRadioButton;
    socks5btn: TsRadioButton;
    sOpenDialog1: TsOpenDialog;
    PanelGK: TsPanel;
    CountKeySpin: TsSpinEdit;
    AcceptBtn: TsButton;
    sMemo1: TsMemo;
    procedure FormCreate(Sender: TObject);
    procedure httpbrnClick(Sender: TObject);
    procedure socks4btnClick(Sender: TObject);
    procedure socks5btnClick(Sender: TObject);
    procedure socks45btnClick(Sender: TObject);
    procedure gbtnClick(Sender: TObject);
    procedure GenKeyBtnClick(Sender: TObject);
    procedure AcceptBtnClick(Sender: TObject);
    procedure CheckKeyBtnClick(Sender: TObject);
    procedure dbtnClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

type
  TMonikThreadGrabb = class(TThread)
  protected
    procedure Execute; override;
  end;

type TCheckerKey = class(TThread)
  private
    KeyT: string;
  public
    HTTP: THTTPSend;
    HTML: TStringList;
    POST: TStringStream;
    Temp: TStringList;
    procedure Log;
    procedure EndWork;
  protected
    procedure Execute; Override;
end;

type
  TGrabbProxy = class(TThread)
  private
    HTTP: THTTPSend;
    HTML: TStringList;
    POST: TStringStream;
    RegEx: TRegExpr;
    ProxyCount: Integer;
    Temp: TStringList;
  public
    procedure Log;
    procedure EndWork;
  protected
    procedure Execute; Override;
  end;

type
  TGenKey = class(TThread)
  private
    s,p:string;
    Temp: TStringList;
  public
    procedure EndWork;
  protected
    procedure Execute; Override;
  end;

type
  TLoadProxyThread = class(TThread)
  private
    FileName: string;
    procedure SyncLog;
  protected
    procedure Execute; override;
  end;

var
  MainForm: TMainForm;
  Data: TDateTime;
  ThreadsCount, ProxyType, CountKey, KeyID, Valid, GoodKey: Integer;
  HideMeKey: string;
  ProxyList, KeyList, CheckKeyList: TStringList;
  MonikThreadGrabb: TMonikThreadGrabb;
  GrabbProxy: TGrabbProxy;
  GenKeyT: TGenKey;
  GrabbWork, CheckWork: Boolean;
  HideMEFile, GebKeyFile, CheckKeyFile: TextFile;

implementation

{$R *.dfm}

procedure TMonikThreadGrabb.Execute;
var
  CheckerKey: TCheckerKey; // Переменная для новых потоков.
begin
  while not Terminated do // До тех пор пока мы существуем и не завершились.
  begin
    Sleep(50000); // Снижаем нагрузку на ЦП чем выше цифра тем меньше скорость и ниже перегрузка.
    if ThreadsCount < 100 then // Если в системе уже все 200 потоков из 200 то ничего не делаем, но если 199 то работаем.
    begin
      Inc(KeyID); // Берем след глобальный индекс аккаунта.
      if KeyID >= CheckKeyList.Count then Break; // Если аккаунты кончились прерываем while и убиваем себя.
      CheckerKey:= TCheckerKey.Create(True); // Создаем новый поток.
      CheckerKey.FreeOnTerminate:= True; // Выгрузка на завершение.
      CheckerKey.KeyT:= CheckKeyList[KeyID]; // Передаем туда строку с логином и паролем.
      CheckerKey.Resume; // Стартуем.
    end;
  end;
end;

procedure TCheckerKey.Execute;
begin
  InterlockedIncrement(ThreadsCount);

  HTTP:= THTTPSend.Create;
  HTML:= TStringList.Create;
  POST:= TStringStream.Create;

  HTTP.Protocol:= '1.1';
  HTTP.Timeout:= 15000;
  HTTP.Sock.SocksTimeout:= 15000;
  HTTP.Sock.SetTimeout(15000);
  HTTP.Sock.SetSendTimeout(15000);
  HTTP.Sock.SetRecvTimeout(15000);
  HTTP.AddPortNumberToHost:= False;

  POST.WriteString('c=' + KeyT);
  HTTP.Headers.Add('Accept: application/json, text/javascript, */*; q=0.0');
  HTTP.MimeType:='application/x-www-form-urlencoded; charset=UTF-8';
  HTTP.UserAgent:='Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; WOW64; Trident/6.0)';
  HTTP.Document.LoadFromStream(POST);

  if HTTP.HTTPMethod('GET', 'http://hideme.ru/api/proxylist.txt?type=hs&out=plain&code=' + KeyT) then
  begin
    HTML.LoadFromStream(HTTP.Document);
    MainForm.sMemo1.Text:= HTML.Text;
    if ((MainForm.sMemo1.Text = '') or (MainForm.sMemo1.Text = 'NOTFOUND') or (MainForm.sMemo1.Text = 'TOOFAST')) then
    begin
      Valid:=0;//Bad
    end else
    Valid:=1;//Good
    Synchronize(Log);
  end
  else
  begin
    Valid:=0;//Bad
  end;
  HTTP.Document.Clear;
  HTTP.Headers.Clear;

  HTTP.Headers.Add('Accept: application/json, text/javascript, */*; q=0.0');
  HTTP.MimeType:='application/x-www-form-urlencoded; charset=UTF-8';
  HTTP.UserAgent:='Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; WOW64; Trident/6.0)';

  POST.Free;
  HTML.Free;
  HTTP.Free;
  InterlockedDecrement(ThreadsCount);
  if ThreadsCount = 0 then
  begin
    Synchronize(EndWork);
  end;
end;

procedure TCheckerKey.Log;
begin
  if Valid = 1 then
  begin
    Append(CheckKeyFile);
    Writeln(CheckKeyFile, KeyT);
    CloseFile(CheckKeyFile);
    GoodKey:= GoodKey + 1;
  end;
end;

procedure TCheckerKey.EndWork;
var StrData, StrTime: string;
begin
  Data := Now;
  StrData:=DateToStr(Data);
  StrData:= StringReplace(StrData, '/', '.', [rfReplaceAll]);
  StrTime:=TimeToStr(Time);
  CheckWork:=False;
  MainForm.logList.Items.Add('PPG Good Key|' + IntToStr(GoodKey) + '|' + StrData + '/' + StrTime);
end;

procedure TLoadProxyThread.Execute;
begin
  if Length(FileName) > 0 then // Если имя файла было передано в поток.
  begin
    try
      CheckKeyList.LoadFromFile(FileName); // Загружаем с исключением.
    except
      MessageBoxW(0,
        PWideChar('The size with proxy exceeds 200 megabytes!'),
        0,
        MB_OK + MB_ICONERROR);
    end;
    Synchronize(SyncLog); // Вывод на форму цифр, так как напрямую записать в Label может вызывать исключение ntdll, нужно юзать
  end;
end;

procedure TLoadProxyThread.SyncLog;
var StrData, StrTime: string;
begin
  Data := Now;
  StrData:=DateToStr(Data);
  StrData:= StringReplace(StrData, '/', '.', [rfReplaceAll]);
  StrTime:=TimeToStr(Time);

  MainForm.logList.Items.Add('PPG Success Load Key|' + IntToStr(CheckKeyList.Count) + '|' + StrData + '/' + StrTime);
  MainForm.logList.Items.Add('PPG Start Checking Key|' + IntToStr(CheckKeyList.Count) + '|' + StrData + '/' + StrTime);

  AssignFile(CheckKeyFile, ExtractFilePath(ParamStr(0)) + '\GOOD_KEY.txt');
  Rewrite(CheckKeyFile);
  CloseFile(CheckKeyFile);

  MonikThreadGrabb:= TMonikThreadGrabb.Create(True); // Создаем поток монитора.
  MonikThreadGrabb.FreeOnTerminate:= True; // Даем свободу после уничтожения.
  MonikThreadGrabb.Priority:= tpNormal; // Приоритет нормальный.
  MonikThreadGrabb.Resume; // Стартуем, он запустит остальные потоки сам.
end;

procedure TGenKey.Execute;
var i,j,r,pl: integer;
label ReBrute;
begin
  Temp:= TStringList.Create;
  Temp.Duplicates:= dupIgnore;
  s:='0123456789';
  p:='';
  ReBrute:
  Randomize; //инициализация генератора
  for i := 1 to CountKey do begin //num — количество генерируемых паролей
    for j:= 1 to 12 do begin //pl — длина одного пароля
      r:=random(length(s)); //получаем случайный символ
      if r=0 then r:=1;
      p:=p+s[r]; //"накручиваем" переменную p до нужной длины
    end;
    Temp.Add(p);
    p:='';
  end;

  if CountKey <> Temp.Count then
  begin
    goto ReBrute;
  end else
  Synchronize(EndWork);
  Temp.Free;
end;

procedure TGenKey.EndWork;
var StrData, StrTime: string;
begin
  Data := Now;
  StrData:=DateToStr(Data);
  StrData:= StringReplace(StrData, '/', '.', [rfReplaceAll]);
  StrTime:=TimeToStr(Time);

  KeyList.Text:= Temp.Text;

  Append(GebKeyFile);
  Writeln(GebKeyFile, KeyList.Text);
  CloseFile(GebKeyFile);

  MainForm.logList.Items.Add('PPG Success GenKey|' + IntToStr(CountKey) + '|' + StrData + '/' + StrTime);

  try
    GenKeyT.Terminate;
  except end;
end;

procedure TGrabbProxy.Execute;
begin
  while GrabbWork do
  begin
    InterlockedIncrement(ThreadsCount);

    HTTP:= THTTPSend.Create;
    HTML:= TStringList.Create;
    POST:= TStringStream.Create;
    RegEx:= TRegExpr.Create;
    Temp:= TStringList.Create;

    RegEx.Expression:= '\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}(:|;)\d{1,5}';
    Temp.Duplicates:= dupIgnore;
    HTTP.Protocol:= '1.1';
    HTTP.Timeout:= 15000;
    HTTP.Sock.SocksTimeout:= 15000;
    HTTP.Sock.SetTimeout(15000);
    HTTP.Sock.SetSendTimeout(15000);
    HTTP.Sock.SetRecvTimeout(15000);
    HTTP.AddPortNumberToHost:= False;

    POST.WriteString('c=' + HideMeKey);
    HTTP.Headers.Add('Accept: application/json, text/javascript, */*; q=0.0');
    HTTP.MimeType:='application/x-www-form-urlencoded; charset=UTF-8';
    HTTP.UserAgent:='Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; WOW64; Trident/6.0)';
    HTTP.Document.LoadFromStream(POST);

    if HTTP.HTTPMethod('POST', 'https://hidemy.name/ru/loginx') then begin end;

    HTTP.Document.Clear;
    HTTP.Headers.Clear;

    HTTP.Headers.Add('Accept: application/json, text/javascript, */*; q=0.0');
    HTTP.MimeType:='application/x-www-form-urlencoded; charset=UTF-8';
    HTTP.UserAgent:='Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; WOW64; Trident/6.0)';

    Temp.Duplicates:=dupIgnore;;

    case ProxyType of
      1:
      begin
        if HTTP.HTTPMethod('GET', 'http://hideme.ru/api/proxylist.txt?type=hs&out=plain&code=' + HideMeKey) then
        begin
          HTML.LoadFromStream(HTTP.Document);
          if RegEx.Exec(HTML.Text) then
          repeat
            Temp.Add(RegEx.Match[0]);
          until not RegEx.ExecNext;
        end;
      end;
      2:
      begin
        if HTTP.HTTPMethod('GET', 'http://hideme.ru/api/proxylist.txt?type=4&out=plain&code=' + HideMeKey) then
        begin
          HTML.LoadFromStream(HTTP.Document);
          if RegEx.Exec(HTML.Text) then
          repeat
            Temp.Add(RegEx.Match[0]);
          until not RegEx.ExecNext;
        end;
      end;
      3:
      begin
        if HTTP.HTTPMethod('GET', 'http://hideme.ru/api/proxylist.txt?type=5&out=plain&code=' + HideMeKey) then
        begin
          HTML.LoadFromStream(HTTP.Document);
          if RegEx.Exec(HTML.Text) then
          repeat
            Temp.Add(RegEx.Match[0]);
          until not RegEx.ExecNext;
        end;
      end;
    end;

    ProxyCount:= Temp.Count;

    RegEx.Free;
    POST.Free;
    HTML.Free;
    HTTP.Free;
    Synchronize(Log);
    Temp.Free;
    ThreadsCount:=0;
    if ThreadsCount = 0 then
    begin
      Synchronize(EndWork);
    end;
  end;
end;

procedure TGrabbProxy.Log;
begin
  ProxyList.Text:= Temp.Text;
end;

procedure TGrabbProxy.EndWork;
var StrData, StrTime: string;
begin
  Data := Now;
  StrData:=DateToStr(Data);
  StrData:= StringReplace(StrData, '/', '.', [rfReplaceAll]);
  StrTime:=TimeToStr(Time);

  case ProxyType of
    1:
    begin
      Append(HideMEFile);
      Writeln(HideMEFile, ProxyList.Text);
      CloseFile(HideMEFile);
    end;
    2:
    begin
      Append(HideMEFile);
      Writeln(HideMEFile, ProxyList.Text);
      CloseFile(HideMEFile);
    end;
    3:
    begin
      Append(HideMEFile);
      Writeln(HideMEFile, ProxyList.Text);
      CloseFile(HideMEFile);
    end;
  end;

  if ProxyCount > 1 then
  begin
    MainForm.logList.Items.Add('PPG Success Grub|' + IntToStr(ProxyCount) + '|' + StrData + '/' + StrTime);
  end
  else
  begin
    MainForm.logList.Items.Add('PPG Error Grub|' + IntToStr(ProxyCount) + '|' + StrData + '/' + StrTime);
  end;
  GrabbWork:=False;
end;

procedure TMainForm.AcceptBtnClick(Sender: TObject);
begin
  CountKey:= CountKeySpin.Value;
  AssignFile(GebKeyFile, ExtractFilePath(ParamStr(0)) + '\HIDME_KEY.txt');
  Rewrite(GebKeyFile);
  CloseFile(GebKeyFile);
  PanelGK.Visible:=False;
  GenKeyT:= TGenKey.Create(True); // Создаем поток монитора.
  GenKeyT.FreeOnTerminate:= True; // Даем свободу после уничтожения.
  GenKeyT.Priority:= tpNormal; // Приоритет нормальный.
  GenKeyT.Resume; // Стартуем, он запустит остальные потоки сам.
end;

procedure TMainForm.CheckKeyBtnClick(Sender: TObject);
var
  LoadProxyThread: TLoadProxyThread; // Поток который нужен.
begin
  sOpenDialog1.Filter:= 'Текстовые файлы | *.txt';
  sOpenDialog1.InitialDir:= ExtractFilePath(ParamStr(0));

  if sOpenDialog1.Execute then
  begin
    if Pos('.txt', sOpenDialog1.FileName) <> 0 then // Если был загружен именно .txt
    begin
      LoadProxyThread:= TLoadProxyThread.Create(True); // Создаем поток.
      LoadProxyThread.FileName:= sOpenDialog1.FileName; // Сообщаем имя файла.
      LoadProxyThread.FreeOnTerminate:= True; // Даем свободу.
      LoadProxyThread.Priority:= tpNormal; // Приоритет нормальный.
      LoadProxyThread.Resume; // Стартуем.
      // Если планируется отключать кнопку при загрузке и включать по завершении то код включения пихать в:
      // procedure TLoadProxyThread.SyncLog;
    end;
  end;

  ThreadsCount:=0;
  KeyID:=0;
  GoodKey:= 0;
  CheckKeyList.Clear;
  CheckWork:=True;
end;

procedure TMainForm.dbtnClick(Sender: TObject);
begin
  ShellExecute(self.handle,'open', 'http://www.donationalerts.ru/r/clichofficel', nil, nil, SW_SHOWMAXIMIZED);
end;

procedure TMainForm.FormCreate(Sender: TObject);
var StrData, StrTime: string;
begin
  try
    ProxyList:= TStringList.Create;
    KeyList:= TStringList.Create;
    CheckKeyList:= TStringList.Create;
    Data := Now;
    StrData:=DateToStr(Data);
    StrData:= StringReplace(StrData, '/', '.', [rfReplaceAll]);
    StrTime:=TimeToStr(Time);
    logList.Items.Add('PPG Success Run | ' + StrData + '/' + StrTime);
  except

  end;
end;

procedure TMainForm.gbtnClick(Sender: TObject);
begin
  case ProxyType of
    1:
    begin
      AssignFile(HideMEFile, ExtractFilePath(ParamStr(0)) + '\PROXY_HTTPS.txt');
      Rewrite(HideMEFile);
      CloseFile(HideMEFile);
    end;
    2:
    begin
      AssignFile(HideMEFile, ExtractFilePath(ParamStr(0)) + '\PROXY_SOCKS4.txt');
      Rewrite(HideMEFile);
      CloseFile(HideMEFile);
    end;
    3:
    begin
      AssignFile(HideMEFile, ExtractFilePath(ParamStr(0)) + '\PROXY_SOCKS5.txt');
      Rewrite(HideMEFile);
      CloseFile(HideMEFile);
    end;
  end;

  GrabbWork:=True;

  HideMeKey:=hidemeEdit.Text;

  GrabbProxy:= TGrabbProxy.Create(True); // Создаем новый поток.
  GrabbProxy.FreeOnTerminate:= True; // Выгрузка на завершение.
  GrabbProxy.Resume; // Стартуем.
end;

procedure TMainForm.httpbrnClick(Sender: TObject);
begin
  ProxyType:=1;
end;

procedure TMainForm.GenKeyBtnClick(Sender: TObject);

begin
  PanelGK.Visible:=True;
end;

procedure TMainForm.socks45btnClick(Sender: TObject);
begin
  ProxyType:=4;
end;

procedure TMainForm.socks4btnClick(Sender: TObject);
begin
  ProxyType:=2;
end;

procedure TMainForm.socks5btnClick(Sender: TObject);
begin
  ProxyType:=3;
end;

end.

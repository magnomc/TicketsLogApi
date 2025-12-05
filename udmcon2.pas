unit udmcon2;

//{$mode ObjFPC}{$H+}
{$MODE DELPHI}//{$H+}
interface

uses
  Classes, SysUtils, ZConnection,ZDataset,
  ZStoredProcedure,uUtilsClass,
  fpjson,JsonTools,
  ZDbcIntfs;

const MsgOk = 'Sucesso!';


type

  { TdmCon2 }

  TdmCon2 = class(TObject)
  private
     zCon : TZConnection;
     qryGenLeitura_Logs : TZReadOnlyQuery;
     SP0001_LOGS : TZStoredProc;
     function ConectaBD(Connect : boolean = True) : Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure FechaConexoes;
    procedure GetStatus(out Resp : TJSONData);
    procedure PesquisaLogs(Req: TJSONObject;out Resp : TJSONData);
    procedure GravaLogBD(Req: TJSONObject; out Resp : TJSONData);
    procedure ResetState;

    var Utils : tUtilsClass;
    var PathApp : string;
  end;

implementation

{ TdmCon2 }

constructor TdmCon2.Create;
begin
  Utils:=nil;
  Utils:=tUtilsClass.Create('L');

  if not(Assigned(Utils)) then
   raise exception.Create('Erro ao instanciar objetos da classe.');

  // Cria a conexão e atribui propriedades
  zCon := TZConnection.Create(nil);
  zCon.Protocol := 'firebird';
  zCon.TransactIsolationLevel := tiReadCommitted;
  zCon.HostName:=Utils.pServidorBd;
  zCon.User:=Utils.pUsuarioBd;
  zCon.Password:=Utils.pSenhaBd;
  zCon.Database:=Utils.pCaminhoBdInt;
  zCon.Port:=Utils.pPortaBd;

  PathApp:=StringReplace(ExtractFilePath(ParamStr(0)),'bin\','',[rfReplaceAll,rfIgnoreCase]);

  if not(ConectaBD(True)) then
    raise exception.Create('Não foi possível conectar ao banco de dados!');

  qryGenLeitura_Logs:=Nil;
  SP0001_LOGS:=Nil;
end;

destructor TdmCon2.Destroy;
begin
  // Libera a conexão
  if Assigned(zCon) then
  begin
    if Assigned(qryGenLeitura_Logs) then qryGenLeitura_Logs.Free;
    if Assigned(SP0001_LOGS) then SP0001_LOGS.Free;
    ConectaBD(False);
    zCon.Free;
  end;
  Utils.Free;
  inherited Destroy;
end;

function TdmCon2.ConectaBD(Connect: boolean): Boolean;
begin
  try
    if (Connect) then
      zCon.Connect
    else
    begin
      if zCon.InTransaction then zcon.Rollback;
      zCon.Disconnect;
    end;
    result:=True;
  except on e:exception do
   begin
     Utils.GravaLogArq('ConectaBD erro: '+e.Message);
     result:=false;
   end;
  end;
end;

procedure TdmCon2.FechaConexoes;
begin
  zCon.Disconnect;
end;

procedure TdmCon2.GetStatus(out Resp : TJSONData);
var //LJsonRet: TJSONData;
    TagJson : string;
begin
  try
    TagJson:='GetStatus';
    Resp:=Utils.CriaObjetoJson(TagJson,1,'Sucesso!',nil);
  Except on e:exception do
    Resp:=Utils.CriaObjetoJson(TagJson,0,'Erro GbnStatus: '+e.Message,nil);
  end;
end;

procedure TdmCon2.ResetState;
begin
  if zCon.InTransaction then
    zCon.Rollback;
  if Assigned(qryGenLeitura_Logs) then qryGenLeitura_Logs.Close;
  if Assigned(SP0001_LOGS) then SP0001_LOGS.Close;
end;

procedure TdmCon2.PesquisaLogs(Req: TJSONObject; out Resp: TJSONData);
var
  vMsg,vFun : string;
  vOk : Boolean;
  TagJson,Item : string;
  vIndice,id_sistema,cont,j : Integer;
  ReqJson : TJsonNode;
  DataHoraIni,DataHoraFin : TDateTime;
  Erro : Boolean;
begin
  vFun:='PesquisaLogs';
  TagJson:=vFun;
  vOk:=False;
  vMsg:='';
  try
    ReqJson:=Nil;
    if not(Assigned(qryGenLeitura_Logs)) then
    begin
      qryGenLeitura_Logs:=TZReadOnlyQuery.Create(nil);
      qryGenLeitura_Logs.Connection:=zCon;
    end;
    try
      if Utils.pAtivaLog then Utils.GravaLogArq(vFun+': entrou');
      ReqJson:=TJsonNode.Create;
      ReqJson.Value:=Utils.DeCryptAes256(Req.Get('request'));
      if ReqJson.Exists('array') then
      begin
        cont:=ReqJson.Find('array').Count;
        for j:=0 to cont-1 do
        begin
          Item:='array/'+j.ToString+'/';
          vIndice:=StrToInt(ReqJson.Find(Item+'indice').AsString);
          case vIndice of
            1:id_sistema:=StrToIntDef(ReqJson.Find(Item+'texto').AsString,-1);
            2:DataHoraIni:=utils.ConverteTimeStamp(ReqJson.Find(Item+'texto').AsString);
            3:DataHoraFin:=utils.ConverteTimeStamp(ReqJson.Find(Item+'texto').AsString);
            4:Erro:=ReqJson.Find(Item+'texto').AsString = 'S';
          end;
        end
      end
      else
        raise Exception.Create('json de requisição inválido!');

      qryGenLeitura_Logs.close;
      qryGenLeitura_Logs.SQL.Text:='select a.id,a.data_hora,'+
        ' case when a.id_sistema = 0 then ''Sistema Interno'''+
        ' when a.id_sistema = 2 then ''TicketsAuxApi.exe (Pagamentos Web/Mobile)'''+
        ' when a.id_sistema = 3 then ''TicketsRelApi.exe (Geracao de Relatorios)'''+
        ' when a.id_sistema = 4 then ''tMod001.exe (Modulo de integração Firebird x Firebase)'''+
        ' when a.id_sistema = 5 then ''TicketsFibApi.exe (Firebase)'''+
        ' when a.id_sistema = 6 then ''TicketsGerencial.exe (Retaguarda Windows)'''+
        ' when a.id_sistema = 7 then ''TicketsPrlApi.exe (Principal)'''+
        ' when a.id_sistema = 8 then ''TicketsVenApi.exe (Reservas, Envio Email e Vendas POS)'''+
        ' when a.id_sistema = 9 then ''TicketsRel2Api.exe (Consultas)'''+
        ' else ''Indefinido'' end as sistema,a.tela as unit,a.identificador_usuario,'+
        ' a.nome_usuario,a.erro,a.descricao from logs a'+
        ' where a.data_hora between :DhIni and :DhFin and a.erro = :Erro';
        {
        -1: Todos
        0: Sistema Interno
        2:TicketsAuxApi.exe (Pagamentos Web/Mobile)
        3:TicketsRelApi.exe (Geração de Relatórios)
        4:tMod001.exe (Módulo de integração Firebird x Firebase)
        5:TicketsFibApi.exe (Firebase)
        6:TicketsGerencial.exe (Retaguarda Windows)
        7:TicketsPrlApi.exe (Principal)
        8:TicketsVenApi.exe (Reservas, Envio Email e Vendas POS)
        9:TicketsRel2Api.exe (Consultas)

        }
        if id_sistema > 0 Then
        begin
          case id_sistema of
            1:id_sistema:=0;
          end;
          qryGenLeitura_Logs.SQL.Text:=qryGenLeitura_Logs.SQL.Text+' and a.id_sistema = :id_sistema';
          qryGenLeitura_Logs.ParamByName('id_sistema').AsInteger:=id_sistema;
        end;

        qryGenLeitura_Logs.SQL.Text:=qryGenLeitura_Logs.SQL.Text+' order by a.data_hora desc';

        qryGenLeitura_Logs.ParamByName('erro').AsBoolean:=Erro;
        qryGenLeitura_Logs.ParamByName('DhIni').AsDateTime:=DataHoraIni;
        qryGenLeitura_Logs.ParamByName('DhFin').AsDateTime:=DataHoraFin;

        qryGenLeitura_Logs.Open;

        if not(qryGenLeitura_Logs.IsEmpty) then
          vOk:=True
        else
          vMsg:='A busca não retornou registros!'
    except on e:exception do
     begin
       vMsg:=vFun+': '+e.Message;
       if Utils.pAtivaLog then  Utils.GravaLogArq(vFun+':'+vMsg);
     end;
    end;
  finally
    try
      if vOk then
        Resp:=Utils.CriaObjetoJson(TagJson,1,MsgOk,qryGenLeitura_Logs)
      else
      begin
        Resp:=Utils.CriaObjetoJson(TagJson,0,vMsg,Nil);
        if Utils.pAtivaLog then Utils.GravaLogArq(vFun+':'+vMsg);
      end;
    except on e:Exception do
      begin
        Utils.GravaLogArq('erro '+vfun+' ParseJSONValue: '+e.Message);
      end;
    end;
    if Utils.pAtivaLog then Utils.GravaLogArq(vFun+':Result: '+Resp.AsJSON+' - saiu');
    If Assigned(ReqJson) then FreeAndNil(ReqJson);
  end;
end;

procedure TdmCon2.GravaLogBD(Req: TJSONObject; out Resp: TJSONData);
var
  vMsg,vFun : string;
  vOk : Boolean;
  TagJson : string;
  ReqJson : TJsonNode;
begin
  vFun:='GravaLogBD';
  TagJson:=vFun;
  vOk:=False;
  vMsg:='';
  try
    ReqJson:=Nil;
    if not(Assigned(SP0001_LOGS)) then
    begin
      SP0001_LOGS:=TZStoredProc.Create(nil);
      SP0001_LOGS.Connection:=zCon;
      SP0001_LOGS.StoredProcName:='SP0001';
    end;
    try
      ReqJson:=TJsonNode.Create;
      ReqJson.Value:=Utils.DeCryptAes256(Req.Get('request'));
      SP0001_LOGS.Close;
      SP0001_LOGS.ParamByName('id_sistema').AsInteger:=StrToIntDef(ReqJson.Find('id_sistema').AsString,0);
      SP0001_LOGS.ParamByName('identificador_usuario').AsInteger:=StrToIntDef(ReqJson.Find('identificador_usuario').AsString,0);
      SP0001_LOGS.ParamByName('descricao').AsString:=copy(ReqJson.Find('descricao').AsString,1,4096);
      SP0001_LOGS.ParamByName('tela').AsString:=ReqJson.Find('tela').AsString;
      SP0001_LOGS.ParamByName('nome_usuario').AsString:=ReqJson.Find('nome_usuario').AsString;
      SP0001_LOGS.ParamByName('erro').AsBoolean:=ReqJson.Find('erro').AsBoolean;
      SP0001_LOGS.ExecProc;
      vOk:=True;
    except on e:exception do
     begin
       vMsg:=vFun+': '+e.Message;
       Utils.GravaLogArq('erro '+vfun+' ParseJSONValue: '+e.Message);
     end;
    end;
  finally
    try
      if vOk then
        Resp:=Utils.CriaObjetoJson(TagJson,1,vMsg,nil)
      else
      begin
        Resp:=Utils.CriaObjetoJson(TagJson,0,vMsg,Nil);
        if Utils.pAtivaLog then  Utils.GravaLogArq(vMsg);
      end;
    except on e:Exception do
      begin
        Utils.GravaLogArq('erro '+vfun+' ParseJSONValue: '+e.Message);
      end;
    end;
    //if Utils.pAtivaLog then Utils.GravaLogArq(vFun+':Result: '+Resp.AsJSON+' - saiu');
    If Assigned(ReqJson) then FreeAndNil(ReqJson);
  end;
end;

end.


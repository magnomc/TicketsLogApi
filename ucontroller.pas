unit uController;

{$mode Delphi}
//{$MODE DELPHI}{$H+}
//{$mode ObjFPC}{$H+}

interface

uses
 horse,Classes, SysUtils,uDmCon,fpjson,uUtilsClass,uDmPool,udmcon2,uDmPool2;


const cTipoApi = 'L';
type

{ TControler }

 TController = class
     class procedure Register;
end;
   procedure GetStatus(Req: THorseRequest; Res: THorseResponse);
   procedure GravaLogBD(Req: THorseRequest; Res: THorseResponse);
   procedure PesquisaLogs(Req: THorseRequest; Res: THorseResponse);
implementation

{ TControler }

class procedure TController.Register;
begin
 FormatSettings.ShortDateFormat:='dd/mm/yyyy';
 THorse.Routes.Prefix('tickets/log/api');
 THorse
   .Get('/GetStatus',GetStatus)
   .Post('/GravaLogBD/:tipo', GravaLogBD)
   .Post('/PesquisaLogs', PesquisaLogs);
end;


procedure GravaLogBD(Req: THorseRequest; Res: THorseResponse);
var
  DmCon: TdmCon;
  DmCon2: TdmCon2;
  JsonData: TJSONData;
  vFun,vTipoLog: string;
begin
  JsonData := nil;
  DmCon := nil;
  vFun:='GravaLogBD';
  try
    vTipoLog:=Req.Params['tipo'];
    if vTipoLog = 'I' then//API de integracoes
    begin
      try
        try
         // PEGA DO POOL (Instantâneo, pois já está criado e conectado)
         DmCon2 := TdmPool2.GetInstance(cTipoApi).GetConnection;

         // Chama seu método (ele não deve mais dar Connect/Disconnect internamente)
         DmCon2.GravaLogBD(Req.Body<TJSONObject>,JsonData);

        except on e: exception do
          begin
            // Se der erro, garante que temos um objeto de resposta
            if JsonData = nil then
               JsonData := DmCon.Utils.CriaObjetoJson(vFun,0,e.Message,nil);
          end;
        end;
      finally
        // DEVOLVE AO POOL (Para ser usado pela próxima requisição)
        if Assigned(DmCon2) then
          TdmPool2.GetInstance(cTipoApi).ReleaseConnection(DmCon2);

        if Assigned(JsonData) then
          Res.Send<TJSONData>(JsonData);
      end;
    end
    else if vTipoLog = 'P' then//padrao.
    begin
      try
        try
         // PEGA DO POOL (Instantâneo, pois já está criado e conectado)
         DmCon := TdmPool.GetInstance(cTipoApi).GetConnection;

         // Chama seu método (ele não deve mais dar Connect/Disconnect internamente)
         DmCon.GravaLogBD(Req.Body<TJSONObject>,JsonData);

        except on e: exception do
          begin
            // Se der erro, garante que temos um objeto de resposta
            if JsonData = nil then
               JsonData := DmCon.Utils.CriaObjetoJson(vFun,0,e.Message,nil);
          end;
        end;
      finally
        // DEVOLVE AO POOL (Para ser usado pela próxima requisição)
        if Assigned(DmCon) then
          TdmPool.GetInstance(cTipoApi).ReleaseConnection(DmCon);

        if Assigned(JsonData) then
          Res.Send<TJSONData>(JsonData);
      end;
    end
    else
      Res.Send('Requição incorreta!')
  except
    Res.Send('erro Requição!')
  end;
end;

procedure GetStatus(Req: THorseRequest; Res: THorseResponse);
var
  DmCon: TdmCon;
  JsonData: TJSONData;
  vFun: string;
begin
  JsonData := nil;
  DmCon := nil;
  vFun:='GetStatus';
  try
    try
      // PEGA DO POOL (Instantâneo, pois já está criado e conectado)
      DmCon := TdmPool.GetInstance(cTipoApi).GetConnection;

      // Chama seu método (ele não deve mais dar Connect/Disconnect internamente)
      DmCon.GetStatus(JsonData);

    except on e: exception do
      begin
        // Se der erro, garante que temos um objeto de resposta
        if JsonData = nil then
           JsonData := DmCon.Utils.CriaObjetoJson(vFun,0,e.Message,nil);
      end;
    end;
  finally
    // DEVOLVE AO POOL (Para ser usado pela próxima requisição)
    if Assigned(DmCon) then
      TdmPool.GetInstance(cTipoApi).ReleaseConnection(DmCon);

    if Assigned(JsonData) then
      Res.Send<TJSONData>(JsonData);
  end;
end;

procedure PesquisaLogs(Req: THorseRequest; Res: THorseResponse);
var
  DmCon: TdmCon;
  JsonData: TJSONData;
  vFun: string;
begin
  JsonData := nil;
  DmCon := nil;
  vFun:='PesquisaLogs';
  try
    try
      // PEGA DO POOL (Instantâneo, pois já está criado e conectado)
      DmCon := TdmPool.GetInstance(cTipoApi).GetConnection;

      // Chama seu método (ele não deve mais dar Connect/Disconnect internamente)
      DmCon.PesquisaLogs(Req.Body<TJSONObject>,JsonData);

    except on e: exception do
      begin
        // Se der erro, garante que temos um objeto de resposta
        if JsonData = nil then
           JsonData := DmCon.Utils.CriaObjetoJson(vFun,0,e.Message,nil);
      end;
    end;
  finally
    // DEVOLVE AO POOL (Para ser usado pela próxima requisição)
    if Assigned(DmCon) then
      TdmPool.GetInstance(cTipoApi).ReleaseConnection(DmCon);

    if Assigned(JsonData) then
      Res.Send<TJSONData>(JsonData);
  end;
end;

end.


program ticketslogapi;

{$mode Delphi}
//{$MODE DELPHI}{$H+}
//{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}

  windows,SysUtils,uController,Horse,Horse.Jhonson,Interfaces;

{$R *.res}

var LportaHttp : Integer;
    procedure OnListen();
    begin
      {$ifopt D+}
         WriteLn(format('Server Ativo em %s:%d', [THorse.Host,THorse.Port]));
      {$else}
         //Utils.GravaLogArq(format('Server Ativo em %s:%d', [THorse.Host,THorse.Port]));
      {$ENDIF}
    end;
begin

  {$ifopt D+}
     WriteLn('Server inciando...');
     WriteLn('Porta: '+ParamStr(1));
  {$else}
     FreeConsole;
  {$ENDIF}
  if ParamCount > 0 then
    LportaHttp:=StrToInt(ParamStr(1))
  else
    LportaHttp:=5161;

  THorse.ListenQueue := 5000;

  TController.Register;
  THorse
    .Use(Jhonson);
  THorse.Listen(LportaHttp,OnListen);
end.

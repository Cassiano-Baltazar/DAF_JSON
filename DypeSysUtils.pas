unit DypeSysUtils;

interface

uses
  Classes, Controls, DB, Types, Windows, DAF_Types;

type
  TDAFSysUtils = class
  public
    class function GetDecimalSeparator: Char;
    class procedure SetDecimalSeparator(AChar: Char);
    // Não criei uma property DecimalSeparator pois esta classe não vira um objeto, logo, não teria como se acessar a propriedade.
    // Se algum dia isso virar um objeto singleton (o que seria mais correto), deve-se trocar todas as chamadas para as class function
    // pelo uso da property. Neste caso as class function deveriam deixar de ser class (estáticas) para normais e virar protected também. Valdir.
  end;

function CenterString(const str: string; tamanho: Integer): string;
function CleanFileName(const InputString: string): string;
function ContainClientControl(Control: TWinControl): Boolean;
function ContainNumber(str: string): Boolean;
function Explode(str: string; delimiter: char = ','): TArrayOfString;
function FilterAlphaNum(Valor: string): string;
function FilterLetter(Valor: string): string;
function FilterNumber(Valor: string): string;
function FloatToStrFormatDecimal(pValue: Double; pFormat, pDecimal: string): string;
function GenerateUniqueName(Owner: TComponent; Prefix: string): string;
function GenerateValidFieldName(Text: string): string;
function GenerateRandomCurrency: Currency;
function GenerateRandomString: string;
function GetApplicationVersion(const FileName: string; const Fmt: string = '%d.%d.%d.%d'): string;
function GetContentFile(const FileName: string): string; overload;
function GetFileVersion(const FileName: string): string;
function GetMaxBottomUsed(Control: TWinControl): Integer;
function GetMaxRightUsed(Control: TWinControl): Integer;
function GetMinLeftUsed(Control: TWinControl): Integer;
function GetSystemDir: string;
function GetTempDir: string;
function GetTerminalName: string;
function iif(Expressao: Boolean; CasoVerdadeiro, CasoFalso: Variant): Variant;
function IncludeHTTP(URL: string): string;
function IsDllRegistered(dllName: String): Boolean;
function LastControlHasBottomAnchor(Control: TWinControl): Boolean;
function LPad(value: string; tamanho: Integer; c: char): string;
function MemoryStreamToString(M: TMemoryStream): string;
function RemoveAccents(const AInput: WideString): WideString;
function Repl(c: char; tam: byte): string;
function RoundDecimalPlaces(AValue: Currency; ADecimalPlaces: Integer = -1): Currency;
function RPad(value: string; tamanho: Integer; c: char): string;
// RunProcess Fonte: http://www.delphibasics.info/home/delphibasicssnippets/createprocessandwaitforexit
function RunProcess(FileName: string; ShowCmd: DWORD; wait: Boolean; ProcID: PDWORD): Longword;
function StrToReal(const str: string; SeparadorDecimal: char): Real;
function StrToCurrency(const str: string; SeparadorDecimal: char): Currency;
function SubstituiChar(pstring: string; char1, char2: char): string;
function ValidaCNPJ(numCNPJ: string): Boolean;
function ValidaCPF(numCPF: string): Boolean;
procedure DisableControls(DataSet: TDataSet);
procedure EnableControls(DataSet: TDataSet);
procedure GetContentFile(const FileName: string; slResult: TStringList); overload;

// Ferramenta de status dos serviço da Dype
function GetDypeStatusPanelURL(const URL, Servico, Token, Frequencia: AnsiString): AnsiString;
procedure TouchDypeStatusPanel(const URL, Servico, Token, Frequencia: AnsiString);

implementation

uses
  DBClient, Math, StrUtils, SysUtils,
  JclStrings, JclSysUtils,
  httpsend, synacode;

const
  LETRASMI = 'abcdefghijklmnopqrstuvwxyz';
  LETRASMA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  NUMEROS = '0123456789';

function CenterString(const str: string; tamanho: Integer): string;
var
  tamStr: Integer;
  tmpTam: Integer;
begin
  tamStr := trunc(length(str) / 2);
  tmpTam := trunc(tamanho / 2);
  if tmpTam > tamStr then
    Result := Repl(' ', tmpTam - tamStr) + str
  else
    Result := copy(str, tamanho);
end;

function CleanFileName(const InputString: string): string;
var
  i: Integer;
  ResultWithSpaces: string;
begin
  ResultWithSpaces := InputString;

  for i := 1 to length(ResultWithSpaces) do
  begin
    // These chars are invalid in file names.
    case ResultWithSpaces[i] of
      '/', '\', ':', '*', '?', '"', '|', ' ', #$D, #$A, #9:
        // Use a * to indicate a duplicate space so we can remove
        // them at the end.
{$WARNINGS OFF} // W1047 Unsafe code 'String index to var param'
        if (i > 1) and ((ResultWithSpaces[i - 1] = ' ') or (ResultWithSpaces[i - 1] = '*')) then
          ResultWithSpaces[i] := '*'
        else
          ResultWithSpaces[i] := ' ';

{$WARNINGS ON}
    end;
  end;

  // A * indicates duplicate spaces.  Remove them.
  Result := ReplaceStr(ResultWithSpaces, '*', '');

  // Also trim any leading or trailing spaces
  Result := Trim(Result);

  if Result = '' then
  begin
    raise (Exception.Create('Resulting FileName was empty Input string was: ' + InputString));
  end;
end;

function ContainClientControl(Control: TWinControl): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Control.ControlCount - 1 do
  begin
    Result := (Control.Controls[i].Align = alClient) and (Control.Controls[i].Constraints.MinHeight = 0);
    if Result then
      Break;
  end;
end;

function ContainNumber(str: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 1 to length(str) do
  begin
    Result := Result or {$IF CompilerVersion>21}CharInSet(str[i], ['0' .. '9']){$ELSE}(str[i] in ['0' .. '9']){$IFEND};
    if Result then
      Break;
  end;
end;

function Explode(str: string; delimiter: char): TArrayOfString;
var
  tmp: TStringList;
  i: Integer;
begin
  tmp := TStringList.Create;
  try
    tmp.Delimiter := delimiter;
    tmp.DelimitedText := str;
    SetLength(Result, tmp.Count);
    for i := 0 to tmp.Count - 1 do
      Result[i] := Trim(tmp[i]);
  finally
    tmp.Free;
  end;
end;

function FilterAlphaNum(Valor: string): string;
var
  i: Integer;
begin
  // Não mude este comportamento, isso é utilizado nas remessas de boletos
  Result := '';
  Valor := RemoveAccents(Valor);
  for i := 1 to Length(Valor) do
    if CharIsAlphaNum(Valor[i]) or (Valor[i] = ' ') or (Valor[i] = '-') then
      Result := Result + Valor[i];
  Result := Trim(Result);
end;

function FilterLetter(Valor: string): string;
var
  i: Integer;
  NewStr: string;
begin
  NewStr := '';
  for i := 1 to length(Valor) do
    if CharIsAlpha(Valor[i]) then
      NewStr := NewStr + Valor[i];
  Result := Trim(NewStr);
end;

function FilterNumber(Valor: string): string;
var
  i: Integer;
  NewStr: string;
begin
  NewStr := '';
  for i := 1 to length(Valor) do
    if CharIsNumber(Valor[i]) then
      NewStr := NewStr + Valor[i];
  Result := Trim(NewStr);
end;

function FloatToStrFormatDecimal(pValue: Double; pFormat, pDecimal: string): string;
begin
  Result := StringReplace(FormatFloat(pFormat, pValue), {$IF CompilerVersion>21}FormatSettings.{$IFEND}DecimalSeparator, pDecimal, [rfReplaceAll, rfIgnoreCase]);
end;

function GenerateUniqueName(Owner: TComponent; Prefix: string): string;
var
  i: Integer;
begin
  Assert(Trim(Prefix) <> '', 'BUGCHECK - É necessário indicar um prefixo para o nome do componente!');

  if Owner = nil then
    Result := Prefix + 'NoOwner'
  else
  begin
    i := 1;
    Result := Prefix + IntToStr(i);
    while Owner.FindComponent(Result) <> nil do
    begin
      Inc(i);
      Result := Prefix + IntToStr(i);
    end;
  end;
end;

function GenerateValidFieldName(Text: string): string;
var
  i: Integer;
begin
  Result := RemoveAccents(Text);
  for i := 1 to length(Result) do
  begin
    case Result[i] of
      #32: Result[i] := '_';
    end;
  end;
end;

function GenerateRandomCurrency: Currency;
begin
  Result := MinCurrency + Random(trunc(MaxCurrency * 100) - trunc(MaxCurrency * 100) + 1) / 100.0;
end;

function GenerateRandomString: string;
begin
  Result := '';
  Result := Result + IntToStr(Random(length(LETRASMI)) + 1);
  Result := Result + IntToStr(Random(length(LETRASMA)) + 1);
  Result := Result + IntToStr(Random(length(NUMEROS)) + 1);
end;

function GetApplicationVersion(const FileName: string; const Fmt: string = '%d.%d.%d.%d'): string;
var
  iBufferSize: DWORD;
  iDummy: DWORD;
  pBuffer: Pointer;
  pFileInfo: Pointer;
  iVer: array [ 1..4 ] of Word;
begin
  // set default value
  Result := '';
  // get size of version info (0 if no version info exists)
  iBufferSize := GetFileVersionInfoSize(PChar(FileName), iDummy);
  if (iBufferSize > 0) then
  begin
    GetMem(pBuffer, iBufferSize);
    try
      // get fixed file info
      GetFileVersionInfo(PChar(FileName), 0, iBufferSize, pBuffer);
      VerQueryValue(pBuffer, '\', pFileInfo, iDummy);
      // read version blocks
      iVer[1] := HiWord(PVSFixedFileInfo(pFileInfo)^.dwFileVersionMS);
      iVer[2] := LoWord(PVSFixedFileInfo(pFileInfo)^.dwFileVersionMS);
      iVer[3] := HiWord(PVSFixedFileInfo(pFileInfo)^.dwFileVersionLS);
      iVer[4] := LoWord(PVSFixedFileInfo(pFileInfo)^.dwFileVersionLS);
    finally
      FreeMem(pBuffer);
    end;
    // format result string
    Result := Format(Fmt, [iVer[1], iVer[2], iVer[3], iVer[4]]);
  end;
end;

function GetContentFile(const FileName: string): string;
var
  tfXML: TextFile;
  sLinha: string;
begin
  AssignFile(tfXML, FileName);
{$I-} // desativa a diretiva de Input
  Reset(tfXML);
{$I+} // ativa a diretiva de Input
  if (IOResult <> 0) then
    raise TDAFUserException.Create('Erro na abertura do arquivo!')
  else
  begin
    Result := '';
    while (not eof(tfXML)) do
    begin
      readln(tfXML, sLinha);
      Result := Result + sLinha;
    end;
    CloseFile(tfXML);
  end;

  if length(Trim(Result)) = 0 then
    raise TDAFUserException.Create('Arquivo em branco!');
end;

function GetFileVersion(const FileName: string): string;
var
  FileInfo: VS_FIXEDFILEINFO;
  InfoSize, Tamanho: DWORD;
  tmpPointer, InfoPointer: Pointer;
begin
  Result := '';
  InfoSize := GetFileVersionInfoSize(PChar(FileName), Tamanho);
  FillChar(FileInfo, SizeOf(VS_FIXEDFILEINFO), 0);
  if InfoSize > 0 then
  begin
    GetMem(tmpPointer, InfoSize);
    GetFileVersionInfo(PChar(FileName), 0, InfoSize, tmpPointer);
    VerQueryValue(tmpPointer, '\', InfoPointer, Tamanho);
    move(InfoPointer^, FileInfo, SizeOf(VS_FIXEDFILEINFO));
    Result := Format('%d.%d.%d.%d', [FileInfo.dwFileVersionMS shr 16, FileInfo.dwFileVersionMS and 65535, FileInfo.dwFileVersionLS shr 16,
      FileInfo.dwFileVersionLS and 65535]);
    FreeMem(tmpPointer);
  end
  else
    Result := '';
end;

function GetMaxBottomUsed(Control: TWinControl): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to Control.ControlCount - 1 do
    if Control.Controls[i].Visible then
      Result := Max(Result, Control.Controls[i].BoundsRect.Bottom);
end;

function GetMaxRightUsed(Control: TWinControl): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to Control.ControlCount - 1 do
    if Control.Controls[i].Visible then
      Result := Max(Result, Control.Controls[i].BoundsRect.Right);
end;

function GetMinLeftUsed(Control: TWinControl): Integer;
var
  i: Integer;
begin
  Result := Control.ClientWidth;
  for i := 0 to Control.ControlCount - 1 do
    if Control.Controls[i].Visible then
      Result := Min(Result, Control.Controls[i].BoundsRect.Left);
end;

function GetSystemDir: string;
resourcestring
  RS_GET_SYSTEM_DIR_ERROR = 'Erro ao procurar o diretório do sistema';
var
  tmp: Cardinal;
  buffer: array [0 .. MAX_PATH] of char;
begin
  tmp := GetSystemDirectory(@buffer[0], MAX_PATH);
  if tmp = 0 then
    raise Exception.Create(RS_GET_SYSTEM_DIR_ERROR);
  buffer[tmp] := #0;
  Result := IncludeTrailingPathDelimiter(buffer);
end;

//Refeito abaixo para funcionar no XE7
//function GetTempDir: string;
//var
//  Buffer: array[0..MAX_PATH] of WideChar;
//begin
//  GetTempPath(SizeOf(Buffer) - 1, Buffer);
//  Result := IncludeTrailingPathDelimiter(Buffer);
//end;

function GetTempDir: string;
var
  iSize: DWORD;
begin
  SetLength(Result, MAX_PATH);
  iSize := GetTempPath(MAX_PATH, PChar(Result));
  SetLength(Result, iSize);
  Result := IncludeTrailingPathDelimiter(Result);
end;

function GetTerminalName: string;
var
  buffer: array [0 .. 254] of char;
  buffersize: Cardinal;
begin
  buffersize := length(buffer);
  GetComputerName(buffer, buffersize);
  Result := AnsiLowerCase(buffer);
end;

function iif(Expressao: Boolean; CasoVerdadeiro, CasoFalso: Variant): Variant;
begin
  if Expressao then
    Result := CasoVerdadeiro
  else
    Result := CasoFalso;
end;

function IncludeHTTP(URL: string): string;
begin
  if AnsiLowerCase(Copy(URL, 1, 7)) <> 'http://' then
    Result := 'http://' + URL
  else
    Result := URL;
end;

function IsDllRegistered(dllName: String): Boolean;
var
  hModule: Cardinal;
begin
  Result := False;

  // Em versões antigas coloque PChar no lugar de PWideChar.
  hModule := LoadLibrary(PChar(dllName));

  if (hModule > 32) Then
  begin
    FreeLibrary(hModule);
    Result := True;
  end
end;

function LastControlHasBottomAnchor(Control: TWinControl): Boolean;
var
  i, tmp: Integer;
begin
  Result := False;
  tmp := 0;
  for i := 0 to Control.ControlCount - 1 do
    if Control.Controls[i].Visible and (Control.Controls[i].BoundsRect.Bottom >= tmp) then
    begin
      tmp := Control.Controls[i].BoundsRect.Bottom;
      Result := (akBottom in Control.Controls[i].Anchors);
      if Result then
        Break;
    end;
end;

function LPad(value: string; tamanho: Integer; c: char): string;
begin
  Result := RightStr(StringOfChar(c, tamanho) + value, tamanho); //É right pois conta da direita para a esquerda.
end;

function MemoryStreamToString(M: TMemoryStream): string;
begin
  SetString(Result, PChar(M.Memory), M.Size div SizeOf(char));
end;

function RemoveAccents(const AInput: WideString): WideString;
const
  CodePage = 20127; // 20127 = us-ascii
var
  WS: WideString;
  WSL: Integer;
{$IF CompilerVersion>21}
  Temp: RawByteString;
{$ELSE}
  Temp: string;
{$IFEND}
begin
  WS := WideString(AInput);
  WSL := WideCharToMultiByte(CodePage, 0, PWideChar(WS), length(WS), nil, 0, nil, nil);
  SetLength(Temp, WSL);
  WideCharToMultiByte(CodePage, 0, PWideChar(WS), WSL, PAnsiChar(AnsiString(Temp)), WSL, nil, nil);
  Result := WideString(Temp);
end;

function Repl(c: Char; tam: byte):string;
var
  i : Byte;
  st : string;
begin
  st := '';
  for i := 1 to tam do
    st := st + c;
  Result := st;
end;

function RoundDecimalPlaces(AValue: Currency; ADecimalPlaces: Integer = -1): Currency;
var
  LFactor, i: Integer;
begin
  if ADecimalPlaces < 0 then
{$IF CompilerVersion>21}
    ADecimalPlaces := FormatSettings.CurrencyDecimals;
{$ELSE}
    ADecimalPlaces := CurrencyDecimals;
{$IFEND}
  if ADecimalPlaces > 4 then
    ADecimalPlaces := 4;

  LFactor := 1;
  for i := 1 to ADecimalPlaces do
    LFactor := LFactor * 10;

  if AValue < 0 then
    Result := trunc(AValue * LFactor - 0.5) / LFactor
  else
    Result := trunc(AValue * LFactor + 0.5) / LFactor;
end;

function RPad(value: string; tamanho: Integer; c: char): string;
begin
  Result := LeftStr(value + StringOfChar(c, tamanho), tamanho);
  // É left pois conta da esquerda para a direita.
end;

function RunProcess(FileName: string; ShowCmd: DWORD; wait: Boolean; ProcID: PDWORD): Longword;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
begin
  FillChar(StartupInfo, SizeOf(StartupInfo), #0);
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_FORCEONFEEDBACK;
  StartupInfo.wShowWindow := ShowCmd;
  if not CreateProcess(nil, @FileName[1], nil, nil, False, CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS, nil, nil, StartupInfo, ProcessInfo) then
    Result := WAIT_FAILED
  else
  begin
    if wait = False then
    begin
      if ProcID <> nil then
        ProcID^ := ProcessInfo.dwProcessId;
      Result := WAIT_FAILED;
      exit;
    end;
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    GetExitCodeProcess(ProcessInfo.hProcess, Result);
  end;
  if ProcessInfo.hProcess <> 0 then
    CloseHandle(ProcessInfo.hProcess);
  if ProcessInfo.hThread <> 0 then
    CloseHandle(ProcessInfo.hThread);
end;

function StrToCurrency(const str: string; SeparadorDecimal: char): Currency;
var
  SepDecAnt: char;
begin
{$IF CompilerVersion>21}
  SepDecAnt := FormatSettings.DecimalSeparator;
  FormatSettings.DecimalSeparator := SeparadorDecimal;
{$ELSE}
  SepDecAnt := DecimalSeparator;
  DecimalSeparator := SeparadorDecimal;
{$IFEND}
  try
    Result := StrToCurrDef(str, 0);
  finally
{$IF CompilerVersion>21}
    FormatSettings.DecimalSeparator := SepDecAnt;
{$ELSE}
    DecimalSeparator := SepDecAnt;
{$IFEND}
  end;
end;

function StrToReal(const str: string; SeparadorDecimal: char): Real;
var
  SepDecAnt: char;
begin
{$IF CompilerVersion>21}
  SepDecAnt := FormatSettings.DecimalSeparator;
  FormatSettings.DecimalSeparator := SeparadorDecimal;
{$ELSE}
  SepDecAnt := DecimalSeparator;
  DecimalSeparator := SeparadorDecimal;
{$IFEND}
  try
    Result := StrToFloatDef(str, 0);
  finally
{$IF CompilerVersion>21}
    FormatSettings.DecimalSeparator := SepDecAnt;
{$ELSE}
    DecimalSeparator := SepDecAnt;
{$IFEND}
  end;
end;

function SubstituiChar(pstring: string; char1, char2: char): string;
var
  i: Integer;
begin
  for i := 1 to length(pstring) do
  begin
    if pstring[i] = char1 then
      pstring[i] := char2;
  end;
  Result := pstring;
end;

function ValidaCNPJ(numCNPJ: string): Boolean;
var
  cnpj: string;
  dg1, dg2: Integer;
  x, total: Integer;
  ret: Boolean;
begin
  ret := False;
  cnpj := '';
  // Analisa os formatos
  if length(numCNPJ) = 18 then
    if (copy(numCNPJ, 3, 1) + copy(numCNPJ, 7, 1) + copy(numCNPJ, 11, 1) + copy(numCNPJ, 16, 1) = '../-') then
    begin
      cnpj := copy(numCNPJ, 1, 2) + copy(numCNPJ, 4, 3) + copy(numCNPJ, 8, 3) + copy(numCNPJ, 12, 4) + copy(numCNPJ, 17, 2);
      ret := True;
    end;
  if length(numCNPJ) = 14 then
  begin
    cnpj := numCNPJ;
    ret := True;
  end;
  // Verifica
  if ret then
  begin
    try
      // 1° digito
      total := 0;
      for x := 1 to 12 do
      begin
        if x < 5 then
          Inc(total, StrToInt(copy(cnpj, x, 1)) * (6 - x))
        else
          Inc(total, StrToInt(copy(cnpj, x, 1)) * (14 - x));
      end;
      dg1 := 11 - (total mod 11);
      if dg1 > 9 then
        dg1 := 0;
      // 2° digito
      total := 0;
      for x := 1 to 13 do
      begin
        if x < 6 then
          Inc(total, StrToInt(copy(cnpj, x, 1)) * (7 - x))
        else
          Inc(total, StrToInt(copy(cnpj, x, 1)) * (15 - x));
      end;
      dg2 := 11 - (total mod 11);
      if dg2 > 9 then
        dg2 := 0;
      // Validação final
      if (dg1 = StrToInt(copy(cnpj, 13, 1))) and (dg2 = StrToInt(copy(cnpj, 14, 1))) then
        ret := True
      else
        ret := False;
    except
      ret := False;
    end;
    // Inválidos
    case AnsiIndexStr(cnpj, ['00000000000000', '11111111111111', '22222222222222', '33333333333333', '44444444444444', '55555555555555',
      '66666666666666', '77777777777777', '88888888888888', '99999999999999']) of
      0 .. 9:
        ret := False;

    end;
  end;
  ValidaCNPJ := ret;
end;

function ValidaCPF(numCPF: string): Boolean;
var
  cpf: string;
  x, total, dg1, dg2: Integer;
  ret: Boolean;
begin
  ret := True;
  for x := 1 to length(numCPF) do
    if not({$IF CompilerVersion>21}CharInSet(numCPF[x], ['0' .. '9', '-', '.', ' ']){$ELSE}numCPF[x] in ['0' .. '9', '-', '.', ' ']{$IFEND}) then
      ret := False;
  if ret then
  begin
    ret := True;
    cpf := '';
    for x := 1 to length(numCPF) do
      if {$IF CompilerVersion>21}CharInSet(numCPF[x], ['0' .. '9']){$ELSE}numCPF[x] in ['0' .. '9']{$IFEND} then
        cpf := cpf + numCPF[x];
    if length(cpf) <> 11 then
      ret := False;
    if ret then
    begin
      // 1° dígito
      total := 0;
      for x := 1 to 9 do
        total := total + (StrToInt(cpf[x]) * x);
      dg1 := total mod 11;
      if dg1 = 10 then
        dg1 := 0;
      // 2° dígito
      total := 0;
      for x := 1 to 8 do
        total := total + (StrToInt(cpf[x + 1]) * (x));
      total := total + (dg1 * 9);
      dg2 := total mod 11;
      if dg2 = 10 then
        dg2 := 0;
      // Validação final
      if dg1 = StrToInt(cpf[10]) then
        if dg2 = StrToInt(cpf[11]) then
          ret := True;
      // Inválidos

      case AnsiIndexStr(cpf, ['00000000000', '11111111111', '22222222222', '33333333333', '44444444444', '55555555555', '66666666666', '77777777777',
        '88888888888', '99999999999']) of
        0 .. 9:
          ret := False;
      end;
    end
    else
    begin
      // Se não informado deixa passar
      if cpf = '' then
        ret := True;
    end;
  end;
  ValidaCPF := ret;
end;

procedure DisableControls(DataSet: TDataSet);
var
  i, j: Integer;
begin
  DataSet.DisableControls;
  // busca por nested datasets para desabilitar também
  for i := 0 to DataSet.FieldCount - 1 do
    if DataSet.Fields[i].ClassType = TDataSetField then
      for j := 0 to DataSet.Owner.ComponentCount - 1 do
        if DataSet.Owner.Components[j].InheritsFrom(TClientDataSet) and (TClientDataSet(DataSet.Owner.Components[j]).DataSetField = DataSet.Fields[i])
        then
          TClientDataSet(DataSet.Owner.Components[j]).DisableControls;
end;

procedure EnableControls(DataSet: TDataSet);
var
  i, j: Integer;
begin
  DataSet.EnableControls;
  // busca por nested datasets para habilitar também
  for i := 0 to DataSet.FieldCount - 1 do
    if DataSet.Fields[i].ClassType = TDataSetField then
      for j := 0 to DataSet.Owner.ComponentCount - 1 do
        if DataSet.Owner.Components[j].InheritsFrom(TClientDataSet) and (TClientDataSet(DataSet.Owner.Components[j]).DataSetField = DataSet.Fields[i]) then
          TClientDataSet(DataSet.Owner.Components[j]).EnableControls;
end;

procedure GetContentFile(const FileName: string; slResult: TStringList);
var
  tfXML: TextFile;
  sLinha: string;
  tmp: Integer;
begin
  AssignFile(tfXML, FileName);
{$I-} // desativa a diretiva de Input
  Reset(tfXML);
{$I+} // ativa a diretiva de Input
  tmp := IOResult;
  if (tmp <> 0) then
    raise TDAFUserException.Create(SysErrorMessage(tmp))
  else
  begin
    slResult.Text := '';
    while (not eof(tfXML)) do
    begin
      readln(tfXML, sLinha);
      slResult.Add(sLinha);
    end;
    CloseFile(tfXML);
  end;

  if length(Trim(slResult.Text)) = 0 then
    raise TDAFUserException.Create('Arquivo em branco!');
end;

function GetDypeStatusPanelURL(const URL, Servico, Token, Frequencia: AnsiString): AnsiString;
begin
  Result := UTF8Encode(Format(
    'http://www.dype.com.br/projetoservico/keepalive?URL=%s&SERVICO=%s&TOKEN=%s&FREQUENCIA=%s', [
    EncodeURLElement(URL),
    EncodeURLElement(Servico),
    EncodeURLElement(Token),
    EncodeURLElement(Frequencia)
    ]));
end;

procedure TouchDypeStatusPanel(const URL, Servico, Token, Frequencia: AnsiString);
var
  Result: TStringList;
begin
  Result := TStringList.Create;
  try
    HttpGetText({$IF CompilerVersion > 21}UTF8ToString({$IFEND}GetDypeStatusPanelURL(URL, Servico, Token,
      Frequencia){$IF CompilerVersion > 21}){$IFEND}, Result);
  finally
    Result.Free;
  end;
end;

{ TDAFSysUtils }

class function TDAFSysUtils.GetDecimalSeparator: Char;
begin
  Result := {$IF CompilerVersion > 21}FormatSettings.{$IFEND}DecimalSeparator;
end;

class procedure TDAFSysUtils.SetDecimalSeparator(AChar: Char);
begin
  {$IF CompilerVersion > 21}FormatSettings.{$IFEND}DecimalSeparator := AChar;
end;

end.

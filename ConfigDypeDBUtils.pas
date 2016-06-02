unit ConfigDypeDBUtils;

interface

uses
  Classes, DB, DBClient, Forms, Math, SysUtils, Variants, Windows, DypeSysUtils;

function DataSetRecord2Text(DataSet: TDataSet; Separator: string = ', '; IgnoreFields: string = ''): string;
function FieldStringValue(AField: TField): string;
function ParamStringValue(AParam: TParam): string;
function FindNested(Component: TComponent; DataSetFieldName: string): TClientDataSet;
function IBDateToDate(const StrDate: string): TDateTime;
procedure cdsUpdateField(cds: TClientDataSet; Campo: string; Valor: Variant);
procedure CopyCDSData(cdsOrigem, cdsDestino: TClientDataSet; CamposIgnorados: string = ''; DoPost: Boolean = True);
procedure CopyCDSFields(cdsOrigem: TDataSet; cdsDestino: TDataSet);
procedure CreateField(AMemData: TDataSet; pName: string; pDataType: TFieldType; pSize: Integer = 0; pRequired: Boolean = False); overload;
procedure CreateField(AMemData: TDataSet; pName: string; pDisplayName: string; pDataType: TFieldType; pSize: Integer = 0;
  pRequired: Boolean = False); overload;
procedure CreateChildField(AField: TFieldDef; pName: string; pDataType: TFieldType; pSize: Integer = 0; pRequired: Boolean = False);
procedure DataSet2Text(DataSet: TDataSet; Target: TStrings; Separator: string = ', '; ClearTarget: Boolean = True);
procedure DuplicateCDS(const Source, Target: TClientDataSet; Fields2Ignore: string = '');
procedure InsertCDSRecord(cdsOrigem: TDataSet; cdsDestino: TDataSet; CamposIgnorados: string = ''; DoPost: Boolean = True);
procedure SetColumn(DataSet: TDataSet; FieldName: string; Value: Variant);
procedure TransNegUpdateValor(cdsAux: TClientDataSet; CampoRef: TField; Valor: Variant; var EvitaRecursividade: Boolean);
procedure UpdateItemValores(Sender: TField; var EvitaRecursividade: Boolean; QtdCasasDecimais: Integer = 2);
procedure UpdatePedidoValores(cdsPedido, cdsItens: TClientDataSet; Sender: TField; var EvitaRecursividade: Boolean);
procedure CreateIndexClientDataSet(ClientDataSet: TClientDataSet; IndexName, FieldList: String);
procedure CopyDataSetRecordByfieldName(const Source, Target: TDataSet);

implementation

var
  FUsable: Boolean;

procedure CopyDataSetRecordByfieldName(const Source, Target: TDataSet);
var
  i: Integer;
  tmp: TField;
begin
  for i := 0 to Target.FieldCount - 1 do
  begin
    tmp := Source.FindField(Target.Fields[i].FieldName);
    if tmp <> nil then
      Target.Fields[i].Value := tmp.Value;
  end;
end;

procedure CreateIndexClientDataSet(ClientDataSet: TClientDataSet; IndexName, FieldList: string);
begin
  ClientDataSet.IndexDefs.Clear;
  with ClientDataSet.IndexDefs.AddIndexDef do
  begin
    Name := IndexName;
    Fields := FieldList;
  end;
end;

function FieldStringValue(AField: TField): string;
begin
  if AField.IsNull then
    Result := ' = null'
  else if AField.DataType = ftDateTime then
    Result := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AField.AsDateTime)
  else if AField.DataType = ftDate then
    Result := FormatDateTime('yyyy-mm-dd', AField.AsDateTime)
  else if AField.DataType = ftTime then
    Result := FormatDateTime('hh:nn:ss.zzz', AField.AsDateTime)
  else
    Result := AField.AsString;
end;

function ParamStringValue(AParam: TParam): string;
begin
  if AParam.IsNull then
    Result := ' = null'
  else if AParam.DataType = ftDateTime then
    Result := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AParam.AsDateTime)
  else if AParam.DataType = ftDate then
    Result := FormatDateTime('yyyy-mm-dd', AParam.AsDate)
  else if AParam.DataType = ftTime then
    Result := FormatDateTime('hh:nn:ss.zzz', AParam.AsTime)
  else
    Result := AParam.AsString;
end;

procedure DataSet2Text(DataSet: TDataSet; Target: TStrings; Separator: string; ClearTarget: Boolean);
begin
  if ClearTarget then
    Target.Clear;
  DataSet.First;
  while not DataSet.Eof do
  begin
    Target.Add(DataSetRecord2Text(DataSet, Separator));
    DataSet.Next;
  end;
end;

function DataSetRecord2Text(DataSet: TDataSet; Separator, IgnoreFields: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to DataSet.FieldCount - 1 do
    if Pos(DataSet.Fields[i].FieldName, IgnoreFields) <= 0 then
      Result := Result + DataSet.Fields[i].AsString + Separator;
  Result := Copy(Result, 1, Length(Result) - Length(Separator));
end;

procedure SetColumn(DataSet: TDataSet; FieldName: string; Value: Variant);
var
  tmpField: TField;
begin
  tmpField := DataSet.FindField(FieldName);
  if tmpField <> nil then
    tmpField.Value := Value;
end;

function FindNested(Component: TComponent; DataSetFieldName: string): TClientDataSet;
var
  i: Integer;
  cds: TClientDataSet;
begin
  Result := nil;
  for i := 0 to Component.ComponentCount - 1 do
  begin
    if Component.Components[i].InheritsFrom(TClientDataSet) then
    begin
      cds := TClientDataSet(Component.Components[i]);
      if (cds.DataSetField <> nil) and (cds.DataSetField.FieldName = DataSetFieldName) then
      begin
        Result := cds;
        Break;
      end;
    end;
  end;
end;

function IBDateToDate(const StrDate: string): TDateTime;
var
  s: string;
begin
  s := {$IF CompilerVersion>21}FormatSettings.{$IFEND}ShortDateFormat;
{$IF CompilerVersion>21}FormatSettings.{$IFEND}ShortDateFormat := 'yyyy/MM/dd';
  try
    Result := StrToDate(StringReplace(StrDate, '-',
{$IF CompilerVersion>21}FormatSettings.{$IFEND}DateSeparator, [rfReplaceAll]));
  finally
{$IF CompilerVersion>21}FormatSettings.{$IFEND}ShortDateFormat := s;
  end;
end;

procedure DuplicateCDS(const Source, Target: TClientDataSet; Fields2Ignore: string = '');
begin
  CopyCDSFields(Source, Target);
  Target.CreateDataSet;
  CopyCDSData(Source, Target, Fields2Ignore, True);
end;

procedure CopyCDSFields(cdsOrigem: TDataSet; cdsDestino: TDataSet);
var
  i: Integer;
begin
  cdsDestino.Close;
  cdsDestino.Fields.Clear;
  cdsDestino.FieldDefs.Clear;
  for i := 0 to cdsOrigem.FieldDefs.Count - 1 do
  begin
    if
      (cdsOrigem.FieldDefs[i].DataType <> ftDataSet) and
      (cdsOrigem.FindField(cdsOrigem.FieldDefs[i].Name) <> nil) and
      (cdsOrigem.FieldByName(cdsOrigem.FieldDefs[i].Name).FieldKind = fkData)
    then
    begin
      if cdsDestino.InheritsFrom(TClientDataSet) then
        cdsDestino.FieldDefs.Add(cdsOrigem.FieldDefs[i].Name, cdsOrigem.FieldDefs[i].DataType, cdsOrigem.FieldDefs[i].Size,
          cdsOrigem.FieldDefs[i].Required)
      else
        CreateField(cdsDestino, cdsOrigem.FieldDefs[i].Name, cdsOrigem.FieldDefs[i].DataType, cdsOrigem.FieldDefs[i].Size,
          cdsOrigem.FieldDefs[i].Required);
    end;
  end;
end;

procedure CopyCDSData(cdsOrigem, cdsDestino: TClientDataSet; CamposIgnorados: string = ''; DoPost: Boolean = True);
  procedure CopyCDSDetailData(pSourceCDS, pTargetCDS: TClientDataSet; pDuplicateIgnoreFields: TStringList);
  var
    i, j, DotPosition: Integer;
    NestedIgnoreFields: TStringList;
    cdsSource, cdsTarget: TClientDataSet;
  begin
    for i := 0 to pTargetCDS.FieldCount - 1 do
    begin
      if (pTargetCDS.Fields[i].DataType = ftDataSet) and (pDuplicateIgnoreFields.IndexOf(pTargetCDS.Fields[i].FieldName) < 0) then
      begin
        cdsSource := TClientDataSet(TDataSetField(pSourceCDS.Fields[i]).NestedDataSet);
        if cdsSource <> nil then
        begin
          cdsTarget := TClientDataSet(TDataSetField(pTargetCDS.Fields[i]).NestedDataSet);
          if cdsTarget <> nil then
          begin
            NestedIgnoreFields := TStringList.Create;
            try
              for j := 0 to pDuplicateIgnoreFields.Count - 1 do
              begin
                DotPosition := Pos('.', pDuplicateIgnoreFields.Strings[j]);
                if (DotPosition > 0) and
                   (Copy(AnsiLowerCase(pDuplicateIgnoreFields.Strings[j]), 1, DotPosition - 1) = AnsiLowerCase(pTargetCDS.Fields[i].FieldName))
                then
                  NestedIgnoreFields.Add(Copy(pDuplicateIgnoreFields.Strings[j], DotPosition + 1, MaxInt));
              end;

              for j := cdsSource.FieldCount - 1 downto 0 do
                if pfInKey in cdsSource.Fields[j].ProviderFlags then
                  NestedIgnoreFields.Insert(0, cdsSource.Fields[j].FieldName);

              // Aqui eu forço o readonly para false, pois se chegou até aqui, tem que conseguir copiar os dados do cds de details
              // Por algum motivo obscuro no framework, nas ordens de serviço estava chegando aqui com true, acho que tem a ver com o código
              // do TModel.OnStateChangeHandler;
              if cdsTarget.ReadOnly then
                cdsTarget.ReadOnly := False;

              CopyCDSData(cdsSource, cdsTarget, NestedIgnoreFields.CommaText, True);
            finally
              NestedIgnoreFields.Free;
            end;
          end;
        end;
      end;
    end;
  end;
var
  SourcePosition: TBookmark;
  tsDuplicateIgnoreFields: TStringList;
begin
  cdsOrigem.DisableControls;
  cdsDestino.DisableControls;
  tsDuplicateIgnoreFields := TStringList.Create;
  try
    tsDuplicateIgnoreFields.CommaText := CamposIgnorados;

    if not cdsOrigem.Active then
      cdsOrigem.Active := True;

    SourcePosition := cdsOrigem.GetBookmark;
    try
      cdsOrigem.First;
      while not cdsOrigem.Eof do
      begin
        InsertCDSRecord(cdsOrigem, cdsDestino, CamposIgnorados, DoPost);
        CopyCDSDetailData(cdsOrigem, cdsDestino, tsDuplicateIgnoreFields);
        if (not DoPost) and (cdsOrigem.RecNo = cdsOrigem.RecordCount) then
          Break
        else
          cdsOrigem.Next;
      end;
      if DoPost then
        cdsDestino.First;
      cdsOrigem.GotoBookmark(SourcePosition);
    finally
      cdsOrigem.FreeBookmark(SourcePosition);
    end;
  finally
    tsDuplicateIgnoreFields.Free;
    cdsOrigem.EnableControls;
    cdsDestino.EnableControls;
  end;
end;

procedure InsertCDSRecord(cdsOrigem: TDataSet; cdsDestino: TDataSet; CamposIgnorados: string = ''; DoPost: Boolean = True);
var
  i: Integer;
  CampoOrigem: TField;
  CampoDestino: TField;
  IgnoreFields: TStringList;
  OldReadOnly: Boolean;
begin
  while not FUsable do;

  FUsable := False;
  try
    IgnoreFields := TStringList.Create;
    try
      IgnoreFields.CommaText := CamposIgnorados;

      cdsDestino.Append;
      for i := 0 to cdsOrigem.FieldCount - 1 do
      begin
        CampoOrigem := cdsOrigem.Fields[i];
        CampoDestino := cdsDestino.FindField(CampoOrigem.FieldName);
        if
          (CampoDestino <> nil) and
          (not CampoOrigem.IsNull) and
          (IgnoreFields.IndexOf(CampoOrigem.FieldName) < 0)
        then
        begin
          OldReadOnly := CampoDestino.ReadOnly;
          try
            CampoDestino.ReadOnly := False;
            if (CampoOrigem is TBCDField) or (CampoOrigem is TFMTBCDField) then
              CampoDestino.AsString := CampoOrigem.AsString
            else
              CampoDestino.AsVariant := CampoOrigem.Value;
          finally
            CampoDestino.ReadOnly := OldReadOnly;
          end;
        end;
      end;
      cdsDestino.Post;
    finally
      IgnoreFields.Free;
    end;
  finally
    FUsable := True;
  end;
end;

procedure UpdatePedidoValores(cdsPedido, cdsItens: TClientDataSet; Sender: TField; var EvitaRecursividade: Boolean);
  procedure CalulaValorTotal(cdsPedido, cdsItens: TClientDataSet);
  var
    SomaValorTabela: Currency;
    ValorDescontoGeral: Currency;
    ValorAcrescimoCondPgto: Currency;
  begin
    if (cdsPedido <> nil) and (cdsItens <> nil) then
      if not(cdsPedido.IsEmpty or cdsItens.IsEmpty) then
      begin
        SomaValorTabela := iif(not(VarIsEmpty(cdsItens.FieldByName('SOMA_VALOR_TABELA').Value) or VarIsNull(cdsItens.FieldByName('SOMA_VALOR_TABELA')
          .Value)), cdsItens.FieldByName('SOMA_VALOR_TABELA').Value, 0);
        ValorDescontoGeral := iif(not(VarIsEmpty(cdsPedido.FieldByName('VALOR_DESCONTO').Value) or VarIsNull(cdsPedido.FieldByName('VALOR_DESCONTO')
          .Value)), cdsPedido.FieldByName('VALOR_DESCONTO').Value, 0);
        ValorAcrescimoCondPgto := iif(not(VarIsEmpty(cdsPedido.FieldByName('VALOR_ACRESCIMO_COND_PGTO').Value) or
          VarIsNull(cdsPedido.FieldByName('VALOR_ACRESCIMO_COND_PGTO').Value)), cdsPedido.FieldByName('VALOR_ACRESCIMO_COND_PGTO').Value, 0);
        if cdsPedido.Active then
        begin
          if not(cdsPedido.State in dsEditModes) then
            cdsPedido.Edit;
          cdsPedido.FieldByName('VALOR_TOTAL').Value := SomaValorTabela - ValorDescontoGeral + ValorAcrescimoCondPgto;
          cdsPedido.Post;
        end;
      end;
  end;

  procedure CalculaValorAcrescimoCondPgto(cdsPedido, cdsItens: TClientDataSet);
  var
    // ValorDescontoGeral: Currency;
    SomaValorTabela: Currency;
    ValorTotal: Currency;
  begin
    if (cdsPedido <> nil) and (cdsItens <> nil) then
      if not(cdsPedido.IsEmpty or cdsItens.IsEmpty) then
      begin
        SomaValorTabela := iif(not(VarIsEmpty(cdsItens.FieldByName('SOMA_VALOR_TABELA').Value) or VarIsNull(cdsItens.FieldByName('SOMA_VALOR_TABELA')
          .Value)), cdsItens.FieldByName('SOMA_VALOR_TABELA').Value, 0);
        // ValorDescontoGeral := iif(not (VarIsEmpty(cdsPedido.FieldByName('VALOR_DESCONTO').Value) or VarIsNull(cdsPedido.FieldByName('VALOR_DESCONTO').Value)), cdsPedido.FieldByName('VALOR_DESCONTO').Value, 0);
        ValorTotal := iif(not(VarIsEmpty(cdsPedido.FieldByName('VALOR_TOTAL').Value) or VarIsNull(cdsPedido.FieldByName('VALOR_TOTAL').Value)),
          cdsPedido.FieldByName('VALOR_TOTAL').Value, 0);
        if cdsPedido.Active then
        begin
          if not(cdsPedido.State in dsEditModes) then
            cdsPedido.Edit;
          cdsPedido.FieldByName('VALOR_ACRESCIMO_COND_PGTO').Value := ValorTotal - SomaValorTabela;
          cdsPedido.Post;
        end;
      end;
  end;

  procedure CalulaValorDesconto(cdsPedido, cdsItens: TClientDataSet);
  var
    SomaValorTabela: Currency;
    ValorTotal: Currency;
    ValorAcrescimoCondPgto: Currency;
  begin
    if (cdsPedido <> nil) and (cdsItens <> nil) then
      if not(cdsPedido.IsEmpty or cdsItens.IsEmpty) then
      begin
        SomaValorTabela := iif(not(VarIsEmpty(cdsItens.FieldByName('SOMA_VALOR_TABELA').Value) or VarIsNull(cdsItens.FieldByName('SOMA_VALOR_TABELA')
          .Value)), cdsItens.FieldByName('SOMA_VALOR_TABELA').Value, 0);
        ValorTotal := iif(not(VarIsEmpty(cdsPedido.FieldByName('VALOR_TOTAL').Value) or VarIsNull(cdsPedido.FieldByName('VALOR_TOTAL').Value)),
          cdsPedido.FieldByName('VALOR_TOTAL').Value, 0);
        ValorAcrescimoCondPgto := iif(not(VarIsEmpty(cdsPedido.FieldByName('VALOR_ACRESCIMO_COND_PGTO').Value) or
          VarIsNull(cdsPedido.FieldByName('VALOR_ACRESCIMO_COND_PGTO').Value)), cdsPedido.FieldByName('VALOR_ACRESCIMO_COND_PGTO').Value, 0);
        if cdsPedido.Active then
        begin
          if not(cdsPedido.State in dsEditModes) then
            cdsPedido.Edit;
          cdsPedido.FieldByName('VALOR_DESCONTO').Value := SomaValorTabela + ValorAcrescimoCondPgto - ValorTotal;
          cdsPedido.Post;
        end;
      end;
  end;

begin

  if (not EvitaRecursividade) and (Sender.DataSet.State in dsEditModes) and (not Sender.DataSet.FieldByName('ID_ENTRADA').IsNull) then
  begin

    EvitaRecursividade := True;
    try
      if not(VarIsEmpty(Sender.Value) or VarIsNull(Sender.Value)) and VarIsNumeric(Sender.Value) then
        if Sender.FieldName = 'VALOR_DESCONTO' then
        begin
          CalculaValorAcrescimoCondPgto(cdsPedido, cdsItens);
          CalulaValorTotal(cdsPedido, cdsItens);
        end
        else if Sender.FieldName = 'VALOR_TOTAL' then
        begin
          CalculaValorAcrescimoCondPgto(cdsPedido, cdsItens);
          CalulaValorDesconto(cdsPedido, cdsItens);
        end
        else if Sender.FieldName = 'VALOR_ACRESCIMO_COND_PGTO' then
        begin
          CalulaValorDesconto(cdsPedido, cdsItens);
          CalulaValorTotal(cdsPedido, cdsItens);
        end;
    finally
      EvitaRecursividade := False;
    end;
  end;

end;

procedure UpdateItemValores(Sender: TField; var EvitaRecursividade: Boolean; QtdCasasDecimais: Integer);
resourcestring
  RS_MANDATORYFIELD_ITENS_VALORES = 'Campos obrigatórios: %s. Não foram encontrados!';
var
  CamposNecessarios: string;
  FieldMultiplicadorProdutoEmbalagem: TField;
  FieldQtd: TField;
  FieldQtdProdutoEmbalagem: TField;
  FieldValorTabela: TField;
  FieldValorTabelaProdutoEmbalagem: TField;
  FieldValorUnitario: TField;
  FieldValorUnitarioProdutoEmbalagem: TField;
  FieldPercentualDesconto: TField;
  FieldValorDesconto: TField;
  FieldValorDescontoProdutoEmbalagem: TField;
  FieldPercentualAcrescimoCondPagto: TField;
  FieldValorAcrescimoCondPagto: TField;
  FieldValorAcrescimoCondPagtoProdutoEmbalagem: TField;
  FieldValorTotal: TField;
  FieldValorTotalIPI: TField;
  FieldIPIValor: TField;

  procedure CalculaValorUnitario(CampoAlterado: TField);
  var
    tmp: Variant;
  begin
    tmp := 0;
    if CampoAlterado = FieldValorTabela then
    begin
      if (not FieldValorTabela.IsNull) and (not FieldPercentualDesconto.IsNull) then
        tmp := RoundDecimalPlaces(FieldValorTabela.AsCurrency - (FieldValorTabela.AsCurrency * FieldPercentualDesconto.AsCurrency / 100),
          QtdCasasDecimais)
      else
        tmp := 0;
      if (tmp <> FieldValorUnitario.AsCurrency) and (FieldValorTabela.AsFloat > 0) then
      begin
        FieldValorUnitario.Value := tmp;
        if FieldValorDesconto <> nil then
          FieldValorDesconto.Value := FieldValorTabela.AsCurrency - tmp;
      end;
    end
    else if CampoAlterado = FieldPercentualDesconto then
    begin
      if FieldValorDesconto <> nil then
      begin
        if FieldValorTabela.AsCurrency <> 0 then
          FieldValorDesconto.Value := RoundDecimalPlaces(FieldValorTabela.AsCurrency * FieldPercentualDesconto.AsCurrency / 100, 4);
        tmp := RoundDecimalPlaces(FieldValorTabela.AsCurrency - FieldValorDesconto.AsCurrency, QtdCasasDecimais);
      end
      else
        tmp := RoundDecimalPlaces(FieldValorTabela.AsCurrency - (FieldValorTabela.AsCurrency * FieldPercentualDesconto.AsCurrency / 100),
          QtdCasasDecimais);
      if (tmp <> FieldValorUnitario.AsCurrency) and (FieldValorTabela.AsCurrency > 0) then
      begin
        FieldValorUnitario.Value := tmp;
        if FieldMultiplicadorProdutoEmbalagem <> nil then
          FieldValorUnitarioProdutoEmbalagem.Value :=
            RoundDecimalPlaces(FieldValorUnitario.AsCurrency * FieldMultiplicadorProdutoEmbalagem.AsCurrency, QtdCasasDecimais);
      end;
    end
    else if CampoAlterado = FieldValorTotal then
    begin
      if FieldQtd.Value = 0 then
        FieldQtd.Value := 1;

      if FieldQtd.AsCurrency > 0 then
      begin
        tmp := RoundDecimalPlaces(FieldValorTotal.AsCurrency / FieldQtd.AsCurrency, QtdCasasDecimais);
        if tmp <> FieldValorUnitario.AsCurrency then
          FieldValorUnitario.Value := tmp;
        if FieldValorTotalIPI <> nil then
          FieldValorTotalIPI.Value := FieldIPIValor.AsCurrency + FieldValorTotal.AsCurrency;
      end;
    end
  end;

  procedure CalculaValorUnitarioProdutoEmbalagem(CampoAlterado: TField);
  var
    tmp: Variant;
  begin
    tmp := 0;
    if CampoAlterado = FieldValorTabelaProdutoEmbalagem then
    begin
      tmp := RoundDecimalPlaces(FieldValorTabelaProdutoEmbalagem.AsCurrency - (FieldValorTabelaProdutoEmbalagem.AsCurrency *
        FieldPercentualDesconto.AsCurrency / 100), QtdCasasDecimais);
      if (tmp <> FieldValorUnitarioProdutoEmbalagem.AsCurrency) and (FieldValorTabelaProdutoEmbalagem.AsFloat > 0) then
        FieldValorUnitarioProdutoEmbalagem.Value := tmp;
    end
    else if CampoAlterado = FieldPercentualDesconto then
    begin
      FieldValorDescontoProdutoEmbalagem.Value := RoundDecimalPlaces(FieldValorTabelaProdutoEmbalagem.AsCurrency * FieldPercentualDesconto.AsCurrency
        / 100, 4);
      tmp := RoundDecimalPlaces(FieldValorTabelaProdutoEmbalagem.AsCurrency - FieldValorDescontoProdutoEmbalagem.AsCurrency, QtdCasasDecimais);
      if (tmp <> FieldValorUnitarioProdutoEmbalagem.AsCurrency) and (FieldValorTabelaProdutoEmbalagem.AsCurrency > 0) then
        FieldValorUnitarioProdutoEmbalagem.Value := tmp;
      FieldValorUnitario.Value := RoundDecimalPlaces(FieldValorUnitarioProdutoEmbalagem.AsCurrency / FieldMultiplicadorProdutoEmbalagem.AsCurrency, QtdCasasDecimais);
    end
    else if CampoAlterado = FieldValorTotal then
    begin
      if FieldQtdProdutoEmbalagem <> nil then
      begin
        if FieldQtdProdutoEmbalagem.AsCurrency <> 0 then
          tmp := RoundDecimalPlaces(FieldValorTotal.AsCurrency / FieldQtdProdutoEmbalagem.AsCurrency, QtdCasasDecimais)
        else
          tmp := 0;
        if tmp <> FieldValorUnitarioProdutoEmbalagem.AsCurrency then
          FieldValorUnitarioProdutoEmbalagem.Value := tmp;
      end;
    end;
  end;

  procedure CalculaValorDesconto(Sender: TField);
  begin
    if FieldPercentualDesconto.Value = 0 then
    begin
      if FieldValorDesconto <> nil then
        FieldValorDesconto.Value := 0;
      if FieldValorDescontoProdutoEmbalagem <> nil then
        FieldValorDescontoProdutoEmbalagem.Value := 0;
    end
    else
    begin
      if FieldValorDesconto <> nil then
        FieldValorDesconto.Value := RoundDecimalPlaces(FieldValorTabela.AsCurrency * FieldPercentualDesconto.AsCurrency / 100, 4);
      if (FieldValorDescontoProdutoEmbalagem <> nil) and (FieldValorTabelaProdutoEmbalagem <> nil) then
        FieldValorDescontoProdutoEmbalagem.Value :=
          RoundDecimalPlaces(FieldValorTabelaProdutoEmbalagem.AsCurrency * FieldPercentualDesconto.AsCurrency / 100, 4);
    end;
  end;

  procedure CalculaPercentualDesconto(CampoAlterado: TField);
  var
    tmp: Variant;
  begin
    if CampoAlterado = FieldValorDesconto then
    begin
      FieldValorUnitario.Value := RoundDecimalPlaces(FieldValorTabela.AsCurrency - FieldValorDesconto.AsCurrency, QtdCasasDecimais);

      if FieldValorTabela.AsCurrency > 0 then
        tmp := RoundDecimalPlaces(100 - (FieldValorUnitario.AsCurrency * 100 / FieldValorTabela.AsCurrency), 4);

      if FieldMultiplicadorProdutoEmbalagem <> nil then
      begin
        FieldValorDescontoProdutoEmbalagem.Value :=
          RoundDecimalPlaces(FieldValorDesconto.AsCurrency * FieldMultiplicadorProdutoEmbalagem.AsCurrency, 4);
        FieldValorUnitarioProdutoEmbalagem.Value :=
          RoundDecimalPlaces(FieldValorTabelaProdutoEmbalagem.AsCurrency - FieldValorDescontoProdutoEmbalagem.AsCurrency, QtdCasasDecimais);
      end;
    end
    else if CampoAlterado = FieldValorDescontoProdutoEmbalagem then
    begin
      FieldValorUnitarioProdutoEmbalagem.Value := RoundDecimalPlaces(FieldValorTabelaProdutoEmbalagem.AsCurrency -
        FieldValorDescontoProdutoEmbalagem.AsCurrency, QtdCasasDecimais);

      if FieldValorTabelaProdutoEmbalagem.AsCurrency > 0 then
        tmp := RoundDecimalPlaces(100 - (FieldValorUnitarioProdutoEmbalagem.AsCurrency * 100 / FieldValorTabelaProdutoEmbalagem.AsCurrency), 4);

      FieldValorDesconto.Value := RoundDecimalPlaces(FieldValorDescontoProdutoEmbalagem.AsCurrency /
        FieldMultiplicadorProdutoEmbalagem.AsCurrency, 4);
      FieldValorUnitario.Value := RoundDecimalPlaces(FieldValorTabela.AsCurrency - FieldValorDesconto.AsCurrency, QtdCasasDecimais);
    end
    else if CampoAlterado = FieldValorUnitario then
    begin
      if (FieldValorTabela.AsCurrency > 0) and (not FieldValorUnitario.IsNull) then
        tmp := RoundDecimalPlaces((FieldValorTabela.AsCurrency - FieldValorUnitario.AsCurrency) / FieldValorTabela.AsCurrency, 4) * 100
      else
      begin
        tmp := 0;
        if FieldValorDesconto <> nil then
          FieldValorDesconto.Value := FieldValorTabela.AsCurrency - FieldValorUnitario.AsCurrency;
      end;
    end
    else if CampoAlterado = FieldValorUnitarioProdutoEmbalagem then
    begin
      if FieldValorTabelaProdutoEmbalagem.AsCurrency > 0 then
        tmp := RoundDecimalPlaces((FieldValorTabelaProdutoEmbalagem.AsCurrency - FieldValorUnitarioProdutoEmbalagem.AsCurrency) /
          FieldValorTabelaProdutoEmbalagem.AsCurrency, 4) * 100;
    end;
    if tmp <> FieldPercentualDesconto.Value then
    begin
      FieldPercentualDesconto.Value := tmp;
      CalculaValorDesconto(Sender);
    end;
  end;

  procedure CalculaValorTotal(Sender: TField);
  var
    tmp: Variant;
    FieldIPIAliquota: TField;
  begin
    if FieldValorUnitario.IsNull then
      tmp := 0
    else
      tmp := RoundDecimalPlaces((FieldQtd.AsCurrency * FieldValorUnitario.AsCurrency), 2);
    if tmp <> FieldValorTotal.AsCurrency then
      FieldValorTotal.Value := tmp;
    // ajusta o valor do IPI se o campo existir
    FieldIPIValor := FieldValorTotal.DataSet.FindField('IPI_VALOR');
    FieldIPIAliquota := FieldValorTotal.DataSet.FindField('IPI_ALIQUOTA');
    if (FieldIPIValor <> nil) and (FieldIPIAliquota <> nil) then
    begin
      if FieldIPIAliquota.IsNull then
        FieldIPIAliquota.Value := 0;
      FieldIPIValor.Value := RoundDecimalPlaces((FieldIPIAliquota.AsCurrency * FieldValorTotal.AsCurrency / 100), 2);
      if FieldValorTotalIPI <> nil then
        FieldValorTotalIPI.Value := FieldIPIValor.AsCurrency + FieldValorTotal.AsCurrency;
    end;
  end;

begin
  if (not EvitaRecursividade) and (Sender.DataSet.State in dsEditModes) and (not Sender.DataSet.FieldByName('ID_ITEM').IsNull) then
  begin
    EvitaRecursividade := True;
    try
      FieldMultiplicadorProdutoEmbalagem := Sender.DataSet.FindField('MULTIPLICADOR_PRODUTO_EMBALAGEM');
      FieldQtdProdutoEmbalagem := Sender.DataSet.FindField('QTD_PRODUTO_EMBALAGEM');
      FieldValorUnitarioProdutoEmbalagem := Sender.DataSet.FindField('VALOR_UNITARIO_PRODUTO_EMBALAG');
      FieldValorTabelaProdutoEmbalagem := Sender.DataSet.FindField('VALOR_TABELA_PRODUTO_EMBALAGEM');
      FieldValorDescontoProdutoEmbalagem := Sender.DataSet.FindField('VALOR_DESCONTO_PRODUTO_EMBALAGE');
      FieldValorAcrescimoCondPagtoProdutoEmbalagem := Sender.DataSet.FindField('VALOR_ACRESC_COND_PGTO_PROD_EMB');
      if (FieldMultiplicadorProdutoEmbalagem <> nil) and FieldMultiplicadorProdutoEmbalagem.IsNull then
        FieldMultiplicadorProdutoEmbalagem.Value := 0;
      if (FieldQtdProdutoEmbalagem <> nil) and FieldQtdProdutoEmbalagem.IsNull then
        FieldQtdProdutoEmbalagem.Value := 0;
      if (FieldValorUnitarioProdutoEmbalagem <> nil) and FieldValorUnitarioProdutoEmbalagem.IsNull then
        FieldValorUnitarioProdutoEmbalagem.Value := 0;
      if (FieldValorTabelaProdutoEmbalagem <> nil) and FieldValorTabelaProdutoEmbalagem.IsNull then
        FieldValorTabelaProdutoEmbalagem.Value := 0;
      if (FieldValorDescontoProdutoEmbalagem <> nil) and FieldValorDescontoProdutoEmbalagem.IsNull then
        FieldValorDescontoProdutoEmbalagem.Value := 0;
      if (FieldValorAcrescimoCondPagtoProdutoEmbalagem <> nil) and FieldValorAcrescimoCondPagtoProdutoEmbalagem.IsNull then
        FieldValorAcrescimoCondPagtoProdutoEmbalagem.Value := 0;

      FieldQtd := Sender.DataSet.FindField('QTD');
      FieldValorTabela := Sender.DataSet.FindField('VALOR_TABELA');
      FieldValorUnitario := Sender.DataSet.FindField('VALOR_UNITARIO');
      FieldPercentualDesconto := Sender.DataSet.FindField('PERCENTUAL_DESCONTO');
      FieldValorDesconto := Sender.DataSet.FindField('VALOR_DESCONTO');
      FieldPercentualAcrescimoCondPagto := Sender.DataSet.FindField('PERCENTUAL_ACRESCIMO_COND_PGTO');
      FieldValorAcrescimoCondPagto := Sender.DataSet.FindField('ACRESCIMO_COND_PGTO');
      FieldValorTotal := Sender.DataSet.FindField('VALOR_TOTAL');
      FieldValorTotalIPI := Sender.DataSet.FindField('VALOR_TOTAL_IPI');
      FieldIPIValor := FieldValorTotal.DataSet.FindField('IPI_VALOR');

      CamposNecessarios := '';
      if FieldQtd = nil then
        CamposNecessarios := CamposNecessarios + 'QTD, ';
      if FieldValorTabela = nil then
        CamposNecessarios := CamposNecessarios + 'VALOR_TABELA, ';
      if FieldValorUnitario = nil then
        CamposNecessarios := CamposNecessarios + 'VALOR_UNITARIO, ';
      if FieldPercentualDesconto = nil then
        CamposNecessarios := CamposNecessarios + 'PERCENTUAL_DESCONTO, ';
      if FieldValorDesconto = nil then
        CamposNecessarios := CamposNecessarios + 'VALOR_DESCONTO, ';
      if FieldPercentualAcrescimoCondPagto = nil then
        CamposNecessarios := CamposNecessarios + 'PERCENTUAL_ACRESCIMO_COND_PGTO, ';
      if FieldValorAcrescimoCondPagto = nil then
        CamposNecessarios := CamposNecessarios + 'ACRESCIMO_COND_PGTO, ';
      if FieldValorTotal = nil then
        CamposNecessarios := CamposNecessarios + 'VALOR_TOTAL, ';
      if FieldValorTotalIPI = nil then
        CamposNecessarios := CamposNecessarios + 'VALOR_TOTAL_IPI, ';

      if Sender = FieldMultiplicadorProdutoEmbalagem then
        raise Exception.Create('BUGCHECK - Multiplicador da PRODUTO_EMBALAGEM não deve ser alterado pelo usuário!')
      else if Sender = FieldQtd then
      begin
        if (FieldQtdProdutoEmbalagem <> nil) and (FieldMultiplicadorProdutoEmbalagem <> nil) and (FieldMultiplicadorProdutoEmbalagem.AsCurrency > 0)
        then
          FieldQtdProdutoEmbalagem.Value := RoundDecimalPlaces(FieldQtd.AsCurrency / FieldMultiplicadorProdutoEmbalagem.AsCurrency, 3);
      end
      else if Sender = FieldQtdProdutoEmbalagem then
        FieldQtd.Value := RoundDecimalPlaces(FieldQtdProdutoEmbalagem.AsCurrency * FieldMultiplicadorProdutoEmbalagem.AsCurrency, 3)
      else if Sender = FieldValorTabela then
      begin
        CalculaValorUnitario(Sender);
        if (FieldValorTabelaProdutoEmbalagem <> nil) and (FieldMultiplicadorProdutoEmbalagem <> nil) then
        begin
          FieldValorTabelaProdutoEmbalagem.Value := FieldValorTabela.AsCurrency * FieldMultiplicadorProdutoEmbalagem.AsCurrency;
          CalculaValorUnitarioProdutoEmbalagem(FieldValorTabelaProdutoEmbalagem);
        end;
      end
      else if Sender = FieldValorTabelaProdutoEmbalagem then
      begin
        CalculaValorUnitarioProdutoEmbalagem(Sender);
        FieldValorTabela.Value := FieldValorTabelaProdutoEmbalagem.AsCurrency / FieldMultiplicadorProdutoEmbalagem.AsCurrency;
        CalculaValorUnitario(FieldValorTabela);
      end
      else if Sender = FieldValorUnitario then
      begin
        CalculaPercentualDesconto(Sender);
        if (FieldValorUnitarioProdutoEmbalagem <> nil) and (FieldMultiplicadorProdutoEmbalagem <> nil) then
          FieldValorUnitarioProdutoEmbalagem.Value := FieldValorUnitario.AsCurrency * FieldMultiplicadorProdutoEmbalagem.AsCurrency;
      end
      else if Sender = FieldValorUnitarioProdutoEmbalagem then
      begin
        CalculaPercentualDesconto(Sender);
        FieldValorUnitario.Value := FieldValorUnitarioProdutoEmbalagem.AsCurrency / FieldMultiplicadorProdutoEmbalagem.AsCurrency;
      end
      else if Sender = FieldPercentualDesconto then
      begin
        CalculaValorUnitario(Sender);
        CalculaValorDesconto(Sender);
      end
      else if (Sender = FieldValorDesconto) or (Sender = FieldValorDescontoProdutoEmbalagem) then
      begin
        CalculaPercentualDesconto(Sender);
        CalculaValorUnitario(FieldPercentualDesconto);
      end
      else if Sender = FieldPercentualAcrescimoCondPagto then
        raise Exception.Create('BUGCHECK - Percentual de acréscimo da condição de pagamento não deve ser alterado pelo usuário!')
      else if (Sender = FieldValorAcrescimoCondPagto) or (Sender = FieldValorAcrescimoCondPagtoProdutoEmbalagem) then
        raise Exception.Create('BUGCHECK - Valor de acréscimo da condição de pagamento não deve ser alterado pelo usuário!')
      else if Sender = FieldValorTotal then
      begin
        CalculaValorUnitario(Sender);
        CalculaValorUnitarioProdutoEmbalagem(Sender);
        CalculaPercentualDesconto(FieldValorUnitario);
      end;
      if Sender <> FieldValorTotal then
        CalculaValorTotal(Sender);
    finally
      EvitaRecursividade := False;
    end;
  end;
end;

procedure TransNegUpdateValor(cdsAux: TClientDataSet; CampoRef: TField; Valor: Variant; var EvitaRecursividade: Boolean);
var
  ValorOrigonal: Variant;
  ValorAcrescimoCondPgto: Variant;
  ValorDesconto: Variant;
begin
  if not(CampoRef.DataSet.IsEmpty or EvitaRecursividade) and (CampoRef.DataSet.State in dsEditModes) then
  begin
    try
      EvitaRecursividade := True;
      if (Valor <> CampoRef.Value) or ((CampoRef.FieldName = 'VALOR_ACRESCIMO_COND_PGTO') and (Valor = 0)) then
      begin
        ValorOrigonal := CampoRef.DataSet.FieldByName('VALOR_ORIGINAL').Value;
        ValorAcrescimoCondPgto := CampoRef.DataSet.FieldByName('VALOR_ACRESCIMO_COND_PGTO').Value;
        ValorDesconto := CampoRef.DataSet.FieldByName('VALOR_DESCONTO').Value;
        Valor := iif(not(VarIsEmpty(Valor) or VarIsNull(Valor)), Valor, 0);
        ValorOrigonal := iif(not(VarIsEmpty(ValorOrigonal) or VarIsNull(ValorOrigonal)), ValorOrigonal, 0);
        ValorAcrescimoCondPgto := iif(not(VarIsEmpty(ValorAcrescimoCondPgto) or VarIsNull(ValorAcrescimoCondPgto)), ValorAcrescimoCondPgto, 0);
        ValorDesconto := iif(not(VarIsEmpty(ValorDesconto) or VarIsNull(ValorDesconto)), ValorDesconto, 0);
        if CampoRef.FieldName <> 'VALOR_ACRESCIMO_COND_PGTO' then
          CampoRef.DataSet.FieldByName(CampoRef.FieldName).Value := Valor;
        if CampoRef.FieldName = 'VALOR_ITENS' then
          cdsUpdateField(cdsAux, 'VALOR_DESCONTO', (ValorOrigonal + ValorAcrescimoCondPgto - Valor))
        else if CampoRef.FieldName = 'VALOR_DESCONTO' then
        begin
          CampoRef.DataSet.FieldByName('VALOR_ITENS').Value := ValorOrigonal + ValorAcrescimoCondPgto - Valor;
          cdsUpdateField(cdsAux, 'VALOR_DESCONTO', Valor);
        end
        else if CampoRef.FieldName = 'VALOR_ACRESCIMO_COND_PGTO' then
          CampoRef.DataSet.FieldByName('VALOR_ITENS').Value := ValorOrigonal - ValorDesconto + CampoRef.Value;
      end;
    finally
      EvitaRecursividade := False;
    end;
  end;
end;

procedure cdsUpdateField(cds: TClientDataSet; Campo: string; Valor: Variant);
begin
  if not(cds.State in dsEditModes) then
    cds.Edit;
  cds.FieldByName(Campo).Value := Valor;
  cds.Post;
end;

procedure CreateField(AMemData: TDataSet; pName: string; pDataType: TFieldType; pSize: Integer; pRequired: Boolean);
begin
  if (AMemData <> nil) and (pName <> '') then
  begin
    with AMemData.FieldDefs.AddFieldDef do
    begin
      Name := pName;
      DataType := pDataType;
      Size := pSize;
      Required := pRequired;
      CreateField(AMemData);
    end;
  end;
end;

procedure CreateField(AMemData: TDataSet; pName: string; pDisplayName: string; pDataType: TFieldType; pSize: Integer; pRequired: Boolean);
begin
  if (AMemData <> nil) and (pName <> '') then
  begin
    CreateField(AMemData, pName, pDataType, pSize, pRequired);
    AMemData.FieldByName(pName).DisplayLabel := pDisplayName;
  end;
end;

procedure CreateChildField(AField: TFieldDef; pName: string; pDataType: TFieldType; pSize: Integer = 0; pRequired: Boolean = False);
begin
  with AField.AddChild do
  begin
    Name := pName;
    DataType := pDataType;
    Size := pSize;
    Required := pRequired;
  end;
end;

initialization

FUsable := True;

end.

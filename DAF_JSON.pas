unit DAF_JSON;

interface

uses
  DB, DBClient, Classes;

function RemoveReservedChar(s:WideString): WideString;

type
  TDAFJSON = class
  private
    FFieldSise: Integer;
    //Mormot
    procedure ProcessJson(vJson: Variant; cds: TClientDataSet; FieldDef: TFieldDef = nil; Value: Boolean = False);
    procedure FillCDSFromJson(vJson: Variant; cds: TClientDataSet);
  public
    constructor Create;
    property FieldSise: Integer read FFieldSise write FFieldSise;
    class function GetFieldDetail(Source: TDataSet; FieldName: string): TField;

    //Mormot
    class function CreateCDSFromJson(sJson: string; cdsName: string = 'MainDataset'): TClientDataSet;
    class function GetPropertyFromJSON(Json: Variant; Name: string): Variant;
    class procedure SetPropertyToJson(var Json: Variant; const Name: string; const Value: Variant);

    class function String2JSON(Source: string; LineBreak: string = '<br />'): string;
  end;

implementation

uses
  StrUtils, SysUtils, SynCommons, Variants;

procedure CreateFieldDef(AMemData: TDataSet; pName: string; pDataType: TFieldType; pSize: Integer = 0; pRequired: Boolean = False); overload;
begin
  if (AMemData <> nil) and (pName <> '') then
  begin
    with AMemData.FieldDefs.AddFieldDef do
    begin
      Name := pName;
      if pDataType = ftInteger then
        DataType := DB.ftCurrency
      else
        DataType := pDataType;
      Size := pSize;
      Required := pRequired;
    end;
  end;
end;

procedure CreateField(AMemData: TDataSet; pName: string; pDataType: TFieldType; pSize: Integer = 0; pRequired: Boolean = False); overload;
begin
  if (AMemData <> nil) and (pName <> '') then
  begin
    with AMemData.FieldDefs.AddFieldDef do
    begin
      Name := pName;
      if pDataType = ftInteger then
        DataType := DB.ftCurrency
      else
        DataType := pDataType;
      Size := pSize;
      Required := pRequired;
      CreateField(AMemData);
    end;
  end;
end;

procedure CreateField(AMemData: TDataSet; pName: string; pDisplayName: string; pDataType: TFieldType; pSize: Integer = 0; pRequired: Boolean = False); overload;
begin
  if (AMemData <> nil) and (pName <> '') then
  begin
    CreateField(AMemData, pName, pDataType, pSize, pRequired);
    AMemData.FieldByName(pName).DisplayLabel := pDisplayName;
  end;
end;

procedure CreateFieldChildDef(AField: TFieldDef; pName: string; pDataType: TFieldType; pSize: Integer = 0; pRequired: Boolean = False);
begin
  with AField.AddChild do
  begin
    Name := pName;
    if pDataType = ftInteger then
      DataType := DB.ftCurrency
    else
      DataType := pDataType;
    Size := pSize;
    Required := pRequired;
  end;
end;

{ TDAFJSON }

constructor TDAFJSON.Create;
begin
  FFieldSise := 32000;
end;

procedure TDAFJSON.FillCDSFromJson(vJson: Variant; cds: TClientDataSet);
var
  dvdJson: TDocVariantData;
  I: Integer;
  V: Variant;
  cdsNested: TClientDataSet;
  FieldName: string;
  Field: TField;
begin
  dvdJson := TDocVariantData(vJson);
  if dvdJson.Kind = dvArray then
  begin
    V := _JsonFast(UTF8Encode(VarToStr(dvdJson.Values[0])));
    if TDocVariantData(V).Kind = dvUndefined then
    begin
      for I := 0 to dvdJson.Count - 1 do
      begin
        if cds.IsEmpty then
          cds.Insert
        else
          cds.Append;

        Field := cds.FindField('Value');
        if Field <> nil then
          Field.Value := dvdJson.Values[I];

        cds.Post;
      end;
    end
    else
    begin
      for I := 0 to dvdJson.Count - 1 do
      begin
        FillCDSFromJson(dvdJson.Values[I], cds);
      end;
    end;
  end
  else if dvdJson.Kind = dvObject then
  begin
    if cds.IsEmpty then
      cds.Insert
    else
      cds.Append;
    for I := 0 to dvdJson.Count - 1 do
    begin
      FieldName := UTF8ToString(dvdJson.Names[I]);
      V := _JsonFast(UTF8Encode(VarToStr(dvdJson.Values[I])));
      try
        if TDocVariantData(V).Kind <> dvUndefined then
        begin
          if not((TDocVariantData(V).Kind = dvArray) and (TDocVariantData(V).Count = 0)) then
          begin
            cdsNested := TClientDataSet(TDataSetField(cds.FieldByName(FieldName)).NestedDataSet);
            FillCDSFromJson(dvdJson.Values[I], TClientDataSet(cdsNested));
          end;
        end
        else
        begin
          Field := cds.FindField(FieldName);
          if Field <> nil then
            Field.Value := dvdJson.Values[I];
        end;
      finally
        TDocVariantData(V).Clear;
      end;
    end;
    cds.Post;
  end;
end;

class function TDAFJSON.CreateCDSFromJson(sJson: string; cdsName: string): TClientDataSet;
var
  DAFJson: TDAFJSON;
  tmpstr: RawUTF8;
  Json: Variant;
begin
  DAFJson := TDAFJSON.Create;
  try
    Result := TClientDataSet.Create(nil);
    Result.Name := cdsName;
    if System.SysUtils.Trim(sJson) <> '' then
    begin
{$IFDEF UNICODE}
      tmpstr := UTF8Encode(sJson);
{$ELSE}
      tmpstr := sJson;
{$ENDIF}
      Json := _JsonFast(tmpstr);
      try
        DAFJson.ProcessJson(Json, Result);
        Result.CreateDataSet;
        DAFJson.FillCDSFromJson(Json, Result);
      finally
        TDocVariantData(Json).Clear;
      end;
    end;
  finally
    DAFJson.Free;
  end;
end;

class function TDAFJSON.GetFieldDetail(Source: TDataSet; FieldName: string): TField;
begin
  Result := Source.FindField(FieldName);
  if Result = nil then
    raise Exception.Create('Não foi encontrado o field ' + FieldName);

  if Result.DataType <> ftDataSet then
    raise Exception.Create('O Field ' + FieldName + ' não é um detail!');
end;

class function TDAFJSON.GetPropertyFromJSON(Json: Variant; Name: string): Variant;
begin
  Result := TdocVariantData(Json).GetValueOrNull(StringToUTF8(Name));
end;

procedure TDAFJSON.ProcessJson(vJson: Variant; cds: TClientDataSet; FieldDef: TFieldDef; Value: Boolean);
var
  dvdJson: TDocVariantData;
  I: Integer;
  FieldValue, V: Variant;
  FieldName: string;
  FieldType: TFieldType;
  FieldSize: Integer;

  procedure CreateField(vJson2: Variant; cds: TClientDataSet; FieldDef: TFieldDef);
  var
    dvdJson2: TDocVariantData;
  begin
    dvdJson2 := TDocVariantData(vJson2);
    if dvdJson2.Kind = dvUndefined then
    begin
      if FieldDef = nil then
      begin
        if (cds.FieldDefs.IndexOf(FieldName) = -1) then
          CreateFieldDef(cds, FieldName, FieldType, FieldSize);
      end
      else
      begin
        if (FieldDef.ChildDefs.IndexOf(FieldName) = -1) then
          CreateFieldChildDef(FieldDef, FieldName, FieldType, FieldSize);
      end;
    end
    else
    begin
      if FieldDef <> nil then
      begin
        if (FieldDef.ChildDefs.IndexOf(FieldName) = -1) then
          CreateFieldChildDef(FieldDef, FieldName, ftDataSet);

        ProcessJson(V, cds, FieldDef.ChildDefs.Find(FieldName));
      end
      else
      begin
        if not((TDocVariantData(V).Kind = dvArray) and (TDocVariantData(V).Count = 0)) then
        begin
          if (cds.FieldDefs.IndexOf(FieldName) = -1) then
            CreateFieldDef(cds, FieldName, ftDataSet);

          ProcessJson(V, cds, cds.FieldDefs.Find(FieldName));
        end;
      end;
    end;
  end;
begin
  dvdJson := TDocVariantData(vJson);
  if dvdJson.Kind = dvArray then
  begin
    FieldName := 'Value';
    FieldValue := dvdJson.Values[0];
    V := _JsonFast(UTF8Encode(VarToStr(FieldValue)));
    if TDocVariantData(V).Kind = dvUndefined then
    begin
      FieldType := ftString;
      FieldSize := 32000;
      CreateField(V, cds, FieldDef)
    end
    else
    begin
      for I := 0 to dvdJson.Count - 1 do
      begin
        ProcessJson(dvdJson.Values[I], cds, FieldDef);
      end;
    end;
  end
  else if dvdJson.Kind = dvObject then
  begin
    for I := 0 to dvdJson.Count - 1 do
    begin
      FieldName := UTF8ToString(dvdJson.Names[I]);
      FieldValue := dvdJson.Values[I];
      if not Value then
      begin
        FieldSize := 0;
        case VarType(FieldValue) and VarTypeMask of
          varEmpty:
          begin
            FieldType := ftString;
            FieldSize := 32000;
          end;
          varNull:
          begin
            FieldType := ftString;
            FieldSize := 32000;
          end;
          varSmallInt: FieldType := ftSmallint;
          varInteger: FieldType := ftInteger;
          varSingle: FieldType := ftInteger;
          varDouble: FieldType := ftFloat;
          varCurrency: FieldType := ftFloat;
          varDate: FieldType := ftDateTime;
          varOleStr:
          begin
            FieldType := ftString;
            FieldSize := 32000;
          end;
          varDispatch:
          begin
            FieldType := ftString;
            FieldSize := 32000;
          end;
          varError:
          begin
            FieldType := ftString;
            FieldSize := 32000;
          end;
          varBoolean: FieldType := ftBoolean;
          varVariant:
          begin
            FieldType := ftString;
            FieldSize := 32000;
          end;
          varUnknown:
          begin
            FieldType := ftString;
            FieldSize := 32000;
          end;
          varByte: FieldType := ftBytes;
          varWord: FieldType := ftWord;
          varLongWord: FieldType := ftInteger;
          varInt64: FieldType := ftLargeint;
          varStrArg:
          begin
            FieldType := ftString;
            FieldSize := 32000;
          end;
          varString:
          begin
            FieldType := ftString;
            FieldSize := 32000;
          end;
          varAny:
          begin
            FieldType := ftString;
            FieldSize := 32000;
          end;
          varTypeMask:
          begin
            FieldType := ftString;
            FieldSize := 32000;
          end;
        end;
      end;

      V := _JsonFast(UTF8Encode(VarToStr(FieldValue)));
      try
        if TDocVariantData(V).Kind = dvUndefined then
          CreateField(V, cds, FieldDef)
        else
          CreateField(dvdJson.Values[I], cds, FieldDef);
      finally
        TDocVariantData(V).Clear;
      end;
    end;
  end;
end;

class procedure TDAFJSON.SetPropertyToJson(var Json: Variant; const Name: string; const Value: Variant);
begin
  TDocVariantData(Json).AddValue(StringToUTF8(Name), Value);
end;

class function TDAFJSON.String2JSON(Source, LineBreak: string): string;
begin
  // Stuffing para a string passar como um JSON
  Result := Source;
  Result := StringReplace(Result, #10, '', [rfReplaceAll]);
  Result := StringReplace(Result, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #9, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, LineBreak, [rfReplaceAll]);
end;

function RemoveReservedChar(s: WideString): WideString;
begin
  Result :=
    AnsiReplaceStr(AnsiReplaceStr(AnsiReplaceStr(AnsiReplaceStr(AnsiReplaceStr(
    AnsiReplaceStr(AnsiReplaceStr(AnsiReplaceStr(AnsiReplaceStr(AnsiReplaceStr(
    AnsiReplaceStr(AnsiReplaceStr(AnsiReplaceStr(AnsiReplaceStr(AnsiReplaceStr(
    AnsiReplaceStr(AnsiReplaceStr(s, #0, ''), #8, ''), #9, ''), #10, ''),
    #12, ''), #13, ''), #32, ''), '"', ''), '.', ''), '[', ''), ']', ''),
    '{', ''), '}', ''), '(', ''), ')', ''), ',', ''), ':', '');
end;

end.


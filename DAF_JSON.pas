unit DAF_JSON;

interface

uses
  superobject, DB, DBClient, Classes;

function RemoveReservedChar(s:WideString): WideString;

type
  TDAFJSON = class
  private
    FFieldSise: Integer;
    procedure ProcessJsonSO(var Result: TClientDataSet; joJSON: ISuperObject; FieldChild: TFieldDef = nil); overload;
    procedure FillCDSFromJsonSO(const joJSON: ISuperObject; var cds: TClientDataSet); overload;
    //Mormot
    procedure ProcessJson(vJson: Variant; cds: TClientDataSet; FieldDef: TFieldDef = nil; Value: Boolean = False);
    procedure FillCDSFromJson(vJson: Variant; cds: TClientDataSet);
  public
    constructor Create;
    property FieldSise: Integer read FFieldSise write FFieldSise;
    class function CreateCDSFromJsonSO(JSON: string; FieldChild: TFieldDef = nil; cdsName: string = 'MainDataset'): TClientDataSet;
    class function GetFieldDetail(Source: TDataSet; FieldName: string): TField;
    class function GetObjectJSON(SuperObject: ISuperObject; Name: WideString): ISuperObject;

    //Mormot
    class function CreateCDSFromJson(sJson: string; AOwner: TComponent = nil; cdsName: string = 'MainDataset'): TClientDataSet;


    class procedure SetJson(SuperObject: ISuperObject; Name: WideString; Value: Boolean); overload;
    class procedure SetJson(SuperObject: ISuperObject; Name: WideString; Value: Double); overload;
    class procedure SetJson(SuperObject: ISuperObject; Name: WideString; Value: Int64); overload;
    class procedure SetJson(SuperObject: ISuperObject; Name: WideString; Value: ISuperObject); overload;
    class procedure SetJson(SuperObject: ISuperObject; Name: WideString; Value: WideString); overload;
  end;

implementation

uses
  StrUtils, SysUtils, SynCommons, Variants, DypeSysUtils;

procedure CreateFieldDef(AMemData: TDataSet; pName: string; pDataType: TFieldType; pSize: Integer = 0; pRequired: Boolean = False); overload;
begin
  if (AMemData <> nil) and (pName <> '') then
  begin
    with AMemData.FieldDefs.AddFieldDef do
    begin
      Name := pName;
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
begin
  dvdJson := TDocVariantData(vJson);
  if dvdJson.Kind = dvArray then
  begin
    for I := 0 to dvdJson.Count - 1 do
    begin
      FillCDSFromJson(dvdJson.Values[I], cds);
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
        if cds.FindField(FieldName) <> nil then
          cds.FieldByName(FieldName).Value := dvdJson.Values[I];
      end;
    end;
    cds.Post;
  end;
end;

procedure TDAFJSON.FillCDSFromJsonSO(const joJSON: ISuperObject; var cds: TClientDataSet);
var
  ArrayItem: TSuperAvlEntry;
  ArrayItens: ISuperObject;
  I: Integer;
  FieldName: string;
  FieldValue: string;
  cdsNested: TDataSet;
  Item: TSuperAvlEntry;
begin
  if joJSON.IsType(stObject) then
  begin
    cds.Append;
    for Item in joJSON.AsObject do
    begin
      if Item.Value.IsType(stArray) then
      begin
        cdsNested := TDataSetField(cds.FieldByName(Item.Name)).NestedDataSet;
        FillCDSFromJsonSO(Item.Value, TClientDataSet(cdsNested));
      end
      else if Item.Value.IsType(stObject) then
      begin
        cdsNested := TDataSetField(cds.FieldByName(Item.Name)).NestedDataSet;
        FillCDSFromJsonSO(Item.Value, TClientDataSet(cdsNested));
      end
      else
      begin
        if cds.FindField(Item.Name) <> nil then // todo - verificar pq a venda com chave 43160502308702000405650010000002371000002370 dá exception de field tef_bandeira not found
          cds.FieldByName(Item.Name).AsString := Item.Value.AsString;
      end;
    end;
    cds.Post;
  end
  else if joJSON.IsType(stArray) then
  begin
    for I := 0 to joJSON.AsArray.Length - 1 do
    begin
      ArrayItens := joJSON.AsArray[I];
      cds.Append;
      for ArrayItem in ArrayItens.AsObject do
      begin
        FieldName := ArrayItem.Name;
        FieldValue := ArrayItem.Value.AsString;
        if ArrayItem.Value.IsType(stObject) then
        begin
          cdsNested := TDataSetField(cds.FieldByName(FieldName)).NestedDataSet;
          FillCDSFromJsonSO(ArrayItem.Value, TClientDataSet(cdsNested));
        end
        else if ArrayItem.Value.IsType(stArray) then
        begin
          cdsNested := TDataSetField(cds.FieldByName(FieldName)).NestedDataSet;
          FillCDSFromJsonSO(ArrayItem.Value, TClientDataSet(cdsNested));
        end
        else
        begin
          cds.FieldByName(FieldName).AsString := FieldValue;
        end;
      end;
      cds.Post;
    end;
  end;
end;

class function TDAFJSON.CreateCDSFromJson(sJson: string; AOwner: TComponent; cdsName: string): TClientDataSet;
var
  DAFJson: TDAFJSON;
begin
  DAFJson := TDAFJSON.Create;
  try
    Result := TClientDataSet.Create(AOwner);
    Result.Name := GenerateUniqueName(AOwner, cdsName);
    DAFJson.ProcessJson(_Json(UTF8Encode(sJson)), Result);
    Result.CreateDataSet;
    DAFJson.FillCDSFromJson(_Json(UTF8Encode(sJson)), Result);
  finally
    DAFJson.Free;
  end;
end;

class function TDAFJSON.CreateCDSFromJsonSO(JSON: string; FieldChild: TFieldDef; cdsName: string): TClientDataSet;
var
  oJSON: ISuperObject;
  DAFJson: TDAFJSON;
begin
  DAFJson := TDAFJSON.Create;
  try
    Result := TClientDataSet.Create(nil);
    Result.Name := cdsName;

    oJSON := SO(JSON);
    DAFJson.ProcessJsonSO(Result, oJSON, FieldChild);
    if Result.FieldDefs.Count > 0 then
    begin
      Result.CreateDataSet;
      DAFJson.FillCDSFromJsonSO(oJSON, Result);
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

class function TDAFJSON.GetObjectJSON(SuperObject: ISuperObject; Name: WideString): ISuperObject;
var
  Item: TSuperObjectIter;
begin
  Result := nil;//TSuperObject.Create(stNull);
  Name := RemoveReservedChar(Name);
  try
    if ObjectFindFirst(SuperObject, Item) then
    repeat
      if Item.key = Name then
      begin
        Result := Item.val;
        Break;
      end;
    until not ObjectFindNext(Item);
  finally
    ObjectFindClose(Item);
  end;
end;

procedure TDAFJSON.ProcessJson(vJson: Variant; cds: TClientDataSet; FieldDef: TFieldDef; Value: Boolean);
var
  dvdJson: TDocVariantData;
  I: Integer;
  V: Variant;
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
    for I := 0 to dvdJson.Count - 1 do
    begin
      ProcessJson(dvdJson.Values[I], cds, FieldDef);
    end;
  end
  else if dvdJson.Kind = dvObject then
  begin
    for I := 0 to dvdJson.Count - 1 do
    begin
      FieldName := UTF8ToString(dvdJson.Names[I]);
      if not Value then
      begin
        FieldSize := 0;
        case VarType(dvdJson.Values[I]) and VarTypeMask of
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

      V := _JsonFast(UTF8Encode(VarToStr(dvdJson.Values[I])));
      if TDocVariantData(V).Kind = dvUndefined then
        CreateField(V, cds, FieldDef)
      else
        CreateField(dvdJson.Values[I], cds, FieldDef);
    end;
  end;
end;

procedure TDAFJSON.ProcessJsonSO(var Result: TClientDataSet; joJSON: ISuperObject; FieldChild: TFieldDef);
  procedure CreateFieldsSO(ArrayItem: TSuperAvlEntry; Result: TClientDataSet; FieldChild: TFieldDef);
  var
    FieldName, FieldValue: string;
  begin
    FieldName := ArrayItem.Name;
    FieldValue := ArrayItem.Value.AsString;
    if ArrayItem.Value.IsType(stArray) then
    begin
      if FieldChild <> nil then
      begin
        if (FieldChild.ChildDefs.IndexOf(FieldName) = -1) then
          CreateFieldChildDef(FieldChild, FieldName, ftDataSet);

        ProcessJsonSO(Result, ArrayItem.Value, FieldChild.ChildDefs.Find(FieldName));
      end
      else
      begin
        if (Result.FieldDefs.IndexOf(FieldName) = -1) then
          CreateFieldDef(Result, FieldName, ftDataSet);

        ProcessJsonSO(Result, ArrayItem.Value, Result.FieldDefs.Find(FieldName));
      end;
    end
    else if ArrayItem.Value.IsType(stObject) then
    begin
      if FieldChild <> nil then
      begin
        if (FieldChild.ChildDefs.IndexOf(FieldName) = -1) then
          CreateFieldChildDef(FieldChild, FieldName, ftDataSet);

        ProcessJsonSO(Result, ArrayItem.Value, FieldChild.ChildDefs.Find(FieldName));
      end
      else
      begin
        if (Result.FieldDefs.IndexOf(FieldName) = -1) then
          CreateFieldDef(Result, FieldName, ftDataSet);

        ProcessJsonSO(Result, ArrayItem.Value, Result.FieldDefs.Find(FieldName));
      end;
    end
    else
    begin
      if FieldChild = nil then
      begin
        if (Result.FieldDefs.IndexOf(FieldName) = -1) then
          CreateFieldDef(Result, FieldName, ftString, FieldSise);
      end
      else
      begin
        if (FieldChild.ChildDefs.IndexOf(FieldName) = -1) then
          CreateFieldChildDef(FieldChild, FieldName, ftString, FieldSise);
      end;
    end;
  end;
var
  ArrayItem: TSuperAvlEntry;
  ArrayItens: ISuperObject;
  I: Integer;
begin
  if joJSON.IsType(stObject) then
  begin
    for ArrayItem in joJSON.AsObject do
    begin
      CreateFieldsSO(ArrayItem, Result, FieldChild);
    end;
  end
  else if joJSON.IsType(stArray) then
  begin
    for I := 0 to joJSON.AsArray.Length - 1 do
    begin
      ArrayItens := joJSON.AsArray[I];
      for ArrayItem in ArrayItens.AsObject do
      begin
        CreateFieldsSO(ArrayItem, Result, FieldChild);
      end;
    end;
  end;
end;

class procedure TDAFJSON.SetJson(SuperObject: ISuperObject; Name: WideString;
  Value: Boolean);
begin
  SuperObject.B[RemoveReservedChar(Name)] := Value;
end;

class procedure TDAFJSON.SetJson(SuperObject: ISuperObject; Name: WideString;
  Value: Double);
begin
  SuperObject.D[RemoveReservedChar(Name)] := Value;
end;

class procedure TDAFJSON.SetJson(SuperObject: ISuperObject; Name: WideString;
  Value: Int64);
begin
  SuperObject.I[RemoveReservedChar(Name)] := Value;
end;

class procedure TDAFJSON.SetJson(SuperObject: ISuperObject; Name: WideString;
  Value: ISuperObject);
begin
  SuperObject.N[RemoveReservedChar(Name)] := Value;
end;

class procedure TDAFJSON.SetJson(SuperObject: ISuperObject; Name, Value: WideString);
begin
  SuperObject.S[RemoveReservedChar(Name)] := Value;
end;

function RemoveReservedChar(s: WideString): WideString;
begin
  Result :=
    AnsiReplaceStr(
      AnsiReplaceStr(
        AnsiReplaceStr(
          AnsiReplaceStr(
            AnsiReplaceStr(
              AnsiReplaceStr(
                AnsiReplaceStr(
                  AnsiReplaceStr(
                    AnsiReplaceStr(
                      AnsiReplaceStr(
                        AnsiReplaceStr(
                          AnsiReplaceStr(
                            AnsiReplaceStr(
                              AnsiReplaceStr(
                                AnsiReplaceStr(
                                  AnsiReplaceStr(
                                    AnsiReplaceStr(
                                      s, #0, ''
                                    ), #8, ''
                                  ), #9, ''
                                ), #10, ''
                              ), #12, ''
                            ), #13, ''
                          ), #32, ''
                        ), '"', ''
                      ), '.', ''
                    ), '[', ''
                  ), ']', ''
                ), '{', ''
              ), '}', ''
            ), '(', ''
          ), ')', ''
        ), ',', ''
      ), ':', ''
    );
end;

end.


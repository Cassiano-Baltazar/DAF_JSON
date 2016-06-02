unit DAF_JSON;

interface

uses
  superobject, DB, DBClient, Classes;

function RemoveReservedChar(s:WideString): WideString;

type
  TDAFJSON = class
  private
    FFieldSise: Integer;
    procedure ProcessJsonSO(Result: TClientDataSet; joJSON: ISuperObject; FieldChild: TFieldDef = nil);
    procedure FillCDSFromJsonSO(JSON: string; var cds: TClientDataSet);
  public
    constructor Create;
    property FieldSise: Integer read FFieldSise write FFieldSise;
    class function CreateCDSFromJsonSO(JSON: string; FieldChild: TFieldDef = nil; cdsName: string = 'MainDataset'): TClientDataSet;
    class function GetObjectJSON(SuperObject: ISuperObject; Name: WideString): ISuperObject;

    class procedure SetJson(SuperObject: ISuperObject; Name: WideString; Value: Boolean); overload;
    class procedure SetJson(SuperObject: ISuperObject; Name: WideString; Value: Double); overload;
    class procedure SetJson(SuperObject: ISuperObject; Name: WideString; Value: Int64); overload;
    class procedure SetJson(SuperObject: ISuperObject; Name: WideString; Value: ISuperObject); overload;
    class procedure SetJson(SuperObject: ISuperObject; Name: WideString; Value: WideString); overload;
  end;

implementation

uses
  StrUtils,
  ConfigDypeDBUtils, DAF_Types;

{ TDAFJSON }

constructor TDAFJSON.Create;
begin
  FFieldSise := 255;
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
    if ((FieldChild = nil) and (Result.FieldCount > 0)) then
    begin
      Result.CreateDataSet;
      DAFJson.FillCDSFromJsonSO(JSON, Result);
    end;
  finally
    DAFJson.Free;
  end;
end;

procedure TDAFJSON.FillCDSFromJsonSO(JSON: string; var cds: TClientDataSet);
var
  ArrayItem: TSuperAvlEntry;
  ArrayItens: ISuperObject;
  I: Integer;
  FieldName: string;
  FieldValue: string;
  joJSON: ISuperObject;
  cdsNested: TClientDataSet;
  Item: TSuperAvlEntry;
begin
  joJSON := SO(JSON);
  if joJSON.IsType(stObject) then
  begin
    cds.Append;
    for Item in joJSON.AsObject do
    begin
      if Item.Value.IsType(stArray) then
      begin
        cdsNested := TClientDataSet(TDataSetField(cds.FieldByName(Item.Name)).NestedDataSet);
        FillCDSFromJsonSO(Item.Value.AsString, cdsNested);
      end
      else if Item.Value.IsType(stObject) then
      begin
        cdsNested := TClientDataSet(TDataSetField(cds.FieldByName(Item.Name)).NestedDataSet);
        FillCDSFromJsonSO(Item.Value.AsString, cdsNested);
      end
      else
      begin
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
          cdsNested := TClientDataSet(TDataSetField(cds.FieldByName(FieldName)).NestedDataSet);
          FillCDSFromJsonSO(FieldValue, cdsNested);
        end
        else if ArrayItem.Value.IsType(stArray) then
        begin
          cdsNested := TClientDataSet(TDataSetField(cds.FieldByName(FieldName)).NestedDataSet);
          FillCDSFromJsonSO(FieldValue, cdsNested);
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

procedure TDAFJSON.ProcessJsonSO(Result: TClientDataSet; joJSON: ISuperObject; FieldChild: TFieldDef);
  procedure CreateFieldsSO(ArrayItem: TSuperAvlEntry; Result: TClientDataSet; FieldChild: TFieldDef);
  var
    FieldName, FieldValue: string;
    Item: TSuperAvlEntry;
  begin
    FieldName := ArrayItem.Name;
    FieldValue := ArrayItem.Value.AsString;
    if ArrayItem.Value.IsType(stArray) then
    begin
      if (Result.FindField(FieldName) = nil) then
      begin
        if (Result.FindField(FieldName) = nil) then
          CreateField(Result, FieldName, ftDataSet);

        if (FieldChild <> nil) and (FieldChild.ChildDefs.IndexOf(FieldName) = -1) then
          CreateChildField(FieldChild, FieldName, ftDataSet);

        if FieldChild <> nil then
        begin
          CreateCDSFromJsonSO(FieldValue, FieldChild.ChildDefs.Find(FieldName), FieldName + 'Detail')
        end
        else
        begin
          CreateCDSFromJsonSO(FieldValue, Result.FieldDefs.Find(FieldName), FieldName + 'Detail');
        end;
      end;
    end
    else if ArrayItem.Value.IsType(stObject) then
    begin
      if (Result.FindField(FieldName) = nil) then
      begin
        if (Result.FindField(FieldName) = nil) then
          CreateField(Result, FieldName, ftDataSet);

        if (FieldChild <> nil) and (FieldChild.ChildDefs.IndexOf(FieldName) = -1) then
          CreateChildField(FieldChild, FieldName, ftDataSet);

        if FieldChild <> nil then
        begin
          CreateCDSFromJsonSO(FieldValue, FieldChild.ChildDefs.Find(FieldName), FieldName + 'Detail')
        end
        else
        begin
          CreateCDSFromJsonSO(FieldValue, Result.FieldDefs.Find(FieldName), FieldName + 'Detail');
        end;
      end;

//      for Item in ArrayItem.Value.AsObject do
//      begin
//        CreateFieldsSO(Item, Result, FieldChild);
//      end;
    end
    else
    begin
      if (Result.FindField(FieldName) = nil) then
        CreateField(Result, FieldName, FieldName, ftString, FieldSise);

      if (FieldChild <> nil) and (FieldChild.ChildDefs.IndexOf(FieldName) = -1) then
        CreateChildField(FieldChild, FieldName, ftString, FieldSise);
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


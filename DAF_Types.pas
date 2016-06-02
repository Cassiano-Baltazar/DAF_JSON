unit DAF_Types;

interface

uses
  DB, SysUtils;

type
{$IF CompilerVersion < 20}
  UnicodeString = WideString;
  TDAFStringField = TStringField;
{$ELSE}
  TDAFStringField = TWideStringField;
{$IFEND}
  
  TArrayOfString = array of string;
  TArrayOfValues = array of Variant;
  TArrayOfTVarRec = array of TVarRec;
  TDAFCharSet = array of Char;

  TDAFException = class(Exception)
  end;

  TDAFUserException = class(TDAFException)
  end;

  TDAFDeveloperException = class(TDAFException)
  end;

const
  GNRE_PATH_FOLDER = '..\Libs\_GNRE.Schemas.1.0'; // _GNRE.Schemas
  NFE_PATH_FOLDER = '..\Libs\_Schemas.1.2'; // _Schemas
  CKEDITOR_PATH_FOLDER = '..\Libs\ckeditor.1.0'; // ckeditor
  LOGOTIPOS_PATH_FOLDER = '..\Libs\Logotipos.1.0'; // Logotipos
  PHP_PATH_FOLDER = '..\Libs\php.1.1'; // php
  RESOURCES_PATH_FOLDER = '..\Libs\Resources.1.0'; // Resources

implementation

end.

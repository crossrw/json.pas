{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}
{$IFDEF FPC}
  {$SMARTLINK ON}
  {$MODE OBJFPC}
{$ENDIF}

{$H+}
{$I-}

unit json;

interface

uses SysUtils, Classes, Contnrs;

type TJSONValueType = (jtString, jtNumber, jtObject, jtArray, jtBoolean, jtNull);

     EJSONException = class(Exception);

     TJSONValue = class(TObject)
      private
       FStream: TStream;
       FName: AnsiString;
       FValues: TObjectList;
       //
       FType: TJSONValueType;
       FValueNumber: Double;
       FValueString: AnsiString;
       //
       FCommentsAllowed: Boolean;
       //
       function GetChar(const SkipSpaces: Boolean = True): Char;
       procedure GoBack;
       function GetValueType: TJSONValueType;
       function GetChars(N: Integer; const SkipStartSpaces: Boolean = True): String;
       //
       function GetString: AnsiString;
       function GetNumber: Double;
       function GetBoolean: Boolean;
       procedure GetNull;
       procedure PurgeComments;
       //
       procedure AddValue(JSONValue: TJSONValue);
       function FindByName(const Name: AnsiString): TJSONValue;
       function GetByIndex(Index: Integer): TJSONValue;
      public
       constructor Create;
       destructor Destroy; override;
       //
       procedure LoadFromStream(AStream: TStream; const AName: AnsiString = '');
       procedure LoadFromFile(const FileName: String);
       procedure Clear;
       property CommentsAllowed: Boolean read FCommentsAllowed write FCommentsAllowed;
       //
       function ByPath(const path: String): TJSONValue;
       function PathExist(const path: String): Boolean;
       property Values[Index: Integer]: TJSONValue read GetByIndex;
       property Name: AnsiString read FName;
       //
       function AsNumber: Double;
       function AsInteger: Integer;
       function AsString: AnsiString;
       function AsBoolean: Boolean;
       //
       function DefValue(const Path, ADefValue: AnsiString): AnsiString; overload;
       function DefValue(const Path: String; ADefValue: Boolean): Boolean; overload;
       function DefValue(const Path: String; ADefValue: Integer): Integer; overload;
       //
       property ValueType: TJSONValueType read FType;
       function IsString(const Path: String = ''): Boolean;
       function IsObject(const Path: String = ''): Boolean;
       function IsArray(const Path: String = ''): Boolean;
       function IsNull(const Path: String = ''): Boolean;
       //
       function Count: Integer;
     end;

implementation

function StreamLinePos(const Stream: TStream; const Offset: Integer = -1): String;
var OrigPos, EndPos, Line, LinePos: Integer;
    B: Char;
begin
  OrigPos:= Stream.Position;
  EndPos:= OrigPos + Offset;
  LinePos:= 1;
  Line:= 1;
  //
  If EndPos > 0 then begin
    Stream.Position:= 0;
    try
      While Stream.Position < EndPos do begin
        Stream.Read(B, 1);
        If B = #10 then begin
          LinePos:= 1;
          Inc(Line);
        end else Inc(LinePos);
      end;
    finally
      Stream.Position:= OrigPos;
    end;
  end;
  result:= Format('line %d pos %d', [Line, LinePos]);
end;

constructor TJSONValue.Create;
begin
  inherited;
  //
  FValues:= Nil;
  FCommentsAllowed:= False;
end;

destructor TJSONValue.Destroy;
begin
  Clear;
  inherited;
end;

procedure TJSONValue.LoadFromStream(AStream: TStream; const AName: AnsiString = '');
var EName: AnsiString;
    JV: TJSONValue;
    Index: Integer;
    B: Char;
begin
 Clear;
 //
 FStream:= AStream;
 FName:= AName;
 //
 FType:= GetValueType;
 Case FType of
  jtString: FValueString:= GetString;
  jtNumber: FValueNumber:= GetNumber;
  jtBoolean: If GetBoolean then FValueNumber:= 1 else FValueNumber:= 0;
  jtNull: GetNull;
  jtObject: begin
   GetChar();                       // '{'
   If GetChar() = '}' then Exit;    // empty object?
   GoBack();
   repeat
    // name
    EName:= GetString();
    // divider
    If GetChar() <> ':' then raise EJSONException.CreateFmt('colon expected at %s', [StreamLinePos(FStream)]);
    // value
    JV:= TJSONValue.Create;
    JV.FCommentsAllowed:= FCommentsAllowed;
    JV.LoadFromStream(FStream, EName);
    AddValue(JV);
    // check end
    PurgeComments();
    B:= GetChar();
    If B = '}' then Break;
    If B = ',' then Continue;
    raise EJSONException.CreateFmt('expected "," or "}" at %s', [StreamLinePos(FStream)]);
   until False;
  end;
  jtArray: begin
   Index:= 0;
   GetChar();                       // '['
   If GetChar() = ']' then Exit;    // empty array
   GoBack;
   repeat
    // next value
    JV:= TJSONValue.Create;
    JV.FCommentsAllowed:= FCommentsAllowed;
    JV.LoadFromStream(FStream, IntToStr(Index));
    AddValue(JV);
    Inc(Index);
    // check end
    PurgeComments();
    B:= GetChar();
    If B = ']' then Break;
    If B = ',' then Continue;
    raise EJSONException.CreateFmt('expected "," or "]" at %s', [StreamLinePos(FStream)]);
   until False;
  end;
 end;
end;

procedure TJSONValue.LoadFromFile(const FileName: String);
var MS: TMemoryStream;
begin
  MS:= TMemoryStream.Create;
  try
    MS.LoadFromFile(FileName);
    MS.Seek(0, soFromBeginning);
    LoadFromStream(MS);
  finally
    FreeAndNil(MS);
  end;
end;

procedure TJSONValue.Clear;
begin
  If FValues <> Nil then FreeAndNil(FValues);
  FName:= '';
  FType:= jtNull;
  FValueString:= '';
end;

function TJSONValue.GetChar(const SkipSpaces: Boolean = True): Char;
var B: Char;
begin
  repeat
    If FStream.Read(B, 1) <> 1 then raise EJSONException.CreateFmt('unexpected end of file at %s', [StreamLinePos(FStream, 0)]);
  until (not (B in [#8,#9,#10,#12,#13,#32])) or (not SkipSpaces);
  result:= B;
end;

procedure TJSONValue.GoBack;
begin
  FStream.Seek(-1, soFromCurrent);
end;

function TJSONValue.GetValueType: TJSONValueType;
begin
  result:= jtNull;
  //
  try
    Case GetChar() of
      '"':             result:= jtString;
      '-', '0'..'9':   result:= jtNumber;
      '{':             result:= jtObject;
      '[':             result:= jtArray;
      't', 'f':        result:= jtBoolean;
      'n':             result:= jtNull;
      else raise EJSONException.CreateFmt('unknown value at %s', [StreamLinePos(FStream)]);
    end;
  finally
    GoBack;
  end;
end;

function TJSONValue.GetChars(N: Integer; const SkipStartSpaces: Boolean = True): String;
var S: AnsiString;
    I: Integer;
begin
  S:= '';
  For I:= 1 to N do S:= S + GetChar(SkipStartSpaces and (I = 1));
  result:= S;
end;

procedure TJSONValue.PurgeComments;
var RemStart: String;
    SavePos: Integer;
    B1, B2: Char;
begin
  If not FCommentsAllowed then Exit;
  //
  repeat
    SavePos:= FStream.Position;
    try
      RemStart:= GetChars(2);
    except
      on E: EJSONException do begin
        // this is not comment
        FStream.Position:= SavePos;
        Break;
      end;
    end;
    //
    If RemStart = '/*' then begin
      // comment "/* */", , read to "*/"
      B1:= ' ';
      repeat
        B2:= B1;
        B1:= GetChar();
      until (B2 = '*') and (B1 = '/');
    end else If RemStart = '//' then begin
      // comment "//", read to end of line
      While GetChar(False) <> #10 do;
    end else begin
      // this is not comment
      FStream.Position:= SavePos;
      Break;
    end;
  until False;
end;

function TJSONValue.GetString: AnsiString;
var S: AnsiString;
    B, B1: Char;
begin
  PurgeComments;
  //
  B:= GetChar();
  If B <> '"' then raise EJSONException.CreateFmt('bad string format at %s', [StreamLinePos(FStream)]);
  //
  S:= '';
  repeat
    B:= GetChar(False);
    If B = '"' then Break;
    If B = '\' then begin
      B1:= GetChar(False);
      Case B1 of
        '"': S:= S + '"';
        '\': S:= S + '\';
        '/': S:= S + '/';
        'b': S:= S + #8;
        'f': S:= S + #12;
        'n': S:= S + #10;
        'r': S:= S + #13;
        't': S:= S + #9;
        'u': raise EJSONException.CreateFmt('sorry, hex digits unsupported at %s', [StreamLinePos(FStream)]);
        else raise EJSONException.CreateFmt('unknown symbol at %s', [StreamLinePos(FStream)]);
      end;
    end else S:= S + B;
    If Length(S) > 1024 then raise EJSONException.CreateFmt('string too long at %s', [StreamLinePos(FStream, -1024)]);
  until False;
  result:= S;
end;

function TJSONValue.GetNumber: Double;
var S: String;
    D: Double;
    Code: Integer;
    B: Char;
begin
  S:= '';
  repeat
    B:= GetChar();
    If B in ['-','+','0'..'9','.','e','E'] then S:= S + B else begin
      GoBack;
      Break;
    end;
  until False;
  //
  Val(S, D, Code);
  If Code <> 0 then raise EJSONException.CreateFmt('unknown number at %s', [StreamLinePos(FStream, -Code)]);
  result:= D;
end;

function TJSONValue.GetBoolean: Boolean;
begin
  If GetChar() = 't' then begin
    If GetChars(3, False) <> 'rue' then raise EJSONException.CreateFmt('bad value at %s', [StreamLinePos(FStream, -4)]);
    result:= True;
  end else begin
    If GetChars(4, False) <> 'alse' then raise EJSONException.CreateFmt('bad value at %s', [StreamLinePos(FStream, -5)]);
    result:= False;
  end;
end;

procedure TJSONValue.GetNull;
begin
  If GetChars(4) <> 'null' then raise EJSONException.CreateFmt('bad value at %s', [StreamLinePos(FStream, -4)]);
end;

procedure TJSONValue.AddValue(JSONValue: TJSONValue);
begin
  If FValues = Nil then FValues:= TObjectList.Create;
  FValues.Add(JSONValue);
end;

function TJSONValue.FindByName(const Name: AnsiString): TJSONValue;
var JV: TJSONValue;
    I: Integer;
begin
  If (FType in [jtObject, jtArray]) and (FValues <> Nil) then begin
    For I:= 1 to FValues.Count do begin
      JV:= FValues.Items[I-1] as TJSONValue;
      If JV.FName = Name then begin
        result:= JV;
        Exit;
      end;
    end;
    result:= Nil;
  end else result:= Nil;
end;

function TJSONValue.GetByIndex(Index: Integer): TJSONValue;
begin
  result:= Nil;
  If FValues = Nil then Exit;
  If (Index < 0) or (Index >= FValues.Count) then Exit;
  //
  result:= FValues.Items[Index] as TJSONValue;
end;

function TJSONValue.IsNull(const Path: String = ''): Boolean;
var JV: TJSONValue;
begin
  result:= False;
  JV:= ByPath(Path);
  If JV = Nil then Exit;
  result:= JV.FType = jtNull;
end;

function TJSONValue.IsArray(const Path: String = ''): Boolean;
var JV: TJSONValue;
begin
  result:= False;
  JV:= ByPath(Path);
  If JV = Nil then Exit;
  result:= JV.FType = jtArray;
end;

function TJSONValue.IsObject(const Path: String = ''): Boolean;
var JV: TJSONValue;
begin
  result:= False;
  JV:= ByPath(Path);
  If JV = Nil then Exit;
  result:= JV.FType = jtObject;
end;

function TJSONValue.IsString(const Path: String = ''): Boolean;
var JV: TJSONValue;
begin
  result:= False;
  JV:= ByPath(Path);
  If JV = Nil then Exit;
  result:= JV.FType = jtString;
end;

function TJSONValue.AsNumber: Double;
begin
  If FType = jtNumber then result:= FValueNumber else raise EJSONException.Create('can''t convert this value to number');
end;

function TJSONValue.AsInteger: Integer;
begin
  result:= Round(AsNumber);
end;

function TJSONValue.AsBoolean: Boolean;
begin
  If FType in [jtBoolean,jtNumber] then result:= FValueNumber <> 0 else raise EJSONException.Create('can''t convert this value to boolean');
end;

function FloatStrEx(const V: Double): String;
{$IFDEF MSWINDOWS}
var FormatSettings: TFormatSettings;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
{$warnings off}
  GetLocaleFormatSettings(0, FormatSettings);
{$warnings on}
  FormatSettings.DecimalSeparator:= '.';
  result:= FloatToStr(V, FormatSettings);
{$ELSE}
  result:= FloatToStr(V);
{$ENDIF}
end;

function TJSONValue.AsString: AnsiString;
begin
  Case FType of
    jtBoolean: If FValueNumber <> 0 then result:= 'true' else result:= 'false';
    jtNumber: result:= FloatStrEx(FValueNumber);
    jtNull: result:= 'null';
    jtString: result:= FValueString;
    else raise EJSONException.Create('can''t get string value from this element');
  end;
end;

function TJSONValue.Count: Integer;
begin
  If FValues <> Nil then result:= FValues.Count else result:= 0;
end;

function TJSONValue.ByPath(const path: String): TJSONValue;
var JV: TJSONValue;
    P: Integer;
begin
  // hhh/ggg/0
  If Length(path) > 0 then begin
    P:= Pos('/', path);
    If P = 0 then JV:= FindByName(path) else JV:= FindByName(Copy(path, 1, P-1));
    If JV <> Nil then begin
      If P > 0 then result:= JV.ByPath(Copy(path, P+1, Length(path)- P)) else result:= JV;
    end else result:= Nil;
  end else result:= Self;
end;

function TJSONValue.PathExist(const path: String): Boolean;
begin
  result:= ByPath(path) <> Nil;
end;

function TJSONValue.DefValue(const Path, ADefValue: AnsiString): AnsiString;
var JV: TJSONValue;
begin
  JV:= ByPath(Path);
  If JV <> Nil then begin
    try
      result:= JV.AsString;
    except
      result:= ADefValue;
    end;
  end else result:= ADefValue;
end;

function TJSONValue.DefValue(const Path: String; ADefValue: Boolean): Boolean;
var JV: TJSONValue;
begin
  JV:= ByPath(Path);
  If JV <> Nil then begin
    try
      result:= JV.AsBoolean;
    except
      result:= ADefValue;
    end;
  end else result:= ADefValue;
end;

function TJSONValue.DefValue(const Path: String; ADefValue: Integer): Integer;
var JV: TJSONValue;
begin
  JV:= ByPath(Path);
  If JV <> Nil then begin
    try
      result:= JV.AsInteger;
    except
      result:= ADefValue;
    end;
  end else result:= ADefValue;
end;

end.

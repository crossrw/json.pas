program test;

{$APPTYPE CONSOLE}

uses SysUtils, json;

var JS, ChildJS: TJSONValue;
    I: Integer;

begin
 // see example file: test.json
 //
 JS:= TJSONValue.Create;
 // comments support on
 JS.CommentsAllowed:= True;
 try
  JS.LoadFromFile('test.json');
  // values by path
  Writeln('values by path:');
  Writeln(' glossary/title: ', JS.DefValue('glossary/title', ''));
  Writeln(' glossary/Age: ', JS.DefValue('glossary/Age', 0));
  Writeln(' glossary/Active: ', JS. DefValue('glossary/Age', False));
  // array values by path
  Writeln('array values by path:');
  Writeln(' glossary/GlossDiv/GlossList/GlossEntry/GlossDef/GlossSeeAlso[0]: ', JS.DefValue('glossary/GlossDiv/GlossList/GlossEntry/GlossDef/GlossSeeAlso/0', ''));
  Writeln(' glossary/GlossDiv/GlossList/GlossEntry/GlossDef/GlossSeeAlso[1]: ', JS.DefValue('glossary/GlossDiv/GlossList/GlossEntry/GlossDef/GlossSeeAlso/1', ''));
  Writeln(' glossary/GlossDiv/GlossList/GlossEntry/GlossDef/GlossSeeAlso[2]: ', JS.DefValue('glossary/GlossDiv/GlossList/GlossEntry/GlossDef/GlossSeeAlso/2', ''));
  Writeln(' glossary/GlossDiv/GlossList/GlossEntry/GlossDef/GlossSeeAlso[3]: ', JS.DefValue('glossary/GlossDiv/GlossList/GlossEntry/GlossDef/GlossSeeAlso/3', ''));
  // check null value
  Writeln('check null value:');
  Writeln(' glossary/Age is NULL: ', JS.IsNull('glossary/Age'));
  Writeln(' glossary/Owner is NULL: ', JS.IsNull('glossary/Owner'));
  // check types
  Writeln('check types:');
  Writeln(' glossary/GlossDiv/GlossList/GlossEntry/GlossDef/GlossSeeAlso is ARRAY: ', JS.IsArray('glossary/GlossDiv/GlossList/GlossEntry/GlossDef/GlossSeeAlso'));
  Writeln(' glossary/Age is STRING: ', JS.IsString('glossary/Age'));
  Writeln(' glossary/Age is OBJECT: ', JS.IsObject('glossary/Age'));
  Writeln(' glossary/GlossDiv is OBJECT: ', JS.IsObject('glossary/GlossDiv'));
  // list of childrens
  Writeln('list of childrens:');
  ChildJS:= JS.ByPath('glossary');
  Writeln(' children count: ', ChildJS.Count);
  Writeln(' names:');
  For I:= 1 to ChildJS.Count do begin
   Writeln('  ', ChildJS.Values[I-1].Name);
  end;
 finally
  FreeAndNil(JS);
 end;
 //
 readln;
end.

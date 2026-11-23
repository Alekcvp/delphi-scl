unit SCL.Writer;

{******************************************************************************}
{  Delphi-SCL - Simple Config Language Library                                 }
{  Copyright (c) 2026 Alexey Shuvalov (alekc.pub@gmail.com)                    }
{                                                                              }
{  SCL is a lightweight configuration format that distills YAML down to        }
{  its essential structure while adopting practical ideas from TOML.           }
{                                                                              }
{  This Source Code Form is subject to the terms of the Mozilla Public         }
{  License, v. 2.0. If a copy of the MPL was not distributed with this         }
{  file, You can obtain one at https://mozilla.org/MPL/2.0/.                   }
{******************************************************************************}

interface

{$Q-} // переполнение не баг, а полезная фича

uses
  {$IFDEF MSWINDOWS} Winapi.Windows, {$ENDIF} System.SysUtils, SCL.Common, SCL.Document;

const
  WRAP_BIAS = 8;

type
  ESCLWritingException = class(Exception);

  TSCLWriter = class
  private const
    MIN_WRAPPED_WIDTH = 32;
  private
    FIndent: TIndentStack;
    FIndentStep: Integer;
    FLeadArray: Boolean;
    FPrevNode: PSCLNode;
    FWrapWidth: Integer;
    FSpaceNodes: Boolean;
    FTextBuffer: TStringBuffer;
    procedure SetIndentStep(const Value: Integer);
    procedure SetWrapWidth(const Value: Integer);
  protected
    procedure WriteComment(const Value: string);
    procedure WriteEscapedString(const Value, Suffix: string);
    procedure WriteLiteralString(const Value, Suffix: string);
    procedure WriteNode(Node: PSCLNode; const Suffix: string);
    procedure WriteSubTree(Node: PSCLNode);
    procedure WriteTextString(const Value: string);
    procedure WriteWrappedString(const Value: string);
  public
    constructor Create(AIndentStep: Integer = 2; AWrapWidth: Integer = 80);
    destructor Destroy; override;
     function WriteDocument(Document: TSCLDocument): string; overload;
    procedure WriteDocument(const AFileName: string; Document: TSCLDocument; Encoding: TEncoding); overload;
    class procedure WriteFile(const AFileName: string; Document: TSCLDocument; Encoding: TEncoding);
     { Шаг отступа для каждого нового уровня, от 2 до 8 }
     property IndentStep: Integer read FIndentStep write SetIndentStep;
     { Писать вложенные в массив контейнеры с новой строки }
     property LeadArray: Boolean read FLeadArray write FLeadArray;
     property SpaceNodes: Boolean read FSpaceNodes write FSpaceNodes;
     { Глобальная ширина для переноса строк }
     property WrapWidth: Integer read FWrapWidth write SetWrapWidth;
  end;

implementation

uses
  SCL.Types;

resourcestring
  s2SmallWrapValue = 'Слишком маленькое значение ширины свёрнутой строки (%d)';
  sFileWriteError  = 'Ошибка записи "%s". %s';
  sInvalidIndntStp = 'Отступ уровня вложенности должен находиться в диапазоне от 2 до 8';
  sInvalidStringCh = 'Недопустимый символ в строке (0x%.2x)';
  sInvalidTextChar = 'Недопустимый символ в текстовом блоке (0x%.2x)';
  sInvalidWrapChar = 'Недопустимый символ в свёрнутой строке (0x%.2x)';
  sUnknownStrType  = 'Неизвестный тип строки ''%s'' (%d)';

const
  LW_CRLF = $000A000D;

  ESCAPE_NOT = $00;
  ESCAPE_CHR = $01; // экранирование подстановкой (\r\n)
  ESCAPE_ORD = $02; // экранирование кодом (\x00)

  STR_VALID  = %0000;
  STR_QUOTE  = %0001;
  STR_BREAK  = %0010;
  STR_SPACE  = %0100;

  MASK_LSTR  = %1011; // quote valid, break invalid, space ignored, $F - invalid char
  MASK_TEXT  = %1010; // quote ignored, break valid, space ignored, $F - invalid char
  MASK_WRAP  = %1110; // quote ignored, break valid, space wrapped, $F - invalid char

  StringMap: TASCIIMap = (
  {  0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F   }
    $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $1F, $10, $12, $2F, $1F, $12, $2F, $2F, // 0
    $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, // 1
    $04, $00, $F0, $00, $00, $00, $00, $01, $00, $00, $00, $00, $00, $00, $00, $00, // 2
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, // 3
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, // 4
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $F0, $00, $00, $00, // 5
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, // 6
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2F  // 7
  );

type
  HSCLNode = record helper for TSCLNode
    function IsArrayItem: Boolean; inline;
  end;

  HStringBuffer = class helper for TStringBuffer
    function AppendByCode(Ch: Char): TStringBuffer;
    function GetString: string;
    function Indent(Count: Integer): TStringBuffer;
    function Remove(Count: Integer; StopChar: Char): TStringBuffer; overload;
  end;

{ HSCLNode }

function HSCLNode.IsArrayItem: Boolean;
begin
  Result := (Parent <> nil) and (Parent.NodeType = ntArray);
end;

{ HStringBuffer }

function HStringBuffer.AppendByCode(Ch: Char): TStringBuffer;
begin
  var Buffer := CheckCapacity(4);
  Buffer[0] := '\';
  Buffer[1] := 'x';
  Buffer[2] := HexChars[Byte(Ch) shr 4];
  Buffer[3] := HexChars[Byte(Ch) and $0F];
  Result := Self;
end;

function HStringBuffer.GetString: string;
begin
  SetLength(FBuffer, FLength);
  Result := FBuffer;
  Finalize(FBuffer);
  FLength := 0;
end;

function HStringBuffer.Indent(Count: Integer): TStringBuffer;
begin
  if Count > 0 then
  begin
    var Buffer := CheckCapacity(Count);
    for var Index := 0 to Count - 1 do
      Buffer[Index] := #32;
  end;
  Result := Self;
end;

function HStringBuffer.Remove(Count: Integer; StopChar: Char): TStringBuffer;
begin
  if (FLength >= Count) and (FBuffer[FLength] <> StopChar) then
    Dec(FLength, Count);
  Result := Self;
end;

{ TSCLWriter }

constructor TSCLWriter.Create(AIndentStep, AWrapWidth: Integer);
begin
  SetIndentStep(AIndentStep);
  SetWrapWidth(AWrapWidth);
  FTextBuffer := TStringBuffer.Create(sLineBreak);
end;

destructor TSCLWriter.Destroy;
begin
  FTextBuffer.Free;
end;

procedure TSCLWriter.SetIndentStep(const Value: Integer);
begin
  if Word(Value - 2) > 6 then
    raise ESCLWritingException.CreateRes(@sInvalidIndntStp);
  FIndentStep := Value;
end;

procedure TSCLWriter.SetWrapWidth(const Value: Integer);
begin
  if Value < MIN_WRAPPED_WIDTH then
    raise ESCLWritingException.CreateResFmt(@s2SmallWrapValue, [Value]);
  FWrapWidth := Value;
end;

function TSCLWriter.WriteDocument(Document: TSCLDocument): string;
begin
  FIndent.Reset(-FIndentStep);
  FTextBuffer.Reset;
  FPrevNode := Document.Root;
  WriteSubTree(Document.Root);
  Result := FTextBuffer.GetString;
end;

procedure TSCLWriter.WriteComment(const Value: string);
begin
  var Comments := Value.Split([#13#10]);
  for var Comment in Comments do
    FTextBuffer.Append('# ').Append(Comment).AppendLineBreak.Indent(FIndent.Value);
end;

procedure TSCLWriter.WriteDocument(const AFileName: string; Document: TSCLDocument; Encoding: TEncoding);
begin
  var Buffer := Encoding.GetBytes(WriteDocument(Document));
  { Открываем файл для записи }
  var hSource := FileCreate(AFileName, fmOpenWrite or fmShareExclusive);
  if hSource = INVALID_HANDLE_VALUE then
    raise ESCLWritingException.CreateResFmt(@sFileWriteError, [AFileName, SysErrorMessage(GetLastError)]);
  { Сохраняем данные документа в файл }
  try
    var Preamble := Encoding.GetPreamble;
    if ((Preamble <> nil) and (FileWrite(hSource, PByte(Preamble)^, Length(Preamble)) < Length(Preamble))) or
       (FileWrite(hSource, PByte(Buffer)^, Length(Buffer)) < Length(Buffer))
    then raise ESCLWritingException.CreateResFmt(@sFileWriteError, [AFileName, SysErrorMessage(GetLastError)]);
  finally
    FileClose(hSource);
  end;
end;

procedure TSCLWriter.WriteEscapedString(const Value, Suffix: string);
const
  EscapeChars: array [#08..#13] of Char = ('b', 't', 'n', '?', 'f', 'r');
begin
  FTextBuffer.Append('"');
  var Source := PPChar(@Value)^;
  var Cursor := Source - 1;
  for var Index := 1 to Value.Length do
  begin
    Inc(Cursor);
    var Ch := Cursor^;
    if Word(Ch) and $FF80 = 0 then
    begin
      { Допускаются любые символы }
      case StringMap[Ch] shr 4 of
        ESCAPE_NOT: Continue;
        ESCAPE_CHR: FTextBuffer.Append(Source, Cursor - Source).Append('\').Append(EscapeChars[Ch]);
        ESCAPE_ORD: FTextBuffer.Append(Source, Cursor - Source).AppendByCode(Ch);
        else FTextBuffer.Append(Source, Cursor - Source).Append('\').Append(Ch);
      end;
      Source := Cursor + 1;
    end;
  end;
  FTextBuffer.Append(Source, Cursor - Source + 1).Append('"').Append(Suffix);
end;

class procedure TSCLWriter.WriteFile(const AFileName: string; Document: TSCLDocument; Encoding: TEncoding);
begin
  with Create do
  try
    WriteDocument(AFileName, Document, Encoding);
  finally
    Free;
  end;
end;

procedure TSCLWriter.WriteLiteralString(const Value, Suffix: string);
begin
  { Инициализация переменных }
  FTextBuffer.Append(#39);
  var Source := PPChar(@Value)^;
  var Cursor := Source;
  { Проверяем строку на наличие недопустимых символов }
  for var Index := 1 to Value.Length do
  begin
    var Ch := Cursor^;
    if Word(Ch) and $FF80 = 0 then
      { Допускаются любые символы, кроме непечатных и переносов строки }
      case StringMap[Ch] and MASK_LSTR of
        STR_VALID: ;
        STR_QUOTE:
          begin
            { Кавычки - допускаются, но удваиваются в строке }
            FTextBuffer.Append(Source, Cursor - Source).Append(#39#39);
            Source := Cursor + 1;
          end;
        else raise ESCLWritingException.CreateResFmt(@sInvalidStringCh, [Ord(Ch)]);
      end;
    Inc(Cursor);
  end;
  { Завершаем строку }
  FTextBuffer.Append(Source, Cursor - Source).Append(#39).Append(Suffix);
end;

procedure TSCLWriter.WriteNode(Node: PSCLNode; const Suffix: string);
begin
  { TODO: Сделать запись комментария узла, в т.ч. многострочного }
  var ParentNode := Node.Parent;
  if (Node.Comment <> string.Empty) and (ParentNode <> nil) and not ParentNode.IsInline then
    WriteComment(Node.Comment);
  var SpacedNode := FSpaceNodes and not Node.IsInline and not Node.IsFirst;
  case ParentNode.NodeType of
    ntArray:
      if not ParentNode.IsInline then
      begin
        if SpacedNode and (FPrevNode.NextSibling <> Node) then
          FTextBuffer.AppendLineBreak.Indent(FIndent.Value);
        FTextBuffer.Append('- ');
      end;
    ntTable:
      begin
        if SpacedNode and ((Node.NodeType in [ntArray, ntTable]) or
          (Node.NodeType = ntString) and (Node.StringType in [stText, stWrapped]))
        then
          FTextBuffer.AppendLineBreak.Indent(FIndent.Value);
        FTextBuffer.Append(Node.Name).Append(': ');
      end;
  end;
  FPrevNode := Node;
  case Node.NodeType of
    ntArray, ntTable:
      WriteSubTree(Node);
    ntString:
      case Node.StringType of
        stDefault: WriteEscapedString(Node.VString, Suffix);
        stLiteral: WriteLiteralString(Node.VString, Suffix);
        stText:    WriteTextString(Node.VString);
        stWrapped: WriteWrappedString(Node.VString);
        else raise ESCLWritingException.CreateResFmt(@sUnknownStrType, [Node.Name, Ord(Node.StringType)]);
      end;
    else FTextBuffer.Append(Node.ToString).Append(Suffix);
  end;
end;

procedure TSCLWriter.WriteSubTree(Node: PSCLNode);
const
  Borders: array [Boolean] of PChar = ('[]', '{}');
  Suffixs: array [Boolean] of string = (', ', '; ');
begin
  var Item := Node.FirstChild;
  if (Node.Count <= 0) or Node.IsInline then
  begin
    var IsTable := Node.NodeType = ntTable;
    var Bracket := Borders[IsTable];
    FTextBuffer.Append(Bracket[0]);
    for var Index := 0 to Node.Count - 1 do
    begin
      WriteNode(Item, Suffixs[IsTable]);
      Item := Item.NextSibling;
    end;
    FTextBuffer.Remove(2, Bracket[0]).Append(Bracket[1]).AppendLineBreak;
    Exit;
  end;
  if Node.IsArrayItem and not FLeadArray then
  begin
    { Пишем элементы с текущей строки }
    FIndent.Increment(2);
    WriteNode(Item, FTextBuffer.LineBreak);
  end else
  begin
    { Пишем элементы с новой строки }
    FIndent.Increment(FIndentStep);
    if FIndent.Value > 0 then
      FTextBuffer.AppendLineBreak.Indent(FIndent.Value);
    WriteNode(Item, FTextBuffer.LineBreak);
  end;
  { Дальше обычный цикл по элементам }
  for var Index := 1 to Node.Count - 1 do
  begin
    Item := Item.NextSibling;
    FTextBuffer.Indent(FIndent.Value);
    WriteNode(Item, FTextBuffer.LineBreak);
  end;
  FIndent.Decrement;
end;

procedure TSCLWriter.WriteTextString(const Value: string);
begin
  { Сохраняем ссылку на начало исходного текста }
  var Source := PPChar(@Value)^;
  { Записываем идентификатор текстового блока и отступ при необходимости }
  FTextBuffer.Append('|');
  if Source <> nil then
  begin
    if Source^ = #32 then
      FTextBuffer.Append(IntToStr(FIndentStep));
    { Если строка завершается переносом строки, то отключаем обрезку }
    case Source[Value.Length - 1] of
      #10, #13: FTextBuffer.Append('+');
    end;
  end;
  FTextBuffer.AppendLineBreak;
  { Увеличиваем значение отступа }
  FIndent.Increment(FIndentStep);
  { Пишем текст построчно с переносами строки }
  var Cursor := Source;
  var Last := Source + Value.Length;
  while Cursor < Last do
  begin
    var Ch := Cursor^;
    if Word(Ch) and $FF80 = 0 then
      { Допускаются любые символы, кроме непечатных }
      case StringMap[Ch] and MASK_TEXT of
        STR_VALID: ;
        STR_BREAK:
          begin
            FTextBuffer.Indent(FIndent.Value).Append(Source, Cursor - Source).AppendLineBreak;
            if PLongWord(Cursor)^ = LW_CRLF then
              Inc(Cursor);
            Source := Cursor + 1;
          end;
        else raise ESCLWritingException.CreateResFmt(@sInvalidTextChar, [Ord(Ch)]);
      end;
    Inc(Cursor);
  end;
  if Cursor > Source then
    FTextBuffer.Indent(FIndent.Value).Append(Source, Cursor - Source).AppendLineBreak;;
  { Уменьшаем значение отступа }
  FIndent.Decrement;
end;

procedure TSCLWriter.WriteWrappedString(const Value: string);

  function FindWrap(Source: PChar; WrapLength, Length: Integer): Integer;
  begin
    var NonWrapped := Min(WrapLength - WRAP_BIAS, Length) - 1;
    { Сначала ищем переносы строки в начале строки }
    for var Index := 0 to NonWrapped do
      if Word(Source^) and $FF80 <> 0 then
        Inc(Source)
      else case StringMap[Source^] and MASK_TEXT of
        STR_VALID: Inc(Source);
        STR_BREAK: Exit(Index);
        else raise ESCLWritingException.CreateResFmt(@sInvalidTextChar, [Ord(Source^)]);
      end;
    { Потом ищем переносы строки и пробелы в конце строки }
    Result := 0;
    for var Index := NonWrapped + 1 to Min(WrapLength + WRAP_BIAS, Length - 1) do
    begin
      if Word(Source^) and $FF80 = 0 then
        case StringMap[Source^] and MASK_WRAP of
          STR_VALID: ;
          STR_BREAK: Exit(Index); // перенос строки приоритетнее пробела
          STR_SPACE: if Abs(WrapLength - Index) < Abs(WrapLength - Result) then Result := Index;
          else raise ESCLWritingException.CreateResFmt(@sInvalidTextChar, [Ord(Source^)]);
        end;
      Inc(Source);
    end;
    { Если не нашли ничего, то возвращаем WrapLength }
    if Result = 0 then
      Result := Min(WrapLength, Length);
  end;

begin
  { Сохраняем ссылки на текст и границу текста }
  var Source := PPChar(@Value)^;
  var Bounds := Source + Value.Length;
  var Indent := FIndent.Value + FIndentStep;
  { Записываем идентификатор свёрнутого текста }
  FTextBuffer.Append('>');
  if Source >= Bounds then
  begin
    { Пустая строка }
    FTextBuffer.AppendLineBreak;
    Exit;
  end;
  { Для пустых строк и строк, начинающихся с пробела, пишем отступ принудительно }
  case Source^ of
   #10, #13, #32: FTextBuffer.Append(IntToStr(FIndentStep));
  end;
  { Если строка завершается переносом строки, то отключаем обрезку }
  case Bounds[-1] of
    #10, #13: FTextBuffer.Append('+');
  end;
  { Ширина текста не может быть меньше чем MIN_WRAPPED_WIDTH }
  var WrapLength := Max(FWrapWidth - Indent, MIN_WRAPPED_WIDTH);
  repeat
    { Ищем следующий пробел-разделитель }
    var WrapIndex := FindWrap(Source, WrapLength, Bounds - Source);
    FTextBuffer.AppendLineBreak.Indent(Indent).Append(Source, WrapIndex);
    { Обрабатываем разделитель }
    case Source[WrapIndex] of
      #00: Break; // завершение строки
      #10, #13:
        begin
          { При пустом параграфе дополнительная пустая строка не вставляется }
          if WrapIndex > 0 then
            FTextBuffer.AppendLineBreak;
          Inc(WrapIndex, 1 + Ord(PDWord(@Source[WrapIndex])^ = LW_CRLF));
        end;
      #32: Inc(WrapIndex);
      else FTextBuffer.Append('\');
    end;
    { Сдвигаем позицию в строке }
    Inc(Source, WrapIndex);
  until False;
  FTextBuffer.AppendLineBreak;
end;

end.

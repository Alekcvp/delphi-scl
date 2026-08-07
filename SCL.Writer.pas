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
    procedure WriteEscapedString(const Value, Suffix: string);
    procedure WriteLiteralString(const Value, Suffix: string);
    procedure WriteNode(Node: PSCLNode; const Suffix: string);
    procedure WriteSubTree(Node: PSCLNode);
    procedure WriteTextString(const Value: string);
    procedure WriteWrappedString(const Value: string);
  public
    constructor Create(AIndentStep: Integer = 4; AWrapWidth: Integer = 80);
    destructor Destroy; override;
    procedure SetLineBreaks(const LineBreak: string); inline;
     function WriteDocument(Document: TSCLDocument): string; overload;
    procedure WriteDocument(const AFileName: string; Document: TSCLDocument; Encoding: TEncoding); overload;
     { Шаг отступа для каждого нового уровня, от 2 до 8 }
     property IndentStep: Integer read FIndentStep write SetIndentStep;
     { Писать вложенные в массив контейнеры с новой строки }
     property LeadArray: Boolean read FLeadArray write FLeadArray;
     property SpaceNodes: Boolean read FSpaceNodes write FSpaceNodes;
     { Глобальная ширина для переноса строк }
     property WrapWidth: Integer read FWrapWidth write SetWrapWidth;
  end;

implementation

resourcestring
  s2SmallWrapValue = 'Слишком маленькое значение ширины свёрнутой строки (%d)';
  sFileWriteError  = 'Ошибка записи "%s". %s';
  sInvalidIndntStp = 'Отступ уровня вложенности должен находиться в диапазоне от 2 до 8';
  sInvalidStringCh = 'Недопустимый символ в строке (0x%.2x)';
  sInvalidTextChar = 'Недопустимый символ в текстовом блоке (0x%.2x)';
  sInvalidWrapChar = 'Недопустимый символ в свёрнутой строке (0x%.2x)';
  sUnknownStrType  = 'Неизвестный тип строки ''%s'' (%d)';

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
  FTextBuffer := TStringBuffer.Create;
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

procedure TSCLWriter.SetLineBreaks(const LineBreak: string);
begin
  FTextBuffer.LineBreak := LineBreak;
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
      case StringMap[Ch] and $F0 of
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
      case StringMap[Ch] and $0F of
        STR_VALID, STR_ESCAPE: ;
        STR_QUOTE:
          if Ch = #39 then         
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
  if Node.NodeType = ntComment then
  begin
    if Node.Name <> '' then
      FTextBuffer.Append('# ').Append(Node.Name);
    FTextBuffer.AppendLineBreak;
    Exit;
  end;
  var ParentNode := Node.Parent;
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
        if SpacedNode and (Node.NodeType in [ntArray, ntTable]) or
          (Node.NodeType = ntString) and (Node.StringType in [stText, stWrapped])
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
        stDefault: WriteEscapedString(Node.asString, Suffix);
        stLiteral: WriteLiteralString(Node.AsString, Suffix);
        stText:    WriteTextString(Node.AsString);
        stWrapped: WriteWrappedString(Node.AsString);
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
const
  LW_CRLF = $000A000D;
begin
  { Сохраняем ссылку на начало исходного текста }
  var Source := PPChar(@Value)^;
  { Записываем идентификатор текстового блока и отступ при необходимости }
  FTextBuffer.Append('|');
  if (Source <> nil) and (Source^ = #32) then
    FTextBuffer.Append(IntToStr(FIndentStep));
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
      case StringMap[Ch] and $0F of
        STR_VALID, STR_ESCAPE, STR_QUOTE: ;
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

  function FindWrap(Cursor: PChar; Margin: Integer): PChar;
  begin
    if Cursor^ <> #32 then
      for var Index := 1 to Margin do
        if (Cursor - Index)^ = #32 then
          Exit(Cursor - Index)
        else if (Cursor + Index)^ = #32 then
          Exit(Cursor + Index);
    Result := Cursor;
  end;

begin
  { Сохраняем длину текста и ссылку на него }
  var Source := PPChar(@Value)^;
  { Увеличиваем значение отступа }
  FIndent.Increment(FIndentStep);
  { Записываем идентификатор свёрнутого текста и отступ при необходимости }
  FTextBuffer.Append('>');
  if (Source <> nil) and (Source^ = #32) then
    FTextBuffer.Append(IntToStr(FIndentStep));
  FTextBuffer.AppendLineBreak;
  { Ширина текста не может быть меньше чем MIN_WRAPPED_WIDTH }
  var WrapLength := Max(FWrapWidth - FIndent.Value, MIN_WRAPPED_WIDTH);
  var Checkpoint := Source + Value.Length - WrapLength;
  var Margin := WrapLength shr 2;
  while Source < Checkpoint do
  begin
    FTextBuffer.Indent(FIndent.Value);
    var WrapSpace := FindWrap(Source + WrapLength, Margin);
    if WrapSpace^ = #32 then
    begin
      FTextBuffer.Append(Source, WrapSpace - Source);
      Source := WrapSpace + 1;
    end else
    begin
      FTextBuffer.Append(Source, WrapSpace - Source).Append('\');
      Source := WrapSpace;
    end;
    FTextBuffer.AppendLineBreak;
  end;
  { Записываем остаток текста при его наличии }
  FTextBuffer.Indent(FIndent.Value).Append(Source, Checkpoint + WrapLength - Source).AppendLineBreak;
  { Уменьшаем значение отступа }
  FIndent.Decrement;
end;

end.

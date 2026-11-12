unit SCL.Reader;

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
  {$IFDEF MSWINDOWS} Winapi.Windows, {$ENDIF} System.SysUtils, System.Types, SCL.Common, SCL.Document;

type
  TSCLParsingError = (
    peInternalSCLError,
    peCommentNotAllowedHere,
    peDateDecodingFailed,
    peEmptyNamesNotAllowed,
    peExponentOutOfRange,
    peExponentValueMissing,
    peFractionPartMissing,
    peIllegalCharacter,
    peIllegalCharacterCode,
    peIllegalEscapeSequence,
    peInlineTextNotAllowed,
    peIntegerPartMissing,
    peInvalidBinaryLength,
    peInvalidDateTimeFormat,
    peInvalidDateTimeValue,
    peInvalidGroupSeparator,
    peInvalidIndentStack,
    peInvalidLineEnding,
    peInvalidNameCharacter,
    peInvalidValueDelimiter,
    peInvalidValueIndent,
    peLeadingZeroNotAllowed,
    peNestedValueNotAllowed,
    peNodeNameColonRequired,
    peTimeDecodingFailed,
    peUnexpectedEndOfFile,
    peUnexpectedEndOfLine,
    peUnknownIdentifier,
    peUnterminatedInline,
    peUnterminatedString,
    peValueOutOfRange
  );

  ESCLParsingException = class(Exception)
    ErrorCode: TSCLParsingError;
    LineIndex: Integer;
    CharIndex: Integer;
    constructor Create(const FileName, ErrorMessage: string; ALineIndex, ACharIndex: Integer; Error: TSCLParsingError);
  end;

  HEncoding = class helper for TEncoding
    function GetString(const Buffer: RawByteString): string;
    class function GuessEncoding(const Buffer: RawByteString): TEncoding;
  end;

  TSCLReader = class
  private type
    TEmptyLines = (elSkipNone, elSkipLast, elSkipAny);
    TTextReader = procedure (EmptyLines: TEmptyLines) of object;
  private
    FFileName: string;          // имя исходного файла с документом
    FSource: PChar;             // начало текущей строки
    FCursor: PChar;             // текущее положение в документе
    FDocEnd: PChar;             // конец текста (завершающий #0)
    FIndent: TIndentStack;      // стек с отступами уровней
    FInlineEnd: Char;           // символ завершения строчного массива или таблицы
    FLineIndex: Integer;        // индекс текущей строки (с 0)
    FStringBuf: TStringBuffer;  // буфер для чтения строк и текста
  protected
     function ReadSourceFromFile(const AFileName: string): RawByteString;
    procedure ParseDateAndTime(Node: PSCLNode; Source: PChar; Value: Word);
    procedure ParseInlineValue(ParentNode: PSCLNode);
    procedure ParseNode(var CurrentNode: PSCLNode);
    procedure ParseNodeValue(var ParentNode: PSCLNode; const NodeName: string = string.Empty);
    procedure ParseNumberOrDate(Node: PSCLNode; Source: PChar; Sign: Integer = 0);
    procedure ParseStructure(Document: TSCLDocument; Buffer: PChar; Count: Integer);
    procedure RaiseParsingError(Error: TSCLParsingError; TokenPos: PChar = nil);
     function ReadBaseTwo(Source: PChar; Shift: Integer): Int64;
     function ReadBinary(Source: PChar): TBytes;
     function ReadNodeName(IsRequired: Boolean): string;
     function ReadString: string;
     function ReadText(TextReader: TTextReader): string;
    procedure ReadTextBlock(EmptyLines: TEmptyLines);
    procedure ReadWrapBlock(EmptyLines: TEmptyLines);
    procedure SkipLineBreak(var Source: PChar);
    procedure ValidateIndent(var CurrentNode: PSCLNode);
  public
    constructor Create(const LineBreaks: string = sLineBreak);
    destructor Destroy; override;
     function ParseDocument(const Buffer: RawByteString; Document: TSCLDocument = nil;
      Encoding: TEncoding = nil): TSCLDocument; overload;
     function ParseDocument(const Buffer: string; Document: TSCLDocument = nil): TSCLDocument; overload;
     function ParseFile(const AFileName: string; Document: TSCLDocument = nil;
      Encoding: TEncoding = nil): TSCLDocument;
    class function ReadFrom(const AFileName: string): TSCLDocument;
  end;

implementation

uses
  SCL.Types;

resourcestring
  sDocumentEncodingError = 'Ошибка при преобразовании кодировки файла "%s"';
  sDocumentParsingError  = '%s(%d:%d): %s';
  sDocumentReadingError  = 'Ошибка чтения "%s". %s';
  sDocumentFileTooLarge  = 'Слишком большой размер SCL документа "%s"';

  sCommentNotAllowedHere = 'Комментарии внутри строчных массивов и таблиц не допускаются';
  sDateDecodingFailed    = 'Не удалось декодировать дату';
  sEmptyNamesNotAllowed  = 'Пустые имена узлов не допускаются';
  sExponentOutOfRange    = 'Значение экспоненты вне допустимых пределов';
  sExponentValueMissing  = 'Отсутствует значение экспоненты';
  sFractionPartMissing   = 'Отсутствует значение дробной части';
  sIllegalCharacter      = 'Недопустимый символ';
  sIllegalCharacterCode  = 'Недопустимый код символа';
  sIllegalEscapeSequence = 'Неизвестная экранированная последовательность';
  sInvalidIndentStack    = 'Внутренняя ошибка в стеке уровней документа';
  sInlineTextNotAllowed  = 'Текстовые блоки в строчных массивах и таблицах не допускаются';
  sIntegerPartMissing    = 'Отсутствует значение целой части числа';
  sInvalidBinaryLength   = 'Неверная длина двоичной последовательности';
  sInvalidDateTimeFormat = 'Неверный формат даты или времени';
  sInvalidDateTimeValue  = 'Недопустимое значение даты или времени';
  sInvalidGroupSeparator = 'Недопустимое расположение разделителя групп';
  sInvalidLineEnding     = 'Неверная последовательность завершения строки';
  sInvalidNameCharacter  = 'Недопустимый символ в имени узла';
  sInvalidValueDelimiter = 'Неверный разделитель значений';
  sInvalidValueIndent    = 'Неверный отступ для значения';
  sLeadingZeroNotAllowed = 'Ведущие нули не допускаются';
  sNestedValueNotAllowed = 'Вложенные массивы и таблицы не допускаются';
  sNodeNameColonRequired = 'Имя узла должно завершаться символом '':''';
  sTimeDecodingFailed    = 'Не удалось декодировать время';
  sUnexpectedEndOfFile   = 'Неожиданный конец файла';
  sUnexpectedEndOfLine   = 'Перенос строки в строчных массивах и таблицах не допускается';
  sUnknownIdentifier     = 'Неизвестный идентификатор';
  sUnknownParsingError   = 'Внутренняя ошибка парсера';
  sUnterminatedInline    = 'Обнаружен незавершенный строчный массив или таблица';
  sUnterminatedString    = 'Обнаружена незавершённая строка';
  sValueOutOfRange       = 'Значение выходит за допустимые пределы';

const
  SCLParsingErrorMessages: array[TSCLParsingError] of string = (
    sUnknownParsingError,        // peInternalSCLError
    sCommentNotAllowedHere,      // peCommentNotAllowedHere
    sDateDecodingFailed,         // peDateDecodingFailed
    sEmptyNamesNotAllowed,       // peEmptyNamesNotAllowed
    sExponentOutOfRange,         // peExponentOutOfRange
    sExponentValueMissing,       // peExponentValueMissing
    sFractionPartMissing,        // peFractionPartMissing
    sIllegalCharacter,           // peIllegalCharacter
    sIllegalCharacterCode,       // peIllegalCharacterCode
    sIllegalEscapeSequence,      // peIllegalEscapeSequence
    sInlineTextNotAllowed,       // peInlineTextNotAllowed
    sIntegerPartMissing,         // peIntegerPartMissing
    sInvalidBinaryLength,        // peInvalidBinaryLength
    sInvalidDateTimeFormat,      // peInvalidDateTimeFormat
    sInvalidDateTimeValue,       // peInvalidDateTimeValue
    sInvalidGroupSeparator,      // peInvalidGroupSeparator
    sInvalidIndentStack,         // peInvalidIndentStack
    sInvalidLineEnding,          // peInvalidLineEnding
    sInvalidNameCharacter,       // peInvalidNameCharacter
    sInvalidValueDelimiter,      // peInvalidValueDelimiter
    sInvalidValueIndent,         // peInvalidValueIndent
    sLeadingZeroNotAllowed,      // peLeadingZeroNotAllowed
    sNestedValueNotAllowed,      // peNestedValueNotAllowed
    sNodeNameColonRequired,      // peNodeNameColonRequired
    sTimeDecodingFailed,         // peTimeDecodingFailed
    sUnexpectedEndOfFile,        // peUnexpectedEndOfFile
    sUnexpectedEndOfLine,        // peUnexpectedEndOfLine
    sUnknownIdentifier,          // peUnknownIdentifier
    sUnterminatedInline,         // peUnterminatedInline
    sUnterminatedString,         // peUnterminatedString
    sValueOutOfRange             // peValueOutOfRange
  );

function IsDateOrTime(Source: PChar): Boolean;
const
  Values: array [0..4] of Char = ('0', '0', ':', '0', '-');
begin
  var Seek := Values - Source;
  for var Index := 1 to Length(Values) do
  begin
    if AsDigit(Source^) > 9 then
      Exit(Source^ = Source[Seek]);
    Inc(Source);
  end;
  Result := False;
end;

function NextToken(var Source: PChar): Char; inline;
begin
  while Source^ = #32 do Inc(Source);
  Result := Source^;
end;

function SameToken(var Source: PChar; Token: PChar): Boolean;
begin
  var Index := Source - Token;
  while Token^ = '?' do Inc(Token);
  { Проверка на Token^ = #0 не нужна, т.к. Word(#0) or $20 = $20 <> Word(#0) всегда! }
  while Word(Token[Index]) or $20 = Word(Token^) do Inc(Token);
  Result := Token^ = #0;
  if Result then
    Source := Token + Index;
end;

function SkipSpaces(Source: PChar): PChar; inline;
begin
  while Source^ = #32 do
    Inc(Source);
  Result := Source;
end;

function SkipToLineEnd(Source: PChar): PChar; overload; inline;
begin
  while (Word(Source^) and $FF80 <> 0) or (StringMap[Source^] and $01 = 0) do
    Inc(Source);
  Result := Source;
end;

function SkipToLineEnd(Source: PChar; out Length: Integer): PChar; overload; inline;
begin
  Result := Source;
  while (Word(Result^) and $FF80 <> 0) or (StringMap[Result^] and $01 = 0) do
    Inc(Result);
  Length := Result - Source;
end;

function TestIndent(var Cursor: PChar; out Source: PChar; Indent: Integer): Boolean;
begin
  var LCursor := Cursor;
  for var Index := 1 to Indent do
    case LCursor^ of
      #10, #13: Break;
      #32: Inc(LCursor);
      else Exit(False);
    end;
  Source := LCursor;
  Cursor := SkipToLineEnd(LCursor); // конец текущей строки
  Result := True;
end;

{ ESCLParsingException }

constructor ESCLParsingException.Create(const FileName, ErrorMessage: string; ALineIndex, ACharIndex: Integer;
  Error: TSCLParsingError);
begin
  ErrorCode := Error;
  LineIndex := ALineIndex;
  CharIndex := ACharIndex;
  CreateResFmt(@sDocumentParsingError, [FileName, ALineIndex, ACharIndex, ErrorMessage]);
end;

{ HEncoding }

function SameBytes(const Buffer: RawByteString; const [ref] Value: array of Byte): Boolean;
begin
  for var Index := 0 to High(Value) do
    if PByte(Buffer)[Index] <> Value[Index] then
      Exit(False);
  Result := True;
end;

function HEncoding.GetString(const Buffer: RawByteString): string;
begin
  var Length := Length(Buffer);
  var Count := GetCharCount(PByte(Buffer), Length);
  SetLength(Result, Count);
  if Count > 0 then
    SetLength(Result, GetChars(PByte(Buffer), Length, Pointer(Result), Count));
end;

class function HEncoding.GuessEncoding(const Buffer: RawByteString): TEncoding;
const
  UTF8BOM: array [0..2] of Byte = ($EF, $BB, $BF);
  UTF16LE: array [0..1] of Byte = ($FF, $FE);
  UTF16BE: array [0..1] of Byte = ($FE, $FF);
begin
  Result := TEncoding.UTF8;
  if Buffer = '' then Exit;
  { Проверяем наличие BOM }
  if SameBytes(Buffer, UTF8BOM) then
    Result := TEncoding.UTF8
  else if SameBytes(Buffer, UTF16LE) then
    Result := TEncoding.Unicode
  else if SameBytes(Buffer, UTF16BE) then
    Result := TEncoding.BigEndianUnicode
  { В UTF-16 с большой вероятностью встретится нулевой байт, который недопустим в UTF-8 }
  else for var Index := 0 to Min(15, Length(Buffer) - 1) do
    if PByte(Buffer)[Index] = 0 then
      if Index and $01 = 0 then
        Exit(TEncoding.BigEndianUnicode)
      else
        Exit(TEncoding.Unicode);
end;

{ TSCLReader }

constructor TSCLReader.Create(const LineBreaks: string);
begin
  FStringBuf := TStringBuffer.Create(LineBreaks);
end;

destructor TSCLReader.Destroy;
begin
  FStringBuf.Free;
end;

procedure TSCLReader.ParseDateAndTime(Node: PSCLNode; Source: PChar; Value: Word);

  function ReadNextPart(Max: Word; Prefix: Char): Word;
  begin
    if Source^ <> Prefix then
      RaiseParsingError(peInvalidDateTimeFormat, Source);
    Result := 0;
    Inc(Source);
    for var Index := 1 to 2 do
    begin
      var Digit := AsDigit(Source^);
      if Digit > 9 then
        RaiseParsingError(peIllegalCharacter, Source);
      Result := Result * 10 + Digit;
      if Result > Max then
        RaiseParsingError(peInvalidDateTimeValue, Source);
      Inc(Source);
    end;
  end;

  function ReadTimeOffset: SmallInt;
  begin
    var Sign := 1;
    case Source^ of
      '+': ; // Sign := 1
      '-': Sign := -1;
      'Z', 'z':
        begin
          Inc(Source);
          Exit(0);
        end
      else Exit(TIME_OFFSET_LOCAL);
    end;
    Result := (ReadNextPart(23, Source^) * MinsPerHour + ReadNextPart(59, ':')) * Sign;
  end;

const
  DATETIME_IS_OK = Word(-1);
begin
  var DateTime: TDateTime := 0;
  var TimeOffset := TIME_OFFSET_LOCAL;
  if Source^ = '-' then
  begin
    var Month := ReadNextPart(12, '-');
    var Day   := ReadNextPart(31, '-');
    if not TryEncodeDate(Value, Month, Day, DateTime) then
      RaiseParsingError(peDateDecodingFailed);
    Value := DATETIME_IS_OK;
    if (Source^ = #32) and (AsDigit(Source[1]) <= 9) or (Ord(Source^) or $20 = Ord('t')) then
      Value := ReadNextPart(23, Source^);
  end;
  if Source^ = ':' then
  begin
    var Minute := ReadNextPart(59, ':');
    var Second: Word := 0;
    { Секунды опциональны }
    if Source^ = ':' then
      Second := ReadNextPart(59, ':');
    var TimeValue: TDateTime;
    if not TryEncodeTime(Value, Minute, Second, 0, TimeValue) then
      RaiseParsingError(peTimeDecodingFailed);
    Value := DATETIME_IS_OK;
    DateTime := DateTime + TimeValue;
    TimeOffset := ReadTimeOffset;
  end;
  if Value <> DATETIME_IS_OK then
    RaiseParsingError(peInvalidDateTimeFormat);
  Node.SetValue(DateTime, TimeOffset);
  FCursor := Source;
end;

function TSCLReader.ParseDocument(const Buffer: RawByteString; Document: TSCLDocument; Encoding: TEncoding): TSCLDocument;
begin
  if Encoding = nil then
    Encoding := TEncoding.GuessEncoding(Buffer);
  var Encoded := Encoding.GetString(Buffer);
  if Encoded.IsEmpty and (Buffer <> '') then
    raise ESCLParsingException.CreateResFmt(@sDocumentEncodingError, [FFileName]);
  Result := ParseDocument(Encoded, Document);
end;

function TSCLReader.ParseDocument(const Buffer: string; Document: TSCLDocument = nil): TSCLDocument;
begin
  var DocumentOwner := Document = nil;
  try
    if DocumentOwner then
      Document := TSCLDocument.Create;
    ParseStructure(Document, Pointer(Buffer), Buffer.Length);
  except
    if DocumentOwner then
      FreeAndNil(Document)
    else Document.Clear;
    raise;
  end;
  Result := Document;
end;

function TSCLReader.ParseFile(const AFileName: string; Document: TSCLDocument; Encoding: TEncoding): TSCLDocument;
begin
  FFileName := ExtractFileName(AFileName);
  Result := ParseDocument(ReadSourceFromFile(AFileName), Document, Encoding);
end;

procedure TSCLReader.ParseInlineValue(ParentNode: PSCLNode);
const
  ValueDelims: array [Boolean] of Char = (',', ';');
begin
  { Строчные контейнеры не могут быть вложенными }
  if FInlineEnd <> #32 then
    RaiseParsingError(peNestedValueNotAllowed);
  FInlineEnd := Char(Word(FCursor^) + 2);
  { Параметры для чтения строчного контейнера }
  var ReadNames := FInlineEnd = '}';
  var Delimeter := ValueDelims[ReadNames];
  var CurrentName := string.Empty;
  { Проверяем на завершающую скобку }
  FCursor := SkipSpaces(FCursor + 1);
  if FCursor^ <> FInlineEnd then
  repeat
    { Дальше читаем данные }
    if FCursor^ = '#' then
      RaiseParsingError(peCommentNotAllowedHere, FCursor);
    if ReadNames then
      CurrentName := ReadNodeName(True);
    ParseNodeValue(ParentNode, CurrentName);
    { Требуется разделитель или завершающая скобка }
    if NextToken(FCursor) <> Delimeter then Break;
    { Пропускаем разделитель элементов }
    FCursor := SkipSpaces(FCursor + 1);
  until False;
  case FCursor^ of
    #00: RaiseParsingError(peUnterminatedInline);
    #10, #13: RaiseParsingError(peUnexpectedEndOfLine)
    else if FCursor^ <> FInlineEnd then
      RaiseParsingError(peInvalidValueDelimiter);
  end;
  FInlineEnd := #32;
  Inc(FCursor); // пропускаем ']' / '}'
end;

procedure TSCLReader.ParseNode(var CurrentNode: PSCLNode);
const
  LW_ARRAY_ITEM = $0020002D; // '- '
  NestedTable: array [#00..#35] of Byte = (
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $00, $00, $01, $00, $00,
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $01);
  NestedTypes: array [Boolean] of TSCLNodeType = (ntTable, ntArray);
begin
  var NodeName := string.Empty;
  ValidateIndent(CurrentNode);
  if PLongWord(FCursor)^ = LW_ARRAY_ITEM then
  begin
    { Парсим элемент массива }
    FCursor := SkipSpaces(FCursor + 2);
    var IsNestedArray := PLongWord(FCursor)^ = LW_ARRAY_ITEM;
    if IsNestedArray or (SkipSpaces(ValidateNodeName(FCursor))^ = ':') then
    begin
      { Нашли вложенный массив или таблицу в той же строке }
      CurrentNode := CurrentNode.AddNode(NodeName, NestedTypes[IsNestedArray]);
      ParseNode(CurrentNode);
      Exit;
    end;
  end else
    NodeName := ReadNodeName(True);
  if (FCursor^ <= #35) and (NestedTable[FCursor^] <> 0) then
    { Нашли вложенный массив или таблицу с новой строки }
    CurrentNode := CurrentNode.AddNode(NodeName, ntEmpty)
  else
    ParseNodeValue(CurrentNode, NodeName);
  { Пропускаем комментарии в конце строки }
  if (FCursor > FSource) and (NextToken(FCursor) = '#') then
    FCursor := SkipToLineEnd(FCursor);
end;

procedure TSCLReader.ParseNodeValue(var ParentNode: PSCLNode; const NodeName: string);

  procedure ValidateValue(Token: PChar; Value: Boolean); overload;
  begin
    if SameToken(FCursor, Token) then
      ParentNode.AddValue(NodeName, Value)
    else RaiseParsingError(peUnknownIdentifier);
  end;

  procedure ValidateValue(Token: PChar; Value: Double); overload;
  begin
    if SameToken(FCursor, Token) then
      ParentNode.AddValue(NodeName, Value)
    else RaiseParsingError(peUnknownIdentifier);
  end;

const
  ParsingErrors: array [Boolean] of TSCLParsingError = (peUnknownIdentifier, peIllegalCharacter);
begin
  case FCursor^ of
    '0': case FCursor[1] of
           'b': ParentNode.AddValue(NodeName, ReadBaseTwo(FCursor + 2, 1), nbBin);
           'o': ParentNode.AddValue(NodeName, ReadBaseTwo(FCursor + 2, 3), nbOct);
           'x': ParentNode.AddValue(NodeName, ReadBaseTwo(FCursor + 2, 4), nbHex);
           else ParseNumberOrDate(ParentNode.AddNode(NodeName, ntEmpty), FCursor);
         end;
    '1'..'9': ParseNumberOrDate(ParentNode.AddNode(NodeName, ntEmpty), FCursor);
    '+': case Char(Word(FCursor[1]) or $20) of
           'i': ValidateValue('??nf', Double.PositiveInfinity);
           'n': ValidateValue('??an', Double.NaN);
           else ParseNumberOrDate(ParentNode.AddNode(NodeName, ntEmpty), FCursor + 1, 1);
         end;
    '-': case Char(Word(FCursor[1]) or $20) of
           'i': ValidateValue('??nf', Double.NegativeInfinity);
           'n': ValidateValue('??an', Double.NaN);
           else ParseNumberOrDate(ParentNode.AddNode(NodeName, ntEmpty), FCursor + 1, -1);
         end;
    #34: ParentNode.AddValue(NodeName, ReadString, stDefault);
    #39: ParentNode.AddValue(NodeName, ReadString, stLiteral);
    '%': ParentNode.AddValue(NodeName, ReadBinary(FCursor + 1));
    '[': ParseInlineValue(ParentNode.AddArray(NodeName, True));
    '{': ParseInlineValue(ParentNode.AddTable(NodeName, True));
    '|': ParentNode.AddValue(NodeName, ReadText(ReadTextBlock), stText);
    '>': ParentNode.AddValue(NodeName, ReadText(ReadWrapBlock), stWrapped);
  else
    { Специальные значения без учёта регистра }
    case Char(Word(FCursor^) or $20) of
      'f': ValidateValue('?alse', False);
      'i': ValidateValue('?nf', Double.PositiveInfinity);
      'n': if FCursor[1] = 'o' then
           begin
             ParentNode.AddValue(NodeName, False);
             Inc(FCursor, 2);
           end else if SameToken(FCursor, '?ull') then
             ParentNode.AddNode(NodeName, ntNull)
           else ValidateValue('?an', Double.NaN);
      't': ValidateValue('?rue', True);
      'y': ValidateValue('?es', True);
      else RaiseParsingError(ParsingErrors[FCursor^ < #32]);
    end;
  end;
end;

procedure TSCLReader.ParseNumberOrDate(Node: PSCLNode; Source: PChar; Sign: Integer);

  function ReadInteger(var Buffer: UInt64): Integer;
  begin
    Result := 0;
    repeat
      case Source^ of
        '0'..'9':
          begin
            var Digit := AsDigit(Source^);
            if Buffer > (UInt64.MaxValue - Digit) div 10 then
              RaiseParsingError(peValueOutOfRange);
            Buffer := Buffer * 10 + Digit;
            Inc(Result);
          end;
        '`': if (AsDigit(Source[1]) > 9) or (Result = 0) then
               RaiseParsingError(peInvalidGroupSeparator);
        else Break;
      end;
      Inc(Source);
    until False;
  end;

  function ReadExponent: Integer;
  const
    MaxExponent: array [Boolean] of Integer = (324, 308);
    SignValues:  array [Boolean] of Integer = (-1, 1);
  begin
    Result := 0;
    { Пропускаем символ экспоненты и читаем знак }
    Inc(Source);
    var PositiveExp := Source^ <> '-';
    case Source^ of
      '-', '+': Inc(Source);
    end;
    var MaxValue := MaxExponent[PositiveExp];
    { В цикле читаем значение экспоненты }
    var From := Source;
    repeat
      var Digit := AsDigit(Source^);
      if Digit > 9 then Break;
      Result := Result * 10 + Digit;
      { Защита от переполнения }
      if Result > MaxValue then
        RaiseParsingError(peExponentOutOfRange, Source);
      Inc(Source);
    until False;
    { Проверяем на отсутствие экспоненты и на ведущие нули }
    case Source - From of
      0: RaiseParsingError(peExponentValueMissing);
      1: ;
      else if Source^ = '0' then
        RaiseParsingError(peLeadingZeroNotAllowed);
    end;
    Result := Result * SignValues[PositiveExp];
  end;

const
  MaxValues: array [-1..1] of UInt64 = (UInt64(Int64.MinValue), 0, Int64.MaxValue);
  DateChars: array [2..4] of Char = (':', #0, '-'); // актуально только 2 и 4
begin
  { Инициализация и определение знака }
  var Buffer: UInt64 := 0;
  var Exponent := 0;
  var Fraction := 0;
  var LeadZero := Source^ = '0';
  { Читаем целую часть числа }
  var Magnitude := ReadInteger(Buffer);
  case Magnitude of
    0: RaiseParsingError(peIntegerPartMissing);
    1: LeadZero := False; // единственный ноль допускается
    2, 4: // это может быть дата или время
      if (Source^ = DateChars[Magnitude]) and (Sign = 0) then
      begin
        ParseDateAndTime(Node, Source, Word(Buffer));
        Exit;
      end;
  end;
  { Проверям на наличие ведущих нулей }
  if LeadZero then
    RaiseParsingError(peLeadingZeroNotAllowed);
  { Читаем дробную часть числа, если она есть }
  if Source^ = '.' then
  begin
    Inc(Source);
    Fraction := ReadInteger(Buffer);
    if Fraction = 0 then
      RaiseParsingError(peFractionPartMissing);
  end;
  if Word(Source^) or $20 = Word('e') then
    Exponent := ReadExponent;
  if Sign = 0 then Inc(Sign); // нормализуем неявный знак
  if Fraction or Exponent = 0 then
  begin
    { Целое число без дробной или экспоненциальной части }
    if Buffer > MaxValues[Sign] then
      RaiseParsingError(peValueOutOfRange);
    Node.SetValue(Int64(Buffer) * Sign);
  end else if Buffer <> 0 then
  begin
    var Value := Double(Power10(Extended(Buffer) * Sign, Exponent - Fraction));
    if Value.SpecialType in [fsInf, fsNInf, fsNaN, fsZero, fsNZero] then
      RaiseParsingError(peValueOutOfRange);
    Node.AsDouble := Value;
  end else
    Node.AsDouble := 0.0 * Sign;
  FCursor := Source;
end;

procedure TSCLReader.ParseStructure(Document: TSCLDocument; Buffer: PChar; Count: Integer);
begin
  Document.Clear;
  { Защита от лишних нолей в конце строки }
  if Buffer <> nil then  
    while (Count > 0) and (Buffer[Count - 1] = #0) do Dec(Count);  
  if (Buffer = nil) or (Count = 0) then Exit;
  { Инициализируем внутренние переменные }
  FIndent.Reset;
  FInlineEnd := #32; // не #0 чтобы не конфликтовало с концом файла
  FLineIndex := 0;
  FDocEnd := Buffer + Count;
  if Buffer^ = #$FEFF then
    Inc(Buffer); // пропускаем BOM при его наличии
  FCursor := Buffer;
  FSource := Buffer;
  { Парсим содержимое документа }
  try
    var CurrentNode := Document.Root;
    repeat
      case NextToken(FCursor) of
        #00: if FCursor >= FDocEnd then Break;
        #10, #13: ;
        '#': FCursor := SkipToLineEnd(FCursor + 1);
      else
        ParseNode(CurrentNode);
        if FCursor = FSource then Continue;
      end;    
      SkipLineBreak(FCursor);
    until False;
  except
    on E: ESCLError do
      raise ESCLParsingException.Create(
        FFileName, E.Message, FLineIndex + 1, FCursor - FSource + 1, peInternalSCLError) at ExceptAddr();
  end;
  FFileName := '';
end;

procedure TSCLReader.RaiseParsingError(Error: TSCLParsingError; TokenPos: PChar);
begin
  if TokenPos = nil then
    TokenPos := FCursor;
  case TokenPos^ of
    #00: if (Error = peIllegalCharacter) and (TokenPos = FDocEnd) then Error := peUnexpectedEndOfFile;
    #10: if (TokenPos > FSource) and (TokenPos[-1] = #13) then Dec(TokenPos);
  end;
  var ErrorMessage := SCLParsingErrorMessages[Error];
  raise ESCLParsingException.Create(FFileName, ErrorMessage, FLineIndex + 1, TokenPos - FSource + 1, Error) at ReturnAddress;
end;

function TSCLReader.ReadBaseTwo(Source: PChar; Shift: Integer): Int64;
begin
  Result := 0;
  var MaxDigit := Word(1 shl Shift);
  var Overflow := Source + 64 div Shift + 1;
  repeat
    var Digit := AsHexDigit(Source^);
    if Digit >= MaxDigit then Break;
    Result := Result shl Shift or Digit;
    Inc(Source);
    if Source >= Overflow then
      RaiseParsingError(peValueOutOfRange);
  until False;
  FCursor := Source;
end;

function TSCLReader.ReadBinary(Source: PChar): TBytes;
begin
  var Cursor := Source;
  while AsHexDigit(Cursor^) < $10 do Inc(Cursor);
  var Length := Cursor - Source;
  if Length and $01 <> 0 then
    RaiseParsingError(peInvalidBinaryLength);
  SetLength(Result, Length shr 1);
  for var Index := 0 to High(Result) do
  begin
    Result[Index] := HexMap[Byte(Source[0])] shl 4 or HexMap[Byte(Source[1])];
    Inc(Source, 2);
  end;
  FCursor := Cursor;
end;

class function TSCLReader.ReadFrom(const AFileName: string): TSCLDocument;
begin
  with Create do
  try
    Result := ParseFile(AFileName);
  finally
    Free;
  end;
end;

function TSCLReader.ReadNodeName(IsRequired: Boolean): string;
const
  NodeNameErrors: array [Boolean] of TSCLParsingError = (peInvalidNameCharacter, peNodeNameColonRequired);
begin
  Result := string.Empty;
  var Next := ValidateNodeName(FCursor);
  var Last := Next;
  if Next^ = #32 then
    Last := SkipSpaces(Next);
  if Last^ = ':' then
  begin
    Result := FCursor.SubString(Next);
    { Пустые имена узлов не допускаются }
    if Result.IsEmpty then
      RaiseParsingError(peEmptyNamesNotAllowed);
    FCursor := SkipSpaces(Last + 1);
  end else if IsRequired then
    RaiseParsingError(NodeNameErrors[Next^ = #32], Last);
end;

function TSCLReader.ReadSourceFromFile(const AFileName: string): RawByteString;
begin
  { Открываем файл для чтения }
  var hSource := FileOpen(AFileName, fmOpenRead or fmShareDenyWrite);
  if hSource = INVALID_HANDLE_VALUE then
    raise ESCLParsingException.CreateResFmt(@sDocumentReadingError, [AFileName, SysErrorMessage(GetLastError)]);
  try
    var FileSize := GetFileSize(hSource, nil);
    if FileSize >= Word.MaxValue then
      raise ESCLParsingException.CreateResFmt(@sDocumentFileTooLarge, [AFileName]);
    SetLength(Result, FileSize);
    if (FileSize > 0) and (FileRead(hSource, PByte(Result)^, Length(Result)) <> Integer(FileSize)) then
      raise ESCLParsingException.CreateResFmt(@sDocumentReadingError, [AFileName, SysErrorMessage(GetLastError)]);
  finally
    FileClose(hSource);
  end;
end;

function TSCLReader.ReadString: string;

  function AppendCharByCode(Source: PChar; Length: Integer): PChar;
  begin
    var CharCode: Integer := 0;
    for var Index := 1 to Length do
    begin
      var Digit := AsHexDigit(Source[Index]);
      if Digit < $10 then
        CharCode := CharCode shl 4 or Digit
      else RaiseParsingError(peIllegalCharacter, Source + Index);
    end;
    if CharCode > $10FFFF then
      RaiseParsingError(peIllegalCharacterCode, Source - 1);
    if CharCode shr 16 <> 0 then
    begin
      Dec(CharCode, $10000);
      FStringBuf.Append(Char($D800 or CharCode shr 10));
      FStringBuf.Append(Char($DC00 or CharCode and $3FF));
    end else FStringBuf.Append(Char(CharCode));
    Result := Source + Length;
  end;

  function AppendSpecialCharacter(Source: PChar): PChar;
  begin
    Inc(Source);
    case Source^ of
      '\',
      '"': FStringBuf.Append(Source^);
      'b': FStringBuf.Append(#08);
      't': FStringBuf.Append(#09);
      'n': FStringBuf.Append(#10);
      'f': FStringBuf.Append(#12);
      'r': FStringBuf.Append(#13);
      'e': FStringBuf.Append(#27);
      'x': Source := AppendCharByCode(Source, 2);
      'u': Source := AppendCharByCode(Source, 4);
      'U': Source := AppendCharByCode(Source, 6);
      else RaiseParsingError(peIllegalEscapeSequence, Source - 1);
    end;
    Result := Source;
  end;

begin
  FStringBuf.Reset;
  var Quote := FCursor^;
  var Source := FCursor + 1;
  var Cursor := Source;
  repeat
    var Ch := Cursor^;
    if Word(Ch) and $FF80 = 0 then
      case StringMap[Ch] and $0F of
        STR_VALID: ;
        STR_QUOTE:
          if Ch = Quote then
            if Ch = Cursor[1] then
            begin
              Inc(Cursor);
              FStringBuf.Append(Source, Cursor - Source);
              Source := Cursor + 1;
            end else Break;
        STR_ESCAPE:
          if Quote = '"' then
          begin
            { Найден экранированный символ }
            FStringBuf.Append(Source, Cursor - Source);
            Cursor := AppendSpecialCharacter(Cursor);
            Source := Cursor + 1;
          end;
        STR_BREAK: RaiseParsingError(peUnterminatedString, Source);
      else
        if (Cursor^ = #0) and (Cursor = FDocEnd) then
          RaiseParsingError(peUnterminatedString, Cursor);
        RaiseParsingError(peIllegalCharacter, Cursor);
      end;
    Inc(Cursor);
  until False;
  { Вовращаем прочитанную строку }
  Result := FStringBuf.Append(Source, Cursor - Source).ToString;
  FCursor := Cursor + 1; // пропускаем кавычки
end;

function TSCLReader.ReadText(TextReader: TTextReader): string;
begin
  if FInlineEnd <> #32 then
    RaiseParsingError(peInlineTextNotAllowed);
  var Source := FCursor + 1; // пропускаем '|' / '>'
  { Пытаемся считать отступ строки [2..8] }
  var FixedIndent := Word(AsDigit(Source^) - 2);
  if FixedIndent <= 6 then
    Inc(Source);
  { Проверяем режим обрезки пустых строк }
  var EmptyLines := elSkipLast;
  case Source^ of
    '+': EmptyLines := elSkipNone;
    '-': EmptyLines := elSkipAny;
    else Dec(Source); // шаг назад для inc()
  end;
  Inc(Source);
  { Пропускаем комментарий в строке при его наличии }
  if NextToken(Source) = '#' then
    Source := SkipToLineEnd(Source);
  { Переходим к содержимому текстового блока }
  SkipLineBreak(Source);
  { Определяем динамический отступ значений }
  if FixedIndent <= 6 then
    FIndent.Increment(FixedIndent + 2)
  else if not FIndent.SetIndent(SkipSpaces(FCursor) - FCursor) then
    Exit(string.Empty); // конец файла или пустой текстовый блок
  { Читаем текстовый блок построчно }
  FStringBuf.Reset;
  TextReader(EmptyLines);
  Result := FStringBuf.ToString;
  { Уменьшаем оступ для текущего уровня }
  FIndent.Decrement;
end;

procedure TSCLReader.ReadTextBlock(EmptyLines: TEmptyLines);
begin
  var Source: PChar;
  var Indent := FIndent.Value;
  while TestIndent(FCursor, Source, Indent) do
  begin
    if FCursor > Source then
      FStringBuf.Append(Source, FCursor - Source).AppendLineBreak
    else if EmptyLines <> elSkipAny then
      FStringBuf.AppendLineBreak;
    SkipLineBreak(FCursor);
  end;
  { Обрезаем пустые строки в конце при необходимости }
  if EmptyLines <> elSkipNone then
    FStringBuf.TrimBreaks;
end;

procedure TSCLReader.ReadWrapBlock(EmptyLines: TEmptyLines);
begin
  var AppendEmpty := True;
  var Indent := FIndent.Value;
  var TrimLength := 0;
  var Source: PChar;
  while TestIndent(FCursor, Source, Indent) do
  begin
    { Обрезаем пробелы в конце строки }
    var Index := FCursor - Source - 1;
    while (Index >= 0) and (Source[Index] = #32) do
      Dec(Index);
    { Копируем строку в буфер, если есть что копировать }
    if Index >= 0 then
      if Source[Index] = '\' then
      begin
        FStringBuf.Append(Source, Index);
        TrimLength := FStringBuf.Length;
      end else
      begin
        FStringBuf.Append(Source, Index + 1).Append(#32);
        TrimLength := FStringBuf.Length - 1;
      end
    else if AppendEmpty then
      FStringBuf.AppendLineBreak; // параграф
    AppendEmpty := (Index >= 0) or (EmptyLines <> elSkipAny);
    SkipLineBreak(FCursor);
  end;
  if EmptyLines <> elSkipNone then
    { Обрезаем пустые строки в конце }
    FStringBuf.Length := TrimLength
  else if FStringBuf.Length <> TrimLength then
    { Обрезаем только последний пробел }
    FStringBuf.TrimSpace;
end;

procedure TSCLReader.SkipLineBreak(var Source: PChar);
begin
  { Проверяем и пропускаем перевод строки Lf или CrLf }
  case Source^ of
    #10: Inc(Source);
    #13: if Source[1] = #10 then Inc(Source, 2)
         else RaiseParsingError(peInvalidLineEnding, Source);
    else if (Source^ <> #0) or (Source <> FDocEnd) then
      RaiseParsingError(peIllegalCharacter, Source);
  end;
  FCursor := Source;
  FSource := Source;
  Inc(FLineIndex);
end;

procedure TSCLReader.ValidateIndent(var CurrentNode: PSCLNode);
begin
  var Indent := FCursor - FSource;
  if not CurrentNode.IsEmpty then
  begin
    { При необходимости идём назад по уровням }
    while FIndent.Value > Indent do
    begin
      CurrentNode := CurrentNode.Parent;
      FIndent.Decrement;
      if CurrentNode = nil then
        RaiseParsingError(peInvalidIndentStack);
    end;
    { Проверяем что отступ значения совпадает с текущим уровнем }
    if FIndent.Value <> Indent then
      RaiseParsingError(peInvalidValueIndent);
  { Для пустых контейнеров запоминаем новый отступ }
  end else if not FIndent.SetIndent(Indent) then
    RaiseParsingError(peInvalidValueIndent);
end;

end.

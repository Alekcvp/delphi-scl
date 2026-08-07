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
  {$IFDEF MSWINDOWS} Winapi.Windows, {$ENDIF} System.SysUtils, SCL.Common, SCL.Document;

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
    class function GuessEncoding(Buffer: PByte; Count: Integer): TEncoding;
  end;

  TSCLReader = class
  private
    FFileName: string;          // имя исходного файла с документом
    FCursor: PChar;             // текущее положение в документе
    FDocEnd: PChar;             // конец текста (завершающий #0)
    FIndent: TIndentStack;      // стек с отступами уровней
    FInlineEnd: Char;           // символ завершения строчного массива или таблицы
    FLineIndex: Integer;        // индекс текущей строки (с 0)
    FLineStart: PChar;          // начало текущей строки
    FStringBuf: TStringBuffer;  // буфер для чтения строк и текста
  protected
     function EncodeSource(const Buffer: TBytes; Encoding: TEncoding): string;
     function ReadSourceFromFile(const AFileName: string): string;
    procedure ParseInlineValue(ParentNode: PSCLNode);
     function ParseArrayItem(var ParentNode: PSCLNode): Boolean;
    procedure ParseNodeValue(var ParentNode: PSCLNode; const Name: string);
    procedure ParseNumberOrDate(Node: PSCLNode; Source: PChar; Sign: Integer = 1);
    procedure ParseStructure(Document: TSCLDocument; const ASource: string);
    procedure RaiseParsingError(Error: TSCLParsingError; TokenPos: PChar = nil);
     function ReadBaseTwo(Source: PChar; Shift: Integer): Int64;
     function ReadBinary: TBytes;
     function ReadDateTime(Year: Word; var TimeOffset: SmallInt): TDateTime;
     function ReadNodeName(IsRequired: Boolean): string;
     function ReadString: string;
     function ReadText(const LineBreak: string): string;
     function ReadTime(Hour: Word): TDateTime;
     function ReadWord(MaxValue, Length: Word): Word;
     function SkipLineBreak(Source: PChar): PChar; 
    procedure ValidateIndent(var CurrentNode: PSCLNode);
  public
    constructor Create;
    destructor Destroy; override;
     function ParseDocument(const Buffer: TBytes): TSCLDocument; overload; inline;
     function ParseDocument(const Source: string): TSCLDocument; overload;
    procedure ParseDocument(const Buffer: TBytes; var Document: TSCLDocument); overload;
    procedure ParseDocument(const Source: string; var Document: TSCLDocument); overload; inline;
     function ParseFile(const AFileName: string): TSCLDocument; overload; inline;
    procedure ParseFile(const AFileName: string; var Document: TSCLDocument); overload; inline;
    procedure SetLineBreaks(const LineBreak: string); inline;
    class function ReadFrom(const AFileName: string): TSCLDocument;
  end;


implementation

resourcestring
  sDocumentEncodingError = '%s: %s при преобразовании кодировки';
  sDocumentParsingError  = '%s(%d, %d): %s';
  sDocumentReadingError  = 'Ошибка чтения "%s". %s';

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

type
  TSCLTokenType = (tkNone, tkArrayItem, tkNodeName);

  HStringBuffer = class helper for TStringBuffer
    function AppendLine(Buf: PChar; Count: Integer; TrimEnd: Boolean): Boolean;
  end;

const
  DOUBLE_MAX_EXP = 308;
  DOUBLE_MIN_EXP = -324;
  DOUBLE_MAX_INT = 9007199254740991; // максимальное целое значение в Double

var
  HexToBinTable: TBytes = nil; // таблица для быстрых 16-ричных преобразований

function SameToken(var Source: PChar; Token: PChar): Boolean;
begin
  var Index := Source - Token;
  while Token^ = '?' do Inc(Token);
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

function SkipToLineEnd(Source: PChar): PChar; inline;
begin
  while (Word(Source^) and $FF80 <> 0) or (StringMap[Source^] and $01 = 0) do
    Inc(Source);
  Result := Source;
end;

function NextToken(var Source: PChar; Skip: Integer = 0): Char; inline;
begin
  var Cursor := Source + Skip;
  while Cursor^ = #32 do
    Inc(Cursor);
  Source := Cursor;
  Result := Cursor^;
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

function SameBytes(Buffer: PByte; const [ref] Value: array of Byte): Boolean;
begin
  for var Index := 0 to High(Value) do
    if Buffer[Index] <> Value[Index] then
      Exit(False);
  Result := True;
end;

class function HEncoding.GuessEncoding(Buffer: PByte; Count: Integer): TEncoding;
const
  UTF8BOM: array [0..2] of Byte = ($EF, $BB, $BF);
  UTF16LE: array [0..1] of Byte = ($FF, $FE);
  UTF16BE: array [0..1] of Byte = ($FE, $FF);
begin
  { Валидный не пустой SCL-документ не может быть короче 3х байт }
  if Count < 3 then
    Exit(TEncoding.UTF8);
  { Проверяем наличие BOM }
  if SameBytes(@Buffer[0], UTF8BOM) then
    Exit(TEncoding.UTF8);
  if SameBytes(@Buffer[0], UTF16LE) then
    Exit(TEncoding.Unicode);
  if SameBytes(@Buffer[0], UTF16BE) then
    Exit(TEncoding.BigEndianUnicode);
  { В UTF-16 с большой вероятностью встретится нулевой байт, который недопустим в UTF-8 }
  for var Index := 0 to Min(15, Count - 1) do
    if Buffer[Index] = 0 then
      if Index and $01 <> 0 then
        Exit(TEncoding.Unicode)
      else Exit(TEncoding.BigEndianUnicode);
  Result := TEncoding.UTF8;
end;

{ HStringBuffer }

function HStringBuffer.AppendLine(Buf: PChar; Count: Integer; TrimEnd: Boolean): Boolean;
begin
  var Last := Buf + Count - 1;
  if TrimEnd then
  begin
    while (Last > Buf) and (Last^ = #32) do
      Dec(Last);
    if Last^ = '\' then
    begin
      Append(Buf, Last - Buf);
      Exit(False);
    end;
  end;
  Append(Buf, Last - Buf + 1);
  Result := True;
end;

{ TSCLReader }

constructor TSCLReader.Create;
begin
  if Length(HexToBinTable) = 0 then
  begin
    { Инициализируем таблицу шестнадцатеричных преобразований }
    SetLength(HexToBinTable, $10000);
    FillChar(PByte(HexToBinTable)^, Length(HexToBinTable), $FF);
    for var Index := Ord('0') to Ord('9') do
      HexToBinTable[Index] := Index - Ord('0');
    for var Index := Ord('A') to Ord('F') do
    begin
      HexToBinTable[Index] := Index - Ord('A') + 10;
      HexToBinTable[Index or $20] := HexToBinTable[Index];
    end;
  end;
  FStringBuf := TStringBuffer.Create;
end;

destructor TSCLReader.Destroy;
begin
  FStringBuf.Free;
end;

function TSCLReader.EncodeSource(const Buffer: TBytes; Encoding: TEncoding): string;
begin
  if Encoding = TEncoding.Unicode then
  begin
    SetString(Result, PChar(Buffer), Length(Buffer) shr 1);
    Exit;
  end;
  Result := Encoding.GetString(Buffer);
  if Result.IsEmpty and (Length(Buffer) > 0) then
    raise ESCLParsingException.CreateResFmt(@sDocumentEncodingError, [FFileName, SysErrorMessage(GetLastError)]);
end;

procedure TSCLReader.ParseDocument(const Buffer: TBytes; var Document: TSCLDocument);
begin
  ParseDocument(EncodeSource(Buffer, TEncoding.GuessEncoding(PByte(Buffer), Length(Buffer))), Document);
end;

function TSCLReader.ParseDocument(const Source: string): TSCLDocument;
begin
  Result := TSCLDocument.Create;
  try
    ParseDocument(Source, Result);
  except
    Result.Free;
    raise;
  end;
end;

function TSCLReader.ParseDocument(const Buffer: TBytes): TSCLDocument;
begin
  Result := ParseDocument(EncodeSource(Buffer, TEncoding.GuessEncoding(PByte(Buffer), Length(Buffer))));
end;

function TSCLReader.ParseArrayItem(var ParentNode: PSCLNode): Boolean;
const
  NestedTypes: array [Boolean] of TSCLNodeType = (ntTable, ntArray);
  LW_ARRAY_ITEM = $0020002D;
begin
  { Проверяем отступ текущего элемента }
  ValidateIndent(ParentNode);
  case FCursor[1] of
    #10, #13, '#', #32: ;
    else RaiseParsingError(peIllegalCharacter);
  end;
  FCursor := SkipSpaces(FCursor + 1);
  { Проверяем на вложенный массив или таблицу }
  var IsNestedArray := PLongWord(FCursor)^ = LW_ARRAY_ITEM;
  if IsNestedArray or (SkipSpaces(ValidateNodeName(FCursor))^ = ':') then
  begin
    ParentNode := ParentNode.AddNode(string.Empty, NestedTypes[IsNestedArray]);
    Exit(False);
  end;
  { Читаем значение элемента }
  ParseNodeValue(ParentNode, string.Empty);
  { Мы завершили чтение строки, можно идти дальше }
  Result := True;
end;

procedure TSCLReader.ParseDocument(const Source: string; var Document: TSCLDocument);
begin
  FFileName := '<memory>';
  ParseStructure(Document, Source);
end;

function TSCLReader.ParseFile(const AFileName: string): TSCLDocument;
begin
  Result := TSCLDocument.Create;
  try
    FFileName := ExtractFileName(AFileName);
    ParseStructure(Result, ReadSourceFromFile(AFileName));
  except
    Result.Free;
    raise;
  end;
end;

procedure TSCLReader.ParseFile(const AFileName: string; var Document: TSCLDocument);
begin
  FFileName := ExtractFileName(AFileName);
  ParseStructure(Document, ReadSourceFromFile(AFileName));
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
  var ValueName := string.Empty;
  { Проверяем на завершающую скобку }
  if NextToken(FCursor, 1) <> FInlineEnd then
  repeat
    { Для таблиц читаем имя узла }
    if ReadNames and (FCursor^ <> '#') then
      ValueName := ReadNodeName(True);
    { Дальше читаем данные }
    if FCursor^ = '#' then
      RaiseParsingError(peCommentNotAllowedHere);
    ParseNodeValue(ParentNode, ValueName);
    { Требуется разделитель или завершающая скобка }
    if FCursor^ <> Delimeter then Break;
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

procedure TSCLReader.ParseNodeValue(var ParentNode: PSCLNode; const Name: string);

  procedure ValidateValue(Token: PChar; Value: Boolean); overload;
  begin
    if SameToken(FCursor, Token) then
      ParentNode.AddValue(Name, Value)
    else RaiseParsingError(peUnknownIdentifier);
  end;

  procedure ValidateValue(Token: PChar; Value: Double); overload;
  begin
    if SameToken(FCursor, Token) then
      ParentNode.AddValue(Name, Value)
    else RaiseParsingError(peUnknownIdentifier);
  end;

const
  ParsingErrors: array [Boolean] of TSCLParsingError = (peUnknownIdentifier, peIllegalCharacter);
begin
  var NextChar := FCursor^;
  case NextChar of
    #10, #13, '#': ParentNode := ParentNode.AddArray(Name, False); // у нас новый дочерний узел
    '0': case FCursor[1] of
           'b': ParentNode.AddValue(Name, ReadBaseTwo(FCursor + 2, 1), nbBin);
           'o': ParentNode.AddValue(Name, ReadBaseTwo(FCursor + 2, 3), nbOct);
           'x': ParentNode.AddValue(Name, ReadBaseTwo(FCursor + 2, 4), nbHex);
           else ParseNumberOrDate(ParentNode.AddNode(Name, ntEmpty), FCursor);
         end;
    '1'..'9': ParseNumberOrDate(ParentNode.AddNode(Name, ntEmpty), FCursor);
    '+': case Char(Word(FCursor[1]) or $20) of
           'i': ValidateValue('??nf', Double.PositiveInfinity);
           'n': ValidateValue('??an', Double.NaN);
           else ParseNumberOrDate(ParentNode.AddNode(Name, ntEmpty), FCursor + 1);
         end;
    '-': case Char(Word(FCursor[1]) or $20) of
           'i': ValidateValue('??nf', Double.NegativeInfinity);
           'n': ValidateValue('??an', Double.NaN);
           else ParseNumberOrDate(ParentNode.AddNode(Name, ntEmpty), FCursor + 1, -1);
         end;
    #34: ParentNode.AddValue(Name, ReadString, stDefault);
    #39: ParentNode.AddValue(Name, ReadString, stLiteral);
    '%': ParentNode.AddValue(Name, ReadBinary);
    '[': ParseInlineValue(ParentNode.AddArray(Name, True));
    '{': ParseInlineValue(ParentNode.AddTable(Name, True));
    '~': begin
           ParentNode.AddNode(Name, ntNull);
           Inc(FCursor);
         end;
    '|': ParentNode.AddValue(Name, ReadText(FStringBuf.LineBreak), stText);
    '>': ParentNode.AddValue(Name, ReadText(#32), stWrapped);
  else
    { Специальные значения без учёта регистра }
    case Char(Word(NextChar) or $20) of
      'f': ValidateValue('?alse', False);
      'i': ValidateValue('?nf', Double.PositiveInfinity);
      'n': if FCursor[1] = 'o' then
           begin
             ParentNode.AddValue(Name, False);
             Inc(FCursor, 2);
           end else ValidateValue('?an', Double.NaN);
      't': ValidateValue('?rue', True);
      'y': ValidateValue('?es', True);
      else RaiseParsingError(ParsingErrors[FCursor^ < #32]);
    end;
  end;
  { Пропускаем комментарии в конце строки }
  if NextToken(FCursor) = '#' then
    FCursor := SkipToLineEnd(FCursor);
end;

procedure TSCLReader.ParseNumberOrDate(Node: PSCLNode; Source: PChar; Sign: Integer);

  function ReadInteger(var Source: PChar; var Buffer: UInt64): Integer;
  begin
    Result := 0;
    var NextChar := Source;
    var Ch := NextChar^;
    { Число не может начинаться с разделителя групп }
    if Ch = '`' then
      RaiseParsingError(peInvalidGroupSeparator);
    repeat
      var Digit := AsDigit(Ch);
      if Digit <= 9 then
        if Buffer < UInt64.MaxValue div 10 then
        begin
          Buffer := Buffer * 10 + Digit;
          Inc(Result);
        end else RaiseParsingError(peValueOutOfRange)
      else if Ch <> '`' then
        Break
      { После разделителя групп обязательно должна идти цифра }
      else if AsDigit(NextChar[1]) > 9 then
        RaiseParsingError(peInvalidGroupSeparator);
      Inc(NextChar);
      Ch := NextChar^;
    until False;
    Source := NextChar;
  end;

  function ReadExponent(var Source: PChar): Integer;
  const
    MaxExponent: array [-1..1] of Integer = (324, 0, 308);
  begin
    { Пропускаем символ экспоненты и читаем знак }
    Inc(Source);
    Result := 0;
    var ExpSign := 1;
    case Source^ of
      '-': begin
             ExpSign := -1;
             Inc(Source);
           end;
      '+': Inc(Source);
    end;
    var MaxValue := MaxExponent[ExpSign];
    { В цикле читаем значение экспоненты }
    var NextChar := Source;
    repeat
      var Digit := AsDigit(NextChar^);
      if Digit > 9 then
        Break;
      Result := Result * 10 + Digit;
      { Защита от переполнения }
      if Result > MaxValue then
        RaiseParsingError(peExponentOutOfRange, Source);
      Inc(NextChar);
    until False;
    { Проверяем на отсутствие экспоненты и на ведущие нули }
    case NextChar - Source of
      0: RaiseParsingError(peExponentValueMissing);
      1: ;
      else if Source^ = '0' then
        RaiseParsingError(peLeadingZeroNotAllowed);
    end;
    Source := NextChar;
    Result := Result * ExpSign;
  end;

  function ReadFraction(var Source: PChar; var Value: UInt64): Integer;
  begin
    { Максимальное значение целой части числа с приемлемой точностью }
    if Value > DOUBLE_MAX_INT then
      RaiseParsingError(peValueOutOfRange);
    Inc(Source);
    Result := ReadInteger(Source, Value);
    if Result = 0 then
      RaiseParsingError(peFractionPartMissing);
  end;

const
  MaxValues: array [-1..1] of UInt64 = (UInt64(Int64.MinValue), 0, Int64.MaxValue);
var
  TimeOffset: SmallInt;
begin
  { Инициализация и определение знака }
  var Buffer: UInt64 := 0;
  var Exponent := 0;
  var Fraction := 0;
  var LeadZero := FCursor^ = '0';
  { Читаем целую часть числа }
  var Magnitude := ReadInteger(Source, Buffer);
  if Magnitude = 0 then
    RaiseParsingError(peIntegerPartMissing);
  { Проверяем на дата, время или дробное значение }
  case Source^ of
    '-': if Magnitude = 4 then
         begin
           FCursor := Source;
           Node.SetValue(ReadDateTime(Word(Buffer), TimeOffset), TimeOffset);
           Exit;
         end;
    ':': if Magnitude = 2 then
         begin
           FCursor := Source;
           Node.SetValue(ReadTime(Word(Buffer)), TIME_OFFSET_LOCAL);
           Exit;
         end;
    '.': Fraction := ReadFraction(Source, Buffer);
  end;
  if (Magnitude > 1) and LeadZero then
      RaiseParsingError(peLeadingZeroNotAllowed);
  if Word(Source^) or $20 = Word('e') then
    Exponent := ReadExponent(Source);
  if Fraction or Exponent = 0 then
  begin
    { Целое число без дробной или экспоненциальной части }
    if Buffer > MaxValues[Sign] then
      RaiseParsingError(peValueOutOfRange);
    Node.SetValue(Int64(Buffer) * Sign);
  end else
  begin
    { Дробное число или число с экспонентой }
    Magnitude := LongWord(Exponent + Magnitude - DOUBLE_MIN_EXP);
    if Magnitude > DOUBLE_MAX_EXP - DOUBLE_MIN_EXP + 1 then
      RaiseParsingError(peValueOutOfRange);
    Node.SetValue(Double(Power10(Int64(Buffer) * Sign, Exponent - Fraction)));
  end;
  FCursor := Source;
end;

procedure TSCLReader.ParseStructure(Document: TSCLDocument; const ASource: string);
begin
  Document.Clear;
  { Инициализируем внутренние переменные }
  FLineIndex := 0;
  FCursor := PChar(ASource);
  FDocEnd := FCursor + ASource.Length;
  { Пропускаем BOM при его наличии }
  if FCursor^ = #$FEFF then 
    Inc(FCursor); 
  FLineStart := FCursor;
  { Парсим содержимое документа }
  if FCursor < FDocEnd then
  try
    FIndent.Reset;
    FInlineEnd := #32; // не #0 чтобы не конфликтовало с концом файла
    var CurrentNode := Document.Root;
    repeat
      case NextToken(FCursor) of
        #00, #13, #10: { Пропускаем };
        '#': FCursor := SkipToLineEnd(FCursor);
        '-': if not ParseArrayItem(CurrentNode) then Continue; // чтение строки не завершено
      else
        { Проверяем отступ текущего элемента }
        ValidateIndent(CurrentNode);
        ParseNodeValue(CurrentNode, ReadNodeName(True));
      end;
      { Пытаемся перейти на новую строку }
      FCursor := SkipLineBreak(FCursor);
      FLineStart := FCursor;
      Inc(FLineIndex);
    until FCursor^ = #0;
  except
    on E: ESCLError do
      raise ESCLParsingException.Create(
        FFileName, E.Message, FLineIndex + 1, FCursor - FLineStart + 1, peInternalSCLError) at ExceptAddr();
  end;
end;

procedure TSCLReader.RaiseParsingError(Error: TSCLParsingError; TokenPos: PChar);
var
  ErrorMessage: string;
begin
  if TokenPos = nil then
    TokenPos := FCursor;
  case TokenPos^ of
    #00: if (Error = peIllegalCharacter) and (TokenPos = FDocEnd) then Error := peUnexpectedEndOfFile;
    #10: if (TokenPos > FLineStart) and (TokenPos[-1] = #13) then Dec(TokenPos);
  end;
  case Error of
    peCommentNotAllowedHere: ErrorMessage := sCommentNotAllowedHere;
    peDateDecodingFailed:    ErrorMessage := sDateDecodingFailed;
    peEmptyNamesNotAllowed:  ErrorMessage := sEmptyNamesNotAllowed;
    peExponentOutOfRange:    ErrorMessage := sExponentOutOfRange;
    peExponentValueMissing:  ErrorMessage := sExponentValueMissing;
    peFractionPartMissing:   ErrorMessage := sFractionPartMissing;
    peIllegalCharacter:      ErrorMessage := sIllegalCharacter;
    peIllegalCharacterCode:  ErrorMessage := sIllegalCharacterCode;
    peIllegalEscapeSequence: ErrorMessage := sIllegalEscapeSequence;
    peInlineTextNotAllowed:  ErrorMessage := sInlineTextNotAllowed;
    peInvalidIndentStack:    ErrorMessage := sInvalidIndentStack;
    peIntegerPartMissing:    ErrorMessage := sIntegerPartMissing;
    peInvalidBinaryLength:   ErrorMessage := sInvalidBinaryLength;
    peInvalidDateTimeFormat: ErrorMessage := sInvalidDateTimeFormat;
    peInvalidDateTimeValue:  ErrorMessage := sInvalidDateTimeValue;
    peInvalidGroupSeparator: ErrorMessage := sInvalidGroupSeparator;
    peInvalidLineEnding:     ErrorMessage := sInvalidLineEnding;
    peInvalidNameCharacter:  ErrorMessage := sInvalidNameCharacter;
    peInvalidValueDelimiter: ErrorMessage := sInvalidValueDelimiter;
    peInvalidValueIndent:    ErrorMessage := sInvalidValueIndent;
    peLeadingZeroNotAllowed: ErrorMessage := sLeadingZeroNotAllowed;
    peNestedValueNotAllowed: ErrorMessage := sNestedValueNotAllowed;
    peNodeNameColonRequired: ErrorMessage := sNodeNameColonRequired;
    peTimeDecodingFailed:    ErrorMessage := sTimeDecodingFailed;
    peUnexpectedEndOfFile:   ErrorMessage := sUnexpectedEndOfFile;
    peUnexpectedEndOfLine:   ErrorMessage := sUnexpectedEndOfLine;
    peUnknownIdentifier:     ErrorMessage := sUnknownIdentifier;
    peUnterminatedInline:    ErrorMessage := sUnterminatedInline;
    peUnterminatedString:    ErrorMessage := sUnterminatedString;
    peValueOutOfRange:       ErrorMessage := sValueOutOfRange;
    else ErrorMessage := sUnknownParsingError;
  end;
  raise ESCLParsingException.Create(FFileName, ErrorMessage, FLineIndex + 1, TokenPos - FLineStart + 1, Error) at ReturnAddress;
end;

function TSCLReader.ReadBaseTwo(Source: PChar; Shift: Integer): Int64;
begin
  Result := 0;
  var MaxDigit := Word(1 shl Shift);
  var Overflow := Source + 64 div Shift + 1;
  repeat
    var Digit := HexToBinTable[Word(Source^)];
    if Digit >= MaxDigit then
      Break;
    Result := Result shl Shift or Digit;
    Inc(Source);
    if Source >= Overflow then
      RaiseParsingError(peValueOutOfRange);
  until False;
  FCursor := Source;
end;

function TSCLReader.ReadBinary: TBytes;
begin
  var Source := FCursor + 1; // пропустили %
  var Cursor := Source;
  while HexToBinTable[Word(Cursor^)] < 16 do
    Inc(Cursor);
  var Length := Cursor - Source;
  if Length and $01 <> 0 then
    RaiseParsingError(peInvalidBinaryLength);
  SetLength(Result, Length shr 1);
  for var Index := 0 to High(Result) do
  begin
    Result[Index] := HexToBinTable[Word(Source[0])] shl 4 or HexToBinTable[Word(Source[1])];
    Inc(Source, 2);
  end;
  FCursor := Cursor;
end;

function TSCLReader.ReadDateTime(Year: Word; var TimeOffset: SmallInt): TDateTime;

  function ReadTimeOffset: SmallInt;
  begin
    var Hour := ReadWord(23, 2);
    if FCursor^ <> ':' then
      RaiseParsingError(peInvalidDateTimeFormat);
    Result := Hour * MinsPerHour + ReadWord(59, 2);
  end;

begin
  TimeOffset := TIME_OFFSET_LOCAL;
  if FCursor^ <> '-' then
    RaiseParsingError(peInvalidDateTimeFormat);
  var Month := ReadWord(12, 2);
  if FCursor^ <> '-' then
    RaiseParsingError(peInvalidDateTimeFormat);
  var Day := ReadWord(31, 2);
  if not TryEncodeDate(Year, Month, Day, Result) then
    RaiseParsingError(peDateDecodingFailed);
  var NextChar := Word(FCursor^);
  if (NextChar = 32) and (AsDigit(FCursor[1]) <= 9) or (NextChar or $20 = Word('t')) then
  begin
    Result := Result + ReadTime(ReadWord(23, 2));
    case FCursor^ of
      '+': TimeOffset :=  ReadTimeOffset;
      '-': TimeOffset := -ReadTimeOffset;
      'Z', 'z':
        begin
          TimeOffset := 0;
          Inc(FCursor);
        end;
    end;
  end;
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
  Result := '';
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

function TSCLReader.ReadSourceFromFile(const AFileName: string): string;
var
  Header: array [0..15] of Byte;
begin
  { Открываем файл для чтения }
  var hSource := FileOpen(AFileName, fmOpenRead or fmShareDenyWrite);
  if hSource = INVALID_HANDLE_VALUE then
    raise ESCLParsingException.CreateResFmt(@sDocumentReadingError, [AFileName, SysErrorMessage(GetLastError)]);
  try
    { Пытаемся определить кодировку файла }
    var Count := FileRead(hSource, Header, Length(Header));
    var Encoding := TEncoding.GuessEncoding(@Header, Count);
    var FileSize := FileSeek(hSource, 0, FILE_END);
    FileSeek(hSource, 0, FILE_BEGIN);
    { Читаем содержимое файла и при необходимости преобразовываем к Unicode }
    if Encoding = TEncoding.Unicode then
    begin
      SetLength(Result, FileSize shr 1);
      if FileRead(hSource, PByte(Result)^, FileSize) <> FileSize then
        raise ESCLParsingException.CreateResFmt(@sDocumentReadingError, [AFileName, SysErrorMessage(GetLastError)]);
    end else
    begin
      var Buffer: TBytes;
      SetLength(Buffer, FileSize);
      if FileRead(hSource, PByte(Buffer)^, FileSize) <> FileSize then
        raise ESCLParsingException.CreateResFmt(@sDocumentReadingError, [AFileName, SysErrorMessage(GetLastError)]);
      Result := EncodeSource(Buffer, Encoding)
    end;
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
      var Digit := HexToBinTable[Word(Source[Index])];
      if Digit <= 15 then
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
    Result := Source + 1;
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
            Source := AppendSpecialCharacter(Cursor);
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

function TSCLReader.ReadText(const LineBreak: string): string;
begin
  if FInlineEnd <> #32 then
    RaiseParsingError(peInlineTextNotAllowed);
  var IsWrappedString := FCursor^ = '>';
  Inc(FCursor); // пропускаем '|' / '>'
  { Пытаемся считать отступ строки [2..8] }
  var FixedIndent := AsDigit(FCursor^);
  if Word(FixedIndent - 2) > 6 then
    FixedIndent := 0
  else Inc(FCursor);
  { Пропускаем комментарий в строке при его наличии }
  if NextToken(FCursor) = '#' then
    FCursor := SkipToLineEnd(FCursor);
  { Переходим к содержимому текстового блока }
  var Source := SkipLineBreak(FCursor);
  { Определяем динамический отступ значений }
  if FixedIndent <> 0 then
    FIndent.Increment(FixedIndent)
  else if not FIndent.SetIndent(SkipSpaces(Source) - Source) then
    Exit(string.Empty); // конец файла или пустой текстовый блок
  { Читаем текстовый блок построчно }
  FStringBuf.Reset;
  repeat
    case Source^ of
      #00: Break;
      #13, #10:
        if not IsWrappedString then
          FStringBuf.Append(LineBreak);
    else
      var Cursor := Source;
      for var Index := 1 to FIndent.Value do
        if Cursor^ = #32 then Inc(Cursor);
      if Cursor - Source < FIndent.Value then Break;
      Source := SkipToLineEnd(Cursor);
      if FStringBuf.AppendLine(Cursor, Source - Cursor, IsWrappedString) then
        FStringBuf.Append(LineBreak);
      FStringBuf.Bookmark;
    end;
    { Завершаем перевод строки }
    FCursor := Source;
    FLineStart := Source;
    Inc(FLineIndex);
    { Переходим на новую строку }
    Source := SkipLineBreak(Source);
  until False;
  { Уменьшаем оступ для текущего уровня }
  FIndent.Decrement;
  { Возвращаем прочитанную строку удаляя пустые переносы строк в конце }
  Result := FStringBuf.Restore.ToString;
end;

function TSCLReader.ReadTime(Hour: Word): TDateTime;
begin
  if FCursor^ <> ':' then
    RaiseParsingError(peInvalidDateTimeFormat);
  var Minute := ReadWord(59, 2);
  var Second: Word := 0;
  { Секунды опциональны }
  if FCursor^ = ':' then
    Second := ReadWord(59, 2);
  if not TryEncodeTime(Hour, Minute, Second, 0, Result) then
    RaiseParsingError(peTimeDecodingFailed);
end;

function TSCLReader.ReadWord(MaxValue, Length: Word): Word;
begin
  Result := 0;
  { Пропускаем первый символ, т.к. это разделитель ('-', ':' и т.п.) }
  var Source := FCursor + 1;
  for var Index := 1 to Length do
  begin
    var Digit := AsDigit(Source^);
    if Digit > 9 then
      RaiseParsingError(peIllegalCharacter, Source);
    Result := Result * 10 + Digit;
    if Result > MaxValue then
      RaiseParsingError(peInvalidDateTimeValue, FCursor + 1);
    Inc(Source);
  end;
  FCursor := Source;
end;

procedure TSCLReader.SetLineBreaks(const LineBreak: string);
begin
  FStringBuf.LineBreak := LineBreak;
end;

function TSCLReader.SkipLineBreak(Source: PChar): PChar;
begin
  { Проверяем и пропускаем перевод строки Lf или CrLf }
  case Source^ of
    #10: Inc(Source);
    #13: if Source[1] = #10 then Inc(Source, 2)
         else RaiseParsingError(peInvalidLineEnding, Source);
    else if (Source^ <> #0) or (Source <> FDocEnd) then
      RaiseParsingError(peIllegalCharacter, Source);
  end;
  Result := Source;
end;

procedure TSCLReader.ValidateIndent(var CurrentNode: PSCLNode);
begin
  var Indent := FCursor - FLineStart;
  if CurrentNode.Count > 0 then
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

unit SCL.Document;

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
  System.SysUtils, SCL.Common;

type
  TSCLNodeType = (
    ntEmpty,
    ntReserved,
    ntBinary,
    ntBoolean,
    ntComment,
    ntDateTime,
    ntFloat,
    ntInteger,
    ntNull,
    ntString,
    ntArray,
    ntTable);

  TSCLDocument = class;

  { Не объявляйте данный тип локально, используйте только по ссылке! }
  PSCLNode = ^TSCLNode;
  TSCLNode = record
  public type
    TPrecision  = 0..16;
    TNumberBase = (nbDefault, nbBin, nbHex, nbOct);
    TStringType = (stDefault, stLiteral, stText, stWrapped);
  private const
    ShiftValues: array [TNumberBase] of Byte = (0, 1, 4, 3);
  private type
    PBytes = ^TBytes;
    TArrayEnumerator = record
    private
      FCurrent: PSCLNode;
      FQueue: PSCLNode;
    public
      constructor Create(FirstItem: PSCLNode);
      function MoveNext: Boolean; inline;
      property Current: PSCLNode read FCurrent;
    end;
    PSCLArray = ^TSCLArray;
    TSCLArray = record
      FDocument: TSCLDocument;
      FFirst: PSCLNode;
      FLast: PSCLNode;
    end;
  private
    FName: string;     // имя узла или комментарий
    FType: TSCLNodeType;
    FSubType: Byte;    // расширенный тип для строк и чисел
    FInfo: SmallInt;   // смещение времени для дат или количество элементов для таблиц и массивов
    FParent: PSCLNode; // TSCLArray.FDocument
    FNext: PSCLNode;   // TSCLArray.FFirst
    FValue: Int64;     // TSCLArray.FLast
     function AddChild(const AName: string; AType: TSCLNodeType; LookupIndex: Integer = -1): PSCLNode;
     function GetBinary: TBytes; inline;
     function GetBoolean: Boolean; inline;
     function GetCount: Integer; inline;
     function GetDateTime: TDateTime; inline;
     function GetFirstChild: PSCLNode;
     function GetFloat: Double; inline;
     function GetInteger: Int64; inline;
     function GetItemByName(const AName: string): PSCLNode;
     function GetItemIndex: Integer;
     function GetLastChild: PSCLNode;
     function GetNumberBase: TNumberBase;
     function GetOrAddNode(const AName: string; RequiredType: TSCLNodeType): PSCLNode;
     function GetPath: string;
     function GetPrecision: TPrecision;
     function GetPrev: PSCLNode;
     function GetString: string; inline;
     function GetStringType: TStringType;
     function GetTimeOffset: SmallInt;
     function SCLArray: PSCLArray;
     function TypeName: string; inline;
    procedure ForceType(RequiredType: TSCLNodeType);
    procedure SetDateTime(const Value: TDateTime); inline;
    procedure SetFloat(const Value: Double); inline;
    procedure SetInteger(const Value: Int64); inline;
    procedure SetNumberBase(const Value: TNumberBase);
    procedure SetPrecision(const Value: TPrecision);
    procedure SetString(const Value: string); inline;
    procedure SetStringType(const Value: TStringType);
    procedure SetTimeOffset(const Value: SmallInt);
    procedure TypeCheck(RequiredType: TSCLNodeType);
    procedure TypeCheckParent;
  public
    class operator Finalize(var Instance: TSCLNode);
    { Используется для блокирования прямого копирования значений }
    class operator Assign(var Dest: TSCLNode; const [ref] Src: TSCLNode);
     { Добавляет комментарий к узлу Node (по факту перед ним) }
     class function AddComment(Node: PSCLNode; const Comment: string): PSCLNode; overload; static;
     function AddComment(const Comment: string): PSCLNode; overload;
     { Добавляет дочерний узел заданного типа }
     function AddNode(const AName: string; AType: TSCLNodeType): PSCLNode; overload; inline;
     { Добавляет дочернюю таблицу или массив. Пустой массив может быть преобразован в таблицу. }
     function AddArray(const AName: string; IsInline: Boolean = False): PSCLNode;
     function AddTable(const AName: string; IsInline: Boolean = False): PSCLNode;
     { Добавляют узлы разных типов и присваивают им значения }
     function AddValue(const AName: string; const Value: Boolean): PSCLNode; overload;
     function AddValue(const AName: string; const Value: string; &Type: TStringType = stDefault): PSCLNode; overload;
     function AddValue(const AName: string; const Value: Int64; Base: TNumberBase = nbDefault): PSCLNode; overload;
     function AddValue(const AName: string; const Value: Double; APrecision: TPrecision = 16): PSCLNode; overload;
     function AddValue(const AName: string; const Value: TBytes): PSCLNode; overload;
     function AddValue(const AName: string; const Value: TDateTime; AOffset: SmallInt = 0): PSCLNode; overload;
    { Присваивает узлу значение и дополнительную информацию в один шаг. Устанавливает тип пустых узлов. }
    procedure SetValue(const Value: Boolean); overload;
    procedure SetValue(const Value: Double; APrecision: TPrecision = 16); overload;
    procedure SetValue(const Value: Int64; Base: TNumberBase = nbDefault); overload;
    procedure SetValue(const Value: TBytes); overload;
    procedure SetValue(const Value: TDateTime; AOffset: SmallInt = 0); overload;
    procedure SetValue(const Value: string; &Type: TStringType = stDefault); overload;
    { Присваивает пустому узлу значение Null }
    procedure SetNullValue; inline;
     function GetEnumerator: TArrayEnumerator; inline;
     { Признак того, что это первый или последний узел у родителя }
     function IsFirst: Boolean; inline;
     function IsLast: Boolean; inline;
     { Возвращает True для строчных массивов и таблиц }
     function IsInline: Boolean; inline;
     { Признак корневого узла документа }
     function IsRoot: Boolean; inline;
     { Возвращает дочерний узел по его пути ('table/array/@<index>') }
     function ItemByPath(const NodePath: string): PSCLNode;
     { Возвращают дочерние узлы в виде массива }
     function ToArray: TArray<PSCLNode>;
     { Преобразует значение узла в вещественное чисто, работает с Integer, Float и String }
     function ToFloat: Double;
     { Преобразует значение узла в целое число, работает с Integer, Float и String }
     function ToInteger: Int64;
     { Преобразует значение узла в строку, не работает с массивами и таблицами }
     function ToString: string; reintroduce;
     { Количество дочерних узлов в контейнере }
     property Count: Integer read GetCount;
     { Возвращает порядковый номер текущего элемента }
     property ItemIndex: Integer read GetItemIndex;
     { Имя узла или текст комментария }
     property Name: string read FName;
     { Путь к узлу от корневого узла }
     property Path: string read GetPath;
     { Точность числа с плавающей точкой }
     property Precision: TPrecision read GetPrecision write SetPrecision;
     { Предыдущий и следующий узлы в текущем контейнере }
     property PrevSibling: PSCLNode read GetPrev;
     property NextSibling: PSCLNode read FNext;
     { Возвращают первый и последний дочерний узел }
     property FirstChild: PSCLNode read GetFirstChild;
     property LastChild: PSCLNode read GetLastChild;
     { Возвращает дочерний узел по его имени, если такого нет вернёт nil }
     property Items[const AName: string]: PSCLNode read GetItemByName; default;
     { Тип узла }
     property NodeType: TSCLNodeType read FType;
     { Система счисления для записи числа }
     property NumberBase: TNumberBase read GetNumberBase write SetNumberBase;
     { Родительский узел, nil для RootNode и NullNode }
     property Parent: PSCLNode read FParent;
     { Смещение времени для ntDateTime, равно -1 для локального времени }
     property TimeOffset: SmallInt read GetTimeOffset write SetTimeOffset;
     { Тип строки }
     property StringType: TStringType read GetStringType write SetStringType;
     { Возвращает дочерний узел соответствующего типа по его имени, при отсутствии создаёт новый }
     property A[const AName: string]: PSCLNode index ntArray    read GetOrAddNode;
     property B[const AName: string]: PSCLNode index ntBoolean  read GetOrAddNode;
     property D[const AName: string]: PSCLNode index ntDateTime read GetOrAddNode;
     property F[const AName: string]: PSCLNode index ntFloat    read GetOrAddNode;
     property I[const AName: string]: PSCLNode index ntInteger  read GetOrAddNode;
     property O[const AName: string]: PSCLNode index ntBinary   read GetOrAddNode; // Octet string - Binary
     property S[const AName: string]: PSCLNode index ntString   read GetOrAddNode;
     property T[const AName: string]: PSCLNode index ntTable    read GetOrAddNode;
     { Значения узлов соответствующего типа }
     property AsBytes: TBytes read GetBinary write SetValue;
     property AsBoolean: Boolean read GetBoolean write SetValue;
     property AsDateTime: TDateTime read GetDateTime write SetDateTime;
     property AsDouble: Double read GetFloat write SetFloat;
     property AsInteger: Int64 read GetInteger write SetInteger;
     property AsString: string read GetString write SetString;
  end;

  TSCLDocument = class
  private const
    MINIMUM_STORE_ITEMS = 1024;
  private type
    { Используется для снижения фрагментации памяти и исключения копирования массивов данных }
    PNodeArray = ^TNodeArray;
    TNodeArray = record
    private
      Data: TArray<TSCLNode>;
      Prev: PNodeArray;
      class function Create(Current: PNodeArray; DefaultSize: Integer): PNodeArray; static;
    end;
  private
    FLookup: TArray<PSCLNode>;
    FHashed: Integer;
    FNodeArray: PNodeArray;
    FNextIndex: Integer;
    FRootNode: PSCLNode;
     function CreateArray: NativeInt; inline;
     function CreateNode(AParent: Pointer; AType: TSCLNodeType; LookupIndex: Integer): PSCLNode;
     function Find(Parent: PSCLNode; const Name: string; out Index: Integer): Boolean;
    procedure GrowAndRehash;
  public
    constructor Create(Capacity: Integer = 0);
    destructor Destroy; override;
    procedure Clear;
     function IsEmpty: Boolean;
     property Root: PSCLNode read FRootNode;
  end;

resourcestring
  sTypeName_Array    = 'массив';
  sTypeName_Binary   = 'двоичный';
  sTypeName_Boolean  = 'логический';
  sTypeName_DateTime = 'дата/время';
  sTypeName_Empty    = 'пустой';
  sTypeName_Float    = 'число';
  sTypeName_Integer  = 'целое';
  sTypeName_Null     = 'null';
  sTypeName_String   = 'строка';
  sTypeName_Table    = 'таблица';

const
  TIME_OFFSET_LOCAL = -1; // зарезервированное смещение времени для локальных дат

  SCLTypeNames: array [TSCLNodeType] of string = (
    sTypeName_Empty,
    '#Reserved', // do not localize!
    sTypeName_Binary,
    sTypeName_Boolean,
    '#Comment',  // do not localize!
    sTypeName_DateTime,
    sTypeName_Float,
    sTypeName_Integer,
    sTypeName_Null,
    sTypeName_String,
    sTypeName_Array,
    sTypeName_Table);

implementation

uses
  System.DateUtils;

{$IF SizeOf(TSCLNode) > 24}{$Message Warn 'Превышен запланированный размер узла SCL в 24 байта!'}{$IFEND}

resourcestring
  sAssignNotAllowed  = 'Не допускается прямое копирование элементов TSCLNode';
  sConversionFailed  = 'Невозможно преобразовать элемент ''%s'' [%s] к типу ''%s''';
  sDuplicateItemName = 'Элемент ''%s'' уже существует в таблице %s';
  sIllegalNameChars  = 'Недопустимый символ в имени узла: ''%s''';
  sInvalidNodePath   = 'Некорректный путь к узлу: ''%s''';
  sInvalidValueType  = 'Элемент ''%s'' [%s] должен иметь тип ''%s''';
  sLookupTableIsFull = 'В массиве хэшей нет свободных мест';
  sNestedInlineError = 'Вложенные строчные массивы и таблицы не допускаются';
  sNoArrayNameAllowd = 'Элементы массива не могут иметь ключей';
  sNoCommentInInline = 'Комментарии в строчных массивах и таблицах не допускаются';
  sNodeIsNotAParent  = 'Элемент ''%s'' [%s] не является массивом или таблицей';
  sNoParentNodeFound = 'У элемента ''%s'' отсутствует родительский узел';
  sNoRootNodeComment = 'Нельзя добавить комментарий к корневому узлу документа';
  sNoTextBlckAllowed = 'Текстовые блоки не допускаются внутри строчных массивов и таблиц';
  sTableItemNameRqrd = 'Для элементов таблиц необходимо указать не пустые имена';
  sTooManyChildItems = 'Достигнут предел дочерних элементов в ''%s''';
  sUnacceptableType  = 'Недопустимый тип элемента ''%s''';

  {$IFDEF CPU64BITS}
  sMaxDocSizeExceed  = 'Превышен максимальный размер SCL-документа';
  sMaxHashSizeExceed = 'Превышен максимально допустимый размер хэш-таблицы';
  {$ENDIF}

var
  SCLNameBuilder: TStringBuffer = nil;
  SCLFormatSettings: TFormatSettings;

type
  TDateTimeParts = record
    Year: Word;
    Month: Word;
    Day: Word;
    Hour: Word;
    Minute: Word;
    Second: Word;
  end;

  HDateTime = record helper for TDateTime
    function Deconstruct: TDateTimeParts; inline;
  end;

var
  SCLHexTable: TArray<LongWord>;

function BinToHex(const Value: TBytes): string;

  procedure InitializeHexTable; inline;
  begin
    SetLength(SCLHexTable, $100);
    for var Index := 0 to High(SCLHexTable) do
      SCLHexTable[Index] := Word(HexChars[Index and $0F]) shl 16 or Word(HexChars[Index shr 4]);
  end;

begin
  if SCLHexTable = nil then
    InitializeHexTable;
  SetLength(Result, Length(Value) shl 1 + 1);
  Result[1] := '%';
  var Buffer := PLongWord(@Result[2]);
  for var Index := 0 to High(Value) do
  begin
    Buffer^ := SCLHexTable[Value[Index]];
    Inc(Buffer);
  end;
end;

function HashFNV1a16(Parent: PSCLNode; const Key: string): Cardinal;
begin
  Result := ($811C9DC5 xor LongWord(Parent)) * $01000193;
  for var Index := 1 to Key.Length do
    { Хеш считается от нижнего регистра (or $20) символов,
      при этом символ '_' ($5F) получает код $7F, который
      сам по себе не допукается в именах ключей. }
    Result := (LongWord(Key[Index]) or $20 xor Result) * $01000193;
end;

function IntToBaseTwo(Value: Int64; Shift: Byte): string;
const
  Bases: array [0..4] of LongWord = (0, $00620030, 0, $006F0030, $00780030);
  MAX_STRING_LENGTH = 66; // 64 бита + '0b'
var
  Buffer: array [0..MAX_STRING_LENGTH - 1] of Char;
begin
  var Mask := 1 shl Shift - 1;
  var Cursor := Buffer + MAX_STRING_LENGTH;
  repeat
    Dec(Cursor);
    Cursor^ := HexChars[Byte(Value) and Mask];
    Value := Value shr Shift;
  until Value = 0;
  Dec(Cursor, 2);
  PLongWord(Cursor)^ := Bases[Shift];
  SetString(Result, Cursor, MAX_STRING_LENGTH - (Cursor - Buffer));
end;

{ HDateTime }

function HDateTime.Deconstruct: TDateTimeParts;
begin
  var MSecs: Word;
  with Result do
    DecodeDateTime(Self, Year, Month, Day, Hour, Minute, Second, MSecs);
end;

{ TSCLNode.TArrayEnumerator }

constructor TSCLNode.TArrayEnumerator.Create(FirstItem: PSCLNode);
begin
  FCurrent := nil;
  FQueue := FirstItem;
end;

function TSCLNode.TArrayEnumerator.MoveNext: Boolean;
begin
  Result := FQueue <> nil;
  if Result then
  begin
    FCurrent := FQueue;
    FQueue := FQueue.FNext;
  end;
end;

{ TSCLNode }

function TSCLNode.AddArray(const AName: string; IsInline: Boolean): PSCLNode;
begin
  Result := AddChild(AName, ntArray);
  Result.FSubType := Byte(IsInline);
end;

function TSCLNode.AddChild(const AName: string; AType: TSCLNodeType; LookupIndex: Integer): PSCLNode;
const
  ParentTypes: array [Boolean] of TSCLNodeType = (ntArray, ntTable);
begin
  { Нельзя создать узлы следующих типов стандартным способом }
  if AType in [ntReserved, ntComment] then
    raise ESCLError.CreateResFmt(@sUnacceptableType, [SCLTypeNames[AType]]);
  var PNodeName := PPChar(@AName)^;
  case FType of
    ntArray:
      if PNodeName <> nil then
        { При попытке добавить в пустой массив узел с именем - массив становится таблицей }
        if FInfo = 0 then
        begin
          FType := ntTable;
          { Необходимо узнать индекс нового элемента в хэш-таблице }
          PSCLArray(FValue).FDocument.Find(@Self, AName, LookupIndex);
        end else raise ESCLError.CreateResFmt(@sNoArrayNameAllowd, [AName, GetPath]);
    ntTable:
      if PNodeName = nil then
        raise ESCLError.CreateResFmt(@sTableItemNameRqrd, [AName, GetPath])
      else if @PNodeName[AName.Length] <> ValidateNodeName(PNodeName) then
        raise ESCLError.CreateResFmt(@sIllegalNameChars, [AName])
      else if (LookupIndex < 0) and PSCLArray(FValue).FDocument.Find(@Self, AName, LookupIndex) then
        raise ESCLError.CreateResFmt(@sDuplicateItemName, [AName, GetPath]);
    else raise ESCLError.CreateResFmt(@sNodeIsNotAParent, [GetPath, TypeName])
  end;
  { Проверяем предел количества дочерних элементов }
  if FInfo = Smallint.MaxValue then
    raise ESCLError.CreateResFmt(@sTooManyChildItems, [GetPath]);
  { Вложенные массивы и таблицы запрещены для строчных }
  if (FSubType <> 0) and (AType in [ntArray, ntTable]) then
    raise ESCLError.CreateResFmt(@sNestedInlineError, [GetPath]);
  with PSCLArray(FValue)^ do
  begin
    Result := FDocument.CreateNode(@Self, AType, LookupIndex);
    Result.FName := AName;
    if FFirst = nil then
      FFirst := Result;
    if FLast <> nil then
      FLast.FNext := Result;
    FLast := Result;
  end;
  Inc(FInfo);
end;

class function TSCLNode.AddComment(Node: PSCLNode; const Comment: string): PSCLNode;
begin
  if Node.FParent = nil then
    raise ESCLError.CreateRes(@sNoRootNodeComment);
  if Node.FParent.FSubType <> 0 then
    raise Exception.CreateRes(@sNoCommentInInline);
  with TSCLNode.PSCLArray(Node.FParent.FValue)^ do
  begin
    Result := FDocument.CreateNode(Node.FParent, ntComment, -1);
    Result.FName := Comment;
    Result.FNext := Node;
    var PrevNode := Node.PrevSibling;
    if PrevNode = nil then
      FFirst := Result
    else
      PrevNode.FNext := Result;
  end;
  Inc(Node.FParent.FInfo);
end;

function TSCLNode.AddComment(const Comment: string): PSCLNode;
begin
  if not (FType in [ntArray, ntTable]) then
    raise ESCLError.CreateResFmt(@sNodeIsNotAParent, [FName, TypeName]);
  if FSubType <> 0 then
    raise Exception.CreateRes(@sNoCommentInInline);
  with PSCLArray(FValue)^ do
  begin
    Result := FDocument.CreateNode(@Self, ntComment, -1);
    Result.FName := Comment;
    if FFirst = nil then
      FFirst := Result;
    if FLast <> nil then
      FLast.FNext := Result;
    FLast := Result;
  end;
  Inc(FInfo);
end;

function TSCLNode.AddNode(const AName: string; AType: TSCLNodeType): PSCLNode;
begin
  Result := AddChild(AName, AType);
end;

function TSCLNode.AddTable(const AName: string; IsInline: Boolean): PSCLNode;
begin
  Result := AddChild(AName, ntTable);
  Result.FSubType := Byte(IsInline);
end;

function TSCLNode.AddValue(const AName, Value: string; &Type: TStringType): PSCLNode;
begin
  { Строчные массивы и таблицы не допускают переноса строк }
  if (&Type in [stText, stWrapped]) and (FType in [ntEmpty, ntArray, ntTable]) and (FSubType <> 0) then
    raise ESCLError.CreateRes(@sNoTextBlckAllowed);
  { Добавляем строку в текущий узел }
  Result := AddChild(AName, ntString);
  Result.FSubType := Byte(&Type);
  PString(@Result.FValue)^ := Value;
end;

function TSCLNode.AddValue(const AName: string; const Value: Boolean): PSCLNode;
begin
  Result := AddChild(AName, ntBoolean);
  PBoolean(@Result.FValue)^ := Value;
end;

function TSCLNode.AddValue(const AName: string; const Value: Int64; Base: TNumberBase): PSCLNode;
begin
  Result := AddChild(AName, ntInteger);
  Result.FSubType := ShiftValues[Base];
  Result.FValue := Value;
end;

function TSCLNode.AddValue(const AName: string; const Value: TDateTime; AOffset: SmallInt): PSCLNode;
begin
  Result := AddChild(AName, ntDateTime);
  Result.FInfo := AOffset;
  PDateTime(@Result.FValue)^ := Value;
end;

function TSCLNode.AddValue(const AName: string; const Value: TBytes): PSCLNode;
begin
  Result := AddChild(AName, ntBinary);
  PBytes(@Result.FValue)^ := Value;
end;

function TSCLNode.AddValue(const AName: string; const Value: Double; APrecision: TPrecision): PSCLNode;
begin
  Result := AddChild(AName, ntFloat);
  Result.FSubType := APrecision;
  PDouble(@Result.FValue)^ := Value;
end;

class operator TSCLNode.Assign(var Dest: TSCLNode; const [ref] Src: TSCLNode);
begin
  raise ESCLError.CreateRes(@sAssignNotAllowed);
end;

class operator TSCLNode.Finalize(var Instance: TSCLNode);
begin
  case Instance.FType of
    ntBinary: Finalize(PBytes(@Instance.FValue)^);
    ntString: Finalize(PString(@Instance.FValue)^);
  end;
end;

procedure TSCLNode.ForceType(RequiredType: TSCLNodeType);
begin
  if FType <> RequiredType then
  begin
    { Нельзя таким образом сделать массив или таблицу }
    if RequiredType in [ntArray, ntTable] then
      raise ESCLError.CreateResFmt(@sNodeIsNotAParent, [FName, TypeName]);
    { Изменить тип можно только у новых узлов }
    if FType <> ntEmpty then
      raise ESCLError.CreateResFmt(@sInvalidValueType, [FName, TypeName, SCLTypeNames[RequiredType]]);
    FType := RequiredType;
  end;
end;

function TSCLNode.GetBinary: TBytes;
begin
  TypeCheck(ntBinary);
  Result := PBytes(@FValue)^;
end;

function TSCLNode.GetBoolean: Boolean;
begin
  TypeCheck(ntBoolean);
  Result := PBoolean(@FValue)^;
end;

function TSCLNode.GetCount: Integer;
begin
  TypeCheckParent;
  Result := FInfo;
end;

function TSCLNode.GetDateTime: TDateTime;
begin
  TypeCheck(ntDateTime);
  Result := PDateTime(@FValue)^;
end;

function TSCLNode.GetEnumerator: TArrayEnumerator;
begin
  Result := TArrayEnumerator.Create(GetFirstChild);
end;

function TSCLNode.GetFirstChild: PSCLNode;
begin
  TypeCheckParent;
  Result := PSCLArray(FValue).FFirst;
end;

function TSCLNode.GetFloat: Double;
begin
  TypeCheck(ntFloat);
  Result := PDouble(@FValue)^;
end;

function TSCLNode.GetInteger: Int64;
begin
  TypeCheck(ntInteger);
  Result := FValue;
end;

function TSCLNode.GetItemByName(const AName: string): PSCLNode;
begin
  TypeCheck(ntTable);
  var LookupIndex: Integer;
  var Document := PSCLArray(FValue).FDocument;
  if Document.Find(@Self, AName, LookupIndex) then
    Result := Document.FLookup[LookupIndex]
  else Result := nil;
end;

function TSCLNode.GetItemIndex: Integer;
begin
  if FParent <> nil then
  begin
    Result := 0;
    var Item := FParent.FirstChild;
    repeat
      if Item = @Self then
        Exit; // мы нашли нужный узел
      Item := Item.FNext;
      Inc(Result);
    until Item = nil;
  end;
  Result := -1;
end;

function TSCLNode.GetLastChild: PSCLNode;
begin
  TypeCheckParent;
  Result := PSCLArray(FValue).FLast;
end;

function TSCLNode.GetNumberBase: TNumberBase;
begin
  TypeCheck(ntInteger);
  Result := TNumberBase(FSubType);
end;

function TSCLNode.GetOrAddNode(const AName: string; RequiredType: TSCLNodeType): PSCLNode;
begin
  TypeCheck(ntTable);
  var LookupIndex: Integer;
  var Document := PSCLArray(FValue).FDocument;
  { Иначе ищем соответствующий узел в хэш-таблице }
  if Document.Find(@Self, AName, LookupIndex) then
  begin
    Result := Document.FLookup[LookupIndex];
    Result.TypeCheck(RequiredType);
  end else // если не нашли нужный узел, то создаём его
    Result := AddChild(AName, RequiredType, LookupIndex);
end;

function TSCLNode.GetPath: string;
var
  NodeStack: TArray<PSCLNode>;
begin
  if (FType in [ntComment, ntReserved]) then Exit('');
  if SCLNameBuilder = nil then
    SCLNameBuilder := TStringBuffer.Create;
  SCLNameBuilder.Reset.Append('/');
  var Count := 0;
  var Node := PSCLNode(@Self);
  { Добавляем все узлы в стек, кроме корневого }
  while Node.FParent <> nil do
  begin
    if Count >= Length(NodeStack) then
      SetLength(NodeStack, NextPowerOfTwo(Count + 1, 16));
    NodeStack[Count] := Node;
    Inc(Count);
    Node := Node.FParent;
  end;
  for var Index := Count - 1 downto 0 do
  begin
    Node := NodeStack[Index];
    if Node.Parent.FType = ntArray then
      SCLNameBuilder.Append('@').Append(IntToStr(Node.ItemIndex))
    else
      SCLNameBuilder.Append('/').Append(Node.Name);
  end;
  Result := SCLNameBuilder.ToString;
end;

function TSCLNode.GetPrecision: TPrecision;
begin
  TypeCheck(ntFloat);
  Result := FSubType;
end;

function TSCLNode.GetPrev: PSCLNode;
begin
  if (FParent <> nil) and not IsFirst then
    for var Item in FParent^ do
      if Item.FNext = @Self then
        Exit(Item);
  Result := nil;
end;

function TSCLNode.GetString: string;
begin
  TypeCheck(ntString);
  Result := PString(@FValue)^;
end;

function TSCLNode.GetStringType: TStringType;
begin
  TypeCheck(ntString);
  Result := TStringType(FSubType);
end;

function TSCLNode.GetTimeOffset: SmallInt;
begin
  TypeCheck(ntDateTime);
  Result := FInfo;
end;

function TSCLNode.IsFirst: Boolean;
begin
  Result := PSCLArray(FParent.FValue).FFirst = @Self;
end;

function TSCLNode.IsInline: Boolean;
begin
  Result := (FType in [ntArray, ntTable]) and (FSubType <> 0);
end;

function TSCLNode.IsLast: Boolean;
begin
  Result := PSCLArray(FParent.FValue).FLast = @Self;
end;

function TSCLNode.IsRoot: Boolean;
begin
  Result := (FType in [ntEmpty, ntArray, ntTable]) and (FParent = nil);
end;

function TSCLNode.ItemByPath(const NodePath: string): PSCLNode;
begin
  if NodePath.IsEmpty then
    raise ESCLError.CreateResFmt(@sInvalidNodePath, [NodePath]);
  var Path := PPChar(@NodePath)^;
  Result := PSCLNode(@Self);
  while Result <> nil do
  begin
    case Path^ of
      #00: Break;
      '@':
        begin
          { Читаем индекс элемента в массиве }
          var NodeIndex := 0;
          repeat
            Inc(Path);
            var Digit := AsDigit(Path^);
            if Digit > 9 then Break; // цифры закончились
            NodeIndex := NodeIndex * 10 + Digit;
          until NodeIndex > SmallInt.MaxValue;
          { При выходе по условию цикла - Path будет указывать на цифру }
          case Path^ of
            #00: ;
            '/': Inc(Path);
            else raise ESCLError.CreateResFmt(@sInvalidNodePath, [NodePath]);
          end;
          { Идём по элементам до нужного }
          Result.TypeCheck(ntArray);
          Result := Result.FirstChild;
          while (NodeIndex > 0) and (Result <> nil) do
          begin
           Result := Result.NextSibling;
           Dec(NodeIndex);
          end;
        end;
    else
      var From := Path;
      var Last := ValidateNodeName(Path);
      { Проверяем следующий разделитель на валидность }
      case Last^ of
        #00: Path := Last;
        '/': Path := Last + 1;
        else raise ESCLError.CreateResFmt(@sInvalidNodePath, [NodePath]);
      end;
      Result := Result.GetItemByName(From.SubString(Last));
    end;
  end;
end;

function TSCLNode.SCLArray: PSCLArray;
begin
  if FType in [ntArray, ntTable] then
    Result := PSCLArray(FValue)
  else if FParent <> nil then
    Result := FParent.SCLArray
  else
    raise ESCLError.CreateResFmt(@sNoParentNodeFound, [FName]) at ReturnAddress;
end;

procedure TSCLNode.SetDateTime(const Value: TDateTime);
begin
  ForceType(ntDateTime);
  PDateTime(@FValue)^ := Value;
end;

procedure TSCLNode.SetFloat(const Value: Double);
begin
  ForceType(ntFloat);
  PDouble(@FValue)^ := Value;
end;

procedure TSCLNode.SetInteger(const Value: Int64);
begin
  ForceType(ntInteger);
  FValue := Value;
end;

procedure TSCLNode.SetNullValue;
begin
  ForceType(ntNull);
end;

procedure TSCLNode.SetNumberBase(const Value: TNumberBase);
begin
  TypeCheck(ntInteger);
  FSubType := Byte(Value);
end;

procedure TSCLNode.SetPrecision(const Value: TPrecision);
begin
  TypeCheck(ntFloat);
  FSubType := Value;
end;

procedure TSCLNode.SetString(const Value: string);
begin
  ForceType(ntString);
  PString(@FValue)^ := Value;
end;

procedure TSCLNode.SetStringType(const Value: TStringType);
begin
  TypeCheck(ntString);
  FSubType := Byte(Value);
end;

procedure TSCLNode.SetTimeOffset(const Value: SmallInt);
begin
  TypeCheck(ntDateTime);
  FInfo := Value;
end;

procedure TSCLNode.SetValue(const Value: Double; APrecision: TPrecision);
begin
  ForceType(ntFloat);
  PDouble(@FValue)^ := Value;
  FSubType := APrecision;
end;

procedure TSCLNode.SetValue(const Value: Int64; Base: TNumberBase);
begin
  ForceType(ntInteger);
  FValue := Value;
  FSubType := ShiftValues[Base];
end;

procedure TSCLNode.SetValue(const Value: TDateTime; AOffset: SmallInt);
begin
  ForceType(ntDateTime);
  PDateTime(@FValue)^ := Value;
  FInfo := AOffset;
end;

procedure TSCLNode.SetValue(const Value: string; &Type: TStringType);
begin
  ForceType(ntString);
  PString(@FValue)^ := Value;
  FSubType := Byte(&Type);
end;

procedure TSCLNode.SetValue(const Value: TBytes);
begin
  ForceType(ntBinary);
  PBytes(@FValue)^ := Value;
end;

procedure TSCLNode.SetValue(const Value: Boolean);
begin
  ForceType(ntBoolean);
  PBoolean(@FValue)^ := Value;
end;

function TSCLNode.ToArray: TArray<PSCLNode>;
begin
  TypeCheckParent;
  SetLength(Result, FInfo);
  var Item := PSCLArray(FValue).FFirst;
  for var Index := 0 to High(Result) do
  begin
    Result[Index] := Item;
    Item := Item.NextSibling;
  end;
end;

function TSCLNode.ToFloat: Double;
begin
  case FType of
    ntInteger: Result := FValue;
    ntFloat:   Result := PDouble(@FValue)^;
    ntString:  Result := StrToFloat(PString(@FValue)^);
    else raise ESCLError.CreateResFmt(@sConversionFailed, [FName, TypeName, sTypeName_Float]);
  end;
end;

function TSCLNode.ToInteger: Int64;
begin
  case FType of
    ntInteger: Result := FValue;
    ntFloat:   Result := Trunc(PDouble(@FValue)^);
    ntString:  Result := StrToInt64(PString(@FValue)^);
    else raise ESCLError.CreateResFmt(@sConversionFailed, [FName, TypeName, sTypeName_Integer]);
  end;
end;

function TSCLNode.ToString: string;

  function DateTimeAsString: string;
  type
    TDateType = (dtLocal, dtUTC, dtBelowUTC, dtAboveUTC, dtDateOnly, dtTimeOnly);
  const
    DateFormats: array [TDateType] of string = (
      '%.4d-%.2d-%.2d %.2d:%.2d:%.2d',            // dtLocal
      '%.4d-%.2d-%.2d %.2d:%.2d:%.2dZ',           // dtUTC
      '%.4d-%.2d-%.2d %.2d:%.2d:%.2d-%.2d:%.2d',  // dtBelowUTC
      '%.4d-%.2d-%.2d %.2d:%.2d:%.2d+%.2d:%.2d',  // dtAboveUTC
      '%.4d-%.2d-%.2d', '%3:.2d:%4:.2d:%5:.2d');  // dtDateOnly / dtTimeOnly
    OffsetTypes: array [0..1] of TDateType = (dtAboveUTC, dtBelowUTC);
  begin
    var OffsetHours:   Word := 0;
    var OffsetMinutes: Word := 0;
    var DateTimeValue: TDateTime := PDateTime(@FValue)^;
    var DateType := dtUTC;
    case FInfo of
      -1: { Если время локальное, то проверяем на упрощённый формат }
          if Trunc(DateTimeValue) = 0 then
            DateType := dtTimeOnly
          else if (Frac(DateTimeValue) = 0) then
            DateType := dtDateOnly
          else DateType := dtLocal;
       0: ;
    else
      var Offset: Word := Abs(FInfo);
      OffsetHours   := Offset div 60;
      OffsetMinutes := Offset - OffsetHours * 60;
      DateType := OffsetTypes[Word(FInfo) shr 15];
    end;
    with DateTimeValue.Deconstruct do
      Result := Format(DateFormats[DateType], [Year, Month, Day, Hour, Minute, Second, OffsetHours, OffsetMinutes]);
  end;

const
  BoolStrings: array [Boolean] of string = ('false', 'true');
begin
  case FType of
    ntReserved:  Result := '#ERROR';
    ntBinary:    Result := BinToHex(PBytes(@FValue)^);
    ntBoolean:   Result := BoolStrings[Boolean(FValue)];
    ntComment:   Result := FName;
    ntDateTime:  Result := DateTimeAsString;
    ntFloat:     Result := PDouble(@FValue)^.ToString(ffGeneral, FSubType, 0, SCLFormatSettings).ToLower;
    ntInteger:   if FSubType = 0 then
                   Result := IntToStr(FValue)
                 else
                   Result := IntToBaseTwo(FValue, FSubType);
    ntNull:      Result := '~';
    ntString:    Result := PString(@FValue)^;
    else raise ESCLError.CreateResFmt(@sConversionFailed, [FName, TypeName, sTypeName_String]);
  end;
end;

procedure TSCLNode.TypeCheck(RequiredType: TSCLNodeType);
begin
  if FType <> RequiredType then
    raise ESCLError.CreateResFmt(@sInvalidValueType, [FName, TypeName, SCLTypeNames[RequiredType]]);
end;

procedure TSCLNode.TypeCheckParent;
begin
  if not (FType in [ntArray, ntTable]) then
    raise ESCLError.CreateResFmt(@sNodeIsNotAParent, [FName, TypeName]);
end;

function TSCLNode.TypeName: string;
begin
  Result := SCLTypeNames[FType];
end;

{ TSCLDocument.TNodeArray }

class function TSCLDocument.TNodeArray.Create(Current: PNodeArray; DefaultSize: Integer): PNodeArray; 
begin
  if (Current <> nil) and (Current.Prev <> nil) then
    DefaultSize := Length(Current.Data) shl 1;
  {$IFDEF CPU64BITS}
  if DefaultSize > Integer.MaxValue div 2 then // недостижимо при компиляции в 32-х битном режиме
    raise ESCLError.CreateRes(@sMaxDocSizeExceed);
  {$ENDIF}
  New(Result);
  with Result^ do
  begin
    Prev := Current;
    SetLength(Data, DefaultSize);
    FillChar(PByte(Data)^, DefaultSize * SizeOf(Data[0]), 0);
  end;
end;

{ TSCLDocument }

procedure TSCLDocument.Clear;
begin
  { Проверка на пустой документ }
  if IsEmpty then Exit;
  { Обнуляем всю существующую структуру документа }
  FHashed := 0;
  FNextIndex := 1; // сохраняем FRoot
  { Удаляем все хранилища узлов, кроме первого }
  while FNodeArray.Prev <> nil do
  begin
    var Next := FNodeArray.Prev;
    Dispose(FNodeArray);
    FNodeArray := Next;
  end;
  { Обрезаем и обнуляем таблицу хэшей со ссылками на элементы }
  var Length := Length(FNodeArray.Data);
  SetLength(FLookup, Length);
  FillChar(FLookup[0], Length * SizeOf(PSCLNode), 0);
  { Обнуляем первичное хранилище данных, включая корневой элемент }
  Finalize(FNodeArray.Data[0], Length);
  FillChar(PByte(FNodeArray.Data)^, Length * SizeOf(FNodeArray.Data[0]), 0);
  { Заного инициализируем значения стандартных узлов }
  FRootNode.FType := ntArray;
  FRootNode.FValue := CreateArray;
end;

constructor TSCLDocument.Create(Capacity: Integer);
begin
  { Выделяем память под элементы и индексы }
  Capacity := NextPowerOfTwo(Capacity, MINIMUM_STORE_ITEMS);
  FNodeArray := TNodeArray.Create(nil, Capacity);
  SetLength(FLookup, Capacity);
  FillChar(FLookup[0], Length(FLookup) * SizeOf(PSCLNode), 0);
  { Создаём основную таблицу документа и пустую ноду }
  FRootNode := CreateNode(nil, ntArray, -1);
end;

function TSCLDocument.CreateArray: NativeInt;
begin
  Result := NativeInt(@CreateNode(Self, ntReserved, -1).FParent);
end;

function TSCLDocument.CreateNode(AParent: Pointer; AType: TSCLNodeType; LookupIndex: Integer): PSCLNode;
begin
  { Проверяем что у нас достаточно свободных элементов }
  if FNextIndex >= Length(FNodeArray.Data) then
  begin
    FNodeArray := TNodeArray.Create(FNodeArray, Length(FNodeArray.Data));
    FNextIndex := 0;
  end;
  { Резервируем новый элемент }
  Result := @FNodeArray.Data[FNextIndex];
  Result.FParent := AParent;
  Result.FType := AType;
  Inc(FNextIndex);
  { Для таблиц и массивов создаём дополнительный элемент }
  if AType in [ntArray, ntTable] then
    Result.FValue := CreateArray;
  { Для таблиц дополнительно обновляем хэш-таблицу }
  if LookupIndex >= 0 then
  begin
    FLookup[LookupIndex] := Result;
    Inc(FHashed);
    if FHashed > Length(FLookup) * 3 shr 2 then
      GrowAndRehash;
  end;
end;

destructor TSCLDocument.Destroy;
begin
  repeat
    var NextArray := FNodeArray.Prev;
    Dispose(FNodeArray);
    FNodeArray := NextArray;
  until FNodeArray = nil;
end;

function TSCLDocument.Find(Parent: PSCLNode; const Name: string; out Index: Integer): Boolean;
begin
  var Mask := High(FLookup);
  var Hash := HashFNV1a16(Parent, Name);
  var From := Integer(Hash and Mask);
  var Step := Integer(Hash shr 8 and Mask or 1);
  Index := From;
  { Ищем по хэшу с индекса From и шагом Step }
  repeat
    if FLookup[Index] = nil then
      Exit(False) // элемент отсутствует в таблице
    else if (FLookup[Index].FParent = Parent) and ASCIISameName(FLookup[Index].FName, Name) then
      Exit(True); // элемент найден
    Index := (Index + Step) and Mask; // следующий шаг
  until Index = From;
  { По идее сюда мы не попадём никогда! }
  raise ESCLError.CreateRes(@sLookupTableIsFull);
end;

procedure TSCLDocument.GrowAndRehash;
begin
  { Создаём новый массив индексов }
  var Rehashed: TArray<PSCLNode>;
  var HashSize := Length(FLookup);
  {$IFDEF CPU64BITS}
  if HashSize > Integer.MaxValue div 2 then // недостижимо при компиляции в 32-х битном режиме
    raise ESCLError.CreateRes(@sMaxHashSizeExceed);
  {$ENDIF}
  SetLength(Rehashed, HashSize shl 1);
  FillChar(Rehashed[0], Length(Rehashed) * SizeOf(PSCLNode), 0);
  { Перераспределяем элементы из старого массива в новый }
  var Mask: Cardinal := High(FLookup);
  for var Index := 0 to Mask do
  begin
    var Item := FLookup[Index];
    if Item <> nil then
    begin
      var Hash := HashFNV1a16(Item.FParent, Item.FName);
      var From := Hash and Mask;
      var Step := Hash shr 8 and Mask or 1;
      var Next := From;
      while Rehashed[Next] <> nil do
        Next := (Next + Step) and Mask;
      Rehashed[Next] := Item;
    end;
  end;
  FLookup := Rehashed;
end;

function TSCLDocument.IsEmpty: Boolean;
begin
  Result := (FRootNode.FType = ntEmpty) and (FRootNode.FInfo = 0);
end;

initialization
  SCLFormatSettings := TFormatSettings.Create;
  SCLFormatSettings.DecimalSeparator := '.';

finalization
  FreeAndNil(SCLNameBuilder);

end.

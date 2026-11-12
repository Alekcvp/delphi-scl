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
  System.SysUtils, SCL.Common, SCL.Types;

const
  MAX_BINARY_LENGTH = 64;
  TIME_OFFSET_LOCAL = -1; // зарезервированное смещение времени для локальных дат

type
  TSCLNodeType = (
    ntEmpty,
    ntReserved,
    ntBinary,   // максимально MAX_BINARY_LENGTH байт, иначе используйте base64 c stWrapped
    ntBoolean,
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
  private const
    ParentTypes: array [Boolean] of TSCLNodeType = (ntArray, ntTable);
    ShiftValues: array [TSCLNumberBase] of Byte = (0, 1, 4, 3);
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
    FName: string;        // имя узла
    FComment: string;     // комментарий к узлу
    FType: TSCLNodeType;  // базовый тип узла
    FSubType: Byte;       // расширенный тип для строк и чисел
    FInfo: SmallInt;      // смещение времени для дат или количество элементов для таблиц и массивов
    FParent: PSCLNode;    // => TSCLArray.FDocument
    FNext: PSCLNode;      // => TSCLArray.FFirst
    FPrev: PSCLNode;      // => TSCLArray.FLast
    FValue: Int64;        // значение узла или ссылка на TSCLArray
     function AddChild(const AName: string; AType: TSCLNodeType; LookupIndex: Integer = -1): PSCLNode;
     function CountNodesInSubtree: Integer;
     function Exists(const AName: string; out LookupIndex: Integer): Boolean; inline;
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
     function GetNumberBase: TSCLNumberBase;
     function GetOrAddNode(const AName: string; RequiredType: TSCLNodeType): PSCLNode;
     function GetPath: string;
     function GetPrecision: TSCLPrecision;
     function GetString: string; inline;
     function GetStringType: TSCLStringType;
     function GetTimeOffset: SmallInt;
     function TypeName: string; inline;
    procedure SetDateTime(const Value: TDateTime); inline;
    procedure SetFloat(const Value: Double); inline;
    procedure SetInteger(const Value: Int64); inline;
    procedure SetNumberBase(const Value: TSCLNumberBase);
    procedure SetPrecision(const Value: TSCLPrecision);
    procedure SetString(const Value: string); inline;
    procedure SetStringType(const Value: TSCLStringType);
    procedure SetTimeOffset(const Value: SmallInt);
    procedure TypeCheck(RequiredType: TSCLNodeType);
     function TypeCheckParent: Boolean;
  public
    class operator Finalize(var Instance: TSCLNode);
    { Используется для блокирования прямого копирования значений }
    class operator Assign(var Dest: TSCLNode; const [ref] Src: TSCLNode);
     { Добавляет дочерний узел заданного типа }
     function AddNode(const AName: string; AType: TSCLNodeType): PSCLNode; inline;
     { Добавляет дочернюю таблицу или массив }
     function AddArray(const AName: string; AsInline: Boolean = False): PSCLNode;
     function AddTable(const AName: string; AsInline: Boolean = False): PSCLNode;
     { Добавляют узлы разных типов и присваивают им значения }
     function AddValue(const AName: string; const Value: Boolean): PSCLNode; overload;
     function AddValue(const AName: string; const Value: string; &Type: TSCLStringType = stDefault): PSCLNode; overload;
     function AddValue(const AName: string; const Value: Int64; Base: TSCLNumberBase = nbDefault): PSCLNode; overload;
     function AddValue(const AName: string; const Value: Double; APrecision: TSCLPrecision = 16): PSCLNode; overload;
     function AddValue(const AName: string; const Value: TBytes): PSCLNode; overload;
     function AddValue(const AName: string; const Value: TDateTime; AOffset: SmallInt = TIME_OFFSET_LOCAL): PSCLNode; overload;
     { Преобразует тип узла к заданному. Возвращает True если тип узла был изменён }
     function ForceType(RequiredType: TSCLNodeType): Boolean;
    { Преобразует пустой узел в массив или таблицу }
    procedure MakeParent(AsTable, AsInline: Boolean);
    { Добавляет дерево узлов, игнорируя существующие }
    procedure MergeNodes(Source: PSCLNode);
    { Удаляет дочерний узел }
    procedure RemoveNode(Node: PSCLNode);
    { Присваивает узлу значение и дополнительную информацию в один шаг. Устанавливает тип пустых узлов. }
    procedure SetValue(const Value: Boolean); overload;
    procedure SetValue(const Value: Double; APrecision: TSCLPrecision = High(TSCLPrecision)); overload;
    procedure SetValue(const Value: Int64; Base: TSCLNumberBase = nbDefault); overload;
    procedure SetValue(const Value: TBytes); overload;
    procedure SetValue(const Value: TDateTime; AOffset: SmallInt = TIME_OFFSET_LOCAL); overload;
    procedure SetValue(const Value: string; &Type: TSCLStringType = stDefault); overload;
    { Присваивает пустому узлу значение Null }
    procedure SetNullValue; inline;
     function GetEnumerator: TArrayEnumerator; inline;
     { Возвращает True для пустых узлов (ntEmpty или массив/таблица без элементов) }
     function IsEmpty: Boolean;
     { Возвращает True для строчных массивов и таблиц }
     function IsInline: Boolean;
     { Признак того, что это первый или последний узел у родителя }
     function IsFirst: Boolean; inline;
     function IsLast: Boolean; inline;
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
     { Имя узла }
     property Name: string read FName;
     { Комментарий к узлу }
     property Comment: string read FComment write FComment;
     { Путь к узлу от корневого узла }
     property Path: string read GetPath;
     { Точность числа с плавающей точкой }
     property Precision: TSCLPrecision read GetPrecision write SetPrecision;
     { Предыдущий и следующий узлы в текущем контейнере }
     property PrevSibling: PSCLNode read FPrev;
     property NextSibling: PSCLNode read FNext;
     { Возвращают первый и последний дочерний узел }
     property FirstChild: PSCLNode read GetFirstChild;
     property LastChild: PSCLNode read GetLastChild;
     { Возвращает дочерний узел по его имени, если такого нет вернёт nil }
     property Items[const AName: string]: PSCLNode read GetItemByName; default;
     { Тип узла }
     property NodeType: TSCLNodeType read FType;
     { Система счисления для записи числа }
     property NumberBase: TSCLNumberBase read GetNumberBase write SetNumberBase;
     { Родительский узел, nil для RootNode и NullNode }
     property Parent: PSCLNode read FParent;
     { Смещение времени для ntDateTime, равно -1 для локального времени }
     property TimeOffset: SmallInt read GetTimeOffset write SetTimeOffset;
     { Тип строки }
     property StringType: TSCLStringType read GetStringType write SetStringType;
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
     property VBytes: TBytes read GetBinary write SetValue;
     property VBoolean: Boolean read GetBoolean write SetValue;
     property VDateTime: TDateTime read GetDateTime write SetDateTime;
     property VDouble: Double read GetFloat write SetFloat;
     property VInteger: Int64 read GetInteger write SetInteger;
     property VString: string read GetString write SetString;
  end;

  TSCLDocument = class
  private const
    MINIMUM_STORE_ITEMS = 1024;
  private type
    { Используется для снижения фрагментации памяти и исключения копирования массивов данных }
    PNodeArray = ^TNodeArray;
    TNodeArray = record
    private
      Items: TArray<TSCLNode>;
      Prev: PNodeArray;
      function Expand(DefaultCount: Integer): PNodeArray;
      function Free: PNodeArray;
    end;
  private
    FBuffer: TStringBuffer;     // используется для работы с путями узлов
    FLookup: TArray<PSCLNode>;  // глобальная хэш таблица для таблиц
    FHashed: Integer;           // количество элементов в хэш-таблице
    FRemoved: Integer;          // счётчик удалённых элементов в хэш-таблице
    FNodeArray: PNodeArray;     // цепочка хранилищ узлов документа
    FNextIndex: Integer;        // индекс следующего свободного узла
    FRootNode: PSCLNode;        // корневой узел документа
     function CreateArray: NativeInt; inline;
     function CreateNode(AParent: Pointer; AType: TSCLNodeType): PSCLNode;
     function Find(Parent: PSCLNode; const Name: string; out Index: Integer): Boolean;
    procedure GrowAndRehash;
    procedure InsertHashed(LookupIndex: Integer; Node: PSCLNode);
    procedure RemoveSubTree(Node: PSCLNode);
  public
    constructor Create(Capacity: Integer = 0);
    destructor Destroy; override;
    procedure Clear;
    procedure Merge(Source: TSCLDocument);
     function IsEmpty: Boolean; inline;
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
  SCLTypeNames: array [TSCLNodeType] of string = (
    sTypeName_Empty,
    '#Reserved', // do not localize!
    sTypeName_Binary,
    sTypeName_Boolean,
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

const
  REMOVED_NODE_LINK = PByte(1);
  SCL_NODE_SIZE = SizeOf(TSCLNode);

{$IF SCL_NODE_SIZE > 32}{$Message Warn 'Превышен запланированный размер узла SCL в 32 байта!'}{$IFEND}

resourcestring
  sAssignNotAllowed  = 'Не допускается прямое копирование элементов TSCLNode';
  sBinaryValueTooBig = 'Слишком большой размер двоичных данных';
  sCantMergeNodeType = 'Нельзя объединить документы с разным типом корневых узлов!';
  sConversionFailed  = 'Невозможно преобразовать элемент %s (%s) к типу ''%s''';
  sDuplicateItemName = 'Элемент %s уже существует в таблице %s';
  sIllegalNameChars  = 'Недопустимый символ в имени узла: ''%s''';
  sInvalidItemLink   = 'Недопустимая ссылка на узел документа (nil)';
  sInvalidNodePath   = 'Некорректный путь к узлу: %s';
  sInvalidValueType  = 'Элемент %s [%s] должен иметь тип ''%s''';
  sLookupTableIsFull = 'В массиве хэшей нет свободных мест';
  sNestedInlineError = 'Вложенные строчные массивы и таблицы не допускаются';
  sNoArrayNameAllowd = 'Элементы массива не могут иметь ключей';
  sNodeIsNotAParent  = 'Элемент %s [%s] не является массивом или таблицей';
  sNoTextBlckAllowed = 'Текстовые блоки не допускаются внутри строчных массивов и таблиц';
  sReservedTypeError = 'Обнаружен недопустимый тип элемента';
  sTableItemNameRqrd = 'Для элементов таблиц необходимо указать не пустые имена';
  sTooManyChildItems = 'Достигнут предел дочерних элементов в %s';

  {$IFDEF CPU64BITS}
  sMaxDocSizeExceed  = 'Превышен максимальный размер SCL-документа';
  sMaxHashSizeExceed = 'Превышен максимально допустимый размер хэш-таблицы';
  {$ENDIF}

const
  FLAG_INLINE = $01; // строчный массив или таблица

var
  SCLFormatSettings: TFormatSettings;

type
  HDateTime = record helper for TDateTime
    function Deconstruct: TDecodedTime; inline;
  end;

var
  SCLHexTable: TArray<LongWord>;

function BinToHex(const Value: TBytes): string;
begin
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
    Result := (Ord(Key[Index]) or $20 xor Result) * $01000193;
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

function HDateTime.Deconstruct: TDecodedTime;
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

function TSCLNode.AddArray(const AName: string; AsInline: Boolean): PSCLNode;
begin
  Result := AddChild(AName, ntArray);
  Result.FSubType := Byte(AsInline);
end;

function TSCLNode.AddChild(const AName: string; AType: TSCLNodeType; LookupIndex: Integer): PSCLNode;
begin
  { Нельзя создать узлы следующих типов стандартным способом }
  if AType = ntReserved then
    raise ESCLError.CreateRes(@sReservedTypeError);
  var PNodeName := PPChar(@AName)^;
  case FType of
    ntEmpty:
      begin
        ForceType(ParentTypes[PNodeName <> nil]);
        if FType = ntTable then
          { Необходимо узнать индекс нового элемента в хэш-таблице }
          PSCLArray(FValue).FDocument.Find(@Self, AName, LookupIndex);
      end;
    ntArray:
      if PNodeName <> nil then
        raise ESCLError.CreateResFmt(@sNoArrayNameAllowd, [AName, GetPath]);
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
  if FInfo = FInfo.MaxValue then
    raise ESCLError.CreateResFmt(@sTooManyChildItems, [GetPath]);
  { Вложенные массивы и таблицы запрещены для строчных }
  if (FSubType and FLAG_INLINE <> 0) and (AType in [ntArray, ntTable]) then
    raise ESCLError.CreateResFmt(@sNestedInlineError, [GetPath]);
  with PSCLArray(FValue)^ do
  begin
    Result := FDocument.CreateNode(@Self, AType);
    Result.FName := AName;
    if FFirst = nil then
      FFirst := Result;
    if FLast <> nil then
      FLast.FNext := Result;
    Result.FPrev := FLast;
    FLast := Result;
    { Для таблиц дополнительно обновляем хэш-таблицу }
    if LookupIndex >= 0 then
      FDocument.InsertHashed(LookupIndex, Result);
  end;
  Inc(FInfo);
end;

function TSCLNode.AddNode(const AName: string; AType: TSCLNodeType): PSCLNode;
begin
  Result := AddChild(AName, AType);
end;

function TSCLNode.AddTable(const AName: string; AsInline: Boolean): PSCLNode;
begin
  Result := AddChild(AName, ntTable);
  Result.FSubType := Byte(AsInline);
end;

function TSCLNode.AddValue(const AName, Value: string; &Type: TSCLStringType): PSCLNode;
begin
  { Строчные массивы и таблицы не допускают переноса строк }
  if (&Type in [stText, stWrapped]) and (FType in [ntEmpty, ntArray, ntTable]) and (FSubType and FLAG_INLINE <> 0) then
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

function TSCLNode.AddValue(const AName: string; const Value: Int64; Base: TSCLNumberBase): PSCLNode;
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

procedure TSCLNode.MakeParent(AsTable, AsInline: Boolean);
const
  Flags: array [Boolean] of Byte = (0, FLAG_INLINE);
begin
  ForceType(ParentTypes[AsTable]);
  FSubType := FSubType and not FLAG_INLINE or Flags[AsInline];
end;

procedure TSCLNode.MergeNodes(Source: PSCLNode);
begin
  { Проверяем на отсутствие существующего узла }
  var LookupIndex: Integer := -1;
  if (Source.FType <> ntReserved) and not Exists(Source.FName, LookupIndex) then
  begin
    { Создаём новый дочерний узел }
    var Target := AddChild(Source.Name, Source.FType, LookupIndex);
    case Source.FType of
      ntBoolean, ntDateTime, ntFloat, ntInteger:
        begin
          { Простые типы }
          Target.FSubType := Source.FSubType;
          Target.FInfo := Source.FInfo;
          Target.FValue := Source.FValue;
        end;
      ntBinary:
        { Массив байт }
        PBytes(@Target.FValue)^ := PBytes(@Source.FValue)^;
      ntString:
        begin
          { Строка }
          Target.FSubType := Source.FSubType;
          PString(@Target.FValue)^ := PString(@Source.FValue)^;
        end;
      ntArray, ntTable:
        begin
          { Массив или таблица }
          Target.FSubType := Source.FSubType and FLAG_INLINE;
          for var Item in Source^ do
            Target.MergeNodes(Item);
        end;
    end;
  end;
end;

procedure TSCLNode.RemoveNode(Node: PSCLNode);
begin
  if Node = nil then
    raise ESCLError.CreateRes(@sInvalidItemLink);
  if Node.FParent <> @Self then
    raise ESCLError.CreateFmt('Узел %s не является дочерним узлом для %s', [Node.FName, FName]);
  var SCLArray := PSCLArray(FValue);
  SCLArray.FDocument.RemoveSubTree(Node);
  { Восстанавливаем связность оставшихся элементов }
  if Node = SCLArray.FFirst then
    SCLArray.FFirst := Node.FNext
  else if Node.FPrev <> nil then
    Node.FPrev.FNext := Node.FNext;
  if SCLArray.FLast = Node then
    SCLArray.FLast := Node.FPrev
  else if Node.FNext <> nil then
    Node.FNext.FPrev := Node.FPrev;
  { Завершаем удаление узла }
  Node^ := Default(TSCLNode);
  Dec(FInfo);
end;

function TSCLNode.AddValue(const AName: string; const Value: TBytes): PSCLNode;
begin
  if Length(Value) > MAX_BINARY_LENGTH then
    Raise ESCLError.CreateRes(@sBinaryValueTooBig);
  Result := AddChild(AName, ntBinary);
  PBytes(@Result.FValue)^ := Value;
end;

function TSCLNode.AddValue(const AName: string; const Value: Double; APrecision: TSCLPrecision): PSCLNode;
begin
  Result := AddChild(AName, ntFloat);
  Result.FSubType := APrecision;
  PDouble(@Result.FValue)^ := Value;
end;

class operator TSCLNode.Assign(var Dest: TSCLNode; const [ref] Src: TSCLNode);
begin
  raise ESCLError.CreateRes(@sAssignNotAllowed);
end;

function TSCLNode.CountNodesInSubtree: Integer;
begin
  Result := 1; // посчитали сами себя
  if FType in [ntArray, ntTable] then
  begin
    var Item := PSCLArray(FValue).FFirst;
    while Item <> nil do
    begin
      Inc(Result, Item.CountNodesInSubtree);
      Item := Item.FNext;
    end;
  end;
end;

function TSCLNode.Exists(const AName: string; out LookupIndex: Integer): Boolean;
begin
  Result := (FType = ntTable) and (AName <> '') and PSCLArray(FValue).FDocument.Find(@Self, AName, LookupIndex);
end;

class operator TSCLNode.Finalize(var Instance: TSCLNode);
begin
  case Instance.FType of
    ntBinary: Finalize(PBytes(@Instance.FValue)^);
    ntString: Finalize(PString(@Instance.FValue)^);
  end;
end;

function TSCLNode.ForceType(RequiredType: TSCLNodeType): Boolean;
begin
  Result := FType <> RequiredType;
  if Result then
  begin
    { Изменить тип можно только у новых узлов }
    if FType <> ntEmpty then
      raise ESCLError.CreateResFmt(@sInvalidValueType, [FName, TypeName, SCLTypeNames[RequiredType]]);
    { Для массивов и таблиц необходимо создать служебный элемент }
    if (RequiredType in [ntArray, ntTable]) and (FParent <> nil) then
      FValue := PSCLArray(FParent.FValue).FDocument.CreateArray;
    { Меняем тип элемента на требуемый }
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
  if not TypeCheckParent then Exit(0);
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
  if not TypeCheckParent then Exit(nil);
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
  if not TypeCheckParent then Exit(nil);
  Result := PSCLArray(FValue).FLast;
end;

function TSCLNode.GetNumberBase: TSCLNumberBase;
begin
  TypeCheck(ntInteger);
  Result := TSCLNumberBase(FSubType);
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
  if IsRoot then Exit('/');
  if (FType = ntReserved) or (FParent = nil) then Exit('');
  var NameBuilder := PSCLArray(FValue).FDocument.FBuffer;
  NameBuilder.Reset.Append('/');
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
      NameBuilder.Append('@').Append(IntToStr(Node.ItemIndex))
    else
      NameBuilder.Append('/').Append(Node.Name);
  end;
  Result := NameBuilder.ToString;
end;

function TSCLNode.GetPrecision: TSCLPrecision;
begin
  TypeCheck(ntFloat);
  Result := FSubType;
end;

function TSCLNode.GetString: string;
begin
  TypeCheck(ntString);
  Result := PString(@FValue)^;
end;

function TSCLNode.GetStringType: TSCLStringType;
begin
  TypeCheck(ntString);
  Result := TSCLStringType(FSubType);
end;

function TSCLNode.GetTimeOffset: SmallInt;
begin
  TypeCheck(ntDateTime);
  Result := FInfo;
end;

function TSCLNode.IsEmpty: Boolean;
begin
  Result := (FType = ntEmpty) or (FType in [ntArray, ntTable]) and (FInfo = 0);
end;

function TSCLNode.IsFirst: Boolean;
begin
  Result := FPrev = nil;
end;

function TSCLNode.IsInline: Boolean;
begin
  const FLAG_INLINE = FLAG_INLINE; // для inline
  Result := (FType in [ntArray, ntTable]) and (FSubType and FLAG_INLINE <> 0);
end;

function TSCLNode.IsLast: Boolean;
begin
  Result := FNext = nil;
end;

function TSCLNode.IsRoot: Boolean;
begin
  Result := (FParent = nil) and (FType in [ntEmpty, ntArray, ntTable]) and (FValue <> 0);
end;

function TSCLNode.ItemByPath(const NodePath: string): PSCLNode;
begin
  if not TypeCheckParent then Exit(nil);
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

procedure TSCLNode.SetDateTime(const Value: TDateTime);
begin
  if ForceType(ntDateTime) then
    FInfo := TIME_OFFSET_LOCAL;
  PDateTime(@FValue)^ := Value;
end;

procedure TSCLNode.SetFloat(const Value: Double);
begin
  if ForceType(ntFloat) then
    FSubType := High(TSCLPrecision);
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

procedure TSCLNode.SetNumberBase(const Value: TSCLNumberBase);
begin
  TypeCheck(ntInteger);
  FSubType := Byte(Value);
end;

procedure TSCLNode.SetPrecision(const Value: TSCLPrecision);
begin
  TypeCheck(ntFloat);
  FSubType := Value;
end;

procedure TSCLNode.SetString(const Value: string);
begin
  ForceType(ntString);
  PString(@FValue)^ := Value;
end;

procedure TSCLNode.SetStringType(const Value: TSCLStringType);
begin
  TypeCheck(ntString);
  FSubType := Byte(Value);
end;

procedure TSCLNode.SetTimeOffset(const Value: SmallInt);
begin
  TypeCheck(ntDateTime);
  FInfo := Value;
end;

procedure TSCLNode.SetValue(const Value: Double; APrecision: TSCLPrecision);
begin
  ForceType(ntFloat);
  PDouble(@FValue)^ := Value;
  FSubType := APrecision;
end;

procedure TSCLNode.SetValue(const Value: Int64; Base: TSCLNumberBase);
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

procedure TSCLNode.SetValue(const Value: string; &Type: TSCLStringType);
begin
  ForceType(ntString);
  PString(@FValue)^ := Value;
  FSubType := Byte(&Type);
end;

procedure TSCLNode.SetValue(const Value: TBytes);
begin
  if Length(Value) > MAX_BINARY_LENGTH then
    Raise ESCLError.CreateRes(@sBinaryValueTooBig);
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
  if not TypeCheckParent then Exit(nil);
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
    var DateType: TDateType;
    var DateTimeValue: TDateTime := PDateTime(@FValue)^;
    var OffsetHours:   Word := 0;
    var OffsetMinutes: Word := 0;
    case FInfo of
      -1: { Если время локальное, то проверяем на упрощённый формат }
          if Trunc(DateTimeValue) = 0 then
            DateType := dtTimeOnly
          else if (Frac(DateTimeValue) = 0) then
            DateType := dtDateOnly
          else DateType := dtLocal;
       0: DateType := dtUTC;
    else
      var Offset: Word := Abs(FInfo);
      OffsetHours   := Offset div 60;
      OffsetMinutes := Offset - OffsetHours * 60;
      DateType := OffsetTypes[Word(FInfo) shr 15];
    end;
    with DateTimeValue.Deconstruct do
      Result := Format(DateFormats[DateType], [Year, Month, Day, Hour, Minute, Second, OffsetHours, OffsetMinutes]);
  end;

  function DoubleToString(Value: Double): string;
  begin
    Result := Value.ToString(ffGeneral, FSubType, 0, SCLFormatSettings);
    var Cursor := PPChar(@Result)^;
    for var Index := 1 to Result.Length do
    begin
      case Cursor^ of
        'A'..'Z': Cursor^ := Chr(Ord(Cursor^) or $20);
      end;
      Inc(Cursor);
    end;
  end;

const
  BoolStrings: array [Boolean] of string = ('false', 'true');
begin
  case FType of
    ntReserved:  Result := '#ERROR';
    ntBinary:    Result := BinToHex(PBytes(@FValue)^);
    ntBoolean:   Result := BoolStrings[Boolean(FValue)];
    ntDateTime:  Result := DateTimeAsString;
    ntFloat:     Result := DoubleToString(PDouble(@FValue)^);
    ntInteger:   if FSubType = 0 then
                   Result := IntToStr(FValue)
                 else
                   Result := IntToBaseTwo(FValue, FSubType);
    ntNull:      Result := 'null';
    ntString:    Result := PString(@FValue)^;
    else raise ESCLError.CreateResFmt(@sConversionFailed, [FName, TypeName, sTypeName_String]);
  end;
end;

procedure TSCLNode.TypeCheck(RequiredType: TSCLNodeType);
begin
  if FType <> RequiredType then
    raise ESCLError.CreateResFmt(@sInvalidValueType, [FName, TypeName, SCLTypeNames[RequiredType]]);
end;

function TSCLNode.TypeCheckParent: Boolean;
begin
  Result := FType in [ntArray, ntTable];
  if not Result and (FType <> ntEmpty) then
    raise ESCLError.CreateResFmt(@sNodeIsNotAParent, [FName, TypeName]);
end;

function TSCLNode.TypeName: string;
begin
  Result := SCLTypeNames[FType];
end;

{ TSCLDocument.TNodeArray }

function TSCLDocument.TNodeArray.Expand(DefaultCount: Integer): PNodeArray;
begin
  if (@Self <> nil) and (Prev <> nil) then
    DefaultCount := Length(Items) shl 1;
  {$IFDEF CPU64BITS}
  if DefaultCount > Integer.MaxValue shr 5 then // недостижимо при компиляции в 32-х битном режиме
    raise ESCLError.CreateRes(@sMaxDocSizeExceed);
  {$ENDIF}
  New(Result);
  Result.Prev := @Self;
  SetLength(Result.Items, DefaultCount);
  FillChar(Result.Items[0], DefaultCount * SizeOf(TSCLNode), 0);
end;

function TSCLDocument.TNodeArray.Free: PNodeArray;
begin
  if @Self = nil then Exit(nil);
  Result := Prev;
  Dispose(PNodeArray(@Self));
end;

{ TSCLDocument }

procedure TSCLDocument.Clear;
begin
  { Проверка на исходное состояние документа }
  if (FRootNode.FType = ntEmpty) and (FNodeArray.Prev = nil) then Exit;
  { Обнуляем всю существующую структуру документа }
  FHashed := 0;
  FRemoved := 0;
  FNextIndex := 0;
  { Удаляем все хранилища узлов, кроме первого }
  while FNodeArray.Prev <> nil do
    FNodeArray := FNodeArray.Free;
  { Обрезаем и обнуляем таблицу хэшей со ссылками на элементы }
  var NodeCount := Length(FNodeArray.Items);
  SetLength(FLookup, NodeCount);
  FillChar(FLookup[0], NodeCount * SizeOf(PSCLNode), 0);
  { Обнуляем первичное хранилище данных }
  Finalize(FNodeArray.Items[0], NodeCount);
  FillChar(FNodeArray.Items[0], NodeCount * SizeOf(TSCLNode), 0);
  { Пересоздаём основную таблицу документа }
  FRootNode := CreateNode(nil, ntEmpty);
  FRootNode.FValue := CreateArray;
end;

constructor TSCLDocument.Create(Capacity: Integer);
begin
  { Выделяем память под элементы и индексы }
  Capacity := NextPowerOfTwo(Capacity, MINIMUM_STORE_ITEMS);
  FNodeArray := FNodeArray.Expand(Capacity);
  SetLength(FLookup, Capacity);
  FillChar(FLookup[0], Length(FLookup) * SizeOf(PSCLNode), 0);
  FBuffer := TStringBuffer.Create(string.Empty);
  { Создаём основную таблицу документа  }
  FRootNode := CreateNode(nil, ntEmpty);
  FRootNode.FValue := CreateArray;
end;

function TSCLDocument.CreateArray: NativeInt;
begin
  Result := NativeInt(@CreateNode(Self, ntReserved).FParent);
end;

function TSCLDocument.CreateNode(AParent: Pointer; AType: TSCLNodeType): PSCLNode;
begin
  { Проверяем что у нас достаточно свободных элементов }
  if FNextIndex >= Length(FNodeArray.Items) then
  begin
    FNodeArray := FNodeArray.Expand(Length(FNodeArray.Items));
    FNextIndex := 0;
  end;
  { Резервируем новый элемент }
  Result := @FNodeArray.Items[FNextIndex];
  Result.FParent := AParent;
  Result.FType := AType;
  Inc(FNextIndex);
  { Для таблиц и массивов создаём дополнительный элемент }
  if AType in [ntArray, ntTable] then
    Result.FValue := CreateArray;
end;

destructor TSCLDocument.Destroy;
begin
  var NextArray := AtomicExchange(FNodeArray, nil);
  while NextArray <> nil do
    NextArray := NextArray.Free;
  FBuffer.Free;
end;

function TSCLDocument.Find(Parent: PSCLNode; const Name: string; out Index: Integer): Boolean;
begin
  var Mask := High(FLookup);
  var Hash := HashFNV1a16(Parent, Name);
  var From := Integer(Hash and Mask);
  var Step := Integer(Hash shr 8 and Mask or 1);
  var Removed := -1;
  Index := From;
  { Ищем по хэшу с индекса From и шагом Step }
  repeat
    var Item := FLookup[Index];
    if PByte(Item) = nil then
    begin
      if Removed >= 0 then
        Index := Removed;
      Exit(False); // элемент отсутствует в таблице
    end else if PByte(Item) = REMOVED_NODE_LINK then
    begin
      if Removed < 0 then
        Removed := Index;
    end else if (Item.FParent = Parent) and ASCIISameName(Item.FName, Name) then
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
  var Lookups := Length(FLookup);
  {$IFDEF CPU64BITS}
  if Lookups > Integer.MaxValue div 2 then // недостижимо при компиляции в 32-х битном режиме
    raise ESCLError.CreateRes(@sMaxHashSizeExceed);
  {$ENDIF}
  SetLength(Rehashed, Lookups shl Ord(FHashed > Length(FLookup) shr 1));
  FillChar(Rehashed[0], Length(Rehashed) * SizeOf(PSCLNode), 0);
  { Перераспределяем элементы из старого массива в новый }
  var ItemCount := 0;
  var Mask: Cardinal := High(Rehashed);
  for var Index := 0 to Lookups - 1 do
  begin
    var Item := FLookup[Index];
    if PByte(Item) > REMOVED_NODE_LINK then
    begin
      var Hash := HashFNV1a16(Item.FParent, Item.FName);
      var From := Hash and Mask;
      var Step := Hash shr 8 and Mask or 1;
      var Next := From;
      while Rehashed[Next] <> nil do
        Next := (Next + Step) and Mask;
      Rehashed[Next] := Item;
      Inc(ItemCount);
    end;
  end;
  FLookup := Rehashed;
  FHashed := ItemCount;
  FRemoved := 0;
end;

procedure TSCLDocument.InsertHashed(LookupIndex: Integer; Node: PSCLNode);
begin
  if PByte(FLookup[LookupIndex]) = REMOVED_NODE_LINK then
    Dec(FRemoved);
  FLookup[LookupIndex] := Node;
  Inc(FHashed);
  if FHashed + FRemoved >= Length(FLookup) * 3 shr 2 then
    GrowAndRehash;
end;

function TSCLDocument.IsEmpty: Boolean;
begin
  Result := FRootNode.IsEmpty;
end;

procedure TSCLDocument.Merge(Source: TSCLDocument);
begin
  if (FRootNode.FType <> Source.FRootNode.FType) and (FRootNode.FType <> ntEmpty) then
    raise ESCLError.CreateRes(@sCantMergeNodeType);
  if Source <> Self then
    for var Item in Source.FRootNode^ do
      FRootNode.MergeNodes(Item);
end;

procedure TSCLDocument.RemoveSubTree(Node: PSCLNode);
begin
  { Удаление корневого узла документа }
  if Node = FRootNode then
  begin
    Clear;
    Exit;
  end;
  if (Node.FParent = nil) or (TSCLNode.PSCLArray(Node.Parent.FValue).FDocument <> Self) then
    raise ESCLError.Create('Попытка удаления узла, не принадлежащего данному документу');
  { Рекурсивно удаляем вложенные элементы }
  if Node.FType in [ntArray, ntTable] then
    for var Item in Node^ do
    begin
      RemoveSubTree(Item);
      Item^ := Default(TSCLNode);
    end;
  { Если узел принадлежит таблице, то удаляем все узлы из хэш-таблицы }
  var LookupIndex := -1;
  if (Node.FParent.FType = ntTable) and Find(Node.FParent, Node.FName, LookupIndex) then
  begin
    FLookup[LookupIndex] := PSCLNode(REMOVED_NODE_LINK);
    Dec(FHashed);
    Inc(FRemoved);
  end;
end;

initialization
  SCLFormatSettings := TFormatSettings.Create;
  SCLFormatSettings.DecimalSeparator := '.';
  SetLength(SCLHexTable, $100);
  for var Index := 0 to High(SCLHexTable) do
    SCLHexTable[Index] := Word(HexChars[Index and $0F]) shl 16 or Word(HexChars[Index shr 4]);

end.

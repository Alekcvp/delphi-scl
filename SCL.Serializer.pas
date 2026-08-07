unit SCL.Serializer;

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

uses
  System.SysUtils, System.Classes, System.Rtti, System.TypInfo, SCL.Document;

type
  ESerializeError = class(Exception);

  SCLBaseAttribute = class(TCustomAttribute)
  private
    FBase: TSCLNode.TNumberBase;
  public
    constructor Create(const ANumberBase: TSCLNode.TNumberBase);
  end;

  SCLCommentAttribute = class(TCustomAttribute)
  private
    FComment: string;
  public
    constructor Create(const AComment: string);
  end;

  SCLInlineAttribute = class(TCustomAttribute)
  end;

  SCLNameAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const AName: string);
  end;

  SCLStateAttribute = class(TCustomAttribute)
  public type
    TValueState = (vsDefault, vsRequired, vsDontWrite, vsIgnore);
  private
    FState: TValueState;
  public
    constructor Create(const AState: TValueState);
  end;

  SCLStringAttribute = class(TCustomAttribute)
  private
    FType: TSCLNode.TStringType;
  public
    constructor Create(const AStringType: TSCLNode.TStringType);
  end;

  SCLTimeZoneAttribute = class(TCustomAttribute)
  end;

  PValueAttributes = ^TValueAttributes;
  TValueAttributes = record
    Name: string;
    Comment: string;
    State: SCLStateAttribute.TValueState;
    HasComment: Boolean;
    InlineMode: Boolean;
    IsTimeZone: Boolean;
    NumberBase: TSCLNode.TNumberBase;
    StringType: TSCLNode.TStringType;
    constructor Create(const AName: string; const Attributes: TArray<TCustomAttribute>);
  end;

  TSCLSerializer = record
  private type
    TValueReader = procedure (Node: PSCLNode; Data: Pointer; AType: TRttiType);
    TValueWriter = procedure (ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
    TTypeReaders = array [System.TTypeKind] of TValueReader;
    TTypeWriters = array [System.TTypeKind] of TValueWriter;
  private class var
    FReaderMap: TTypeReaders;
    FWriterMap: TTypeWriters;
  private
    FRTTIContext: TRttiContext;
    class procedure InitMappingTables; static;
    class procedure ReadAnsiChar(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadDynamycArray(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadEnumeration(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadFloat(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadInt64(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadInteger(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadLString(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadRecord(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadSet(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadStaticArray(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadString(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadUString(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadWideChar(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure ReadWString(Node: PSCLNode; Data: Pointer; AType: TRttiType); static;
    class procedure TypeNotSupported(Node: PSCLNode; Data: Pointer; AType: TRttiType); overload; static;
    class procedure TypeNotSupported(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); overload; static;
    class procedure WriteAnsiChar(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteDynamycArray(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteEnumeration(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteFloat(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteInt64(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteInteger(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteLString(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteRecord(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteSet(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteStaticArray(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteString(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteUString(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteWideChar(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
    class procedure WriteWString(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType); static;
  public
    class operator Initialize(out Instance: TSCLSerializer);
    class operator Finalize(var Instance: TSCLSerializer);
    class procedure ReadValue(ParentNode: PSCLNode; const Name: string;
      const Attributes: TArray<TCustomAttribute>; Data: Pointer; AType: TRttiType); static;
    class procedure WriteValue(ParentNode: PSCLNode; const Name: string;
      const Attributes: TArray<TCustomAttribute>; Data: Pointer; AType: TRttiType); static;
  public
    procedure Deserialize<T>(Document: TSCLDocument; out Value: T; const Name: string = string.Empty);
    procedure Serialize<T>(Document: TSCLDocument; const Value: T; const Name: string = string.Empty); overload;
     function Serialize<T>(const Value: T; const Name: string = string.Empty): TSCLDocument; overload;
  end;


implementation

uses
  System.DateUtils, System.TimeSpan, SCL.Common;

resourcestring
  sArraySizeMismatch = 'Размер данных (%d) не соответствует размеру массива (%d)';
  sCharacterRequired = 'Вместо символа обнаружена строка';
  sNodeNameRequired  = 'Имя узла не может быть пустой строкой';
  sReqrdValueMissing = 'Отсутствует требуемое значение: ''%s''';
  sUnknownEnumValue  = 'Неизвестное значение ''%s'' для типа %s';
  sValueTypeNotSupp  = 'Тип данных ''%s'' не поддерживается';

type
  HBytes = record helper for TBytes
    constructor Create(Buffer: PByte; Count: Integer);
  end;

const
  ArrayItemAttributes: TValueAttributes = (
    Name: string.Empty;
    Comment: string.Empty;
    State: vsDefault;
    InlineMode: False;
    NumberBase: nbDefault;
    StringType: stDefault;
  );

function EnumItemIndex(const SearchName: string; ATypeInfo: PTypeInfo): Integer;
begin
  var TypeData := ATypeInfo.TypeData;
  for var Index := TypeData.MinValue to TypeData.MaxValue do
  begin
    var EnumName := GetEnumName(ATypeInfo, Index);
    if AnsiCompareText(SearchName, EnumName) = 0 then
      Exit(Index);
  end;
  raise ESerializeError.CreateResFmt(@sUnknownEnumValue, [SearchName, ATypeInfo.Name]);
end;

function GetChar(Node: PSCLNode): Char;
begin
  var Value := Node.AsString;
  if Value.Length <> 1 then
    raise ESerializeError.CreateRes(@sCharacterRequired);
  Result := Value[1];
end;

function IsBitSet(Value: PByte; Index: Integer): Boolean; assembler;
asm
  {$IFDEF CPU64BIT}
  bt    [rcx], rdx
  {$ELSE}
  bt    [eax], edx
  {$ENDIF}
  setb  al
end;

procedure SetBit(Value: PByte; Index: Integer); assembler;
asm
  {$IFDEF CPU64BIT}
  bts   [rcx], rdx
  {$ELSE}
  bts   [eax], edx
  {$ENDIF}
end;

function SplitComment(const Comment: string): TArray<string>;
begin
  if Comment.IsEmpty then Exit(nil);
  var Source := PPChar(@Comment)^;
  var Cursor := Source;
  var Index := 0;
  repeat
    while (Cursor^ >= #32) or (Cursor^ = #09) do Inc(Cursor);
    if Index >= Length(Result) then
      SetLength(Result, NextPowerOfTwo(Index + 1, 16));
    Result[Index] := Source.SubString(Cursor);
    if Cursor^ = #13 then Inc(Cursor);
    if Cursor^ = #10 then Inc(Cursor);
    Source := Cursor;
    Inc(Index);
  until Cursor^ = #0;
  SetLength(Result, Index);
end;

function StringFromCharArray(Buffer: PWideChar; Count: Integer): string; overload; inline;
begin
  SetString(Result, Buffer, Count);
end;

function StringFromCharArray(Buffer: PAnsiChar; Count: Integer): string; overload; inline;
begin
  SetString(Result, Buffer, Count);
end;

{ HBytes }

constructor HBytes.Create(Buffer: PByte; Count: Integer);
begin
  SetLength(Self, Count);
  if Count > 0 then
    Move(Buffer^, PByte(Self)^, Count);
end;

{ SCLBaseAttribute }

constructor SCLBaseAttribute.Create(const ANumberBase: TSCLNode.TNumberBase);
begin
  FBase := ANumberBase;
end;

{ SCLNameAttribute }

constructor SCLNameAttribute.Create(const AName: string);
begin
  if AName = '' then
    raise ESerializeError.CreateRes(@sNodeNameRequired);
  FName := AName;
end;

{ SCLCommentAttribute }

constructor SCLCommentAttribute.Create(const AComment: string);
begin
  FComment := AComment;
end;

{ SCLStateAttribute }

constructor SCLStateAttribute.Create(const AState: TValueState);
begin
  FState := AState;
end;

{ SCLStringAttribute }

constructor SCLStringAttribute.Create(const AStringType: TSCLNode.TStringType);
begin
  FType := AStringType;
end;

{ TValueAttributes }

constructor TValueAttributes.Create(const AName: string; const Attributes: TArray<TCustomAttribute>);
const
  IgnoreStates: array [Boolean] of SCLStateAttribute.TValueState = (vsDontWrite, vsIgnore);
begin
  Self := Default(TValueAttributes);
  for var Attribute in Attributes do
    if Attribute is SCLNameAttribute then
      Name := SCLNameAttribute(Attribute).FName
    else if Attribute is SCLBaseAttribute then
      NumberBase := SCLBaseAttribute(Attribute).FBase
    else if Attribute is SCLCommentAttribute then
    begin
      Comment := SCLCommentAttribute(Attribute).FComment;
      HasComment := True;
    end else if Attribute is SCLStateAttribute then
      State := SCLStateAttribute(Attribute).FState
    else if Attribute is SCLStringAttribute then
      StringType := SCLStringAttribute(Attribute).FType
    else if Attribute is SCLInlineAttribute then
      InlineMode := True
    else if Attribute is SCLTimeZoneAttribute then
      IsTimeZone := True;
  if Name = '' then
    Name := AName;
end;

{ TSCLSerializer }

procedure TSCLSerializer.Deserialize<T>(Document: TSCLDocument; out Value: T; const Name: string);
begin
  var TypeInfo := PTypeInfo(TypeInfo(T));
  if TypeInfo <> nil then
    if (Name = '') and (TypeInfo.Kind in [tkArray, tkDynArray, tkRecord, tkMRecord]) then
      FReaderMap[TypeInfo.Kind](Document.Root, @Value, FRTTIContext.GetType(TypeInfo))
    else
    ReadValue(Document.Root, Name, nil, @Value, FRTTIContext.GetType(TypeInfo));
end;

class operator TSCLSerializer.Finalize(var Instance: TSCLSerializer);
begin
  Instance.FRTTIContext.Free;
end;

class operator TSCLSerializer.Initialize(out Instance: TSCLSerializer);
begin
  Instance.FRTTIContext := TRttiContext.Create;
end;

class procedure TSCLSerializer.InitMappingTables;
begin
  for var Index := Low(FReaderMap) to High(FReaderMap) do
    FReaderMap[Index] := TypeNotSupported;
  FReaderMap[tkInteger]     := ReadInteger;
  FReaderMap[tkChar]        := ReadAnsiChar;
  FReaderMap[tkEnumeration] := ReadEnumeration;
  FReaderMap[tkFloat]       := ReadFloat;
  FReaderMap[tkString]      := ReadString;
  FReaderMap[tkSet]         := ReadSet;
  FReaderMap[tkWChar]       := ReadWideChar;
  FReaderMap[tkLString]     := ReadLString;
  FReaderMap[tkWString]     := ReadWString;
  FReaderMap[tkArray]       := ReadStaticArray;
  FReaderMap[tkRecord]      := ReadRecord;
  FReaderMap[tkInt64]       := ReadInt64;
  FReaderMap[tkDynArray]    := ReadDynamycArray;
  FReaderMap[tkUString]     := ReadUString;
  FReaderMap[tkMRecord]     := ReadRecord;
  for var Index := Low(FWriterMap) to High(FWriterMap) do
    FWriterMap[Index] := TypeNotSupported;
  FWriterMap[tkInteger]     := WriteInteger;
  FWriterMap[tkChar]        := WriteAnsiChar;
  FWriterMap[tkEnumeration] := WriteEnumeration;
  FWriterMap[tkFloat]       := WriteFloat;
  FWriterMap[tkString]      := WriteString;
  FWriterMap[tkSet]         := WriteSet;
  FWriterMap[tkWChar]       := WriteWideChar;
  FWriterMap[tkLString]     := WriteLString;
  FWriterMap[tkWString]     := WriteWString;
  FWriterMap[tkArray]       := WriteStaticArray;
  FWriterMap[tkRecord]      := WriteRecord;
  FWriterMap[tkInt64]       := WriteInt64;
  FWriterMap[tkDynArray]    := WriteDynamycArray;
  FWriterMap[tkUString]     := WriteUString;
  FWriterMap[tkMRecord]     := WriteRecord;
end;

class procedure TSCLSerializer.ReadAnsiChar(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  PAnsiChar(Data)^ := AnsiChar(GetChar(Node));
end;

class procedure TSCLSerializer.ReadDynamycArray(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  var ArrayType := AType as TRttiDynamicArrayType;
  var ItemType := ArrayType.ElementType;
  if ItemType.Handle = TypeInfo(Byte) then
  begin
    { Динамический массив байт читаем как байтовую строку }
    var Bytes := Node.AsBytes;
    var Count := Length(Bytes);
    DynArraySetLength(PPointer(Data)^, AType.Handle, 1, @Count);
    Move(PByte(Bytes)^, PPointer(Data)^^, Count);
  end else if ItemType.Handle = TypeInfo(WideChar) then
  begin
    var Chars := Node.AsString;
    var Count := Length(Chars);
    DynArraySetLength(PPointer(Data)^, AType.Handle, 1, @Count);
    Move(PByte(Chars)^, PPointer(Data)^^, Count shl 1);
  end else if ItemType.Handle = TypeInfo(AnsiChar) then
  begin
    var Chars := AnsiString(Node.AsString);
    var Count := Length(Chars);
    DynArraySetLength(PPointer(Data)^, AType.Handle, 1, @Count);
    Move(PByte(Chars)^, PPointer(Data)^^, Count);
  end else
  begin
    { Обычный динамический массив }
    var Bytes := ArrayType.ElementSize;
    var Count := Node.Count;
    DynArraySetLength(PPointer(Data)^, AType.Handle, 1, @Count);
    var ItemData := PByte(PPointer(Data)^);
    for var Item in Node^ do
    begin
      FReaderMap[ItemType.Handle.Kind](Item, ItemData, ItemType);
      Inc(ItemData, Bytes);
    end;
  end;
end;

class procedure TSCLSerializer.ReadEnumeration(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  var TypeInfo := AType.Handle;
  if TypeInfo = System.TypeInfo(Boolean) then
  begin
    PBoolean(Data)^ := Node.AsBoolean;
    Exit;
  end;
  var SearchName := AType.QualifiedName + '.';
  if GetEnumName(TypeInfo, 0).StartsWith(SearchName) then
    SearchName := SearchName + Node.AsString
  else SearchName := Node.AsString;
  var EnumIndex := EnumItemIndex(SearchName, TypeInfo);
  case TypeInfo.TypeData.OrdType of
    otSByte, otUByte: PByte(Data)^ := Byte(EnumIndex);
    otSWord, otUWord: PWord(Data)^ := Word(EnumIndex);
    else PLongWord(Data)^ := LongWord(EnumIndex);
  end;
end;

class procedure TSCLSerializer.ReadFloat(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  var TypeInfo := AType.Handle;
  if TypeInfo = System.TypeInfo(TDateTime) then
    PDateTime(Data)^ := Node.AsDateTime
  else if TypeInfo = System.TypeInfo(Comp) then
    PInt64(Data)^ := Node.AsInteger
  else if TypeInfo = System.TypeInfo(Currency) then
    PCurrency(Data)^ := Currency(Node.AsDouble)
  else if TypeInfo = System.TypeInfo(Extended) then
    PExtended(Data)^ := Extended(Node.AsDouble)
  else if TypeInfo = System.TypeInfo(Single) then
    PSingle(Data)^ := Single(Node.AsDouble)
  else
    PDouble(Data)^ := Node.AsDouble;
end;

class procedure TSCLSerializer.ReadInt64(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  PInt64(Data)^ := Node.AsInteger;
end;

class procedure TSCLSerializer.ReadInteger(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  var OrdinalValue := Int64Rec(Node.AsInteger).Lo;
  case AType.AsOrdinal.OrdType of
    otSByte, otUByte: PByte(Data)^ := Byte(OrdinalValue);
    otSWord, otUWord: PWord(Data)^ := Word(OrdinalValue);
    else PCardinal(Data)^ := OrdinalValue; // otSLong, otULong
  end;
end;

class procedure TSCLSerializer.ReadLString(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  PAnsiString(Data)^ := AnsiString(Node.AsString);
end;

class procedure TSCLSerializer.ReadRecord(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  for var Field in AType.GetFields do
    if Field.FieldType <> nil then
      ReadValue(Node, Field.Name, Field.GetAttributes, PByte(Data) + Field.Offset, Field.FieldType);
end;

class procedure TSCLSerializer.ReadSet(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  var ItemType := AType.AsSet.ElementType;
  if ItemType.TypeKind = tkEnumeration then
  begin
    var TypeInfo := ItemType.Handle;
    var TypeName := ItemType.QualifiedName + '.';
    var NeedType := GetEnumName(TypeInfo, ItemType.AsOrdinal.MinValue).StartsWith(TypeName);
    for var Item in Node^ do
    begin
      var ItemName := Item.AsString;
      if NeedType then
        ItemName := TypeName + ItemName;
      SetBit(Data, EnumItemIndex(ItemName, TypeInfo));
    end;
  end else for var Item in Node^ do
    SetBit(Data, Item.AsInteger);
end;

class procedure TSCLSerializer.ReadStaticArray(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  var ArrayType := AType as TRttiArrayType;
  var ItemType := ArrayType.ElementType;
  if ItemType.Handle = TypeInfo(Byte) then
  begin
    { Динамический массив байт читаем как байтовую строку }
    var Bytes := Node.AsBytes;
    var Count := Length(Bytes);
    if ArrayType.TotalElementCount <> Count then
      raise ESerializeError.CreateResFmt(@sArraySizeMismatch, [Count, ArrayType.TotalElementCount]);
    Move(PByte(Bytes)^, PByte(Data)^, Count);
  end else if ItemType.Handle = TypeInfo(WideChar) then
  begin
    var Chars := Node.AsString;
    var Count := Length(Chars);
    if ArrayType.TotalElementCount <> Count then
      raise ESerializeError.CreateResFmt(@sArraySizeMismatch, [Count, ArrayType.TotalElementCount]);
    Move(PByte(Chars)^, PByte(Data)^, Count shl 1);
  end else if ItemType.Handle = TypeInfo(AnsiChar) then
  begin
    var Chars := AnsiString(Node.AsString);
    var Count := Length(Chars);
    if ArrayType.TotalElementCount <> Count then
      raise ESerializeError.CreateResFmt(@sArraySizeMismatch, [Count, ArrayType.TotalElementCount]);
    Move(PByte(Chars)^, PByte(Data)^, Count);
  end else
  begin
    var ItemSize := ArrayType.TypeSize div ArrayType.TotalElementCount;
    var ItemData := PByte(Data);
    if ArrayType.TotalElementCount <> Node.Count then
      raise ESerializeError.CreateResFmt(@sArraySizeMismatch, [Node.Count, ArrayType.TotalElementCount]);
    for var Item in Node^ do
    begin
      FReaderMap[ItemType.Handle.Kind](Item, ItemData, ItemType);
      Inc(ItemData, ItemSize);
    end;
  end;
end;

class procedure TSCLSerializer.ReadString(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  PShortString(Data)^ := ShortString(Node.AsString);
end;

class procedure TSCLSerializer.ReadUString(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  PString(Data)^ := Node.AsString;
end;

class procedure TSCLSerializer.ReadValue(ParentNode: PSCLNode; const Name: string;
  const Attributes: TArray<TCustomAttribute>; Data: Pointer; AType: TRttiType);
begin
  var ValueAttr := TValueAttributes.Create(Name, Attributes);
  var ValueNode := ParentNode^[ValueAttr.Name];
  if ValueAttr.State <> vsIgnore then
    if (ValueNode <> nil) and not (ValueNode.NodeType in [ntEmpty, ntNull]) then
      FReaderMap[AType.Handle.Kind](ValueNode, Data, AType)
    else if ValueAttr.State = vsRequired then
      raise ESerializeError.CreateResFmt(@sReqrdValueMissing, [ValueAttr.Name]);
end;

class procedure TSCLSerializer.ReadWideChar(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  PWideChar(Data)^ := GetChar(Node);
end;

class procedure TSCLSerializer.ReadWString(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  PWideString(Data)^ := WideString(Node.AsString);
end;

procedure TSCLSerializer.Serialize<T>(Document: TSCLDocument; const Value: T; const Name: string);
begin
  var TypeInfo := PTypeInfo(TypeInfo(T));
  if TypeInfo <> nil then
    if (Name = '') and (TypeInfo.Kind in [tkArray, tkDynArray, tkRecord, tkMRecord]) then
      FWriterMap[TypeInfo.Kind](Document.Root, nil, @Value, FRTTIContext.GetType(TypeInfo))
    else
      WriteValue(Document.Root, Name, nil, @Value, FRTTIContext.GetType(TypeInfo));
end;

function TSCLSerializer.Serialize<T>(const Value: T; const Name: string): TSCLDocument;
begin
  Result := TSCLDocument.Create;
  try
    Serialize<T>(Result, Value, Name);
  except
    FreeAndNil(Result);
    raise;
  end;
end;

class procedure TSCLSerializer.TypeNotSupported(Node: PSCLNode; Data: Pointer; AType: TRttiType);
begin
  raise ESerializeError.CreateResFmt(@sValueTypeNotSupp, [GetEnumName(TypeInfo(TTypeKind), Ord(AType.TypeKind))]) at ReturnAddress;
end;

class procedure TSCLSerializer.TypeNotSupported(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  raise ESerializeError.CreateResFmt(@sValueTypeNotSupp, [GetEnumName(TypeInfo(TTypeKind), Ord(AType.TypeKind))]) at ReturnAddress;
end;

class procedure TSCLSerializer.WriteAnsiChar(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  ParentNode.AddValue(Attrs.Name, string(PAnsiChar(Data)^));
end;

class procedure TSCLSerializer.WriteDynamycArray(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  var ArrayType := AType as TRttiDynamicArrayType;
  var ItemType := ArrayType.ElementType;
  var ItemData := PByte(PPointer(Data)^);
  if ItemType.Handle = TypeInfo(Byte) then
    { Массив байт пишем в бинарное значение }
    ParentNode.AddValue(Attrs.Name, TBytes.Create(ItemData, DynArraySize(ItemData)))
  else if ItemType.Handle = TypeInfo(WideChar) then
    { Массивы символов пишем в обычную строку }
    ParentNode.AddValue(Attrs.Name, StringFromCharArray(PWideChar(ItemData), DynArraySize(ItemData)))
  else if ItemType.Handle = TypeInfo(AnsiChar) then
    ParentNode.AddValue(Attrs.Name, StringFromCharArray(PAnsiChar(ItemData), DynArraySize(ItemData)))
  else
  begin
    var ItemSize := ArrayType.ElementSize;
    if Attrs <> nil then
      ParentNode := ParentNode.AddArray(Attrs.Name, Attrs.InlineMode);
    for var Index := 0 to DynArraySize(ItemData) - 1 do
    begin
      WriteValue(ParentNode, string.Empty, nil, ItemData, ItemType);
      Inc(ItemData, ItemSize);
    end;
  end;
end;

class procedure TSCLSerializer.WriteEnumeration(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
var
  ValueName: string;
begin
  if AType.Handle = TypeInfo(Boolean) then
  begin
    ParentNode.AddValue(Attrs.Name, PBoolean(Data)^);
    Exit;
  end;
  case (AType as TRttiOrdinalType).OrdType of
    otSByte: ValueName := GetEnumName(AType.Handle, PShortInt(Data)^);
    otUByte: ValueName := GetEnumName(AType.Handle, PByte(Data)^);
    otSWord: ValueName := GetEnumName(AType.Handle, PSmallInt(Data)^);
    otUWord: ValueName := GetEnumName(AType.Handle, PWord(Data)^);
    { Максимальное количество элементов в перечисляемом типе равно 2^31 - 1 }
    else ValueName := GetEnumName(AType.Handle, PInteger(Data)^);
  end;
  var TypeName := string(AType.Name) + '.';
  if ValueName.StartsWith(TypeName) then
    Delete(ValueName, 1, TypeName.Length);
  ParentNode.AddValue(Attrs.Name, ValueName, stLiteral);
end;

class procedure TSCLSerializer.WriteFloat(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  if AType.Handle = TypeInfo(TDateTime) then
  begin
    var TimeOffset: SmallInt := TIME_OFFSET_LOCAL;
    if Attrs.IsTimeZone then
      TimeOffset := Round(TTimeZone.Local.GetUtcOffset(Now).TotalMinutes);
    ParentNode.AddValue(Attrs.Name, PDateTime(Data)^, TimeOffset);
  end else if AType.Handle = TypeInfo(Comp) then
    ParentNode.AddValue(Attrs.Name, PInt64(Data)^)
  else if AType.Handle = TypeInfo(Currency) then
    ParentNode.AddValue(Attrs.Name, Double(PCurrency(Data)^))
  else if AType.Handle = TypeInfo(Extended) then
    ParentNode.AddValue(Attrs.Name, Double(PExtended(Data)^))
  else if AType.Handle = TypeInfo(Single) then
    ParentNode.AddValue(Attrs.Name, Double(PSingle(Data)^))
  else
    ParentNode.AddValue(Attrs.Name, PDouble(Data)^);
end;

class procedure TSCLSerializer.WriteInt64(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  ParentNode.AddValue(Attrs.Name, PInt64(Data)^, Attrs.NumberBase);
end;

class procedure TSCLSerializer.WriteInteger(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  var Value: Int64;
  case (AType as TRttiOrdinalType).OrdType of
    otSByte: Value := PShortInt(Data)^;
    otUByte: Value := PByte(Data)^;
    otSWord: Value := PSmallInt(Data)^;
    otUWord: Value := PWord(Data)^;
    otSLong: Value := PInteger(Data)^
    else Value := PCardinal(Data)^; // otULong
  end;
  ParentNode.AddValue(Attrs.Name, Value, Attrs.NumberBase);
end;

class procedure TSCLSerializer.WriteLString(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  ParentNode.AddValue(Attrs.Name, string(PAnsiString(Data)^), Attrs.StringType);
end;

class procedure TSCLSerializer.WriteRecord(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  if Attrs <> nil then
    ParentNode := ParentNode.AddTable(Attrs.Name);
  for var Field in AType.GetFields do
    if Field.FieldType <> nil then
      WriteValue(ParentNode, Field.Name, Field.GetAttributes, PByte(Data) + Field.Offset, Field.FieldType);
end;

class procedure TSCLSerializer.WriteSet(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  var ElementType := (AType as TRttiSetType).ElementType;
  var ValueNode := ParentNode.AddArray(Attrs.Name, True);
  if ElementType.TypeKind = tkEnumeration then
  begin
    var ItemName: string;
    var TypeName := string(AType.Name) + '.';
    var NamesArray := TRttiEnumerationType(ElementType).GetNames;
    var StripPrefix := NamesArray[0].StartsWith(TypeName);
    for var Index := 0 to AType.TypeSize * 8 - 1 do
      if IsBitSet(Data, Index) then
      begin
        ItemName := NamesArray[Index];
        if StripPrefix then
          Delete(ItemName, 1, TypeName.Length);
        ValueNode.AddValue(string.Empty, ItemName, stLiteral);
      end;
  end else for var Index := 0 to AType.TypeSize * 8 - 1 do
    if IsBitSet(Data, Index) then
      ValueNode.AddValue(string.Empty, Index);
end;

class procedure TSCLSerializer.WriteStaticArray(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  var ArrayType := AType as TRttiArrayType;
  var ItemType := ArrayType.ElementType;
  if ItemType.Handle = TypeInfo(Byte) then
    { Массив байт пишем в бинарное значение }
    ParentNode.AddValue(Attrs.Name, TBytes.Create(Data, ArrayType.TotalElementCount))
  else if ItemType.Handle = TypeInfo(WideChar) then
    { Массивы символов пишем в обычную строку }
    ParentNode.AddValue(Attrs.Name, StringFromCharArray(PWideChar(Data), ArrayType.TotalElementCount))
  else if ItemType.Handle = TypeInfo(AnsiChar) then
    ParentNode.AddValue(Attrs.Name, StringFromCharArray(PAnsiChar(Data), ArrayType.TotalElementCount))
  else
  begin
    { Иначе записываем массив поэлементно }
    var ItemSize := ArrayType.TypeSize div ArrayType.TotalElementCount;
    var ItemData := PByte(Data);
    if Attrs <> nil then
      ParentNode := ParentNode.AddArray(Attrs.Name, Attrs.InlineMode);
    for var Index := 0 to ArrayType.TotalElementCount - 1 do
    begin
      WriteValue(ParentNode, string.Empty, nil, ItemData, ItemType);
      Inc(ItemData, ItemSize);
    end;
  end;
end;

class procedure TSCLSerializer.WriteString(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  ParentNode.AddValue(Attrs.Name, string(PShortString(Data)^), Attrs.StringType);
end;

class procedure TSCLSerializer.WriteUString(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  ParentNode.AddValue(Attrs.Name, PString(Data)^, Attrs.StringType);
end;

class procedure TSCLSerializer.WriteValue(ParentNode: PSCLNode; const Name: string;
  const Attributes: TArray<TCustomAttribute>; Data: Pointer; AType: TRttiType);
begin
  var ValueAttributes := TValueAttributes.Create(Name, Attributes);
  if not (ValueAttributes.State in [vsDontWrite, vsIgnore]) then
  begin
    if ValueAttributes.HasComment then
    begin
      var Comments := SplitComment(ValueAttributes.Comment);
      for var Index := 0 to High(Comments) do
        ParentNode.AddComment(Comments[Index]);
    end;
    FWriterMap[AType.TypeKind](ParentNode, @ValueAttributes, Data, AType);
  end;
end;

class procedure TSCLSerializer.WriteWideChar(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  ParentNode.AddValue(Attrs.Name, string(PWideChar(Data)^));
end;

class procedure TSCLSerializer.WriteWString(ParentNode: PSCLNode; Attrs: PValueAttributes; Data: Pointer; AType: TRttiType);
begin
  ParentNode.AddValue(Attrs.Name, string(PWideString(Data)^), Attrs.StringType);
end;

initialization
  TSCLSerializer.InitMappingTables;

end.

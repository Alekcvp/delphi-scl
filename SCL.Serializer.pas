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
  System.SysUtils, System.Classes, System.Rtti, System.TypInfo, SCL.Document, SCL.Types;

type
  ESerializeError = class(Exception);

  PSCLParams = ^TSCLParams;
  TSCLParams = record
    Name: string;
    Comment: string;
    State: SCLStateAttribute.TValueState;
    InlineMode: Boolean;
    IsTimeZone: Boolean;
    NumberBase: TSCLNumberBase;
    StringType: TSCLStringType;
    constructor Create(const AName: string; const Attrs: TArray<TCustomAttribute>);
  end;

  TSCLSerializer = record
  private type
    TDataEncoder = procedure (Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
  private
    FRTTIContext: TRttiContext;
    { Статические методы для чтения значений }
    class procedure DecodeAnsiChar(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeDynamycArray(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeEnumeration(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeFloat(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeInt64(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeInteger(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeLString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeRecord(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeSet(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeStaticArray(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeUString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeWideChar(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure DecodeWString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    { Статические методы для записи значений }
    class procedure EncodeAnsiChar(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeDynamycArray(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeEnumeration(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeFloat(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeInt64(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeInteger(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeLString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeRecord(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeSet(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeStaticArray(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeUString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeWideChar(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    class procedure EncodeWString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
    { Дополнительные вспомогательные методы }
    class procedure TypeNotSupported(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams); static;
  public
    class operator Initialize(out Instance: TSCLSerializer);
    class operator Finalize(var Instance: TSCLSerializer);
  public
    procedure Deserialize<T>(RootNode: PSCLNode; out Value: T; const AName: string = string.Empty);
    procedure Serialize<T>(RootNode: PSCLNode; const Value: T; const AName: string = string.Empty); overload;
     function Serialize<T>(const Value: T; const AName: string = string.Empty): TSCLDocument; overload;
  end;

const
  DecoderMap: array [System.TTypeKind] of TSCLSerializer.TDataEncoder = (
    TSCLSerializer.TypeNotSupported,   // tkUnknown
    TSCLSerializer.DecodeInteger,      // tkInteger
    TSCLSerializer.DecodeAnsiChar,     // tkChar
    TSCLSerializer.DecodeEnumeration,  // tkEnumeration
    TSCLSerializer.DecodeFloat,        // tkFloat
    TSCLSerializer.DecodeString,       // tkString
    TSCLSerializer.DecodeSet,          // tkSet
    TSCLSerializer.TypeNotSupported,   // tkClass
    TSCLSerializer.TypeNotSupported,   // tkMethod
    TSCLSerializer.DecodeWideChar,     // tkWChar
    TSCLSerializer.DecodeLString,      // tkLString
    TSCLSerializer.DecodeWString,      // tkWString
    TSCLSerializer.TypeNotSupported,   // tkVariant
    TSCLSerializer.DecodeStaticArray,  // tkArray
    TSCLSerializer.DecodeRecord,       // tkRecord
    TSCLSerializer.TypeNotSupported,   // tkInterface
    TSCLSerializer.DecodeInt64,        // tkInt64
    TSCLSerializer.DecodeDynamycArray, // tkDynArray
    TSCLSerializer.DecodeUString,      // tkUString
    TSCLSerializer.TypeNotSupported,   // tkClassRef
    TSCLSerializer.TypeNotSupported,   // tkPointer
    TSCLSerializer.TypeNotSupported,   // tkProcedure
    TSCLSerializer.DecodeRecord        // tkMRecord
  );

  EncoderMap: array [System.TTypeKind] of TSCLSerializer.TDataEncoder = (
    TSCLSerializer.TypeNotSupported,   // tkUnknown
    TSCLSerializer.EncodeInteger,      // tkInteger
    TSCLSerializer.EncodeAnsiChar,     // tkChar
    TSCLSerializer.EncodeEnumeration,  // tkEnumeration
    TSCLSerializer.EncodeFloat,        // tkFloat
    TSCLSerializer.EncodeString,       // tkString
    TSCLSerializer.EncodeSet,          // tkSet
    TSCLSerializer.TypeNotSupported,   // tkClass
    TSCLSerializer.TypeNotSupported,   // tkMethod
    TSCLSerializer.EncodeWideChar,     // tkWChar
    TSCLSerializer.EncodeLString,      // tkLString
    TSCLSerializer.EncodeWString,      // tkWString
    TSCLSerializer.TypeNotSupported,   // tkVariant
    TSCLSerializer.EncodeStaticArray,  // tkArray
    TSCLSerializer.EncodeRecord,       // tkRecord
    TSCLSerializer.TypeNotSupported,   // tkInterface
    TSCLSerializer.EncodeInt64,        // tkInt64
    TSCLSerializer.EncodeDynamycArray, // tkDynArray
    TSCLSerializer.EncodeUString,      // tkUString
    TSCLSerializer.TypeNotSupported,   // tkClassRef
    TSCLSerializer.TypeNotSupported,   // tkPointer
    TSCLSerializer.TypeNotSupported,   // tkProcedure
    TSCLSerializer.EncodeRecord        // tkMRecord
  );

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
  DefaultParams: TSCLParams = (
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

{ TSCLParams }

constructor TSCLParams.Create(const AName: string; const Attrs: TArray<TCustomAttribute>);
const
  IgnoreStates: array [Boolean] of SCLStateAttribute.TValueState = (vsDontWrite, vsIgnore);
begin
  Self := Default(TSCLParams);
  Name := AName;
  for var Attribute in Attrs do
    if Attribute is SCLNameAttribute then
    begin
      Name := SCLNameAttribute(Attribute).Name;
      if Name = '' then
        raise ESerializeError.CreateRes(@sNodeNameRequired);
    end else if Attribute is SCLBaseAttribute then
      NumberBase := SCLBaseAttribute(Attribute).NumberBase
    else if Attribute is SCLCommentAttribute then
      Comment := SCLCommentAttribute(Attribute).Comment
    else if Attribute is SCLStateAttribute then
      State := SCLStateAttribute(Attribute).State
    else if Attribute is SCLStringAttribute then
      StringType := SCLStringAttribute(Attribute).StringType
    else if Attribute is SCLInlineAttribute then
      InlineMode := True
    else if Attribute is SCLTimeZoneAttribute then
      IsTimeZone := True;
end;

{ TSCLSerializer }

class procedure TSCLSerializer.DecodeAnsiChar(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  PAnsiChar(Data)^ := AnsiChar(GetChar(Node));
end;

class procedure TSCLSerializer.DecodeDynamycArray(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
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
    { Массивы символов читаем как строки }
    var Chars := Node.AsString;
    var Count := Length(Chars);
    DynArraySetLength(PPointer(Data)^, AType.Handle, 1, @Count);
    Move(PByte(Chars)^, PPointer(Data)^^, Count * SizeOf(Char));
  end else if ItemType.Handle = TypeInfo(AnsiChar) then
  begin
    var Chars := AnsiString(Node.AsString);
    var Count := Length(Chars);
    DynArraySetLength(PPointer(Data)^, AType.Handle, 1, @Count);
    Move(PByte(Chars)^, PPointer(Data)^^, Count);
  end else
  begin
    { Обычный динамический массив }
    var ESize := ArrayType.ElementSize;
    var Count := Node.Count;
    DynArraySetLength(PPointer(Data)^, AType.Handle, 1, @Count);
    var ItemData := PByte(PPointer(Data)^);
    for var Item in Node^ do
    begin
      DecoderMap[ItemType.Handle.Kind](Item, ItemData, ItemType, @DefaultParams);
      Inc(ItemData, ESize);
    end;
  end;
end;

class procedure TSCLSerializer.DecodeEnumeration(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  var LTypeInfo := AType.Handle;
  if LTypeInfo = TypeInfo(Boolean) then
  begin
    PBoolean(Data)^ := Node.AsBoolean;
    Exit;
  end;
  var SearchName := AType.QualifiedName + '.';
  if GetEnumName(LTypeInfo, AType.AsOrdinal.MinValue).StartsWith(SearchName) then
    SearchName := SearchName + Node.AsString
  else SearchName := Node.AsString;
  var EnumIndex := EnumItemIndex(SearchName, LTypeInfo);
  case LTypeInfo.TypeData.OrdType of
    otSByte, otUByte: PByte(Data)^ := Byte(EnumIndex);
    otSWord, otUWord: PWord(Data)^ := Word(EnumIndex);
    else PLongWord(Data)^ := LongWord(EnumIndex);
  end;
end;

class procedure TSCLSerializer.DecodeFloat(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  var ATypeInfo := AType.Handle;
  if ATypeInfo = TypeInfo(TDateTime) then
    PDateTime(Data)^ := Node.AsDateTime
  else if ATypeInfo = TypeInfo(Comp) then
    PInt64(Data)^ := Node.AsInteger
  else if ATypeInfo = TypeInfo(Currency) then
    PInt64(Data)^ := Node.AsInteger
  else if ATypeInfo = TypeInfo(Extended) then
    PExtended(Data)^ := Extended(Node.AsDouble)
  else if ATypeInfo = TypeInfo(Single) then
    PSingle(Data)^ := Single(Node.AsDouble)
  else
    PDouble(Data)^ := Node.AsDouble;
end;

class procedure TSCLSerializer.DecodeInt64(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  PInt64(Data)^ := Node.AsInteger;
end;

class procedure TSCLSerializer.DecodeInteger(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  var OrdinalValue := Int64Rec(Node.AsInteger).Lo;
  case AType.AsOrdinal.OrdType of
    otSByte, otUByte: PByte(Data)^ := Byte(OrdinalValue);
    otSWord, otUWord: PWord(Data)^ := Word(OrdinalValue);
    else PCardinal(Data)^ := OrdinalValue; // otSLong, otULong
  end;
end;

class procedure TSCLSerializer.DecodeLString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  PAnsiString(Data)^ := AnsiString(Node.AsString);
end;

class procedure TSCLSerializer.DecodeRecord(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  for var Field in AType.GetFields do
    if Field.FieldType <> nil then
    begin
      var LParams := TSCLParams.Create(Field.Name, Field.GetAttributes);
      if LParams.State <> vsIgnore then
      begin
        var ItemNode := Node.Items[LParams.Name];
        if ItemNode <> nil then
          DecoderMap[Field.FieldType.TypeKind](ItemNode, PByte(Data) + Field.Offset, Field.FieldType, @LParams)
        else if LParams.State = vsRequired then
          raise ESerializeError.CreateResFmt(@sReqrdValueMissing, [LParams.Name]);
      end;
    end;
end;

class procedure TSCLSerializer.DecodeSet(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
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

class procedure TSCLSerializer.DecodeStaticArray(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
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
      DecoderMap[ItemType.Handle.Kind](Item, ItemData, ItemType, @DefaultParams);
      Inc(ItemData, ItemSize);
    end;
  end;
end;

class procedure TSCLSerializer.DecodeString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  PShortString(Data)^ := ShortString(Node.AsString);
end;

class procedure TSCLSerializer.DecodeUString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  PString(Data)^ := Node.AsString;
end;

class procedure TSCLSerializer.DecodeWideChar(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  PWideChar(Data)^ := GetChar(Node);
end;

class procedure TSCLSerializer.DecodeWString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  PWideString(Data)^ := WideString(Node.AsString);
end;

procedure TSCLSerializer.Deserialize<T>(RootNode: PSCLNode; out Value: T; const AName: string);
begin
  var AType := FRTTIContext.GetType(TypeInfo(T));
  if AType <> nil then
  begin
    var Params := TSCLParams.Create(AName, AType.GetAttributes);
    if Params.Name <> string.Empty then
      RootNode := RootNode.Items[Params.Name]
    else if not (AType.TypeKind in [tkDynArray, tkArray, tkRecord, tkMRecord, tkSet]) then
      { Для простых типов без имени получаем первый элемент массива }
      RootNode := RootNode.FirstChild;
    DecoderMap[AType.TypeKind](RootNode, @Value, AType, @Params);
  end;
end;

class procedure TSCLSerializer.EncodeAnsiChar(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  Node.AsString := string(PAnsiChar(Data)^);
end;

class procedure TSCLSerializer.EncodeDynamycArray(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  var ArrayType := AType as TRttiDynamicArrayType;
  var ItemType := ArrayType.ElementType;
  var ItemData := PByte(PPointer(Data)^);
  if ItemType.Handle = TypeInfo(Byte) then
    { Массив байт пишем в бинарное значение }
    Node.AsBytes := TBytes.Create(ItemData, DynArraySize(ItemData))
  else if ItemType.Handle = TypeInfo(WideChar) then
    { Массивы символов пишем в обычную строку }
    Node.AsString := StringFromCharArray(PWideChar(ItemData), DynArraySize(ItemData))
  else if ItemType.Handle = TypeInfo(AnsiChar) then
    Node.AsString := StringFromCharArray(PAnsiChar(ItemData), DynArraySize(ItemData))
  else
  begin
    Node.MakeParent(False, Params.InlineMode and (Node.Parent <> nil));
    var ItemSize := ArrayType.ElementSize;
    for var Index := 0 to DynArraySize(ItemData) - 1 do
    begin
      EncoderMap[ItemType.TypeKind](Node.AddNode(string.Empty, ntEmpty), ItemData, ItemType, @DefaultParams);
      Inc(ItemData, ItemSize);
    end;
  end;
end;

class procedure TSCLSerializer.EncodeEnumeration(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  if AType.Handle = TypeInfo(Boolean) then
  begin
    Node.AsBoolean := PBoolean(Data)^;
    Exit;
  end;
  var ValueName: string;
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
  Node.SetValue(ValueName, stLiteral);
end;

class procedure TSCLSerializer.EncodeFloat(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  var ATypeInfo := AType.Handle;
  if ATypeInfo = TypeInfo(TDateTime) then
  begin
    Node.AsDateTime := PDateTime(Data)^;
    if Params.IsTimeZone then
      Node.TimeOffset := Round(TTimeZone.Local.GetUtcOffset(Now).TotalMinutes);
  end else if ATypeInfo = TypeInfo(Comp) then
    Node.AsInteger := PInt64(Data)^
  else if ATypeInfo = TypeInfo(Currency) then
    Node.AsInteger := PInt64(Data)^
  else if ATypeInfo = TypeInfo(Extended) then
    Node.AsDouble := Double(PExtended(Data)^)
  else if ATypeInfo = TypeInfo(Single) then
    Node.AsDouble := Double(PSingle(Data)^)
  else
    Node.AsDouble := PDouble(Data)^;
end;

class procedure TSCLSerializer.EncodeInt64(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  Node.SetValue(PInt64(Data)^, Params.NumberBase);
end;

class procedure TSCLSerializer.EncodeInteger(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  var Int64Value: Int64;
  case (AType as TRttiOrdinalType).OrdType of
    otSByte: Int64Value := PShortInt(Data)^;
    otUByte: Int64Value := PByte(Data)^;
    otSWord: Int64Value := PSmallInt(Data)^;
    otUWord: Int64Value := PWord(Data)^;
    otSLong: Int64Value := PInteger(Data)^
    else Int64Value := PCardinal(Data)^; // otULong
  end;
  Node.SetValue(Int64Value, Params.NumberBase);
end;

class procedure TSCLSerializer.EncodeLString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  Node.SetValue(string(PAnsiString(Data)^), Params.StringType);
end;

class procedure TSCLSerializer.EncodeRecord(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  for var Field in AType.GetFields do
    if Field.FieldType <> nil then
    begin
      var FldType := Field.FieldType;
      var LParams := TSCLParams.Create(Field.Name, Field.GetAttributes);
      if not (LParams.State in [vsDontWrite, vsIgnore]) then
      begin
        var ItemNode := Node.AddNode(LParams.Name, ntEmpty);
        ItemNode.Comment := LParams.Comment;
        EncoderMap[FldType.TypeKind](ItemNode, PByte(Data) + Field.Offset, FldType, @LParams);
      end;
    end;
end;

class procedure TSCLSerializer.EncodeSet(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  var EType := (AType as TRttiSetType).ElementType;
  Node.MakeParent(False, (AType.TypeSize = 1) and (Node.Parent <> nil));
  if EType.TypeKind = tkEnumeration then
  begin
    var ItemName: string;
    var TypeName := string(AType.Name) + '.';
    var NamesArray := TRttiEnumerationType(EType).GetNames;
    var StripPrefix := NamesArray[0].StartsWith(TypeName);
    for var Index := 0 to AType.TypeSize * 8 - 1 do
      if IsBitSet(Data, Index) then
      begin
        ItemName := NamesArray[Index];
        if StripPrefix then
          Delete(ItemName, 1, TypeName.Length);
        Node.AddValue(string.Empty, ItemName, stLiteral);
      end;
  end else for var Index := 0 to AType.TypeSize * 8 - 1 do
    if IsBitSet(Data, Index) then
      Node.AddValue(string.Empty, Index);
end;

class procedure TSCLSerializer.EncodeStaticArray(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  var ArrayType := AType as TRttiArrayType;
  var ItemType := ArrayType.ElementType;
  if ItemType.Handle = TypeInfo(Byte) then
    { Массив байт пишем в бинарное значение }
    Node.AsBytes := TBytes.Create(Data, ArrayType.TotalElementCount)
  else if ItemType.Handle = TypeInfo(WideChar) then
    { Массивы символов пишем в обычную строку }
    Node.AsString := StringFromCharArray(PWideChar(Data), ArrayType.TotalElementCount)
  else if ItemType.Handle = TypeInfo(AnsiChar) then
    Node.AsString := StringFromCharArray(PAnsiChar(Data), ArrayType.TotalElementCount)
  else
  begin
    { Иначе записываем массив поэлементно }
    var ItemSize := ArrayType.TypeSize div ArrayType.TotalElementCount;
    var ItemData := PByte(Data);
    Node.MakeParent(False, Params.InlineMode and (Node.Parent <> nil));
    for var Index := 0 to ArrayType.TotalElementCount - 1 do
    begin
      EncoderMap[ItemType.TypeKind](Node.AddNode(string.Empty, ntEmpty), ItemData, ItemType, @DefaultParams);
      Inc(ItemData, ItemSize);
    end;
  end;
end;

class procedure TSCLSerializer.EncodeString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  Node.SetValue(string(PShortString(Data)^), Params.StringType);
end;

class procedure TSCLSerializer.EncodeUString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  Node.SetValue(PString(Data)^, Params.StringType);
end;

class procedure TSCLSerializer.EncodeWideChar(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  Node.AsString := string(PWideChar(Data)^);
end;

class procedure TSCLSerializer.EncodeWString(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  Node.SetValue(string(PWideString(Data)^), Params.StringType);
end;

class operator TSCLSerializer.Finalize(var Instance: TSCLSerializer);
begin
  Instance.FRTTIContext.Free;
end;

class operator TSCLSerializer.Initialize(out Instance: TSCLSerializer);
begin
  Instance.FRTTIContext := TRttiContext.Create;
end;

procedure TSCLSerializer.Serialize<T>(RootNode: PSCLNode; const Value: T; const AName: string);
begin
  var AType := FRTTIContext.GetType(TypeInfo(T));
  if AType <> nil then
  begin
    var Params := TSCLParams.Create(AName, AType.GetAttributes);
    if Params.Name <> string.Empty then
      RootNode := RootNode.AddNode(Params.Name, ntEmpty)
    else if not (AType.TypeKind in [tkDynArray, tkArray, tkRecord, tkMRecord, tkSet]) then
      { Для простых типов без имени мы создаём массив из одного элемента }
      RootNode := RootNode.AddNode(string.Empty, ntEmpty);
    EncoderMap[AType.TypeKind](RootNode, @Value, AType, @Params)
  end;
end;

function TSCLSerializer.Serialize<T>(const Value: T; const AName: string): TSCLDocument;
begin
  Result := TSCLDocument.Create;
  try
    Serialize<T>(Result.Root, Value, AName);
  except
    FreeAndNil(Result);
    raise;
  end;
end;

class procedure TSCLSerializer.TypeNotSupported(Node: PSCLNode; Data: Pointer; AType: TRttiType; Params: PSCLParams);
begin
  raise ESerializeError.CreateResFmt(@sValueTypeNotSupp, [GetEnumName(TypeInfo(TTypeKind), Ord(AType.TypeKind))]) at ReturnAddress;
end;

end.

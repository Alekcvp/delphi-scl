unit SCL.Testing;

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
  System.SysUtils, System.Classes, SCL.Document, SCL.Serializer;

type
  // Вложенная запись для тестирования
  TInnerRecord = record
    IntVal: Integer;
    FloatVal: Double;
    CharVal: AnsiChar;
    WideCharVal: WideChar;
    StrVal: string;
    AnsiStrVal: AnsiString;
    WideStrVal: WideString;
  end;

  TInnerArray = TArray<TInnerRecord>;

  // Статические массивы - отдельные типы для RTTI
  TStaticIntArray = array[0..4] of Integer;
  TStaticByteArray = array[0..9] of Byte;
  TStaticWideCharArray = array[0..2] of WideChar;
  TStaticAnsiCharArray = array[0..3] of AnsiChar;
  TStaticFloatArray = array[0..1] of Double;
  TStaticInnerRecordArray = array[0..2] of TInnerRecord;  // Массив вложенных записей

  // Перечисление для тестирования
  TTestEnum = (teFirst, teSecond, teThird, teFourth);

  // Основная запись для тестирования сериализации
  TTestRecord = record
    // Целочисленные типы
    Int8: ShortInt;
    Int16: SmallInt;
    Int32: Integer;
    Int64: Int64;
    [SCLName('Byte')]
    UInt8: Byte;
    UInt16: Word;
    UInt32: LongWord;
    [SCLBase(nbHex)]
    UInt64: UInt64;

    // Числовые типы с плавающей точкой
    SingleVal: Single;
    DoubleVal: Double;
    ExtendedVal: Extended;
    CurrencyVal: Currency;

    // Логический тип
    BoolVal: Boolean;
    BoolVal8: Boolean;  // Дополнительный для проверки упаковки

    // Символы
    [SCLComment('ANSI-строка')]
    AnsiCharVal: AnsiChar;
    [SCLComment('')]
    WideCharVal: WideChar;

    // Строки
    ShortStrVal: ShortString;    // Короткая строка (длина до 255 символов)
    AnsiStrVal: AnsiString;      // AnsiString
    WideStrVal: WideString;      // WideString
    UnicodeStrVal: string;       // UnicodeString (обычная строка)

    // Статические массивы (объявлены как отдельные типы)
    [SCLInline]
    StaticIntArr: TStaticIntArray;
    StaticByteArr: TStaticByteArray;
    StaticWideCharArr: TStaticWideCharArray;
    StaticAnsiCharArr: TStaticAnsiCharArray;
    [SCLInline]
    StaticFloatArr: TStaticFloatArray;
    StaticInnerArr: TStaticInnerRecordArray;

    // Динамические массивы
    [SCLInline]
    DynamicIntArray: TArray<Integer>;
    DynamicByteArray: TArray<Byte>;
    DynamicWideCharArray: TArray<WideChar>;
    DynamicAnsiCharArray: TArray<AnsiChar>;
    DynamicStringArray: TArray<string>;
    [SCLInline]
    DynamicDoubleArray: TArray<Double>;
    DynamicInnerArray: TInnerArray;

    // Вложенные записи
    Inner: TInnerRecord;

    // Даты и время
    DateVal: TDate;
    TimeVal: TTime;
    DateTimeVal: TDateTime;

    // Enum (перечисление)
    EnumVal: TTestEnum;

    // Дополнительные типы для проверки
    IntPtr: NativeInt;      // Размер зависит от платформы
    UIntPtr: NativeUInt;    // Размер зависит от платформы
  end;

procedure CheckDeserialization(const Original, Deserialized: TTestRecord);
function CreateTestRecord: TTestRecord;
procedure WriteSCLStructure(Document: TSCLDocument);

implementation

uses
  System.RTTI, System.TypInfo, System.Math, System.Variants;

procedure CheckDeserialization(const Original, Deserialized: TTestRecord);
var
  Errors: TStringList;

  procedure AddError(const FieldName, ErrorMsg: string);
  begin
    Errors.Add(Format('  [ОШИБКА] %s: %s', [FieldName, ErrorMsg]));
  end;

  procedure CheckInteger(const FieldName: string; Expected, Actual: Int64);
  begin
    if Expected <> Actual then
      AddError(FieldName, Format('Ожидалось %d, получено %d', [Expected, Actual]));
  end;

  procedure CheckUInteger(const FieldName: string; Expected, Actual: UInt64);
  begin
    if Expected <> Actual then
      AddError(FieldName, Format('Ожидалось %d, получено %d', [Expected, Actual]));
  end;

  procedure CheckFloat(const FieldName: string; Expected, Actual: Extended; Epsilon: Extended = 0.0000001);
  begin
    if not SameValue(Expected, Actual, Epsilon) then
      AddError(FieldName, Format('Ожидалось %g, получено %g', [Expected, Actual]));
  end;

  procedure CheckString(const FieldName: string; Expected, Actual: string);
  begin
    if Expected <> Actual then
      AddError(FieldName, Format('Ожидалось "%s", получено "%s"', [Expected, Actual]));
  end;

  procedure CheckAnsiString(const FieldName: string; Expected, Actual: AnsiString);
  begin
    if Expected <> Actual then
      AddError(FieldName, Format('Ожидалось "%s", получено "%s"', [Expected, Actual]));
  end;

  procedure CheckWideString(const FieldName: string; Expected, Actual: WideString);
  begin
    if Expected <> Actual then
      AddError(FieldName, Format('Ожидалось "%s", получено "%s"', [Expected, Actual]));
  end;

  procedure CheckShortString(const FieldName: string; Expected, Actual: ShortString);
  begin
    if Expected <> Actual then
      AddError(FieldName, Format('Ожидалось "%s", получено "%s"', [Expected, Actual]));
  end;

  procedure CheckChar(const FieldName: string; Expected, Actual: Char);
  begin
    if Expected <> Actual then
      AddError(FieldName, Format('Ожидалось "%s", получено "%s"', [Expected, Actual]));
  end;

  procedure CheckAnsiChar(const FieldName: string; Expected, Actual: AnsiChar);
  begin
    if Expected <> Actual then
      AddError(FieldName, Format('Ожидалось "%s", получено "%s"', [Expected, Actual]));
  end;

  procedure CheckWideChar(const FieldName: string; Expected, Actual: WideChar);
  begin
    if Expected <> Actual then
      AddError(FieldName, Format('Ожидалось "%s", получено "%s"', [Expected, Actual]));
  end;

  procedure CheckBoolean(const FieldName: string; Expected, Actual: Boolean);
  begin
    if Expected <> Actual then
      AddError(FieldName, Format('Ожидалось %s, получено %s',
        [BoolToStr(Expected, True), BoolToStr(Actual, True)]));
  end;

  procedure CheckEnum(const FieldName: string; Expected, Actual: TTestEnum);
  begin
    if Expected <> Actual then
      AddError(FieldName, Format('Ожидалось %d, получено %d', [Ord(Expected), Ord(Actual)]));
  end;

  procedure CheckDateTime(const FieldName: string; Expected, Actual: TDateTime);
  begin
    if not SameValue(Expected, Actual, 0.0000001) then
      AddError(FieldName, Format('Ожидалось %s, получено %s',
        [DateTimeToStr(Expected), DateTimeToStr(Actual)]));
  end;

  procedure CheckStaticIntArray(const FieldName: string; const Expected, Actual: TStaticIntArray);
  var
    I: Integer;
  begin
    for I := 0 to High(Expected) do
      if Expected[I] <> Actual[I] then
        AddError(Format('%s[%d]', [FieldName, I]),
          Format('Ожидалось %d, получено %d', [Expected[I], Actual[I]]));
  end;

  procedure CheckStaticByteArray(const FieldName: string; const Expected, Actual: TStaticByteArray);
  var
    I: Integer;
  begin
    for I := 0 to High(Expected) do
      if Expected[I] <> Actual[I] then
        AddError(Format('%s[%d]', [FieldName, I]),
          Format('Ожидалось %d, получено %d', [Expected[I], Actual[I]]));
  end;

  procedure CheckStaticWideCharArray(const FieldName: string; const Expected, Actual: TStaticWideCharArray);
  var
    I: Integer;
  begin
    for I := 0 to High(Expected) do
      if Expected[I] <> Actual[I] then
        AddError(Format('%s[%d]', [FieldName, I]),
          Format('Ожидалось "%s", получено "%s"', [Expected[I], Actual[I]]));
  end;

  procedure CheckStaticAnsiCharArray(const FieldName: string; const Expected, Actual: TStaticAnsiCharArray);
  var
    I: Integer;
  begin
    for I := 0 to High(Expected) do
      if Expected[I] <> Actual[I] then
        AddError(Format('%s[%d]', [FieldName, I]),
          Format('Ожидалось "%s", получено "%s"', [Expected[I], Actual[I]]));
  end;

  procedure CheckStaticFloatArray(const FieldName: string; const Expected, Actual: TStaticFloatArray);
  var
    I: Integer;
  begin
    for I := 0 to High(Expected) do
      if not SameValue(Expected[I], Actual[I]) then
        AddError(Format('%s[%d]', [FieldName, I]),
          Format('Ожидалось %g, получено %g', [Expected[I], Actual[I]]));
  end;

  procedure CheckStaticInnerArray(const FieldName: string; const Expected, Actual: TStaticInnerRecordArray);
  var
    I: Integer;
  begin
    for I := 0 to High(Expected) do
    begin
      if Expected[I].IntVal <> Actual[I].IntVal then
        AddError(Format('%s[%d].IntVal', [FieldName, I]),
          Format('Ожидалось %d, получено %d', [Expected[I].IntVal, Actual[I].IntVal]));

      if not SameValue(Expected[I].FloatVal, Actual[I].FloatVal) then
        AddError(Format('%s[%d].FloatVal', [FieldName, I]),
          Format('Ожидалось %g, получено %g', [Expected[I].FloatVal, Actual[I].FloatVal]));

      if Expected[I].StrVal <> Actual[I].StrVal then
        AddError(Format('%s[%d].StrVal', [FieldName, I]),
          Format('Ожидалось "%s", получено "%s"', [Expected[I].StrVal, Actual[I].StrVal]));
    end;
  end;

  procedure CheckDynamicArray(const FieldName: string; Expected, Actual: TArray<Integer>);
  var
    I: Integer;
  begin
    if Length(Expected) <> Length(Actual) then
    begin
      AddError(FieldName, Format('Длина: ожидалось %d, получено %d',
        [Length(Expected), Length(Actual)]));
      Exit;
    end;

    for I := 0 to High(Expected) do
      if Expected[I] <> Actual[I] then
        AddError(Format('%s[%d]', [FieldName, I]),
          Format('Ожидалось %d, получено %d', [Expected[I], Actual[I]]));
  end;

  procedure CheckDynamicByteArray(const FieldName: string; Expected, Actual: TArray<Byte>);
  var
    I: Integer;
  begin
    if Length(Expected) <> Length(Actual) then
    begin
      AddError(FieldName, Format('Длина: ожидалось %d, получено %d',
        [Length(Expected), Length(Actual)]));
      Exit;
    end;

    for I := 0 to High(Expected) do
      if Expected[I] <> Actual[I] then
        AddError(Format('%s[%d]', [FieldName, I]),
          Format('Ожидалось %d, получено %d', [Expected[I], Actual[I]]));
  end;

  procedure CheckDynamicWideCharArray(const FieldName: string; Expected, Actual: TArray<WideChar>);
  var
    I: Integer;
  begin
    if Length(Expected) <> Length(Actual) then
    begin
      AddError(FieldName, Format('Длина: ожидалось %d, получено %d',
        [Length(Expected), Length(Actual)]));
      Exit;
    end;

    for I := 0 to High(Expected) do
      if Expected[I] <> Actual[I] then
        AddError(Format('%s[%d]', [FieldName, I]),
          Format('Ожидалось "%s", получено "%s"', [Expected[I], Actual[I]]));
  end;

  procedure CheckDynamicAnsiCharArray(const FieldName: string; Expected, Actual: TArray<AnsiChar>);
  var
    I: Integer;
  begin
    if Length(Expected) <> Length(Actual) then
    begin
      AddError(FieldName, Format('Длина: ожидалось %d, получено %d',
        [Length(Expected), Length(Actual)]));
      Exit;
    end;

    for I := 0 to High(Expected) do
      if Expected[I] <> Actual[I] then
        AddError(Format('%s[%d]', [FieldName, I]),
          Format('Ожидалось "%s", получено "%s"', [Expected[I], Actual[I]]));
  end;

  procedure CheckDynamicStringArray(const FieldName: string; Expected, Actual: TArray<string>);
  var
    I: Integer;
  begin
    if Length(Expected) <> Length(Actual) then
    begin
      AddError(FieldName, Format('Длина: ожидалось %d, получено %d',
        [Length(Expected), Length(Actual)]));
      Exit;
    end;

    for I := 0 to High(Expected) do
      if Expected[I] <> Actual[I] then
        AddError(Format('%s[%d]', [FieldName, I]),
          Format('Ожидалось "%s", получено "%s"', [Expected[I], Actual[I]]));
  end;

  procedure CheckDynamicDoubleArray(const FieldName: string; Expected, Actual: TArray<Double>);
  var
    I: Integer;
  begin
    if Length(Expected) <> Length(Actual) then
    begin
      AddError(FieldName, Format('Длина: ожидалось %d, получено %d',
        [Length(Expected), Length(Actual)]));
      Exit;
    end;

    for I := 0 to High(Expected) do
      if not SameValue(Expected[I], Actual[I]) then
        AddError(Format('%s[%d]', [FieldName, I]),
          Format('Ожидалось %g, получено %g', [Expected[I], Actual[I]]));
  end;

  procedure CheckDynamicInnerArray(const FieldName: string;
    const Expected, Actual: TArray<TInnerRecord>);
  var
    I: Integer;
  begin
    if Length(Expected) <> Length(Actual) then
    begin
      AddError(FieldName, Format('Длина: ожидалось %d, получено %d',
        [Length(Expected), Length(Actual)]));
      Exit;
    end;

    for I := 0 to High(Expected) do
    begin
      if Expected[I].IntVal <> Actual[I].IntVal then
        AddError(Format('%s[%d].IntVal', [FieldName, I]),
          Format('Ожидалось %d, получено %d', [Expected[I].IntVal, Actual[I].IntVal]));

      if not SameValue(Expected[I].FloatVal, Actual[I].FloatVal) then
        AddError(Format('%s[%d].FloatVal', [FieldName, I]),
          Format('Ожидалось %g, получено %g', [Expected[I].FloatVal, Actual[I].FloatVal]));

      if Expected[I].StrVal <> Actual[I].StrVal then
        AddError(Format('%s[%d].StrVal', [FieldName, I]),
          Format('Ожидалось "%s", получено "%s"', [Expected[I].StrVal, Actual[I].StrVal]));
    end;
  end;

  procedure CheckInnerRecord(const FieldName: string; const Expected, Actual: TInnerRecord);
  begin
    CheckInteger(FieldName + '.IntVal', Expected.IntVal, Actual.IntVal);
    CheckFloat(FieldName + '.FloatVal', Expected.FloatVal, Actual.FloatVal);
    CheckAnsiChar(FieldName + '.CharVal', Expected.CharVal, Actual.CharVal);
    CheckWideChar(FieldName + '.WideCharVal', Expected.WideCharVal, Actual.WideCharVal);
    CheckString(FieldName + '.StrVal', Expected.StrVal, Actual.StrVal);
    CheckAnsiString(FieldName + '.AnsiStrVal', Expected.AnsiStrVal, Actual.AnsiStrVal);
    CheckWideString(FieldName + '.WideStrVal', Expected.WideStrVal, Actual.WideStrVal);
  end;

begin
  Errors := TStringList.Create;
  try
    Writeln('=== ПРОВЕРКА ДЕСЕРИАЛИЗАЦИИ ===');
    Writeln;

    // === Простые типы ===
    CheckInteger('Int8', Original.Int8, Deserialized.Int8);
    CheckInteger('Int16', Original.Int16, Deserialized.Int16);
    CheckInteger('Int32', Original.Int32, Deserialized.Int32);
    CheckInteger('Int64', Original.Int64, Deserialized.Int64);
    CheckUInteger('UInt8', Original.UInt8, Deserialized.UInt8);
    CheckUInteger('UInt16', Original.UInt16, Deserialized.UInt16);
    CheckUInteger('UInt32', Original.UInt32, Deserialized.UInt32);
    CheckUInteger('UInt64', Original.UInt64, Deserialized.UInt64);

    // === Числа с плавающей точкой ===
    CheckFloat('SingleVal', Original.SingleVal, Deserialized.SingleVal, 0.00001);
    CheckFloat('DoubleVal', Original.DoubleVal, Deserialized.DoubleVal);
    CheckFloat('ExtendedVal', Original.ExtendedVal, Deserialized.ExtendedVal);
    CheckFloat('CurrencyVal', Original.CurrencyVal, Deserialized.CurrencyVal, 0.001);

    // === Логические типы ===
    CheckBoolean('BoolVal', Original.BoolVal, Deserialized.BoolVal);

    // === Символы ===
    CheckAnsiChar('AnsiCharVal', Original.AnsiCharVal, Deserialized.AnsiCharVal);
    CheckWideChar('WideCharVal', Original.WideCharVal, Deserialized.WideCharVal);

    // === Строки ===
    CheckShortString('ShortStrVal', Original.ShortStrVal, Deserialized.ShortStrVal);
    CheckAnsiString('AnsiStrVal', Original.AnsiStrVal, Deserialized.AnsiStrVal);
    CheckWideString('WideStrVal', Original.WideStrVal, Deserialized.WideStrVal);
    CheckString('UnicodeStrVal', Original.UnicodeStrVal, Deserialized.UnicodeStrVal);

    // === Статические массивы ===
    CheckStaticIntArray('StaticIntArr', Original.StaticIntArr, Deserialized.StaticIntArr);
    CheckStaticByteArray('StaticByteArr', Original.StaticByteArr, Deserialized.StaticByteArr);
    CheckStaticWideCharArray('StaticWideCharArr', Original.StaticWideCharArr, Deserialized.StaticWideCharArr);
    CheckStaticAnsiCharArray('StaticAnsiCharArr', Original.StaticAnsiCharArr, Deserialized.StaticAnsiCharArr);
    CheckStaticFloatArray('StaticFloatArr', Original.StaticFloatArr, Deserialized.StaticFloatArr);
    CheckStaticInnerArray('StaticInnerArr', Original.StaticInnerArr, Deserialized.StaticInnerArr);

    // === Динамические массивы ===
    CheckDynamicArray('DynamicIntArray', Original.DynamicIntArray, Deserialized.DynamicIntArray);
    CheckDynamicByteArray('DynamicByteArray', Original.DynamicByteArray, Deserialized.DynamicByteArray);
    CheckDynamicWideCharArray('DynamicWideCharArray', Original.DynamicWideCharArray, Deserialized.DynamicWideCharArray);
    CheckDynamicAnsiCharArray('DynamicAnsiCharArray', Original.DynamicAnsiCharArray, Deserialized.DynamicAnsiCharArray);
    CheckDynamicStringArray('DynamicStringArray', Original.DynamicStringArray, Deserialized.DynamicStringArray);
    CheckDynamicDoubleArray('DynamicDoubleArray', Original.DynamicDoubleArray, Deserialized.DynamicDoubleArray);
    CheckDynamicInnerArray('DynamicInnerArray', Original.DynamicInnerArray, Deserialized.DynamicInnerArray);

    // === Вложенные записи ===
    CheckInnerRecord('Inner', Original.Inner, Deserialized.Inner);

    // === Даты ===
    CheckDateTime('DateVal', Original.DateVal, Deserialized.DateVal);
    CheckDateTime('TimeVal', Original.TimeVal, Deserialized.TimeVal);
    CheckDateTime('DateTimeVal', Original.DateTimeVal, Deserialized.DateTimeVal);

    // === Перечисления ===
    CheckEnum('EnumVal', Original.EnumVal, Deserialized.EnumVal);

    // === Native типы ===
    CheckInteger('IntPtr', Original.IntPtr, Deserialized.IntPtr);
    CheckUInteger('UIntPtr', Original.UIntPtr, Deserialized.UIntPtr);

    // === Результаты ===
    Writeln;
    if Errors.Count = 0 then
    begin
      Writeln('✓ ВСЕ ПОЛЯ УСПЕШНО ДЕСЕРИАЛИЗОВАНЫ!');
      Writeln(Format('  Проверено полей: %d', [59])); // Примерное количество
    end
    else
    begin
      Writeln(Format('✗ Найдено %d ошибок:', [Errors.Count]));
      Writeln(Errors.Text);
    end;

  finally
    Errors.Free;
  end;
end;

function CreateTestRecord: TTestRecord;
var
  I: Integer;
begin
  // Инициализация всех полей
  FillChar(Result, SizeOf(Result), 0);

  // Числовые типы
  Result.Int8 := -127;
  Result.Int16 := 32767;
  Result.Int32 := -2147483647;
  Result.Int64 := 9223372036854775807;
  Result.UInt8 := 255;
  Result.UInt16 := 65535;
  Result.UInt32 := 4294967295;
  Result.UInt64 := 18446744073709551615;

  Result.SingleVal   := 3.14159;
  Result.DoubleVal   := 3.14159265358979;
  Result.ExtendedVal := 3.14159265358979323846;
  Result.CurrencyVal := 123.4567;

  Result.BoolVal := True;
  Result.AnsiCharVal := 'A';
  Result.WideCharVal := WideChar('W');

  Result.ShortStrVal := 'Short string';
  Result.AnsiStrVal := 'Ansi string';
  Result.WideStrVal := 'Wide string';
  Result.UnicodeStrVal := 'Unicode string';

  // Статические массивы
  for I := 0 to 4 do
    Result.StaticIntArr[I] := I * 10;

  for I := 0 to 9 do
    Result.StaticByteArr[I] := I;

  Result.StaticWideCharArr[0] := 'A';
  Result.StaticWideCharArr[1] := 'B';
  Result.StaticWideCharArr[2] := 'C';

  Result.StaticAnsiCharArr[0] := 'X';
  Result.StaticAnsiCharArr[1] := 'Y';
  Result.StaticAnsiCharArr[2] := 'Z';
  Result.StaticAnsiCharArr[3] := 'W';

  // Динамические массивы
  SetLength(Result.DynamicIntArray, 5);
  for I := 0 to 4 do
    Result.DynamicIntArray[I] := I * 100;

  SetLength(Result.DynamicByteArray, 10);
  for I := 0 to 9 do
    Result.DynamicByteArray[I] := I * 2;

  SetLength(Result.DynamicWideCharArray, 3);
  Result.DynamicWideCharArray[0] := 'a';
  Result.DynamicWideCharArray[1] := 'b';
  Result.DynamicWideCharArray[2] := 'c';

  SetLength(Result.DynamicAnsiCharArray, 4);
  Result.DynamicAnsiCharArray[0] := 'x';
  Result.DynamicAnsiCharArray[1] := 'y';
  Result.DynamicAnsiCharArray[2] := 'z';
  Result.DynamicAnsiCharArray[3] := 'w';

  SetLength(Result.DynamicStringArray, 3);
  Result.DynamicStringArray[0] := 'First';
  Result.DynamicStringArray[1] := 'Second';
  Result.DynamicStringArray[2] := 'Third';

  SetLength(Result.DynamicDoubleArray, 3);
  Result.DynamicDoubleArray[0] := 1.1;
  Result.DynamicDoubleArray[1] := 2.2;
  Result.DynamicDoubleArray[2] := 3.3;

  // Вложенная запись
  Result.Inner.IntVal := 999;
  Result.Inner.FloatVal := 123.456;
  Result.Inner.CharVal := 'Z';
  Result.Inner.WideCharVal := 'Я';
  Result.Inner.StrVal := 'Inner string';
  Result.Inner.AnsiStrVal := 'Inner Ansi';
  Result.Inner.WideStrVal := 'Inner Wide';

  // Массив вложенных записей
  for I := 0 to 2 do
  begin
    Result.StaticInnerArr[I].IntVal := I * 1000;
    Result.StaticInnerArr[I].FloatVal := I * 1.5;
    Result.StaticInnerArr[I].StrVal := Format('Inner static %d', [I]);
  end;

  // Динамический массив вложенных записей
  SetLength(Result.DynamicInnerArray, 2);
  for I := 0 to 1 do
  begin
    Result.DynamicInnerArray[I].IntVal := I * 2000;
    Result.DynamicInnerArray[I].FloatVal := I * 2.5;
    Result.DynamicInnerArray[I].StrVal := Format('Inner dynamic %d', [I]);
  end;

  Result.EnumVal := teThird;
  Result.DateTimeVal := Now;
  Result.DateVal := Date;
  Result.TimeVal := Time;

  Result.IntPtr := 12345;
  Result.UIntPtr := 67890;

end;

procedure WriteSCLStructure(Document: TSCLDocument);

  procedure WriteNode(Node: PSCLNode; Indent: string; IsLast: Boolean);
  var
    Prefix: string;
  begin
    if Node = nil then Exit;

    // Пропускаем нулевой узел и корневой узел (если он пустой)
    if (Node.NodeType = ntEmpty) and (Node.Parent = nil) then
      Exit;

    // Префикс для текущей строки
    if Indent = '' then
      Prefix := ''
    else if IsLast then
      Prefix := Indent + '└─ '
    else
      Prefix := Indent + '├─ ';

    // Вывод имени и типа узла
    var NodeType := '[' + SCLTypeNames[Node.NodeType] + ']';

    if Node.NodeType = ntComment then
      Write(Prefix, '# ', Node.Name)
    else if Node.Name <> '' then
      Write(Prefix, Node.Name, ' ', NodeType)
    else
      Write(Prefix, NodeType);

    // Рекурсивный обход дочерних элементов
    if Node.NodeType in [ntArray, ntTable] then
    begin
      WriteLn;
      var Childs := Node.ToArray;
      var Count := High(Childs);
      for var Index := 0 to Count do
      begin
        var NewIndent := Indent;
        if Indent = '' then
          NewIndent := '  '
        else if IsLast then
          NewIndent := Indent + '   '
        else
          NewIndent := Indent + '│  ';
        WriteNode(Childs[Index], NewIndent, Index = Count);
      end;
    // Вывод значения для простых типов
    end else WriteLn(' = ', Node.ToString);
  end;

begin
  if Document = nil then
  begin
    WriteLn('Document is nil');
    Exit;
  end;

  WriteLn('SCL Document Structure:');
  WriteNode(Document.Root, '', True);
end;

end.

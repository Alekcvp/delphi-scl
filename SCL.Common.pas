unit SCL.Common;

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
  System.SysUtils;

type
  ESCLError = class(Exception);
  TASCIIMap = array [#0..#127] of Byte;

  HPChar = record helper for PChar
    function SubString(Last: PChar): string; inline;
  end;

  TDecodedTime = record
    Year:   Word;
    Month:  Word;
    Day:    Word;
    Hour:   Word;
    Minute: Word;
    Second: Word;
  end;

  { Стек отступов для уровней документа }
  TIndentStack = record
  private const
    DEFAULT_STACK_SIZE = 16;
  private
    FStack: TArray<Integer>;
    FCount: Integer;
    FValue: Integer;
  public
    procedure Decrement;
    procedure Increment(ByValue: Integer); inline;
     function SetIndent(const AValue: Integer): Boolean;
    procedure Reset(BaseValue: Integer = 0);
     property Value: Integer read FValue;
  end;

  { Облегчённый кастомный вариант TStringBuilder'а }
  TStringBuffer = class
  private const
    DEFAULT_BUFFER_SIZE = 256;
    procedure SetLength(const Value: Integer); inline;
  protected
    FBuffer: string;
    FLength: Integer;
    FLineBreak: string;
     function CheckCapacity(Count: Integer): PChar;
  public
    constructor Create(const ALineBreaks: string);
     function Append(const Str: string): TStringBuffer; overload; inline;
     function Append(Buf: PChar; Count: Integer): TStringBuffer; overload; inline;
     function Append(Ch: Char): TStringBuffer; overload; inline;
     function AppendLineBreak: TStringBuffer; inline;
     function Reset: TStringBuffer; inline;
     function ToString: string; override;
    procedure TrimBreaks;
    procedure TrimSpace; inline;
     property Length: Integer read FLength write SetLength;
     property LineBreak: string read FLineBreak;
  end;

function ASCIISameName(const A, B: string): Boolean;
function AsDigit(Ch: Char): Word; inline;
function AsHexDigit(Ch: Char): Word; inline;
function Max(A, B: Integer): Integer; inline;
function Min(A, B: Integer): Integer; inline;
function NextPowerOfTwo(Value, Default: Integer): Integer;
function ValidateNodeName(Source: PChar): PChar;

const
  HexChars: array [0..15] of Char = '0123456789ABCDEF';
  HexMap: array [$00..$7F] of Byte = (
    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, // 00..0F
    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, // 10..1F
    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, // 20..2F
    $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$FF,$FF,$FF,$FF,$FF,$FF, // 30..3F  '0'..'9'
    $FF,$0A,$0B,$0C,$0D,$0E,$0F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, // 40..4F  'A'..'F'
    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, // 50..5F
    $FF,$0A,$0B,$0C,$0D,$0E,$0F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, // 60..6F  'a'..'f'
    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  // 70..7F
  );

//  ReaderMap: TASCIIMap = (

implementation

resourcestring
  sBufferOversize = 'Запрошен недопустимый размер буфера';

const
  { Таблица разрешённых символов для имён узлов }
  NameMap: TASCIIMap = (
  {  0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F    }
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, // 0
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, // 1
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, // 2
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF, $FF, $FF, // 3
    $FF, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, // 4
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF, $00, // 5
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, // 6
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF, $FF  // 7
  );

{ Допустимый набор символов в соответствии с NameMap: 0..9, _, A..Z, a..z }
function ASCIISameName(const A, B: string): Boolean;
begin
  { Получаем указатели на строки как на массив слов и смещение }
  var Source := PByte(A);
  var Index: NativeInt := PByte(B) - Source;
  { Тривиальные случаи: пустые строки или разные длины строк }
  if (Source = nil) or (A.Length <> B.Length) then Exit(Index = 0); // B = Source = nil
  { Сравниваем без учёта регистра }
  while (Source^ <> 0) and ((Source^ xor Source[Index]) and $DF = 0) do
    Inc(Source, SizeOf(Char));
  Result := Source^ = Source[Index]; // = 0
end;

function AsDigit(Ch: Char): Word; inline;
begin
  Result := Word(Ord(Ch) - Ord('0'));
end;

//function AsHexDigit(Ch: Char): Word; assembler;
//asm
//  mov   edx, eax
//  and   edx, $7F
//  and   ax, $FF80
//  or    al, byte ptr HexMap[edx]
//end;

function AsHexDigit(Ch: Char): Word; inline;
begin
  Result := HexMap[Ord(Ch) and $7F] or (Ord(Ch) and $FF80);
end;

function Max(A, B: Integer): Integer; inline;
begin
  if A < B then
    Exit(B);
  Result := A;
end;

function Min(A, B: Integer): Integer; inline;
begin
  if A > B then
    Exit(B);
  Result := A;
end;

function NextPowerOfTwo(Value, Default: Integer): Integer;
begin
  if Value < Default then
    Value := Default
  else if Value > $40000000 then
    raise ESCLError.CreateRes(@sBufferOversize);
  Result := Value - 1;
  Result := Result or (Result shr 1);
  Result := Result or (Result shr 2);
  Result := Result or (Result shr 4);
  Result := Result or (Result shr 8);
  Result := Result or (Result shr 16);
  Inc(Result);
end;

function ValidateNodeName(Source: PChar): PChar;
begin
  while (Word(Source^) and $FF80 = 0) and (NameMap[Source^] = $00) do
    Inc(Source);
  Result := Source;
end;

{ HPChar }

function HPChar.SubString(Last: PChar): string;
begin
  SetString(Result, Self, Last - Self);
end;

{ TStringBuffer }

function TStringBuffer.Append(Buf: PChar; Count: Integer): TStringBuffer;
begin
  if Count > 0 then
    Move(Buf^, CheckCapacity(Count)^, Count shl 1);
  Result := Self;
end;

function TStringBuffer.Append(const Str: string): TStringBuffer;
begin
  Result := Append(Pointer(Str), Str.Length);
end;

function TStringBuffer.Append(Ch: Char): TStringBuffer;
begin
  CheckCapacity(1)^ := Ch;
  Result := Self;
end;

function TStringBuffer.AppendLineBreak: TStringBuffer;
begin
  Result := Append(Pointer(FLineBreak), FLineBreak.Length);
end;

function TStringBuffer.CheckCapacity(Count: Integer): PChar;
begin
  if FBuffer.Length - FLength < Count then
    System.SetLength(FBuffer, NextPowerOfTwo(FLength + Count, DEFAULT_BUFFER_SIZE));
  Result := PPChar(@FBuffer)^ + FLength;
  Inc(FLength, Count);
end;

constructor TStringBuffer.Create(const ALineBreaks: string);
begin
  FLineBreak := ALineBreaks;
end;

function TStringBuffer.Reset: TStringBuffer;
begin
  FLength := 0;
  Result := Self;
end;

procedure TStringBuffer.SetLength(const Value: Integer);
begin
  if Value < FLength then
    FLength := Max(Value, 0);
end;

function TStringBuffer.ToString: string;
begin
  SetString(Result, PPChar(@FBuffer)^, FLength);
end;

procedure TStringBuffer.TrimBreaks;
begin
  var Source := PPChar(@FBuffer)^ - 1;
  var Cursor := Source + FLength;
  while Cursor > Source do
    case Cursor^ of
      #10, #13: Dec(Cursor);
      else Break;
    end;
  FLength := Cursor - Source;
end;

procedure TStringBuffer.TrimSpace;
begin
  if (FLength > 0) and (FBuffer[FLength] = #32) then
    Dec(FLength);
end;

{ TIndentStack }

procedure TIndentStack.Decrement;
begin
  if FCount > 0 then
  begin
    Dec(FCount);
    FValue := FStack[FCount];
  end;
end;

procedure TIndentStack.Increment(ByValue: Integer);
begin
  SetIndent(FValue + ByValue);
end;

procedure TIndentStack.Reset(BaseValue: Integer);
begin
  SetLength(FStack, DEFAULT_STACK_SIZE);
  FCount := 0;
  FValue := BaseValue;
end;

function TIndentStack.SetIndent(const AValue: Integer): Boolean;
begin
  Result := (FCount = 0) or (AValue > FValue + 1);
  if Result then
  begin
    if FCount >= Length(FStack) then
      SetLength(FStack, NextPowerOfTwo(FCount + 1, DEFAULT_STACK_SIZE));
    FStack[FCount] := FValue;
    Inc(FCount);
    FValue := AValue;
  end;
end;

end.

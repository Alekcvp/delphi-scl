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

  { Стек отступов для уровней документа }
  TIndentStack = record
  private const
    DEFAULT_STACK_SIZE = 16;
  private
    FStack: TArray<Integer>;
    FCount: Integer;
    function GetValue: Integer; inline;
  public
    procedure Decrement;
    procedure Increment(ByValue: Integer); inline;
     function SetIndent(const AValue: Integer): Boolean;
    procedure Reset(BaseValue: Integer = 0);
     property Value: Integer read GetValue;
  end;

  { Облегчённый кастомный вариант TStringBuilder'а }
  TStringBuffer = class
  private const
    DEFAULT_BUFFER_SIZE = 256;
  protected
    FBuffer: string;
    FLength: Integer;
    FBookmark: Integer;
    FLineBreak: string;
     function CheckCapacity(Count: Integer): PChar;
  public
    constructor Create;
     function Append(const Str: string): TStringBuffer; overload; inline;
     function Append(Buf: PChar; Count: Integer): TStringBuffer; overload; inline; { TODO: проверить как работает inline }
     function Append(Ch: Char): TStringBuffer; overload; inline;
     function AppendLineBreak: TStringBuffer; inline;
     function Bookmark: TStringBuffer; inline;
     function Restore: TStringBuffer; inline;
     function Reset: TStringBuffer; inline;
     function ToString: string; reintroduce;
     property Length: Integer read FLength;
     property LineBreak: string read FLineBreak write FLineBreak;
  end;

function ASCIISameName(const A, B: string): Boolean;
function AsDigit(Ch: Char): Word; inline;
function Max(A, B: Integer): Integer; inline;
function Min(A, B: Integer): Integer; inline;
function NextPowerOfTwo(Value, Default: Integer): Integer;
function ValidateNodeName(Source: PChar): PChar;

const
  HexChars: array [0..15] of Char = '0123456789ABCDEF';

  ESCAPE_NOT = $00;
  ESCAPE_CHR = $10; // экранирование подстановкой (\r\n)
  ESCAPE_ORD = $20; // экранирование кодом (\x00)

  STR_VALID  = $00;
  STR_BREAK  = $01;
  STR_QUOTE  = $02;
  STR_ESCAPE = $04;

  // Запись обычной строки: StringMap[Ch] and $F0
  // Все остальные строки:  StringMap[Ch] and $0F
  StringMap: TASCIIMap = (
  {  0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F   }
    $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $1F, $10, $11, $1F, $1F, $11, $2F, $2F, // 0
    $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, $2F, // 1
    $00, $00, $F2, $00, $00, $00, $00, $02, $00, $00, $00, $00, $00, $00, $00, $00, // 2
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, // 3
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, // 4
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $F4, $00, $00, $00, // 5
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, // 6
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2F  // 7
  );

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
  { Тривиальные случаи: пустые строки или разные длины строк }
  var Source := PByte(A);
  if (Source = nil) or (A.Length <> B.Length) then Exit(Source = nil);
  { Получаем указатели на строки как на массив слов и смещение }
  var Index: NativeInt := PByte(B) - Source;
  { Сравниваем без учёта регистра }
  while (Source^ <> 0) and ((Source^ xor Source[Index]) and $DF = 0) do
    Inc(Source, SizeOf(Char));
  Result := Source[Index] = 0;
end;

function AsDigit(Ch: Char): Word; inline;
begin
  Result := Word(Ord(Ch) - Word('0'));
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

function TStringBuffer.Bookmark: TStringBuffer;
begin
  FBookmark := FLength;
  Result := Self;
end;

function TStringBuffer.CheckCapacity(Count: Integer): PChar;
begin
  if FBuffer.Length - FLength < Count then
    SetLength(FBuffer, NextPowerOfTwo(FLength + Count, DEFAULT_BUFFER_SIZE));
  Result := PPChar(@FBuffer)^ + FLength;
  Inc(FLength, Count);
end;

constructor TStringBuffer.Create;
begin
  FLineBreak := sLineBreak;
end;

function TStringBuffer.Reset: TStringBuffer;
begin
  FBookmark := 0;
  FLength := 0;
  Result := Self;
end;

function TStringBuffer.Restore: TStringBuffer;
begin
  FLength := FBookmark;
  Result := Self;
end;

function TStringBuffer.ToString: string;
begin
  SetString(Result, PPChar(@FBuffer)^, FLength);
end;

{ TIndentStack }

procedure TIndentStack.Decrement;
begin
  if FCount > 0 then
    Dec(FCount);
end;

function TIndentStack.GetValue: Integer;
begin
  Result := FStack[FCount];
end;

procedure TIndentStack.Increment(ByValue: Integer);
begin
  SetIndent(FStack[FCount] + ByValue);
end;

procedure TIndentStack.Reset(BaseValue: Integer);
begin
  SetLength(FStack, DEFAULT_STACK_SIZE);
  FCount := 0;
  FStack[FCount] := BaseValue;
end;

function TIndentStack.SetIndent(const AValue: Integer): Boolean;
begin
  Result := (FCount = 0) or (AValue > FStack[FCount] + 1);
  if Result then
  begin
    if FCount >= Length(FStack) then
      SetLength(FStack, NextPowerOfTwo(FCount + 1, DEFAULT_STACK_SIZE));
    Inc(FCount);
    FStack[FCount] := AValue;
  end;
end;

end.

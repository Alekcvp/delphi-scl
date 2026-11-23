unit SCL.Types;

interface

uses
  System.SysUtils;

type
  TSCLPrecision  = 0..16;
  TSCLNumberBase = (nbDefault, nbBin, nbHex, nbOct);
  TSCLStringType = (stDefault, stLiteral, stText, stWrapped);
  TSCLValueState = (vsDefault, vsRequired, vsDontWrite, vsIgnore);

  SCLInfoAttribute = class(TCustomAttribute)
  private
    FName: string;
    FComment: string;
    FState: TSCLValueState;
  public
    constructor Create(const AComment: string = string.Empty); overload;
    constructor Create(const AName: string; const AComment: string = string.Empty); overload;
    constructor Create(const AName: string; AState: TSCLValueState = vsDefault; const AComment: string = string.Empty); overload;
    constructor Create(AState: TSCLValueState = vsDefault; const AComment: string = string.Empty); overload;
    procedure TrySetName(var Name: string);
    property Comment: string read FComment;
    property State: TSCLValueState read FState;
  end;

  SCLNumberAttribute = class(TCustomAttribute)
  private
    FNumberBase: TSCLNumberBase;
    FPrecision: TSCLPrecision;
  public
    constructor Create(const ANumberBase: TSCLNumberBase); overload;
    constructor Create(const APrecision: TSCLPrecision); overload;
    property NumberBase: TSCLNumberBase read FNumberBase;
    property Precision: TSCLPrecision read FPrecision;
  end;

  SCLStringAttribute = class(TCustomAttribute)
  private
    FStringType: TSCLStringType;
  public
    constructor Create(const AStringType: TSCLStringType);
    property StringType: TSCLStringType read FStringType;
  end;

  SCLInlineAttribute = class(TCustomAttribute)
  end;

  SCLTimeZoneAttribute = class(TCustomAttribute)
  end;

implementation

{ SCLInfoAttribute }

constructor SCLInfoAttribute.Create(const AComment: string);
begin
  FComment := AComment;
end;

constructor SCLInfoAttribute.Create(const AName, AComment: string);
begin
  FName := AName;
  FComment := AComment;
end;

constructor SCLInfoAttribute.Create(const AName: string; AState: TSCLValueState; const AComment: string);
begin
  FName := AName;
  FComment := AComment;
  FState := AState;
end;

constructor SCLInfoAttribute.Create(AState: TSCLValueState; const AComment: string);
begin
  FComment := AComment;
  FState := AState;
end;

procedure SCLInfoAttribute.TrySetName(var Name: string);
begin
  if FName <> string.Empty then
    Name := FName;
end;

{ SCLNumberAttribute }

constructor SCLNumberAttribute.Create(const APrecision: TSCLPrecision);
begin
  FPrecision := APrecision;
end;

constructor SCLNumberAttribute.Create(const ANumberBase: TSCLNumberBase);
begin
  FNumberBase := ANumberBase;
  FPrecision := High(FPrecision); // максимальная точность по умолчанию
end;

{ SCLStringAttribute }

constructor SCLStringAttribute.Create(const AStringType: TSCLStringType);
begin
  FStringType := AStringType;
end;

end.

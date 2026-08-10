unit SCL.Types;

interface

uses
  System.SysUtils;

type
  TSCLPrecision  = 0..16;
  TSCLNumberBase = (nbDefault, nbBin, nbHex, nbOct);
  TSCLStringType = (stDefault, stLiteral, stText, stWrapped);

  SCLBaseAttribute = class(TCustomAttribute)
  private
    FNumberBase: TSCLNumberBase;
  public
    constructor Create(const ANumberBase: TSCLNumberBase);
    property NumberBase: TSCLNumberBase read FNumberBase;
  end;

  SCLCommentAttribute = class(TCustomAttribute)
  private
    FComment: string;
  public
    constructor Create(const AComment: string);
    property Comment: string read FComment;
  end;

  SCLInlineAttribute = class(TCustomAttribute)
  end;

  SCLNameAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const AName: string);
    property Name: string read FName;
  end;

  SCLStateAttribute = class(TCustomAttribute)
  public type
    TValueState = (vsDefault, vsRequired, vsDontWrite, vsIgnore);
  private
    FState: TValueState;
  public
    constructor Create(const AState: TValueState);
    property State: TValueState read FState;
  end;

  SCLStringAttribute = class(TCustomAttribute)
  private
    FStringType: TSCLStringType;
  public
    constructor Create(const AStringType: TSCLStringType);
    property StringType: TSCLStringType read FStringType;
  end;

  SCLTimeZoneAttribute = class(TCustomAttribute)
  end;

implementation

{ SCLBaseAttribute }

constructor SCLBaseAttribute.Create(const ANumberBase: TSCLNumberBase);
begin
  FNumberBase := ANumberBase;
end;

{ SCLNameAttribute }

constructor SCLNameAttribute.Create(const AName: string);
begin
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

constructor SCLStringAttribute.Create(const AStringType: TSCLStringType);
begin
  FStringType := AStringType;
end;

end.

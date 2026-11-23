# Документация по модулю SCL.Types

## Обзор

Модуль `SCL.Types` определяет базовые типы-перечисления и RTTI-атрибуты, используемые библиотекой Delphi-SCL для настройки сериализации/десериализации (модуль `SCL.Serializer`) и представления значений в SCL-документах. Атрибуты применяются к полям записей и самим типам данных, чтобы управлять именованием узлов, комментариями, состоянием значений, системой счисления, точностью, строковым представлением и режимом форматирования контейнеров.

---

## Перечисления

### `TSCLPrecision`

```pascal
TSCLPrecision = 0..16;
```

Диапазон допустимой точности представления чисел (количество знаков после запятой/значащих цифр).

### `TSCLNumberBase`

```pascal
TSCLNumberBase = (nbDefault, nbBin, nbHex, nbOct);
```

Система счисления для числовых значений:

| Значение | Описание |
|---|---|
| `nbDefault` | По умолчанию (десятичная) |
| `nbBin` | Двоичная (`0b...`) |
| `nbHex` | Шестнадцатеричная (`0x...`) |
| `nbOct` | Восьмеричная (`0o...`) |

### `TSCLStringType`

```pascal
TSCLStringType = (stDefault, stLiteral, stText, stWrapped);
```

Тип строкового представления значения:

| Значение | Описание |
|---|---|
| `stDefault` | Обычная строка в двойных кавычках с экранированием |
| `stLiteral` | Литеральная строка в одинарных кавычках |
| `stText` | Блочный литерал (`\|`) с сохранением переносов строк |
| `stWrapped` | Свёрнутый блок (`>`) с переносом длинных строк |

### `TSCLValueState`

```pascal
TSCLValueState = (vsDefault, vsRequired, vsDontWrite, vsIgnore);
```

Состояние значения/поля при сериализации и десериализации:

| Значение | Описание |
|---|---|
| `vsDefault` | Обычное поведение |
| `vsRequired` | Значение обязательно при десериализации (иначе ошибка) |
| `vsDontWrite` | Не записывать значение при сериализации |
| `vsIgnore` | Полностью игнорировать поле (ни читать, ни писать) |

---

## Атрибуты

### `SCLInfoAttribute`

```pascal
SCLInfoAttribute = class(TCustomAttribute)
```

Основной атрибут для настройки узла: имя, комментарий и состояние значения. Применяется к полям записей и типам.

#### Конструкторы

```pascal
constructor Create(const AComment: string = string.Empty); overload;
constructor Create(const AName: string; const AComment: string = string.Empty); overload;
constructor Create(const AName: string; AState: TSCLValueState = vsDefault;
  const AComment: string = string.Empty); overload;
constructor Create(AState: TSCLValueState = vsDefault;
  const AComment: string = string.Empty); overload;
```

Позволяют задать различные комбинации имени узла, состояния и комментария.

---

### `SCLNumberAttribute`

```pascal
SCLNumberAttribute = class(TCustomAttribute)
```

Атрибут для настройки числового представления: система счисления и точность.

#### Конструкторы

```pascal
constructor Create(const ANumberBase: TSCLNumberBase); overload;
constructor Create(const APrecision: TSCLPrecision); overload;
```

- При указании системы счисления точность автоматически устанавливается в максимум (`High(TSCLPrecision)`).
- При указании только точности система счисления остаётся `nbDefault`.

---

### `SCLStringAttribute`

```pascal
SCLStringAttribute = class(TCustomAttribute)
```

Атрибут для задания строкового представления значения.

#### Конструктор

```pascal
constructor Create(const AStringType: TSCLStringType);
```

---

### `SCLInlineAttribute`

```pascal
SCLInlineAttribute = class(TCustomAttribute)
```

Маркерный атрибут без параметров. Применяется к полям-контейнерам (массивам, множествам, записям), чтобы указать сериализатору писать их в строчном режиме (`[...]` или `{...}` вместо блочного представления с отступами).

---

### `SCLTimeZoneAttribute`

```pascal
SCLTimeZoneAttribute = class(TCustomAttribute)
```

Маркерный атрибут без параметров. Применяется к полям типа `TDateTime`, чтобы при сериализации сохранять информацию о часовом поясе (смещение от UTC).

---

## Пример использования

```pascal
type
  [SCLInfo('server')]
  TServerConfig = record
    [SCLInfo('host', 'Адрес сервера')]
    Host: string;

    [SCLInfo('port')]
    [SCLNumber(nbHex)]
    Port: Integer;

    [SCLString(stLiteral)]
    Path: string;

    [SCLInline]
    Tags: TArray<string>;

    [SCLInfo(vsRequired)]
    Secret: string;

    [SCLTimeZone]
    StartedAt: TDateTime;

    [SCLInfo(vsIgnore)]
    Cache: Pointer;
  end;
```
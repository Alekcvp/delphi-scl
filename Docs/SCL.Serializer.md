# Документация по модулю SCL.Serializer

## Обзор

Модуль `SCL.Serializer` реализует двустороннее преобразование между произвольными типами данных Delphi (через RTTI) и объектной моделью SCL-документа (`TSCLDocument`/`TSCLNode`). Модуль предоставляет:

- запись (`Serialize`) значений Delphi-типов в узлы SCL-документа;
- чтение (`Deserialize`) значений Delphi-типов из узлов SCL-документа;
- механизм настройки поведения через атрибуты (`SCLInfoAttribute`, `SCLNumberAttribute`, `SCLStringAttribute`, `SCLInlineAttribute`, `SCLTimeZoneAttribute`), применяемые к полям записей и самим типам.

Модуль работает с типами: целые (все размеры, знаковые/беззнаковые), `Int64`, числа с плавающей точкой (`Single`, `Double`, `Extended`, `Comp`, `Currency`), `TDateTime`, перечисления, множества, символьные типы (`AnsiChar`, `WideChar`), строки (`ShortString`, `AnsiString`, `WideString`, `UnicodeString`), статические и динамические массивы, а также записи (`record`).

---

## Класс `ESerializeError`

Исключение, возбуждаемое при ошибках сериализации/десериализации: неподдерживаемый тип, несоответствие размера массива, отсутствие обязательного значения, неизвестное значение перечисления, неверный символ и т.п.

---

## Запись `TSCLParams`

```pascal
PSCLParams = ^TSCLParams;
TSCLParams = record
  Name: string;
  Comment: string;
  State: TSCLValueState;
  InlineMode: Boolean;
  IsTimeZone: Boolean;
  NumberBase: TSCLNumberBase;
  Precision: TSCLPrecision;
  StringType: TSCLStringType;
  constructor Create(const AName: string; const Attrs: TArray<TCustomAttribute>);
end;
```

Контейнер параметров сериализации для конкретного узла/поля. Формируется из имени и набора RTTI-атрибутов. Назначение полей:

| Поле | Описание |
|---|---|
| `Name` | Имя узла в SCL-документе (переопределяется через `SCLInfoAttribute`). Пустое имя недопустимо — возбуждается `ESerializeError` |
| `Comment` | Комментарий узла (из `SCLInfoAttribute`) |
| `State` | Состояние узла (`vsDefault`, `vsIgnore`, `vsRequired`, `vsDontWrite` и т.п.) |
| `InlineMode` | Признак строчного (`[...]`/`{...}`) представления контейнера (из `SCLInlineAttribute`) |
| `IsTimeZone` | Признак сохранения часового пояса для `TDateTime` (из `SCLTimeZoneAttribute`) |
| `NumberBase` | Система счисления для чисел (из `SCLNumberAttribute`) |
| `Precision` | Точность представления чисел (из `SCLNumberAttribute`) |
| `StringType` | Тип строкового представления (`stDefault`, `stLiteral`, `stText`, `stWrapped`) (из `SCLStringAttribute`) |

**Конструктор** `Create(AName, Attrs)` инициализирует запись значениями по умолчанию, затем применяет переданные атрибуты. Если после применения имя осталось пустым — возбуждает `ESerializeError`.

---

## Запись `TSCLSerializer`

Основной тип модуля (реализован как `record` с автоматическим управлением RTTI-контекстом через операторы `Initialize`/`Finalize`). Благодаря этому экземпляр можно создавать как обычную переменную без явного освобождения ресурсов.

### Инициализация и финализация

```pascal
class operator Initialize(out Instance: TSCLSerializer);
class operator Finalize(var Instance: TSCLSerializer);
```

Автоматически создают и освобождают внутренний `TRttiContext` при создании/уничтожении экземпляра записи.

### Методы сериализации

```pascal
procedure Serialize<T>(RootNode: PSCLNode; const Value: T;
  const AName: string = string.Empty); overload;
```

Записывает значение `Value` типа `T` в указанный узел `RootNode`.

- Если у типа есть атрибут с именем (или задан `AName`), создаётся дочерний узел с этим именем.
- Для «контейнерных» типов (`tkDynArray`, `tkArray`, `tkRecord`, `tkMRecord`, `tkSet`) значение пишется непосредственно в `RootNode`.
- Для простых типов без имени создаётся узел-обёртка (массив из одного элемента).

```pascal
function Serialize<T>(const Value: T;
  const AName: string = string.Empty): TSCLDocument; overload;
```

Создаёт новый `TSCLDocument`, сериализует в него `Value` и возвращает документ. При возникновении исключения документ освобождается и исключение пробрасывается дальше.

### Методы десериализации

```pascal
procedure Deserialize<T>(RootNode: PSCLNode; out Value: T;
  const AName: string = string.Empty);
```

Читает значение типа `T` из узла `RootNode` в переменную `Value`.

- Если задано имя (через `AName` или атрибут типа), соответствующий дочерний узел ищется по имени.
- Для простых типов без имени берётся первый дочерний элемент.
- Для записей отсутствующие поля заполняются согласно их атрибутам: `vsIgnore` — пропускается, `vsRequired` — при отсутствии возбуждается `ESerializeError`.

### Поддерживаемые типы и особенности

| Категория | Поведение |
|---|---|
| **Целые** (`tkInteger`, `tkInt64`) | Пишутся/читаются с учётом `NumberBase`; при чтении приводятся к нужному размеру |
| **Числа с плавающей точкой** (`tkFloat`) | `TDateTime` обрабатывается как дата/время (с опциональным часовым поясом), `Comp`/`Currency` — как целое, `Extended`/`Single`/`Double` — как вещественное |
| **Перечисления** (`tkEnumeration`) | `Boolean` — как булево значение; остальные — по имени (с отбрасыванием префикса типа при необходимости). При чтении неизвестное имя возбуждает `ESerializeError` |
| **Множества** (`tkSet`) | Пишутся как массив имён элементов (для перечислений) или индексов (для остальных). При чтении устанавливаются соответствующие биты; для одно-байтовых множеств возможно строчное представление |
| **Символы** (`tkChar`, `tkWChar`) | Пишутся как строка из одного символа. При чтении строка обязана содержать ровно один символ, иначе `ESerializeError` |
| **Строки** (`tkString`, `tkLString`, `tkWString`, `tkUString`) | Пишутся с учётом `StringType`; читаются с приведением к целевому типу |
| **Статические массивы** (`tkArray`) | Массивы `Byte` пишутся как бинарное значение, `WideChar`/`AnsiChar` — как строка; остальные — поэлементно. При чтении проверяется соответствие размера, иначе `ESerializeError` |
| **Динамические массивы** (`tkDynArray`) | Аналогично статическим, но размер определяется по факту. Массивы `Byte` — бинарные, `WideChar`/`AnsiChar` — строковые, остальные — поэлементно |
| **Записи** (`tkRecord`, `tkMRecord`) | Обход полей через RTTI: каждое поле получает собственные `TSCLParams` на основе атрибутов. Поля с `vsIgnore`/`vsDontWrite` пропускаются при записи; с `vsRequired` — обязательны при чтении |
| **Неподдерживаемые типы** (`tkClass`, `tkInterface`, `tkVariant`, `tkPointer`, `tkMethod`, `tkProcedure`, `tkClassRef`, `tkUnknown`) | Возбуждается `ESerializeError` с именем типа |

### Внутренние карты обработчиков

Модуль содержит две публичные константы-массива, индексируемые по `System.TTypeKind`:

- **`DecoderMap`** — карта методов чтения (десериализации) для каждого `TTypeKind`;
- **`EncoderMap`** — карта методов записи (сериализации) для каждого `TTypeKind`.

Обе карты связывают `TTypeKind` со статическим методом `TDataEncoder`; для неподдерживаемых типов указан `TypeNotSupported`, возбуждающий `ESerializeError`. Карты доступны извне модуля и могут использоваться для расширения/инспекции поведения.

### Вспомогательные публичные элементы

Помимо методов класса, модуль экспортирует:

- `DefaultParams: TSCLParams` — параметры по умолчанию, используемые для элементов массивов и вложенных значений без явных атрибутов.

---

## Атрибуты, используемые сериализатором

Модуль опирается на следующие атрибуты (определены в `SCL.Types`), распознаваемые в `TSCLParams.Create`:

| Атрибут | Влияние |
|---|---|
| `SCLInfoAttribute` | Имя узла, комментарий, состояние (`State`) |
| `SCLNumberAttribute` | Система счисления (`NumberBase`) и точность (`Precision`) |
| `SCLStringAttribute` | Тип строкового представления (`StringType`) |
| `SCLInlineAttribute` | Включает строчный режим (`InlineMode`) для контейнеров |
| `SCLTimeZoneAttribute` | Сохранять часовой пояс для `TDateTime` (`IsTimeZone`) |

---

## Пример использования (концептуально)

```pascal
type
  TConfig = record
    [SCLInfo('host')]
    Host: string;
    [SCLInfo('port')]
    Port: Integer;
    [SCLInline]
    Tags: TArray<string>;
  end;

var
  Serializer: TSCLSerializer;
  Doc: TSCLDocument;
  Cfg: TConfig;
begin
  Cfg.Host := 'localhost';
  Cfg.Port := 8080;
  Cfg.Tags := ['a', 'b'];

  Doc := Serializer.Serialize<TConfig>(Cfg);
  try
    Serializer.Deserialize<TConfig>(Doc.Root, Cfg);
  finally
    Doc.Free;
  end;
end;
```

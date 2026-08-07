# SCL Library API

## TSCLDocument

Основной класс для управления SCL-документом. Обеспечивает хранение и управление узлами с эффективной хэш-таблицей для быстрого доступа.

### Особенности
- **Автоматическое управление памятью** — узлы хранятся в блоках для снижения фрагментации
- **Хэш-таблица** — быстрый поиск узлов по имени (для таблиц)
- **Динамическое расширение** — автоматическое увеличение хэш-таблицы при заполнении

### Свойства

| Свойство | Тип | Описание |
|----------|-----|----------|
| `Root` | `PSCLNode` | Корневой узел документа (тип `ntArray`) |

### Методы

| Метод | Описание |
|-------|----------|
| `Create(Capacity: Integer = 0)` | Создаёт документ с начальной ёмкостью |
| `Clear` | Очищает все данные документа |
| `IsEmpty: Boolean` | Проверяет, пуст ли документ |

---

## PSCLNode

Узел SCL-документа. Может представлять различные типы данных: примитивы, массивы, таблицы.

### Типы узлов (`TSCLNodeType`)

| Тип | Описание |
|-----|----------|
| `ntEmpty` | Пустой узел |
| `ntBinary` | Бинарные данные |
| `ntBoolean` | Логическое значение |
| `ntComment` | Комментарий |
| `ntDateTime` | Дата/время |
| `ntFloat` | Число с плавающей точкой |
| `ntInteger` | Целое число |
| `ntNull` | Null-значение |
| `ntString` | Строка |
| `ntArray` | Массив |
| `ntTable` | Таблица (словарь) |

### Свойства

| Свойство | Тип | Описание |
|----------|-----|----------|
| `Name` | `string` | Имя узла или текст комментария |
| `NodeType` | `TSCLNodeType` | Тип узла |
| `Parent` | `PSCLNode` | Родительский узел |
| `FirstChild` / `LastChild` | `PSCLNode` | Первый/последний дочерний узел |
| `PrevSibling` / `NextSibling` | `PSCLNode` | Предыдущий/следующий узел |
| `Count` | `Integer` | Количество дочерних узлов |
| `ItemIndex` | `Integer` | Порядковый номер в родителе |
| `Path` | `string` | Путь от корня (например, `/table/subtable/@0`) |
| `Items[AName]` | `PSCLNode` | Доступ к дочернему узлу по имени |
| `AsString` / `AsInteger` / `AsDouble` / `AsBoolean` / `AsBytes` / `AsDateTime` | — | Значения узла |

### Значения

| Свойство | Тип | Описание |
|----------|-----|----------|
| `Precision` | `0..16` | Точность для чисел с плавающей точкой |
| `NumberBase` | `nbDefault, nbBin, nbHex, nbOct` | Система счисления для целых чисел |
| `StringType` | `stDefault, stLiteral, stText, stWrapped` | Тип строки |
| `TimeOffset` | `SmallInt` | Смещение для дат (`-1` = локальное время) |

### Методы для создания

| Метод | Описание |
|-------|----------|
| `AddNode(AName, AType)` | Добавляет дочерний узел |
| `AddTable(AName, IsInline)` | Добавляет таблицу |
| `AddArray(AName, IsInline)` | Добавляет массив |
| `AddValue(AName, Value, ...)` | Добавляет узел со значением |
| `AddComment(Comment)` | Добавляет комментарий |

### Быстрый доступ (`A`, `B`, `D`, `F`, `I`, `O`, `S`, `T`)

```delphi
// Автоматически создают узел, если его нет
var
  Table: PSCLNode;
  Node: PSCLNode;
begin
  Table := Root.T['config'];      // ntTable
  Node := Table.I['port'];        // ntInteger
  Node := Table.S['name'];        // ntString
  Node := Table.A['items'];       // ntArray
  Node := Table.B['enabled'];     // ntBoolean
  Node := Table.O['data'];        // ntBinary
  Node := Table.D['created'];     // ntDateTime
  Node := Table.F['rate'];        // ntFloat
end;
```

### Методы для работы

| Метод | Описание |
|-------|----------|
| `SetValue(...)` | Устанавливает значение (меняет тип если ntEmpty) |
| `SetNullValue` | Устанавливает null |
| `ToInteger` / `ToFloat` / `ToString` | Преобразует значение |
| `ToArray` | Возвращает дочерние узлы как массив |
| `ItemByPath(Path)` | Поиск узла по пути |
| `GetEnumerator` | Перебор дочерних узлов (`for ... in`) |
| `IsRoot` / `IsInline` / `IsFirst` / `IsLast` | Проверки состояния |

### Пример использования

```delphi
var
  Doc: TSCLDocument;
  Root, Node: PSCLNode;
begin
  Doc := TSCLDocument.Create;
  Root := Doc.Root;
  
  // Создание таблицы
  var Config := Root.T['app'];
  Config.S['name'] := 'MyApp';
  Config.I['version'] := 1;
  Config.F['score'] := 99.9;
  Config.B['debug'] := False;
  
  // Создание массива
  var Servers := Config.A['servers'];
  Servers.AddValue('', 'server1');
  Servers.AddValue('', 'server2');
  Servers.AddValue('', 'server3');
  
  // Перебор
  for var Server in Servers^ do
    WriteLn(Server.AsString);
  
  // Поиск по пути
  Node := Root.ItemByPath('/app/servers/@2'); // '/app/servers/@0' для первого элемента
end;
```

# SCL Reader & Writer

## TSCLReader

Парсер для загрузки SCL-документов из строк, байтовых буферов или файлов. Автоматически определяет кодировку (UTF-8, UTF-16LE, UTF-16BE) и обеспечивает детальную диагностику ошибок с указанием позиции.

### Особенности

- **Автоопределение кодировки** — поддержка UTF-8, UTF-16LE, UTF-16BE с BOM и без
- **Детальные ошибки** — точное указание строки и колонки с описанием проблемы
- **Гибкая загрузка** — из строки, байтового буфера или файла
- **Обработка отступов** — автоматическое определение уровней вложенности

### Методы

| Метод | Описание |
|-------|----------|
| `ParseDocument(Source: string): TSCLDocument` | Парсит строку, возвращает новый документ |
| `ParseDocument(Buffer: TBytes): TSCLDocument` | Парсит байтовый буфер |
| `ParseDocument(Source: string; var Document)` | Парсит в существующий документ |
| `ParseFile(AFileName: string): TSCLDocument` | Парсит файл, возвращает новый документ |
| `ParseFile(AFileName: string; var Document)` | Парсит файл в существующий документ |
| `SetLineBreaks(LineBreak: string)` | Устанавливает разделитель строк для вывода |
| `ReadFrom(AFileName: string): TSCLDocument` | **Статический метод** — быстрый парсинг файла |

### Пример использования

```delphi
var
  Doc: TSCLDocument;
  Reader: TSCLReader;
begin
  Reader := TSCLReader.Create;
  try
    // Из файла
    Doc := Reader.ParseFile('config.scl');
    
    // Или из строки
    Doc := Reader.ParseDocument(
      'app:' + sLineBreak +
      '  name: "MyApp"' + sLineBreak +
      '  version: 1' + sLineBreak +
      '  servers: [' + sLineBreak +
      '    "server1",' + sLineBreak +
      '    "server2"' + sLineBreak +
      '  ]'
    );
    
    // Или статически
    Doc := TSCLReader.ReadFrom('config.scl');
  finally
    Reader.Free;
  end;
end;
```

---

## TSCLWriter

Генератор SCL-документов из структуры `TSCLDocument`. Поддерживает форматирование с отступами, перенос строк и различные стили записи строковых значений.

### Особенности

- **Настраиваемое форматирование** — отступы (2–8 пробелов), ширина переноса
- **Поддержка всех типов строк** — экранированные, литеральные, текстовые блоки (`|`), свёрнутые (`>`)
- **Строчные массивы и таблицы** — компактная запись в одну строку
- **Сохранение в файл** — с указанием кодировки (UTF-8, UTF-16 и др.)

### Свойства

| Свойство | Тип | Описание |
|----------|-----|----------|
| `IndentStep` | `Integer` | Шаг отступа для уровней вложенности (2–8) |
| `WrapWidth` | `Integer` | Ширина для переноса свёрнутых строк (минимум 32) |
| `LeadArray` | `Boolean` | Выводить элементы массива с новой строки |
| `SpaceNodes` | `Boolean` | Разделять узлы пустыми строками |

### Методы

| Метод | Описание |
|-------|----------|
| `WriteDocument(Document): string` | Возвращает SCL-представление документа |
| `WriteDocument(AFileName, Document, Encoding)` | Сохраняет документ в файл |
| `SetLineBreaks(LineBreak: string)` | Устанавливает разделитель строк |

### Стили строк

| Тип | Описание | Пример |
|-----|----------|--------|
| `stDefault` | Экранированная строка в кавычках | `"Hello\nWorld"` |
| `stLiteral` | Литеральная строка (одинарные кавычки) | `'Hello World'` |
| `stText` | Многострочный текстовый блок | <pre>\|<br>  Hello<br>  World</pre> |
| `stWrapped` | Свёрнутый текст с переносом | <pre>&gt;<br>  Hello<br>  World</pre> |

### Пример использования

```delphi
var
  Doc: TSCLDocument;
  Writer: TSCLWriter;
  Output: string;
begin
  // Создаём документ
  Doc := TSCLReader.ReadFrom('config.scl');
  
  Writer := TSCLWriter.Create(2, 80); // отступ 2, ширина 80
  try
    Writer.SpaceNodes := True;  // разделять секции
    Writer.LeadArray := False;  // элементы массива в той же строке
    
    // Получить как строку
    Output := Writer.WriteDocument(Doc);
    
    // Сохранить в файл (UTF-8 с BOM)
    Writer.WriteDocument('output.scl', Doc, TEncoding.UTF8);
  finally
    Writer.Free;
  end;
end;
```

### Пример форматирования

**Входной документ:**
```scl
app:
  name: "MyApp"
  version: 1
  debug: false
  servers: 
    - name: "server1" 
      type: "ftp" 
      ipv4: "10.10.0.17"
  description: |
    This is a multi-line
    text block with
    preserved formatting
```

**С настройками:**
```delphi
Writer.IndentStep := 4;
Writer.SpaceNodes := True;
Writer.LeadArray := True;
```

**Результат:**
```scl
app:
    name: "MyApp"
    version: 1
    debug: false

    servers:
        -
            name: "server1"
            type: "ftp"
            ipv4: "10.10.0.17"

    description: |
        This is a multi-line
        text block with
        preserved formatting
```

# SCL Serializer

Сериализатор для преобразования между SCL-документами и Delphi-объектами (записи, массивы, перечисления, коллекции). Использует RTTI для автоматического отображения полей на узлы документа.

## Особенности

- **Автоматическое отображение** — поля записей преобразуются в узлы документа
- **Поддержка всех типов** — целые, числа с плавающей точкой, строки, перечисления, множества, массивы
- **Кастомизация через атрибуты** — имена, комментарии, формат чисел, тип строк

## Атрибуты для кастомизации

| Атрибут | Описание |
|---------|----------|
| `SCLName('name')` | Задаёт имя узла (по умолчанию — имя поля) |
| `SCLComment('text')` | Добавляет комментарий перед полем |
| `SCLInline` | Сохраняет массив/таблицу в строчном формате `[...]` / `{...}` |
| `SCLState(vsRequired / vsDontWrite / vsIgnore)` | Управляет сериализацией |
| `SCLString(stLiteral / stText / stWrapped)` | Задаёт тип строки |
| `SCLBase(nbBin / nbHex / nbOct)` | Система счисления для целых чисел |
| `SCLTimeZone` | Сохраняет дату с часовым поясом |

### SCLState

| Значение | Описание |
|----------|----------|
| `vsDefault` | Обычное поведение (запись/чтение) |
| `vsRequired` | Поле обязательно должно присутствовать при чтении |
| `vsDontWrite` | Поле читается, но не записывается |
| `vsIgnore` | Поле игнорируется полностью |

### Пример с атрибутами

```delphi
type
  TAppConfig = record
    [SCLName('app_name')]
    [SCLComment('Application display name')]
    Name: string;

    [SCLState(vsRequired)]
    Version: Integer;

    [SCLBase(nbHex)]
    Permissions: Int64;

    [SCLString(stText)]
    Description: string;

    [SCLInline]
    [SCLComment('Server endpoints')]
    Servers: TArray<string>;

    [SCLTimeZone]
    CreatedAt: TDateTime;
  end;
```

## Поддерживаемые типы

| Тип Delphi | Преобразование |
|------------|----------------|
| `Integer`, `Int64`, `Word` и др. | Целое число |
| `Double`, `Single`, `Extended`, `Currency` | Число с плавающей точкой |
| `Boolean` | `true` / `false` |
| `String`, `AnsiString`, `WideString`, `ShortString` | Строка |
| `Char`, `WideChar`, `AnsiChar` | Одиночный символ |
| `TDateTime` | Дата/время |
| `Enumeration` | Имя элемента перечисления |
| `Set` | Массив значений |
| `array`, `TArray<T>` | Массив |
| `record` | Таблица |

## Методы

| Метод | Описание |
|-------|----------|
| `Deserialize<T>(Document, out Value, Name)` | Десериализует документ в запись |
| `Serialize<T>(Document, const Value, Name)` | Сериализует запись в документ |
| `Serialize<T>(const Value, Name): TSCLDocument` | Сериализует в новый документ |

## Примеры использования

### Базовый пример

```delphi
type
  TConfig = record
    Host: string;
    Port: Integer;
    Debug: Boolean;
    Timeout: Double;
  end;

var
  Serializer: TSCLSerializer;
  Doc: TSCLDocument;
  Config: TConfig;
begin
  Serializer := TSCLSerializer.Create;
  try
    // Сериализация
    Config.Host := 'localhost';
    Config.Port := 8080;
    Config.Debug := True;
    Config.Timeout := 30.5;
    
    Doc := Serializer.Serialize<TConfig>(Config, 'server');
    // Документ:
    // server:
    //   Host: "localhost"
    //   Port: 8080
    //   Debug: true
    //   Timeout: 30.5
    
    // Десериализация
    Serializer.Deserialize<TConfig>(Doc, Config, 'server');
  finally
    Serializer.Free;
  end;
end;
```

### Вложенные записи

```delphi
type
  TDatabase = record
    Driver: string;
    ConnectionString: string;
    PoolSize: Integer;
  end;

  TAppConfig = record
    Name: string;
    Version: Integer;
    Database: TDatabase;
    [SCLInline]
    Tags: TArray<string>;
  end;

// Сериализация:
// app:
//   Name: "MyApp"
//   Version: 1
//   Database:
//     Driver: "MySQL"
//     ConnectionString: "host=localhost"
//     PoolSize: 10
//   Tags: ["production", "api"]
```

### Перечисления и множества

```delphi
type
  TLogLevel = (llDebug, llInfo, llWarning, llError);
  TPermissions = set of (pRead, pWrite, pExecute, pDelete);

  TConfig = record
    LogLevel: TLogLevel;        // становится строкой
    Permissions: TPermissions;  // становится массивом
  end;

// Результат:
// LogLevel: 'llWarning'
// Permissions: ['pRead', 'pWrite']
```

### Массивы байт и символов

```delphi
type
  TData = record
    [SCLName('raw')]
    BinaryData: TArray<Byte>;   // записывается как %A1B2C3
    Signature: array[0..3] of Char; // записывается как строка
  end;
```

### Использование с файлами

```delphi
var
  Config: TAppConfig;
  Doc: TSCLDocument;
  Serializer: TSCLSerializer;
begin
  Serializer := TSCLSerializer.Create;
  try
    // Чтение из файла
    Doc := TSCLReader.ReadFrom('config.scl');
    Serializer.Deserialize<TAppConfig>(Doc, Config, 'app');
    
    // Изменение и сохранение
    Config.Version := 2;
    Serializer.Serialize<TAppConfig>(Doc, Config, 'app');
    
    TSCLWriter.Create.WriteDocument('config.scl', Doc, TEncoding.UTF8);
  finally
    Serializer.Free;
  end;
end;
```

## Важные замечания

1. **Имена полей** — нечувствительны к регистру
2. **Обязательные поля** — при отсутствии узла с `vsRequired` возникает ошибка
3. **Массивы байт** — автоматически преобразуются в бинарный формат (`%...`)
4. **Дата/время** — по умолчанию локальное время, с `SCLTimeZone` сохраняется смещение
5. **Перечисления** — имена записываются как строки
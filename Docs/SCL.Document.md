# SCL.Document — Документация API

Модуль `SCL.Document` реализует ядро библиотеки **Delphi-SCL** — легковесного формата конфигурации, упрощающего YAML до базовой структуры с заимствованием практичных идей из TOML.

> **Важно:** тип `TSCLNode` — это **record**, на который ссылаются через указатель `PSCLNode`. Прямое копирование значений `TSCLNode` запрещено (перегрузка `Assign` возбуждает исключение). Всегда используйте только ссылки `PSCLNode`.

---

## TSCLDocument

Класс документа. Владеет хранилищем узлов, хэш-таблицей для поиска по именам в таблицах и корневым узлом.

### Конструкторы и деструкторы

| Метод | Описание |
|---|---|
| `constructor Create(Capacity: Integer = 0)` | Создаёт документ. `Capacity` — ожидаемое количество узлов; округляется до степени двойки, минимум `1024`. |
| `destructor Destroy` | Освобождает все хранилища узлов и буфер путей. |

```pascal
var Doc := TSCLDocument.Create;
try
  Doc.Root.AddValue('host', 'localhost');
  Doc.Root.AddValue('port', 8080);
finally
  Doc.Free;
end;
```

### Методы

| Метод | Описание |
|---|---|
| `procedure Clear` | Полностью очищает документ, возвращая его в исходное состояние (пустой корень). |
| `procedure Merge(Source: TSCLDocument)` | Рекурсивно сливает содержимое `Source` в текущий документ. Существующие узлы (по имени) не перезаписываются. Типы корневых узлов должны совпадать (кроме случая пустого корня). |
| `function IsEmpty: Boolean` | `True`, если корневой узел пуст. |

```pascal
var A := TSCLDocument.Create;
var B := TSCLDocument.Create;
try
  A.Root.T['server'].AddValue('host', 'a.local');
  B.Root.T['server'].AddValue('port', 80);
  A.Merge(B); // server/host = a.local, server/port = 80
finally
  A.Free; B.Free;
end;
```

### Свойства

| Свойство | Тип | Описание |
|---|---|---|
| `Root` | `PSCLNode` | Корневой узел документа (read-only). |

---

## TSCLNode

Основной тип представления данных. Record, доступный только по указателю `PSCLNode`. Каждый узел имеет имя, комментарий, тип, подтип (расширенный тип), служебную информацию и значение, а также связи с родителем и соседями.

### Перечисление `TSCLNodeType`

| Значение | Описание |
|---|---|
| `ntEmpty` | Пустой узел (ещё не имеет типа) |
| `ntReserved` | Зарезервированный (служебный, нельзя создать вручную) |
| `ntBinary` | Двоичные данные (`TBytes`) <br> Максимальный размер MAX_BINARY_LENGTH байт, иначе используйте base64 c stWrapped |
| `ntBoolean` | Логическое значение |
| `ntDateTime` | Дата/время |
| `ntFloat` | Число с плавающей точкой |
| `ntInteger` | Целое число |
| `ntNull` | Null (`~`) |
| `ntString` | Строка |
| `ntArray` | Массив |
| `ntTable` | Таблица (словарь) |

---

### Создание дочерних узлов

| Метод | Описание |
|---|---|
| `function AddNode(const AName: string; AType: TSCLNodeType): PSCLNode` | Добавляет дочерний узел заданного типа. |
| `function AddArray(const AName: string; AsInline: Boolean = False): PSCLNode` | Добавляет массив. `AsInline` — строчный (inline) массив. |
| `function AddTable(const AName: string; AsInline: Boolean = False): PSCLNode` | Добавляет таблицу. `AsInline` — строчная (inline) таблица. |

```pascal
var Root := Doc.Root;
var Arr := Root.AddArray('items');
Arr.AddValue('', 1);   // элементы массива не имеют имён
Arr.AddValue('', 2);

var Tbl := Root.AddTable('server');
Tbl.AddValue('host', 'localhost');
```

---

### Добавление значений

| Перегрузка | Описание |
|---|---|
| `AddValue(const AName: string; const Value: Boolean)` | Логическое значение. |
| `AddValue(const AName: string; const Value: string; &Type: TSCLStringType = stDefault)` | Строка с указанием типа строки. |
| `AddValue(const AName: string; const Value: Int64; Base: TSCLNumberBase = nbDefault)` | Целое с указанием системы счисления. |
| `AddValue(const AName: string; const Value: Double; APrecision: TSCLPrecision = 16)` | Вещественное с указанием точности. |
| `AddValue(const AName: string; const Value: TBytes)` | Двоичные данные. |
| `AddValue(const AName: string; const Value: TDateTime; AOffset: SmallInt = 0)` | Дата/время со смещением часового пояса в минутах (`0` — UTC, `-1` — локальное). |

```pascal
Tbl.AddValue('enabled', True);
Tbl.AddValue('timeout', Int64(30));
Tbl.AddValue('ratio', 0.75);
Tbl.AddValue('started', Now, TIME_OFFSET_LOCAL);
Tbl.AddValue('blob', TBytes.Create(1, 2, 3));
```

---

### Присваивание значений (для существующих узлов)

| Метод | Описание |
|---|---|
| `procedure SetValue(const Value: Boolean)` | Устанавливает логическое значение. |
| `procedure SetValue(const Value: Double; APrecision: TSCLPrecision = 16)` | Вещественное. |
| `procedure SetValue(const Value: Int64; Base: TSCLNumberBase = nbDefault)` | Целое. |
| `procedure SetValue(const Value: TBytes)` | Двоичные данные. |
| `procedure SetValue(const Value: TDateTime; AOffset: SmallInt = 0)` | Дата/время. |
| `procedure SetValue(const Value: string; &Type: TSCLStringType = stDefault)` | Строка. |
| `procedure SetNullValue` | Преобразует узел в Null. |

```pascal
var Node := Tbl['host'];
Node.SetValue('example.com');
Node.SetNullValue;
```

---

### Преобразования и извлечение значений

| Метод / свойство | Описание |
|---|---|
| `function ToFloat: Double` | Преобразует значение к `Double` (работает с Integer, Float, String). |
| `function ToInteger: Int64` | Преобразует к `Int64` (Integer, Float, String). |
| `function ToString: string` | Преобразует к строке (не работает с массивом/таблицей). Для даты форматирует ISO-подобно, для чисел — с учётом системы счисления, для двоичных — hex с префиксом `%`. |
| `function ToArray: TArray<PSCLNode>` | Возвращает дочерние узлы массивом. |

```pascal
var N := Doc.Root['port'];
var Port := N.ToInteger;
var AsText := N.ToString; // '8080'
```

---

### Работа с узлами

| Метод | Описание |
|---|---|
| `function ForceType(RequiredType: TSCLNodeType): Boolean` | Преобразует тип пустого узла к заданному. Возвращает `True`, если тип был изменён. Бросает исключение, если узел уже имеет другой тип. |
| `procedure MakeParent(AsTable, AsInline: Boolean)` | Преобразует пустой узел в массив или таблицу (с флагом inline). |
| `procedure MergeNodes(Source: PSCLNode)` | Добавляет дерево узлов из `Source`, игнорируя существующие по имени. |
| `procedure RemoveNode(Node: PSCLNode)` | Удаляет дочерний узел (с поддеревом). |
| `function ItemByPath(const NodePath: string): PSCLNode` | Возвращает узел по пути вида `table/array/@3/key`. |
| `function GetEnumerator: TArrayEnumerator` | Итератор по дочерним узлам (поддержка `for..in`). |

```pascal
for var Item in Doc.Root['items'] do
  Writeln(Item.ToString);

var Host := Doc.Root.ItemByPath('server/host');
```

---

### Свойства

| Свойство | Тип | Описание |
|---|---|---|
| `Name` | `string` | Имя узла (read-only). |
| `Comment` | `string` | Комментарий к узлу. |
| `Path` | `string` | Путь от корня (например, `/server/@0/host`). |
| `Precision` | `TSCLPrecision` | Точность числа с плавающей точкой. |
| `NumberBase` | `TSCLNumberBase` | Система счисления целого числа. |
| `StringType` | `TSCLStringType` | Тип строки. |
| `TimeOffset` | `SmallInt` | Смещение времени (минуты), `-1` — локальное. |
| `NodeType` | `TSCLNodeType` | Тип узла (read-only). |
| `Parent` | `PSCLNode` | Родительский узел (`nil` для корня и Null). |
| `PrevSibling` | `PSCLNode` | Предыдущий узел в контейнере (read-only). |
| `NextSibling` | `PSCLNode` | Следующий узел в контейнере (read-only). |
| `FirstChild` | `PSCLNode` | Первый дочерний узел (read-only). |
| `LastChild` | `PSCLNode` | Последний дочерний узел (read-only). |
| `Count` | `Integer` | Количество дочерних узлов. |
| `ItemIndex` | `Integer` | Порядковый номер узла у родителя. |
| `Items[const AName: string]` | `PSCLNode` | Дочерний узел по имени (default-свойство). `nil`, если не найден. |

```pascal
var Tbl := Doc.Root['server'];
Writeln(Tbl.Count);
Writeln(Tbl['host'].ToString);
Writeln(Tbl['host'].Path);
```

---

### Индексированные аксессоры (get-or-add)

Эти свойства возвращают дочерний узел указанного типа по имени, а при отсутствии — **создают** его:

| Свойство | Тип узла |
|---|---|
| `A[const AName: string]` | `ntArray` |
| `B[const AName: string]` | `ntBoolean` |
| `D[const AName: string]` | `ntDateTime` |
| `F[const AName: string]` | `ntFloat` |
| `I[const AName: string]` | `ntInteger` |
| `O[const AName: string]` | `ntBinary` (Octet string) |
| `S[const AName: string]` | `ntString` |
| `T[const AName: string]` | `ntTable` |

```pascal
Doc.Root.T['server'].S['host'].SetValue('localhost');
Doc.Root.T['server'].I['port'].SetValue(8080);
Doc.Root.A['items'].AddValue('', 42);
```

---

### Типизированные свойства-значения

| Свойство | Тип | Описание |
|---|---|---|
| `VBoolean` | `Boolean` | Логическое значение. |
| `VBytes` | `TBytes` | Двоичные данные. |
| `VDateTime` | `TDateTime` | Дата/время. |
| `VDouble` | `Double` | Вещественное. |
| `VInteger` | `Int64` | Целое. |
| `VString` | `string` | Строка. |

```pascal
Doc.Root.S['name'].VString := 'SCL';
Doc.Root.I['version'].VInteger := 1;
Writeln(Doc.Root.F['ratio'].VDouble);
```

---

### Проверки состояния

| Метод | Описание |
|---|---|
| `function IsEmpty: Boolean` | `True` для `ntEmpty` или для пустого массива/таблицы. |
| `function IsInline: Boolean` | `True` для строчных (inline) массивов и таблиц. |
| `function IsFirst: Boolean` | `True`, если узел первый у родителя. |
| `function IsLast: Boolean` | `True`, если узел последний у родителя. |
| `function IsRoot: Boolean` | `True`, если узел — корень документа. |

```pascal
if Doc.Root.T['items'].IsEmpty then
  Writeln('items пуст');

if Doc.Root.IsRoot then
  Writeln('это корень');
```

---

### Операторы

| Оператор | Описание |
|---|---|
| `class operator Finalize(var Instance: TSCLNode)` | Освобождает ресурсы строк и двоичных данных при финализации. |
| `class operator Assign(var Dest: TSCLNode; const [ref] Src: TSCLNode)` | **Запрещён** — возбуждает исключение. Копирование значений `TSCLNode` недопустимо. |

---

## Константы и строковые ресурсы

| Идентификатор | Значение / Назначение |
|---|---|
| `MAX_BINARY_LENGTH` | `64` - максимальная длина двоичных данных (ntBinary) |
| `TIME_OFFSET_LOCAL` | `-1` — смещение для локальных дат. |
| `SCLTypeNames` | Массив имён типов `TSCLNodeType` (локализуемые). |

---

## Полный пример

```pascal
uses
  System.SysUtils, SCL.Document, SCL.Types;

var Doc := TSCLDocument.Create;
try
  // Таблица server
  var Server := Doc.Root.T['server'];
  Server.S['host'].SetValue('localhost');
  Server.I['port'].SetValue(8080);
  Server.B['enabled'].SetValue(True);
  Server.F['ratio'].SetValue(0.75);
  Server.D['started'].SetValue(Now, TIME_OFFSET_LOCAL);

  // Массив items с элементами
  var Items := Doc.Root.A['items'];
  for var Index := 1 to 3 do
    Items.AddValue('', Index * 10);

  // Чтение
  Writeln(Doc.Root.ItemByPath('server/host').VString); // localhost
  Writeln(Doc.Root['server']['port'].ToInteger);        // 8080

  for var Item in Doc.Root['items'] do
    Writeln(Item.Path, ' = ', Item.ToString);           // /items/@0 = 10 ...

  // Слияние
  var Extra := TSCLDocument.Create;
  try
    Extra.Root.T['server'].S['host'].SetValue('ignored');
    Extra.Root.T['server'].I['timeout'].SetValue(30);
    Doc.Merge(Extra); // host не перезапишется, timeout добавится
  finally
    Extra.Free;
  end;
finally
  Doc.Free;
end;
```

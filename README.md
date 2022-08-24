参考 https://github.com/deCardenas/json_config_generator

json 文件创建配置类的生成器

## 安装

```yaml
dependencies:
  default_config_annotation: ^0.0.2

dev_dependencies:
  build_runner:
  default_config_generator: ^0.1.0
```

## 使用

创建一个空配置类

```dart
import 'package:default_config_annotation/default_config_annotation.dart';

part 'default_config.g.dart'; //{dart file name}.g.dart

@DefaultConfig(path: 'assets/config/dev.json')
class $DefaultConfig {}
```

JSON文件 dev.json

```json
{
  "base_url": "https://example.com",
  "custom_class": {
    "value_1": "we324523b252dghfdhd",
    "value_2": "3c252bv66b7yn5m8m6"
  },
  "int_value": 3,
  "double_value": 3.5,
  "boolean_value": true,
  "string_list": ["hello", "world"],
  "int_list": [1, 23, 5],
  "bool_list": [false, true, true]
}
```

## 运行命令

```
flutter pub run build_runner build
```


生成器创建文件

default_config.g.dart

```dart
class DefaultSetting {
  static const String baseUrl = "https://example.com";

  static const customClass = _CustomClass();

  static const int intValue = 3;

  static const double doubleValue = 3.5;

  static const bool booleanValue = true;

  static const List<String> stringList = ["hello", "world"];

  static const List<int> intList = [1, 23, 5];

  static const List<bool> boolList = [false, true, true];
}

class _CustomClass {
  const _CustomClass();

  final String value1 = "we324523b252dghfdhd";

  final String value2 = "3c252bv66b7yn5m8m6";
}
```

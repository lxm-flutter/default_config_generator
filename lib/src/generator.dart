import 'dart:io';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:built_collection/src/list.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:default_config_annotation/default_config_annotation.dart';
import 'package:json5/json5.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

import 'utils.dart';

class DefaultConfigGenerator extends GeneratorForAnnotation<DefaultConfig> {
  const DefaultConfigGenerator();

  @override
  generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    throwIf(
        !element.displayName.startsWith('\$'), 'class name must start with \$',
        element: element);
    final className = element.displayName.replaceAll('\$', '');
    var path = annotation.read('path').stringValue;
    throwIf(path.isEmpty, 'path could not be empty', element: element);
    checkPath(path, element);
    final Map<String, dynamic> config = await getConfigMap(path);
    var hasComment = annotation.read('hasComment').boolValue;
    Map<String, List<String>> commentMap = const {};
    if (hasComment) {
      commentMap = await comment(path);
    }
    return mainClassGenerator(className, config,
        configFile: path, commentMap: commentMap);
  }

  /// 读取JSON文件
  Future<Map<String, dynamic>> getConfigMap(String path) async {
    final jsonString = await File(path).readAsString();
    throwIf(jsonString.isEmpty, 'file in path "$path" could not be empty');
    Map<String, dynamic> map = JSON5.parse(jsonString);
    throwIf(map.isEmpty, 'file in path "$path" do not have fields');
    return map;
  }

  String mainClassGenerator(String name, Map<String, dynamic> config,
      {String? configFile, Map<String, List<String>> commentMap = const {}}) {
    var toRemove = [];
    String subClasses = '';
    config.forEach((key, value) {
      final type = getType(key, value).fieldType;
      if (value is Map) {
        subClasses += subClassesGenerator(key, value, commentMap: commentMap);
      } else if (type == 'List<_${key.pascalCase}>') {
        toRemove.add(key);
      }
    });
    config.removeWhere((key, value) => toRemove.contains(key));
    final mainClass = Class((c) => c
      ..name = name
      ..fields.addAll([
        ...config
            .map((key, value) {
              var builder = ListBuilder<String>();
              var comment = commentMap[key];
              if (comment != null && comment.length > 0) {
                builder.addAll(comment.map((e) => "/// $e").toList());
              }
              return MapEntry(
                key,
                Field((f) => f
                  ..name = key.camelCase
                  ..docs = builder
                  ..static = true
                  ..modifier = FieldModifier.constant
                  ..type = getType(key, value).type
                  ..assignment = Code(getType(key, value).val)),
              );
            })
            .values
            .toList()
      ]));
    return stringConverter(mainClass) + subClasses;
  }

  String subClassesGenerator(String name, dynamic values,
      {Map<String, List<String>> commentMap = const {}}) {
    Map<String, dynamic> data;
    String subClasses = '';
    if (getType(name, values).fieldType == 'List<_${name.pascalCase}>') {
      data = (values as List).first;
    } else if (values is Map<String, dynamic>) {
      data = values;
    } else {
      return '';
    }
    var toRemove = [];
    data.forEach((key, value) {
      final type = getType(key, value).fieldType;
      if (value is Map) {
        subClasses += subClassesGenerator(key, value, commentMap: commentMap);
      } else if (type == 'List<_${key.pascalCase}>') {
        toRemove.add(key);
      }
    });
    data.removeWhere((key, value) => toRemove.contains(key));
    final subclass = Class((c) => c
      ..name = '_${name.pascalCase}'
      ..fields.addAll(data
          .map((key, value) {
            var builder = ListBuilder<String>();
            var comment = commentMap[key];
            if (comment != null && comment.length > 0) {
              builder.addAll(comment.map((e) => "/// $e").toList());
            }
            return MapEntry(
              key,
              Field((FieldBuilder f) => f
                ..name = key.camelCase
                ..docs = builder
                ..type = getType(key, value).type
                ..modifier = FieldModifier.final$
                ..assignment = Code(getType(key, value).val)),
            );
          })
          .values
          .toList())
      ..constructors.addAll([Constructor((c) => c..constant = true)]));
    return stringConverter(subclass) + subClasses;
  }

  FieldInfo getType(String key, dynamic value) {
    if (value is String)
      return FieldInfo(fieldType: 'String', value: value);
    else if (value is bool)
      return FieldInfo(fieldType: 'bool', value: value);
    else if (value is int)
      return FieldInfo(fieldType: 'int', value: value);
    else if (value is double)
      return FieldInfo(fieldType: 'double', value: value);
    else if (value is List) {
      return FieldInfo(
          fieldType: 'List<${getType(key, value.first).fieldType}>',
          value: value);
    } else
      return FieldInfo(
          fieldType: '_${key.pascalCase}', value: value, isClass: true);
  }

  void checkPath(String path, Element element) {
    throwIf(path.trim().isEmpty, 'path could not be empty', element: element);
    final fileName = path.split('/').last;
    throwIf(!fileName.contains('.json'),
        'environment file "$fileName" must have extension ".json"',
        element: element);
  }

  String stringConverter(Spec obj) {
    final emitter = DartEmitter(useNullSafetySyntax: true);
    return DartFormatter().format(obj.accept(emitter).toString());
  }

  /// 注释
  Future<Map<String, List<String>>> comment(String path,
      {String symbol = "//"}) async {
    var list = await File(path).readAsLines();
    Map<String, List<String>> comment = {};
    List<String> temp = [];
    for (int i = 0; i < list.length; i++) {
      // 注释符开头
      if (list[i].trim().startsWith(symbol)) {
        temp.add(list[i].replaceAll(symbol, '').trim());
        continue;
      }

      // 末尾注释

      // 匹配字符串值存在 [symbol] 的情况
      var endComment = getEndComment(list[i]);
      if (endComment != null && endComment.isNotEmpty) {
        temp.add(endComment);
      }
      if (temp.isNotEmpty) {
        var split = list[i].split(':');
        if (split.length > 1) {
          var key = split.first.replaceAll('"', "").trim();
          comment[key] = temp.sublist(0);
          temp.clear();
        }
      }
    }
    return comment;
  }
}

class FieldInfo {
  late String fieldType;

  late dynamic value;

  late bool isClass;

  FieldInfo(
      {required this.fieldType, required this.value, this.isClass = false});

  bool get isStringType => const ['String', 'String?'].contains(fieldType);

  String get val {
    if (isClass) {
      return '${fieldType}()';
    }
    if (value is List && value.first is String) {
      var list = value as List;
      var join = list.map((e) => '"$e"').toList().join(",");
      return "[${join}]";
    }
    return isStringType ? '"$value"' : '$value';
  }

  Reference? get type => isClass ? null : refer(fieldType);
}

String? getEndComment(String str, {String symbol = "//"}) {
  var regExp = RegExp(r':\s*".*"');
  if (regExp.hasMatch(str)) {
    str = str.replaceFirst(regExp, '');
  }
  var match = RegExp('$symbol(.*)').firstMatch(str);
  return match?.group(1)?.trim();
}

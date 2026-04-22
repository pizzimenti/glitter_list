import 'todo_item.dart';

class TodoList {
  TodoList({required this.id, required this.name, List<TodoItem>? items})
      : items = items ?? [];

  final String id;
  String name;
  List<TodoItem> items;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'items': items.map((e) => e.toMap()).toList(),
      };

  factory TodoList.fromMap(Map<dynamic, dynamic> map) => TodoList(
        id: map['id'] as String,
        name: map['name'] as String,
        items: ((map['items'] as List?) ?? const [])
            .map((e) => TodoItem.fromMap(e as Map))
            .toList(),
      );
}

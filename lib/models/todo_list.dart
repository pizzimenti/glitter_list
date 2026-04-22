import 'todo_item.dart';

class TodoList {
  const TodoList({
    required this.id,
    required this.name,
    this.items = const [],
  });

  final String id;
  final String name;
  final List<TodoItem> items;

  TodoList copyWith({String? name, List<TodoItem>? items}) => TodoList(
        id: id,
        name: name ?? this.name,
        items: items ?? this.items,
      );

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

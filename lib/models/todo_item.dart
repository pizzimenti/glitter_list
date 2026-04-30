class TodoItem {
  const TodoItem({
    required this.id,
    required this.text,
    this.done = false,
    this.glittered = false,
  });

  final String id;
  final String text;
  final bool done;
  final bool glittered;

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'done': done,
        'glittered': glittered,
      };

  factory TodoItem.fromMap(Map<dynamic, dynamic> map) => TodoItem(
        id: map['id'] as String,
        text: map['text'] as String,
        done: map['done'] as bool? ?? false,
        glittered: map['glittered'] as bool? ?? false,
      );

  TodoItem copyWith({String? text, bool? done, bool? glittered}) => TodoItem(
        id: id,
        text: text ?? this.text,
        done: done ?? this.done,
        glittered: glittered ?? this.glittered,
      );
}

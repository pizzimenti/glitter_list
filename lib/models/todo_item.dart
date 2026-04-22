class TodoItem {
  TodoItem({required this.id, required this.text, this.done = false});

  final String id;
  String text;
  bool done;

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'done': done,
      };

  factory TodoItem.fromMap(Map<dynamic, dynamic> map) => TodoItem(
        id: map['id'] as String,
        text: map['text'] as String,
        done: map['done'] as bool? ?? false,
      );

  TodoItem copyWith({String? text, bool? done}) => TodoItem(
        id: id,
        text: text ?? this.text,
        done: done ?? this.done,
      );
}

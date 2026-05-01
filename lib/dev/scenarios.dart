import '../models/todo_item.dart';
import '../models/todo_list.dart';
import '../state/app_state.dart';

/// Named seed states for tests and the `tool/qa_main.dart` runner.
///
/// Single source of truth so an integration test exercising
/// `mixedDoneGlittered` and a Claude-driven QA session launching
/// `--dart-define=SCENARIO=mixedDoneGlittered` are looking at the
/// same data.
///
/// Item ids are stable and globally unique (`L<n>-i<n>`) so
/// `ReorderableListView`'s key-uniqueness check is satisfied across
/// scenarios that mix multiple lists.
class Scenarios {
  Scenarios._();

  static const String defaultName = 'mixedDoneGlittered';

  /// All scenario names, in the order they're exposed to the QA runner.
  static const List<String> names = [
    'empty',
    'singleListShort',
    'mixedDoneGlittered',
    'longList50',
    'multiList3',
    'glitteredEndState',
    'longTitle',
    'singleListEmpty',
  ];

  /// Resolve a scenario by name, or null if unknown. Used by the QA
  /// runner to map `--dart-define=SCENARIO=<name>` to an `AppState`.
  static AppState? byName(String name) => switch (name) {
        'empty' => empty(),
        'singleListShort' => singleListShort(),
        'mixedDoneGlittered' => mixedDoneGlittered(),
        'longList50' => longList50(),
        'multiList3' => multiList3(),
        'glitteredEndState' => glitteredEndState(),
        'longTitle' => longTitle(),
        'singleListEmpty' => singleListEmpty(),
        _ => null,
      };

  /// Zero lists. Exercises the empty-app surface (no current list,
  /// no FAB, "No lists" body).
  static AppState empty() =>
      const AppState(lists: [], currentListIndex: 0);

  /// One list, three plain items. The default seed for tests that need
  /// a few items to operate on without any pre-set state flags.
  static AppState singleListShort() => const AppState(
        lists: [
          TodoList(id: 'L1', name: 'Today', items: [
            TodoItem(id: 'L1-i0', text: 'Buy oat milk'),
            TodoItem(id: 'L1-i1', text: 'Pilates 5pm'),
            TodoItem(id: 'L1-i2', text: 'Call grandma'),
          ]),
        ],
        currentListIndex: 0,
      );

  /// One list with every state combination represented: plain, done,
  /// glittered, done+glittered, plus a long item that wraps. The visual
  /// QA scenario — every paint path is on screen at once.
  static AppState mixedDoneGlittered() => const AppState(
        lists: [
          TodoList(id: 'L1', name: 'Mix', items: [
            TodoItem(id: 'L1-i0', text: 'Plain item'),
            TodoItem(id: 'L1-i1', text: 'Done item', done: true),
            TodoItem(id: 'L1-i2', text: 'Glittered item', glittered: true),
            TodoItem(
              id: 'L1-i3',
              text: 'Done and glittered',
              done: true,
              glittered: true,
            ),
            TodoItem(
              id: 'L1-i4',
              text: 'A longer item that probably wraps onto two lines',
            ),
          ]),
        ],
        currentListIndex: 0,
      );

  /// One list, fifty items. Exercises the scroll path and the
  /// `_ScrollIndicator` thumb.
  static AppState longList50() => AppState(
        lists: [
          TodoList(
            id: 'L1',
            name: 'Long list',
            items: List<TodoItem>.generate(
              50,
              (i) => TodoItem(id: 'L1-i$i', text: 'Item $i'),
            ),
          ),
        ],
        currentListIndex: 0,
      );

  /// Three lists with mixed sizes — exercises page-dot rendering,
  /// horizontal swipe between lists, and the empty-state hero on the
  /// third list.
  static AppState multiList3() => const AppState(
        lists: [
          TodoList(id: 'L1', name: 'Today', items: [
            TodoItem(id: 'L1-i0', text: 'Pilates'),
            TodoItem(id: 'L1-i1', text: 'Coffee with Jess'),
          ]),
          TodoList(id: 'L2', name: 'Wishlist', items: [
            TodoItem(id: 'L2-i0', text: 'Linen dress'),
            TodoItem(
              id: 'L2-i1',
              text: 'Birkenstock Bostons',
              glittered: true,
            ),
            TodoItem(id: 'L2-i2', text: 'Silk pillowcase', done: true),
          ]),
          TodoList(id: 'L3', name: 'Empty', items: []),
        ],
        currentListIndex: 0,
      );

  /// Single list, single item with `glittered: true` so
  /// [GlitterOutline]'s `_ctrl` is at value=1.0 on the first frame.
  /// Used by the glitter-outline golden — captures the squiggle at its
  /// stable end-state with no animation in flight.
  static AppState glitteredEndState() => const AppState(
        lists: [
          TodoList(id: 'L1', name: 'Glitter', items: [
            TodoItem(
              id: 'L1-i0',
              text: 'Sparkle this one',
              glittered: true,
            ),
          ]),
        ],
        currentListIndex: 0,
      );

  /// Single list, zero items. Triggers the per-list empty-state hero
  /// in `ListPage` (caticorn image + "Empty list. Tap + to add an
  /// item." line). Distinct from [empty] which produces zero lists
  /// and the home-page "No lists" fallback.
  static AppState singleListEmpty() => const AppState(
        lists: [
          TodoList(id: 'L1', name: 'Today', items: []),
        ],
        currentListIndex: 0,
      );

  /// Single list with a deliberately long name that wraps to 2-3
  /// lines in the AppBar, plus a couple of items. Used by the AppBar
  /// title golden — exercises the AppBar's frosted-strip path
  /// (ungrouped, separate from the per-tile strips).
  static AppState longTitle() => const AppState(
        lists: [
          TodoList(
            id: 'L1',
            name: 'A Really Long List Title That Definitely Wraps Onto Multiple Lines',
            items: [
              TodoItem(id: 'L1-i0', text: 'Just one item'),
              TodoItem(id: 'L1-i1', text: 'And another'),
            ],
          ),
        ],
        currentListIndex: 0,
      );
}

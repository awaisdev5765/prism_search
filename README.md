# prism_search

Adaptive search for Flutter — an inline field with dropdown suggestions on
desktop/tablet, and a full-screen search page on phones. Debounced async
backends, match highlighting, and zero configuration.

Part of the **Prism** package family.

## Features

- ✅ Adaptive — full-screen search on phones, inline field + dropdown on
  desktop/tablet (Material 3 breakpoints via `prism_adaptive_scaffold`)
- ✅ Works with a local list or an async backend
- ✅ Debounced queries — stale responses automatically discarded
- ✅ Match highlighting (custom color/bold)
- ✅ `maxSuggestions` cap, custom field decoration, hint text
- ✅ Pure Flutter, all six platforms

## Installation

```yaml
dependencies:
  prism_search: ^0.1.0
```

## Quick start

```dart
PrismSearch<String>(
  items: ['Dart', 'Flutter', 'Firebase'],
  itemLabel: (item) => item,
  onSelected: (item) => print('picked $item'),
)
```

Drop it anywhere in your tree. On phones, tapping the field opens a
full-screen search page; on wider windows, suggestions drop down beneath the
field.

## Async backend

```dart
PrismSearch<Book>(
  onSearch: (query) => api.searchBooks(query),
  itemLabel: (book) => book.title,
  debounce: const Duration(milliseconds: 300),
)
```

Rapid keystrokes are debounced, and slower earlier responses are ignored so
the UI never shows stale results.

## Highlighting

```dart
PrismSearch<String>(
  items: tags,
  itemLabel: (t) => t,
  highlightStyle: const PrismSearchHighlightStyle(color: Colors.deepPurple),
)
```

## The Prism package family

| Package | What it does |
| --- | --- |
| [prism_markdown](https://pub.dev/packages/prism_markdown) | Markdown widget with full CommonMark + GFM support |
| [prism_code_view](https://pub.dev/packages/prism_code_view) | Syntax-highlighted code viewer (Dart/JSON/YAML built in) |
| [prism_adaptive_scaffold](https://pub.dev/packages/prism_adaptive_scaffold) | Responsive scaffolds: bottom bar → rail → extended rail |
| [prism_adaptive_dialog](https://pub.dev/packages/prism_adaptive_dialog) | Dialogs that become bottom sheets on phones |
| [prism_state_views](https://pub.dev/packages/prism_state_views) | Empty, loading, error, and success states from one widget |
| [prism_master_detail](https://pub.dev/packages/prism_master_detail) | Adaptive master-detail layouts |
| [prism_banner](https://pub.dev/packages/prism_banner) | Dismissible announcement banners |
| **prism_search** | Adaptive search with suggestions |

All pure Flutter, all six platforms, MIT licensed, built to work together.

## License

MIT — see [LICENSE](LICENSE).
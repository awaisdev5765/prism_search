import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prism_adaptive_scaffold/prism_adaptive_scaffold.dart';

import 'highlight.dart';

List<T> _searchLocal<T>(PrismSearch<T> w, String query) {
  final lower = query.toLowerCase();
  return [
    for (final item in w.items!)
      if (w.itemLabel(item).toLowerCase().contains(lower)) item,
  ].take(w.maxSuggestions).toList();
}

/// An adaptive search widget.
///
/// - **Compact windows** (< 600px): tapping the field opens a full-screen
///   search page — the pattern phone users expect.
/// - **Medium+ windows**: the field stays inline and suggestions drop down
///   beneath it.
///
/// Provide either a local [items] list or an async [onSearch] backend.
///
/// ```dart
/// PrismSearch<String>(
///   items: ['Dart', 'Flutter', 'Firebase'],
///   itemLabel: (item) => item,
///   onSelected: (item) => print('picked $item'),
/// )
/// ```
class PrismSearch<T> extends StatefulWidget {
  /// Creates an adaptive search.
  const PrismSearch({
    super.key,
    this.items,
    this.onSearch,
    required this.itemLabel,
    this.onSelected,
    this.hintText = 'Search…',
    this.debounce = const Duration(milliseconds: 250),
    this.maxSuggestions = 8,
    this.highlightStyle,
    this.fieldDecoration,
    this.debugCompactOverride = false,
  }) : assert(
         (items != null) != (onSearch != null),
         'Provide exactly one of items or onSearch.',
       );

  /// Local dataset searched in memory. Mutually exclusive with [onSearch].
  final List<T>? items;

  /// Async backend invoked (debounced) with the raw query.
  /// Mutually exclusive with [items].
  final Future<List<T>> Function(String query)? onSearch;

  /// Renders the display string for a result item.
  final String Function(T item) itemLabel;

  /// Invoked when the user picks a suggestion.
  final ValueChanged<T>? onSelected;

  /// Hint shown in the empty field.
  final String hintText;

  /// Delay before [onSearch] fires while the user types.
  final Duration debounce;

  /// Maximum number of suggestions shown at once.
  final int maxSuggestions;

  /// Styling for the matched substring in suggestions.
  final PrismSearchHighlightStyle? highlightStyle;

  /// Optional [InputDecoration] override for the search field.
  final InputDecoration? fieldDecoration;

  /// Forces compact behavior (full-screen page) even on wide windows —
  /// useful for previews and tests. Do not use in production code.
  final bool debugCompactOverride;

  @override
  State<PrismSearch<T>> createState() => _PrismSearchState<T>();
}

class _PrismSearchState<T> extends State<PrismSearch<T>> {
  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenSearch<T>(widget: widget),
      ),
    );
  }

  InputDecoration _decoration({IconData? icon}) =>
      widget.fieldDecoration ??
      InputDecoration(
        hintText: widget.hintText,
        prefixIcon: icon == null ? null : Icon(icon),
        isDense: true,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final isCompact =
        widget.debugCompactOverride ||
        PrismBreakpoint.resolve(MediaQuery.sizeOf(context).width) ==
            PrismBreakpoint.compact;

    if (isCompact) {
      return TextField(
        readOnly: true,
        showCursor: false,
        decoration: _decoration(icon: Icons.search),
        onTap: _openFullScreen,
      );
    }

    return _InlineSearch<T>(widget: widget, decoration: _decoration());
  }
}

/// Medium+ mode: inline field with a dropdown suggestion overlay.
class _InlineSearch<T> extends StatefulWidget {
  const _InlineSearch({required this.widget, required this.decoration});

  final PrismSearch<T> widget;
  final InputDecoration decoration;

  @override
  State<_InlineSearch<T>> createState() => _InlineSearchState<T>();
}

class _InlineSearchState<T> extends State<_InlineSearch<T>> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  Timer? _debounce;
  List<T> _results = const [];
  bool _loading = false;
  String _lastQuery = '';

  bool get _useAsyncBackend => widget.widget.onSearch != null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _refresh(_controller.text);
    } else {
      _removeOverlay();
    }
  }

  void _onChanged() {
    if (!_useAsyncBackend) {
      _refresh(_controller.text);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(widget.widget.debounce, () => _refresh(_controller.text));
  }

  Future<void> _refresh(String query) async {
    final trimmed = query.trim();
    _lastQuery = trimmed;
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    if (_useAsyncBackend) {
      if (!mounted) return;
      setState(() => _loading = true);
      final results = await widget.widget.onSearch!(trimmed);
      if (!mounted || _lastQuery != trimmed) return;
      setState(() {
        _results = results.take(widget.widget.maxSuggestions).toList();
        _loading = false;
      });
    } else {
      final results = _searchLocal(widget.widget, trimmed);
      if (!mounted) return;
      setState(() => _results = results);
    }
    _showOverlay();
  }

  void _select(T item) {
    _removeOverlay();
    _focusNode.unfocus();
    widget.widget.onSelected?.call(item);
  }

  void _showOverlay() {
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    _overlay = OverlayEntry(
      builder: (_) => _SuggestionsOverlay<T>(link: _layerLink, state: this),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: widget.decoration,
      ),
    );
  }
}

/// Dropdown overlay anchored to the search field (medium+ windows).
class _SuggestionsOverlay<T> extends StatelessWidget {
  const _SuggestionsOverlay({required this.link, required this.state});

  final LayerLink link;
  final _InlineSearchState<T> state;

  @override
  Widget build(BuildContext context) {
    final results = state._results;
    final loading = state._loading;
    final query = state._controller.text.trim();
    final style = DefaultTextStyle.of(context).style;
    final w = state.widget.widget;

    Widget body;
    if (loading) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (results.isEmpty) {
      return const SizedBox.shrink();
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in results)
            InkWell(
              onTap: () => state._select(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text.rich(
                  highlightQuery(
                    w.itemLabel(item),
                    query,
                    style,
                    w.highlightStyle,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Stack(
      children: [
        // Dismiss suggestions on outside tap.
        ModalBarrier(
          dismissible: true,
          onDismiss: () => state._removeOverlay(),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          showWhenUnlinked: false,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(child: IntrinsicWidth(child: body)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact mode: full-screen search page with a results list.
class _FullScreenSearch<T> extends StatefulWidget {
  const _FullScreenSearch({required this.widget});

  final PrismSearch<T> widget;

  @override
  State<_FullScreenSearch<T>> createState() => _FullScreenSearchState<T>();
}

class _FullScreenSearchState<T> extends State<_FullScreenSearch<T>> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<T> _results = const [];
  bool _loading = false;
  String _lastQuery = '';

  bool get _useAsyncBackend => widget.widget.onSearch != null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!_useAsyncBackend) {
      _refresh(_controller.text);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(widget.widget.debounce, () => _refresh(_controller.text));
  }

  Future<void> _refresh(String query) async {
    final trimmed = query.trim();
    _lastQuery = trimmed;
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    if (_useAsyncBackend) {
      if (!mounted) return;
      setState(() => _loading = true);
      final results = await widget.widget.onSearch!(trimmed);
      if (!mounted || _lastQuery != trimmed) return;
      setState(() {
        _results = results.take(widget.widget.maxSuggestions).toList();
        _loading = false;
      });
    } else {
      final results = _searchLocal(widget.widget, trimmed);
      if (!mounted) return;
      setState(() => _results = results);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.widget;
    final style = DefaultTextStyle.of(context).style;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: w.hintText,
            border: InputBorder.none,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : ListView(
              children: [
                for (final item in _results)
                  ListTile(
                    title: Text.rich(
                      highlightQuery(
                        w.itemLabel(item),
                        _controller.text.trim(),
                        style,
                        w.highlightStyle,
                      ),
                    ),
                    onTap: () {
                      w.onSelected?.call(item);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
    );
  }
}

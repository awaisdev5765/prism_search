import 'package:flutter/material.dart';

/// How matched text is emphasized inside suggestion rows.
@immutable
class PrismSearchHighlightStyle {
  /// Creates a highlight style.
  const PrismSearchHighlightStyle({this.color, this.bold = true});

  /// Color applied to the matched substring; defaults to
  /// [ColorScheme.primary].
  final Color? color;

  /// Whether the matched substring is also rendered bold.
  final bool bold;
}

/// Splits [label] into plain/highlighted segments around every
/// case-insensitive occurrence of [query].
///
/// Returns the full [TextSpan] for a suggestion row; when [query] is empty
/// or not found, a single plain span is returned.
TextSpan highlightQuery(
  String label,
  String query,
  TextStyle baseStyle,
  PrismSearchHighlightStyle? highlightStyle,
) {
  if (query.isEmpty) return TextSpan(text: label, style: baseStyle);
  final lowerLabel = label.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final start = lowerLabel.indexOf(lowerQuery);
  if (start < 0) return TextSpan(text: label, style: baseStyle);

  final color = highlightStyle?.color;
  final bold = highlightStyle?.bold ?? true;
  final matchStyle = baseStyle.copyWith(
    color: color,
    fontWeight: bold ? FontWeight.w700 : null,
  );

  return TextSpan(
    style: baseStyle,
    children: [
      if (start > 0) TextSpan(text: label.substring(0, start)),
      TextSpan(
        text: label.substring(start, start + query.length),
        style: matchStyle,
      ),
      if (start + query.length < label.length)
        TextSpan(text: label.substring(start + query.length)),
    ],
  );
}

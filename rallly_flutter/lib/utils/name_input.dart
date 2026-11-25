import 'package:flutter/services.dart';

/// Letters of any script, spaces, hyphen and apostrophes only. \p{M} keeps
/// combining marks, which some keyboards emit for accented letters.
final nameInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(
    RegExp(r"[\p{L}\p{M} '’\-]", unicode: true),
  ),
];

import 'dart:convert';

const _spanishMonths = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String formatSpanishDate(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return repairMojibake(value);
  return '${parsed.day} ${_spanishMonths[parsed.month - 1]} ${parsed.year}';
}

/// Repairs strings that were decoded as Latin-1 after being sent in UTF-8.
/// The original API value remains untouched; this only affects presentation.
String repairMojibake(String value) {
  if (!value.contains('Ã') && !value.contains('Â')) return value;
  try {
    return utf8.decode(latin1.encode(value));
  } on FormatException {
    return value;
  }
}

/// Normalizes the single and double UTF-8/Latin-1 decoding errors currently
/// returned by the content API, without changing the stored API response.
String normalizeApiText(String value) {
  var repaired = value;
  for (var attempt = 0; attempt < 2; attempt++) {
    if (!repaired.contains('\u00c3') && !repaired.contains('\u00c2')) break;
    try {
      final candidate = utf8.decode(latin1.encode(repaired));
      if (candidate == repaired) break;
      repaired = candidate;
    } on FormatException {
      break;
    }
  }
  return repaired;
}

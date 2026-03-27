class ParsedVoiceReminder {
  final String title;
  final DateTime dateTime;
  final bool hasSchedule;

  const ParsedVoiceReminder({
    required this.title,
    required this.dateTime,
    required this.hasSchedule,
  });
}

class _MatchedTime {
  final int hour;
  final int minute;
  final _TextSpan span;

  const _MatchedTime({
    required this.hour,
    required this.minute,
    required this.span,
  });
}

class _TextSpan {
  final int start;
  final int end;

  const _TextSpan(this.start, this.end);
}

ParsedVoiceReminder parseVoiceReminderCommand(
  String transcript, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final originalText = transcript.trim();
  if (originalText.isEmpty) {
    return ParsedVoiceReminder(
      title: '',
      dateTime: reference,
      hasSchedule: false,
    );
  }

  final matchableText = _normalizeText(originalText.toLowerCase());
  final spans = <_TextSpan>[];
  final matchedTime = _extractTime(matchableText, spans);
  final matchedDate = _extractDate(
    matchableText,
    reference,
    matchedTime,
    spans,
  );

  return ParsedVoiceReminder(
    title: _cleanTitle(originalText, spans),
    dateTime: _resolveDateTime(
      reference: reference,
      matchedDate: matchedDate,
      matchedTime: matchedTime,
    ),
    hasSchedule: matchedTime != null || matchedDate != null,
  );
}

_MatchedTime? _extractTime(String text, List<_TextSpan> spans) {
  final numericPattern = RegExp(
    r'\ba\s+l(?:a|as)\s+(\d{1,2})(?:(?::| y )(\d{1,2}))?(?:\s+y\s+(media|cuarto)|\s+menos\s+cuarto)?(?:\s+de\s+la\s+(manana|tarde|noche|madrugada)|\s+del\s+(mediodia))?\b',
    caseSensitive: false,
  );

  for (final match in numericPattern.allMatches(text)) {
    final parsed = _parseNumericTime(match);
    if (parsed == null) continue;
    spans.add(parsed.span);
    return parsed;
  }

  final wordPattern = RegExp(
    r'\ba\s+l(?:a|as)\s+([a-z]+(?:\s+[a-z]+){0,2})(?:\s+y\s+(media|cuarto)|\s+menos\s+cuarto)?(?:\s+de\s+la\s+(manana|tarde|noche|madrugada)|\s+del\s+(mediodia))?\b',
    caseSensitive: false,
  );

  for (final match in wordPattern.allMatches(text)) {
    final hour = _parseNumberWord(match.group(1));
    if (hour == null || hour > 23) continue;

    var resolvedHour = hour;
    var minute = 0;
    if ((match.group(0) ?? '').contains('menos cuarto')) {
      minute = 45;
      resolvedHour = (resolvedHour - 1) % 24;
      if (resolvedHour < 0) {
        resolvedHour += 24;
      }
    } else {
      final fraction = match.group(2);
      if (fraction == 'media') {
        minute = 30;
      } else if (fraction == 'cuarto') {
        minute = 15;
      }
    }

    spans.add(_TextSpan(match.start, match.end));
    return _MatchedTime(
      hour: _applyDayPart(resolvedHour, match.group(3) ?? match.group(4)),
      minute: minute,
      span: _TextSpan(match.start, match.end),
    );
  }

  final dayPartPattern = RegExp(
    r'\b(?:por\s+la\s+(manana|tarde|noche)|a(?:l)?\s+(mediodia|medianoche))\b',
    caseSensitive: false,
  );

  for (final match in dayPartPattern.allMatches(text)) {
    final phrase = match.group(0) ?? '';
    final time = switch (phrase) {
      'por la manana' => const _MatchedTime(
          hour: 9,
          minute: 0,
          span: _TextSpan(0, 0),
        ),
      'por la tarde' => const _MatchedTime(
          hour: 16,
          minute: 0,
          span: _TextSpan(0, 0),
        ),
      'por la noche' => const _MatchedTime(
          hour: 21,
          minute: 0,
          span: _TextSpan(0, 0),
        ),
      'a mediodia' || 'al mediodia' => const _MatchedTime(
          hour: 12,
          minute: 0,
          span: _TextSpan(0, 0),
        ),
      'a medianoche' || 'al medianoche' => const _MatchedTime(
          hour: 0,
          minute: 0,
          span: _TextSpan(0, 0),
        ),
      _ => null,
    };

    if (time == null) continue;
    spans.add(_TextSpan(match.start, match.end));
    return _MatchedTime(
      hour: time.hour,
      minute: time.minute,
      span: _TextSpan(match.start, match.end),
    );
  }

  return null;
}

_MatchedTime? _parseNumericTime(Match match) {
  final hour = int.tryParse(match.group(1) ?? '');
  if (hour == null || hour > 23) return null;

  var resolvedHour = hour;
  var minute = int.tryParse(match.group(2) ?? '') ?? 0;
  if (minute > 59) return null;

  if ((match.group(0) ?? '').contains('menos cuarto')) {
    minute = 45;
    resolvedHour = (resolvedHour - 1) % 24;
    if (resolvedHour < 0) {
      resolvedHour += 24;
    }
  } else {
    final fraction = match.group(3);
    if (fraction == 'media') {
      minute = 30;
    } else if (fraction == 'cuarto') {
      minute = 15;
    }
  }

  return _MatchedTime(
    hour: _applyDayPart(resolvedHour, match.group(4) ?? match.group(5)),
    minute: minute,
    span: _TextSpan(match.start, match.end),
  );
}

DateTime? _extractDate(
  String text,
  DateTime reference,
  _MatchedTime? matchedTime,
  List<_TextSpan> spans,
) {
  final relativePatterns = <RegExp, DateTime Function()>{
    RegExp(r'\bpasado\s+manana\b', caseSensitive: false): () {
      return _dateOnly(reference.add(const Duration(days: 2)));
    },
    RegExp(r'\bhoy\b', caseSensitive: false): () => _dateOnly(reference),
    RegExp(r'\bmanana\b', caseSensitive: false): () {
      return _dateOnly(reference.add(const Duration(days: 1)));
    },
  };

  for (final entry in relativePatterns.entries) {
    for (final match in entry.key.allMatches(text)) {
      if (_overlaps(match.start, match.end, spans)) continue;
      if (_isBlockedRelativeDateContext(text, match)) continue;
      spans.add(_TextSpan(match.start, match.end));
      return entry.value();
    }
  }

  final numericDatePattern = RegExp(
    r'\b(?:el\s+)?(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b',
    caseSensitive: false,
  );

  for (final match in numericDatePattern.allMatches(text)) {
    if (_overlaps(match.start, match.end, spans)) continue;
    final day = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    var year = int.tryParse(match.group(3) ?? '');
    if (day == null || month == null) continue;

    if (year != null && year < 100) {
      year += 2000;
    }
    year ??= reference.year;

    final candidate = DateTime(year, month, day);
    if (candidate.month != month || candidate.day != day) continue;

    spans.add(_TextSpan(match.start, match.end));
    if (year == reference.year && candidate.isBefore(_dateOnly(reference))) {
      return DateTime(reference.year + 1, month, day);
    }
    return candidate;
  }

  final weekdayPattern = RegExp(
    r'\b(?:(el|este|proximo)\s+)?(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\b',
    caseSensitive: false,
  );

  for (final match in weekdayPattern.allMatches(text)) {
    if (_overlaps(match.start, match.end, spans)) continue;
    final weekday = _weekdayFromName(match.group(2));
    if (weekday == null) continue;

    var daysAhead = (weekday - reference.weekday + 7) % 7;
    final modifier = match.group(1);
    if (daysAhead == 0) {
      if (modifier == 'proximo') {
        daysAhead = 7;
      } else if (matchedTime != null) {
        final candidate = DateTime(
          reference.year,
          reference.month,
          reference.day,
          matchedTime.hour,
          matchedTime.minute,
        );
        if (!candidate.isAfter(reference)) {
          daysAhead = 7;
        }
      } else {
        daysAhead = 7;
      }
    }

    spans.add(_TextSpan(match.start, match.end));
    return _dateOnly(reference.add(Duration(days: daysAhead)));
  }

  return null;
}

DateTime _resolveDateTime({
  required DateTime reference,
  required DateTime? matchedDate,
  required _MatchedTime? matchedTime,
}) {
  if (matchedDate != null && matchedTime != null) {
    return DateTime(
      matchedDate.year,
      matchedDate.month,
      matchedDate.day,
      matchedTime.hour,
      matchedTime.minute,
    );
  }

  if (matchedDate != null) {
    if (_isSameDate(matchedDate, reference)) {
      return reference.add(const Duration(hours: 1));
    }
    return DateTime(matchedDate.year, matchedDate.month, matchedDate.day, 9);
  }

  if (matchedTime != null) {
    var candidate = DateTime(
      reference.year,
      reference.month,
      reference.day,
      matchedTime.hour,
      matchedTime.minute,
    );
    if (!candidate.isAfter(reference)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  return reference;
}

String _cleanTitle(String originalText, List<_TextSpan> spans) {
  final title = spans.isEmpty
      ? originalText
      : _removeSpansFromOriginal(originalText, _mergeSpans(spans));
  return _cleanupPhrase(title);
}

String _removeSpansFromOriginal(String originalText, List<_TextSpan> spans) {
  final buffer = StringBuffer();
  var cursor = 0;

  for (final span in spans) {
    if (cursor < span.start) {
      buffer.write(originalText.substring(cursor, span.start));
    }
    cursor = span.end;
  }

  if (cursor < originalText.length) {
    buffer.write(originalText.substring(cursor));
  }

  return buffer.toString();
}

String _cleanupPhrase(String value) {
  var cleaned = value
      .replaceAll(RegExp(r'\s+([,.;:!?])'), r'$1')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  cleaned = cleaned.replaceAll(RegExp(r'^[,.;:!?-]+|[,.;:!?-]+$'), '').trim();
  cleaned = _stripLeadingPhrase(cleaned, const [
    'recordarme',
    'recuerdame',
    'recordar',
    'anade',
    'agrega',
    'crea',
    'crear',
    'pon',
    'ponme',
    'apunta',
  ]);
  cleaned =
      _stripLeadingPhrase(cleaned, const ['que', 'de', 'del', 'para', 'por']);
  cleaned = _stripTrailingPhrase(
    cleaned,
    const ['para', 'de', 'del', 'por', 'el', 'la', 'al'],
  );
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (cleaned.isEmpty) return '';
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

String _stripLeadingPhrase(String value, List<String> phrases) {
  var cleaned = value.trimLeft();
  var changed = true;

  while (changed) {
    changed = false;
    final normalized = _normalizeText(cleaned.toLowerCase());
    for (final phrase in phrases) {
      if (!normalized.startsWith(phrase)) continue;
      if (normalized.length > phrase.length &&
          normalized[phrase.length] != ' ' &&
          normalized[phrase.length] != ':' &&
          normalized[phrase.length] != ',' &&
          normalized[phrase.length] != '-') {
        continue;
      }
      cleaned = cleaned.substring(phrase.length).trimLeft();
      cleaned = cleaned.replaceFirst(RegExp(r'^[:,-]\s*'), '');
      changed = true;
      break;
    }
  }

  return cleaned;
}

String _stripTrailingPhrase(String value, List<String> phrases) {
  var cleaned = value.trimRight();
  var changed = true;

  while (changed) {
    changed = false;
    final normalized = _normalizeText(cleaned.toLowerCase());
    for (final phrase in phrases) {
      if (!normalized.endsWith(phrase)) continue;
      final start = normalized.length - phrase.length;
      if (start > 0 && normalized[start - 1] != ' ') {
        continue;
      }
      cleaned =
          cleaned.substring(0, cleaned.length - phrase.length).trimRight();
      changed = true;
      break;
    }
  }

  return cleaned;
}

List<_TextSpan> _mergeSpans(List<_TextSpan> spans) {
  final ordered = [...spans]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <_TextSpan>[];

  for (final span in ordered) {
    if (merged.isEmpty) {
      merged.add(span);
      continue;
    }

    final last = merged.last;
    if (span.start <= last.end) {
      merged[merged.length - 1] = _TextSpan(
        last.start,
        span.end > last.end ? span.end : last.end,
      );
      continue;
    }

    merged.add(span);
  }

  return merged;
}

bool _overlaps(int start, int end, List<_TextSpan> spans) {
  for (final span in spans) {
    if (start < span.end && end > span.start) {
      return true;
    }
  }
  return false;
}

bool _isBlockedRelativeDateContext(String text, Match match) {
  if ((match.group(0) ?? '') != 'manana') return false;

  final prefix =
      text.substring(match.start > 6 ? match.start - 6 : 0, match.start);
  return prefix.endsWith('de ') ||
      prefix.endsWith('la ') ||
      prefix.endsWith('por ') ||
      prefix.endsWith('del ');
}

int _applyDayPart(int hour, String? dayPart) {
  return switch (dayPart) {
    'manana' || 'madrugada' => hour == 12 ? 0 : hour,
    'tarde' => hour < 12 ? hour + 12 : hour,
    'noche' => hour == 12 ? 0 : (hour < 12 ? hour + 12 : hour),
    'mediodia' => 12,
    _ => hour,
  };
}

int? _parseNumberWord(String? value) {
  switch (value) {
    case 'cero':
      return 0;
    case 'un':
    case 'uno':
    case 'una':
      return 1;
    case 'dos':
      return 2;
    case 'tres':
      return 3;
    case 'cuatro':
      return 4;
    case 'cinco':
      return 5;
    case 'seis':
      return 6;
    case 'siete':
      return 7;
    case 'ocho':
      return 8;
    case 'nueve':
      return 9;
    case 'diez':
      return 10;
    case 'once':
      return 11;
    case 'doce':
      return 12;
    case 'trece':
      return 13;
    case 'catorce':
      return 14;
    case 'quince':
      return 15;
    case 'dieciseis':
      return 16;
    case 'diecisiete':
      return 17;
    case 'dieciocho':
      return 18;
    case 'diecinueve':
      return 19;
    case 'veinte':
      return 20;
    case 'veintiuno':
    case 'veintiun':
    case 'veintiuna':
      return 21;
    case 'veintidos':
      return 22;
    case 'veintitres':
      return 23;
    default:
      return null;
  }
}

int? _weekdayFromName(String? value) {
  return switch (value) {
    'lunes' => DateTime.monday,
    'martes' => DateTime.tuesday,
    'miercoles' => DateTime.wednesday,
    'jueves' => DateTime.thursday,
    'viernes' => DateTime.friday,
    'sabado' => DateTime.saturday,
    'domingo' => DateTime.sunday,
    _ => null,
  };
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _normalizeText(String value) {
  return value
      .replaceAll('\u00e1', 'a')
      .replaceAll('\u00e9', 'e')
      .replaceAll('\u00ed', 'i')
      .replaceAll('\u00f3', 'o')
      .replaceAll('\u00fa', 'u')
      .replaceAll('\u00fc', 'u')
      .replaceAll('\u00f1', 'n');
}

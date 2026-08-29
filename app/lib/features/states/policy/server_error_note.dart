import '../../../design/math/spec/es_mx_number.dart';

/// The annotation chip on `Error de servidor`.
///
/// **PURE** — a status and an instant in, a line or nothing out. No clock of
/// its own: the caller reads the time, because a function that called
/// `DateTime.now()` could not be tested and would make the screen change under
/// a golden.
///
/// The design draws `error 503 · 18:42`. Both halves are optional in practice:
/// `accountStateFor` collapses every unusable answer into one enum member, so a
/// caller holding the state and not the response has no code to name. What it
/// must never do is invent one.
///
/// Returns null when it knows neither, because a chip reading `error` is the
/// headline again in a smaller font — the same reading that keeps `HISTORIAL`
/// away when there is nothing true to say.
String? serverErrorNote({required int? status, required DateTime? at}) {
  if (status == null && at == null) {
    return null;
  }

  final String code = status == null ? 'error' : 'error $status';
  if (at == null) {
    return code;
  }
  return '$code · ${EsMxNumber.clockTime(hour: at.hour, minute: at.minute)}';
}

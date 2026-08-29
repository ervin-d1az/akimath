import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';
import '../data/prefs_settings_stores.dart';
import '../data/settings_store.dart';
import '../policy/notification_settings.dart';
import 'settings_choice_row.dart';
import 'settings_detail_scaffold.dart';
import 'settings_toggle_row.dart';

/// `Notificaciones` — three switches and the hour the first one lands on.
///
/// **Nothing is sent, and the screen says so.** There is no notification plugin
/// in `pubspec.yaml` and adding one is a DEP-1 decision rather than a session's,
/// so what the player moves here is *recorded* and not acted on. That is a
/// different thing from DR-P2's absent row: a control that stores a real answer
/// has done what it claims, and a footer says what has not happened yet.
/// Silently doing nothing is the case both readings rule out.
///
/// **The hour is three chips and no picker**, because [ReminderTime] is a
/// closed set — so the two boxes above them can always show what is set.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.onBack,
    this.store = const PrefsNotificationSettingsStore(),
  });

  final VoidCallback onBack;

  /// Where the answers are kept. A widget test hands in memory; the app takes
  /// the device.
  final SettingsStore<NotificationSettings> store;

  /// How many switches this screen draws, so its test holds the list to a
  /// number stated once rather than typed twice.
  static const int toggleCount = 3;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// The defaults until the store answers. A screen that drew nothing while it
  /// waited would flash, and there is nothing here worth a spinner.
  NotificationSettings _settings = NotificationSettings.defaults;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final NotificationSettings stored = await widget.store.read();
    if (mounted) {
      setState(() => _settings = stored);
    }
  }

  void _apply(NotificationSettings next) {
    setState(() => _settings = next);
    // Written and not awaited: the screen already shows the answer, and a
    // storage failure is reported by the adapter rather than held against the
    // press.
    widget.store.write(next);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: 'NOTIFICACIONES',
      onBack: widget.onBack,
      children: <Widget>[
        SettingsToggleRow(
          label: 'Recordatorio diario',
          note: 'Una vez al día, nada más',
          isOn: _settings.dailyReminder,
          onChanged: (bool on) => _apply(_settings.copyWith(dailyReminder: on)),
        ),
        _hourCard(),
        SettingsToggleRow(
          label: 'Racha en riesgo',
          note: 'Solo si no jugaste y ya va a ser tarde',
          isOn: _settings.streakAtRisk,
          onChanged: (bool on) => _apply(_settings.copyWith(streakAtRisk: on)),
        ),
        SettingsToggleRow(
          label: 'Puzzle nuevo',
          note: 'Cuando entra el del día',
          isOn: _settings.newPuzzle,
          onChanged: (bool on) => _apply(_settings.copyWith(newPuzzle: on)),
        ),
        Text(notificationsNotYetSentNotice, style: BrandText.caption()),
      ],
    );
  }

  Widget _hourCard() {
    final ReminderTime hour = _settings.reminderTime;

    return SettingsGroupCard(
      eyebrow: '¿A QUÉ HORA?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _clock(hour),
          const SizedBox(height: BrandShape.space3),
          SettingsChoiceRow(
            options: <SettingsChoiceOption>[
              for (final ReminderTime option in ReminderTime.values)
                SettingsChoiceOption(label: option.label),
            ],
            selected: hour.index,
            unselectedBackground: BrandColors.surface,
            onSelected: (int index) => _apply(
              _settings.copyWith(reminderTime: ReminderTime.values[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clock(ReminderTime hour) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _digits(hour.hour),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BrandShape.space2),
          child: Text(':', style: BrandText.cardTitle(size: 30)),
        ),
        _digits(hour.minute),
      ],
    );
  }

  /// One of the design's two number boxes. It reads back the chosen preset and
  /// never a figure of its own, so it cannot disagree with the chip below it.
  Widget _digits(String value) {
    return CandySurface(
      width: 82,
      minHeight: 74,
      background: BrandColors.cream,
      borderRadius: BrandShape.radiusPill,
      shadowOffset: Offset.zero,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(BrandShape.space1),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, style: BrandText.numeral(40)),
      ),
    );
  }
}

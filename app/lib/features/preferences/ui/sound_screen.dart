import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../data/prefs_settings_stores.dart';
import '../data/settings_store.dart';
import '../policy/sound_settings.dart';
import 'settings_detail_scaffold.dart';
import 'settings_toggle_row.dart';
import 'volume_bars.dart';

/// `Sonido y vibración` — a volume, two sounds and a haptic.
///
/// **Three switches, and the fourth one nobody drew is the point.** There is no
/// sound for a wrong answer, and the design says so in a footer rather than by
/// leaving a gap: making it a switch would turn a product rule into a
/// preference. The line is kept verbatim for that reason.
///
/// **Nothing plays.** There is no audio engine in `pubspec.yaml` and the keypad
/// asks for no haptic, so what the player sets here is recorded and the footer
/// says it has not been acted on — the same reading `4.4` takes.
class SoundScreen extends StatefulWidget {
  const SoundScreen({
    super.key,
    required this.onBack,
    this.store = const PrefsSoundSettingsStore(),
  });

  final VoidCallback onBack;

  /// Where the answers are kept. A widget test hands in memory; the app takes
  /// the device.
  final SettingsStore<SoundSettings> store;

  /// How many switches this screen draws.
  static const int toggleCount = 3;

  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> {
  /// The defaults until the store answers.
  SoundSettings _settings = SoundSettings.defaults;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SoundSettings stored = await widget.store.read();
    if (mounted) {
      setState(() => _settings = stored);
    }
  }

  void _apply(SoundSettings next) {
    setState(() => _settings = next);
    widget.store.write(next);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: 'SONIDO Y VIBRACIÓN',
      onBack: widget.onBack,
      children: <Widget>[
        SettingsGroupCard(
          eyebrow: 'VOLUMEN',
          child: VolumeBars(
            level: _settings.volume.level,
            onSelected: _chooseLevel,
          ),
        ),
        SettingsToggleRow(
          label: 'Sonido de teclas',
          note: 'Un toque seco, corto',
          isOn: _settings.keyPresses,
          onChanged: (bool on) => _apply(_settings.copyWith(keyPresses: on)),
        ),
        SettingsToggleRow(
          label: 'Sonido al acertar',
          isOn: _settings.correctAnswer,
          onChanged: (bool on) => _apply(_settings.copyWith(correctAnswer: on)),
        ),
        SettingsToggleRow(
          label: 'Vibración',
          note: 'Al presionar y al enviar',
          isOn: _settings.vibration,
          onChanged: (bool on) => _apply(_settings.copyWith(vibration: on)),
        ),
        Text(nothingSoundsOnAWrongAnswerNotice, style: BrandText.caption()),
        Text(soundNotYetPlayedNotice, style: BrandText.caption()),
      ],
    );
  }

  /// A level the row cannot produce is ignored rather than clamped: the bars
  /// count from one to five and so does [VolumeStep], so a miss would be a
  /// defect in the row and clamping it would hide that.
  void _chooseLevel(int level) {
    final VolumeStep? step = volumeStepAtLevel(level);
    if (step != null) {
      _apply(_settings.copyWith(volume: step));
    }
  }
}

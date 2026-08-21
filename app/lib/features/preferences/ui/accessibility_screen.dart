import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/spec/verdict.dart';
import '../../../design/widgets/spec/verdict_copy.dart';
import '../../../design/widgets/verdict_ring.dart';
import '../data/prefs_settings_stores.dart';
import '../data/settings_store.dart';
import '../policy/accessibility_settings.dart';
import 'settings_choice_row.dart';
import 'settings_detail_scaffold.dart';
import 'settings_toggle_row.dart';

/// `4.5 Accesibilidad` — the text size, two switches, and the pair of marks.
///
/// **The colour-blind card has no switch, and that is the design read rather
/// than a shortcut.** `4.5` draws one, on, beside its own note that the mode
/// *"no cambia el diseño: solo lo hace obvio"*. The outline-and-glyph encoding
/// is always on (BRD-1, design D6), so the switch would be a control that can
/// never move — which is DR-P2's *not yet* versus *not for you* problem in a
/// smaller box. The card says it in words and draws the pair instead, which is
/// the half of that card that always had a job.
///
/// **The three settings above it are recorded and not yet applied.** Nothing
/// scales its text off `textSize`, nothing animates, nothing repaints darker;
/// applying the first means the app's root `MediaQuery`, which is a decision
/// above this screen. The footer says so rather than leaving a player to
/// conclude the controls are broken.
class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({
    super.key,
    required this.onBack,
    this.store = const PrefsAccessibilitySettingsStore(),
  });

  final VoidCallback onBack;

  /// Where the answers are kept. A widget test hands in memory; the app takes
  /// the device.
  final SettingsStore<AccessibilitySettings> store;

  /// How many switches this screen draws. Two, not the design's three — see
  /// the note above.
  static const int toggleCount = 2;

  /// The size each chip draws its `A` at, which is the chip's whole content:
  /// a size chooser that cannot yet apply anything can still show what it
  /// would look like. The design's four.
  static const List<double> previewSizes = <double>[14, 19, 24, 30];

  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  /// The defaults until the store answers. There is nothing here worth a
  /// spinner, and a blank screen that then fills would flash.
  AccessibilitySettings _settings = AccessibilitySettings.defaults;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AccessibilitySettings stored = await widget.store.read();
    if (mounted) {
      setState(() => _settings = stored);
    }
  }

  void _apply(AccessibilitySettings next) {
    setState(() => _settings = next);
    widget.store.write(next);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: 'ACCESIBILIDAD',
      onBack: widget.onBack,
      children: <Widget>[
        _textSizeCard(),
        SettingsToggleRow(
          label: 'Reducir movimiento',
          note: 'Aki deja de rebotar y la cola no se mueve',
          isOn: _settings.reduceMotion,
          onChanged: (bool on) => _apply(_settings.copyWith(reduceMotion: on)),
        ),
        SettingsToggleRow(
          label: 'Alto contraste',
          isOn: _settings.highContrast,
          onChanged: (bool on) => _apply(_settings.copyWith(highContrast: on)),
        ),
        const _ColourBlindCard(),
        Text(accessibilityNotYetAppliedNotice, style: BrandText.caption()),
      ],
    );
  }

  Widget _textSizeCard() {
    return SettingsGroupCard(
      eyebrow: 'TAMAÑO DE TEXTO',
      child: SettingsChoiceRow(
        options: <SettingsChoiceOption>[
          for (final TextSizeStep step in TextSizeStep.values)
            SettingsChoiceOption(
              label: 'A',
              labelSize: AccessibilityScreen.previewSizes[step.index],
            ),
        ],
        selected: _settings.textSize.index,
        onSelected: (int index) => _apply(
          _settings.copyWith(textSize: TextSizeStep.values[index]),
        ),
      ),
    );
  }
}

/// The two marks, side by side, with what each one means.
///
/// It earns its place by teaching the pair somewhere other than mid-round: a
/// learner meets these two marks in the second where they most want to know
/// what happened, which is the worst moment to be learning a convention.
///
/// The two differ by **shape** before they differ by hue — a solid ring against
/// a dashed one — which is the whole reason `Verdict` carries an outline and a
/// glyph and no colour (BRD-1). Shown together so the difference is legible as
/// a difference, which it never is one screen at a time.
class _ColourBlindCard extends StatelessWidget {
  const _ColourBlindCard();

  @override
  Widget build(BuildContext context) {
    return SettingsGroupCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Modo daltonismo', style: BrandText.cardTitle(size: 16)),
          const SizedBox(height: BrandShape.space2),
          Text(verdictEncodingAlwaysOnNotice, style: BrandText.caption()),
          const SizedBox(height: BrandShape.space3),
          for (final Verdict verdict in Verdict.values) ...<Widget>[
            if (verdict != Verdict.values.first)
              const SizedBox(height: BrandShape.space3),
            _MarkRow(verdict),
          ],
        ],
      ),
    );
  }
}

/// One mark, its headline and what its outline looks like.
class _MarkRow extends StatelessWidget {
  const _MarkRow(this.verdict);

  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        VerdictRing(verdict),
        const SizedBox(width: BrandShape.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // **The same words the screens use** — from `verdict_copy.dart`,
              // so the card cannot teach a term a player will never meet.
              Text(verdictHeadline(verdict), style: BrandText.cardTitle()),
              const SizedBox(height: BrandShape.space1),
              Text(verdictMarkDescription(verdict), style: BrandText.caption()),
            ],
          ),
        ),
      ],
    );
  }
}

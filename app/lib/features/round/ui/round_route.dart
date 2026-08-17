import 'package:flutter/material.dart';

import '../../../content/model/pack.dart';
import '../../../content/pack_reader.dart';
import '../../../design/tokens/tokens.dart';
import 'round_screen.dart';

/// Loads the pack, then hands its items to [RoundScreen].
///
/// **The IO lives here so the screen has none.** `RoundScreen` takes a list of
/// items and is testable by handing it one; this widget is the adapter that
/// gets that list off disk, and it is also the only place a clock is read — the
/// expiry decision itself is `Pack.isExpiredAt`, which takes `now` as an
/// argument and is tested with two dates rather than a fake clock.
class RoundRoute extends StatefulWidget {
  const RoundRoute({super.key, this.reader = const PackReader()});

  final PackReader reader;

  @override
  State<RoundRoute> createState() => _RoundRouteState();
}

class _RoundRouteState extends State<RoundRoute> {
  late final Future<Pack> _pack = widget.reader.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Pack>(
      future: _pack,
      builder: (BuildContext context, AsyncSnapshot<Pack> snapshot) {
        if (snapshot.hasError) {
          return _message('No se pudo abrir el paquete de retos.');
        }
        final Pack? pack = snapshot.data;
        if (pack == null) {
          // Assets resolve in a frame or two. No spinner: `4.11` is annotated
          // *esqueletos, sin ruedita*, and `LoadingDots` is explicitly not to
          // be repurposed for product screens.
          return const Scaffold(backgroundColor: BrandColors.cream, body: SizedBox.shrink());
        }
        if (pack.isExpiredAt(DateTime.now().toUtc())) {
          return _message('Estos retos ya vencieron. Conéctate para recibir nuevos.');
        }
        return RoundScreen(items: pack.items);
      },
    );
  }

  Widget _message(String text) {
    return Scaffold(
      backgroundColor: BrandColors.cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(BrandShape.space6),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: BrandText.body(),
          ),
        ),
      ),
    );
  }
}

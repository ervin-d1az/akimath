# Ajustes is not a home, and the bar has said it was since F2

## Why

Declared rule 1, verbatim from the design: *"La barra inferior desaparece en
sesión … Vuelve en **inicio, mapa, progreso y perfil**."* Four homes, named.
Ajustes is not among them — it is `4.2`, reached from the gear on `4.1 Perfil`,
and the group badge over `4.1`–`4.7` says *"Aquí sí va la barra inferior"*
because the **stack** sits above the profile root, not because Ajustes is one.

The app's third root is labelled `Ajustes` and drawn with a settings glyph. That
was right when it landed: it was the only second destination there was, and a
bar needs two. It stopped being right when `Avance` arrived and it has been a
contradiction of a rule this repository quotes ever since.

It is not cosmetic. The root currently mixes three things a player thinks about
separately — who they are, what the app does, and how to leave — and there is
nowhere to put a fourth. `4.4` through `4.7` all push from a list that does not
exist, so every settings screen this product ever grows has no home to arrive
in.

## What changes

- **`AppTab.profile` becomes `Perfil`** — the label and the glyph. One line in
  `NavBar.labelOf` and one in the glyph map, both already switch on the tab.
- **`features/profile/`** — the root. `4.1`'s identity row: the avatar tile with
  Aki clipped inside it, the address, and the **gear that pushes the stack**.
  Below it, the account's state and the erasure door, both moving across from
  Ajustes unchanged.
- **`features/preferences/` becomes the stack's first screen** — `4.2`'s
  disclosure list, pushed rather than rooted, with a `DetailHeader`: a back
  control and a Darumadrop title.
- **`design/widgets/detail_header.dart`** — back plus title, which `4.2`–`4.7`
  share. The design shrinks the title as it lengthens (40 → 38 → 34 → 32);
  that is fit-to-width on one line, not six magic numbers.
- **`design/widgets/settings_row.dart`** — the `height:62` disclosure row.
  Trailing is a chevron, a value and a chevron, or nothing.

## What the list holds, and what it does not

**Two rows**, because two destinations exist:

- `Cuenta` → the account state, the address, and the way out
- `Cómo se leen los retos` → the verdict legend, which is already built and is
  the one thing on today's Ajustes that is neither identity nor account

`Notificaciones`, `Sonido y vibración` and `Ayuda` are **not drawn**. No
notification plugin, no audio engine, no designed help screen — and DR-P2 is
that a row leading nowhere is worse than an absent one. `Accesibilidad` is
absent **today and not on principle**: `TAMAÑO DE TEXTO` is the one control in
`4.4`–`4.6` whose recorded reasoning does not survive, since four steps map onto
a text scale the app is already gated at, and it lands in the next change into
the row this one leaves room for.

`Datos y privacidad` is not a row either. Its two halves are `Pedir mi archivo`,
which needs a server job and an email path, and `Borrar historial`, which is a
**third erasure path** against a schema granting DELETE on `attempts` to
`retention_job` alone. The erasure that *does* exist — `DELETE /me` — is not
buried under a heading with nothing else in it; it stays on `Cuenta`, where the
sentence about what survives can sit next to the address it is about.

## What Perfil does not print

`RATING`, `+36 esta semana`, `312 RETOS`, `78% ACIERTOS`, `6,8 s PROMEDIO` and
`HISTORIAL`. The first five are F4 or need aggregates no endpoint answers. The
sixth exists and is **already on `Avance`**, moved there on the recorded ground
that what a player has done is not a setting; drawing it twice would make two
screens that can disagree.

That leaves the profile root thin, and thin is the honest state of it. The
alternative is a screen of figures nothing can compute, which this project has
now declined three times — on the verdict screens, on `Avance`, and on `4.13`.

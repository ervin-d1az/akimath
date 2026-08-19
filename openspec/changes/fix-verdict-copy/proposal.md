# Say it in words a player already knows

## Why

Reported from reading the app: *"Se torció"* and *"El aro va cortado"* are not clear.

They are the captions in `4.5 Ajustes`' verdict legend — the key that teaches a player to tell
the two marks apart. Three things are wrong with them:

1. **"Se torció"** — *it got twisted* — is a metaphor about Aki's tail curl. The legend does not
   draw the tail, so the sentence has no subject a reader can find.
2. **"El aro va cortado"** names the mark *el aro* as though the player already knows the ring
   is a named part of the app, and calls a dashed circle a **cut** one, which is not what a
   dashed line looks like.
3. Worst of the three: **the legend taught two words the app never shows.** It said `Acierto`
   and `Se torció` while the screens a player actually meets say `¡Bien hecho!` and `Casi`. A
   key to terms that appear nowhere is worse than no key.

## What changes

- One home for the two headlines, `verdict_copy.dart`, read by both `04 Error` and the legend —
  so the key cannot drift from the screen again.
- The legend's captions describe the **shape**: *Círculo de línea continua* and *Círculo de
  línea punteada*.
- `04 Error`'s headline loses its second sentence, *"Mira cómo va."* The diagnosis steps
  underneath now say exactly that, concretely, instead of promising it.

## Out of scope

The rest of the app's copy. This is the one place two screens disagreed about the same word.

/**
 * What Aki says when an answer is wrong, in es-MX.
 *
 * **A value, not a file.** It used to be `content/misconceptions.json`, read
 * by the build script — which was fine while the only consumer ran at build
 * time. `packages/server` issues packs now and needs the same copy inside a
 * request, and a request path that reads a file out of another package's
 * content directory is ambient IO in the one package that forbids it. One
 * source, and it is here.
 *
 * **Still validated rather than trusted.** `parseMisconceptions` runs over it
 * exactly as it ran over the JSON, so the shape rules — a snake_case id, one to
 * four steps, a non-empty explanation — keep biting on a typo in this file.
 *
 * **Excluded from mutation testing** (`stryker.config.json`), because it is
 * prose. Every mutant here blanks a Spanish sentence, and the only test that
 * could kill one would restate the sentence — a test that says nothing except
 * that somebody typed the same words twice. What *is* mutation-tested is
 * `misconceptions.ts`, which decides whether copy is acceptable, and
 * `test/pack/misconception-copy.test.ts` holds these values to those rules.
 *
 * The copy is the only es-MX in this package and that is deliberate: it is
 * end-user-visible text, which `CLAUDE.md` puts in Spanish wherever it lives.
 * It does not scold, and it does not name the mistake before it names the fix.
 */
export const MISCONCEPTION_COPY: Readonly<
  Record<string, { readonly steps: readonly string[]; readonly explain: string }>
> = Object.freeze({
  no_specific_diagnosis: {
    steps: [
      "Lee otra vez el reto, sin prisa.",
      "Rehaz la cuenta paso por paso.",
      "Comprueba el resultado antes de enviarlo.",
    ],
    explain: "Repasa el reto con calma: vuelve a leer los números, rehaz la cuenta paso por paso y compara lo que te salió con lo que pedía el reto.",
  },
  subtracted_in_reverse: {
    steps: [
      "Fíjate en cuál número va primero.",
      "Quita el segundo al primero, en ese orden.",
    ],
    explain: "Al restar, el orden importa: 8 − 3 y 3 − 8 no dan lo mismo. El primer número es del que quitas; el segundo es lo que quitas.",
  },
  added_instead_of_subtracting: {
    steps: [
      "Mira el signo que hay entre los dos números.",
      "Si es −, quita en vez de juntar.",
    ],
    explain: "Ese resultado sale de juntar los dos números. El signo − pide lo contrario: quitar el segundo del primero.",
  },
  subtracted_instead_of_adding: {
    steps: [
      "Mira el signo que hay entre los dos números.",
      "Si es +, junta en vez de quitar.",
    ],
    explain: "Ese resultado sale de quitar un número del otro. El signo + pide lo contrario: juntar los dos.",
  },
});

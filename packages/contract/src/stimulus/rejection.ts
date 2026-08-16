/** Every way a stimulus payload can be malformed. Stable, and closed. */
export type StimulusRejectionTag =
  | "payload_shape"
  | "division_by_zero_term"
  | "unknown_index_out_of_range"
  | "matrix_cell_count"
  | "query_repeats_example"
  | "figures_not_increasing";

/**
 * Every family that draws an unknown tile bounds it the same way, so the
 * check lives once rather than five times.
 */
export function checkUnknownIndex(
  unknownIndex: number,
  arity: number,
): StimulusRejectionTag | null {
  return unknownIndex < arity ? null : "unknown_index_out_of_range";
}

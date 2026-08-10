export type AudioGenerationStatus =
  | "queued"
  | "generating"
  | "ready"
  | "failed";

export function shouldReuseInFlightGeneration(
  status: AudioGenerationStatus | null,
): boolean {
  return status === "queued" || status === "generating";
}

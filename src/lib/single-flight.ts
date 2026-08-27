export function singleFlight<T>(start: () => Promise<T>): () => Promise<T> {
  let inFlight: Promise<T> | undefined;

  return () => {
    // Raycast development renders may execute an effect twice; one native operation must serve both callers.
    if (!inFlight) {
      inFlight = start().finally(() => {
        inFlight = undefined;
      });
    }
    return inFlight;
  };
}

import type { Meta } from "./meta";

const META_URL = "/api/v1/meta";

let cache: Promise<Meta> | null = null;

export function fetchMeta(): Promise<Meta> {
  if (!cache) {
    cache = fetch(META_URL)
      .then((r) => {
        if (!r.ok) throw new Error(`meta request failed: ${r.status}`);
        return r.json() as Promise<Meta>;
      })
      .catch((err) => {
        cache = null;
        throw err;
      });
  }
  return cache;
}

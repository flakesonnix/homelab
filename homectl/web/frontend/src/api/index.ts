import type { Meta } from "./meta";
import type { HostHealth, Resources, Network, VMEntry, FailedUnit } from "./runtime";

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

async function getJSON<T>(url: string): Promise<T> {
  const r = await fetch(url);
  if (!r.ok) {
    const body = await r.text().catch(() => "");
    throw new Error(`${url} failed: ${r.status} ${body}`);
  }
  return (await r.json()) as T;
}

export function fetchHosts(): Promise<{ hosts: { name: string; hostname: string; roles: string[] }[] }> {
  return getJSON("/api/v1/hosts");
}

export function fetchHealth(host: string): Promise<HostHealth> {
  return getJSON(`/api/v1/hosts/${encodeURIComponent(host)}/health`);
}

export function fetchResources(host: string): Promise<Resources> {
  return getJSON(`/api/v1/hosts/${encodeURIComponent(host)}/resources`);
}

export function fetchNetwork(host: string): Promise<Network> {
  return getJSON(`/api/v1/hosts/${encodeURIComponent(host)}/network`);
}

export function fetchVMs(host: string): Promise<{ vms: VMEntry[] }> {
  return getJSON(`/api/v1/hosts/${encodeURIComponent(host)}/vms`);
}

export function fetchFailed(host: string): Promise<{ failed: FailedUnit[] }> {
  return getJSON(`/api/v1/hosts/${encodeURIComponent(host)}/systemd/failed`);
}

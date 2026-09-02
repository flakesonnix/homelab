export interface HostHealth {
  host: string;
  hostname: string;
  kernel?: string;
  os?: string;
  osPretty?: string;
  uptimeS?: number;
  health: "healthy" | "degraded" | "critical" | "unknown";
  agent: "connected" | "unavailable";
  failedUnits: number;
  timestamp: string;
}

export interface Resources {
  cpu: { logical: number; usagePct?: number };
  load: { load1: number; load5: number; load15: number };
  memory: { total: number; available: number; used: number; free: number; usedPct: number };
  storage: { filesystem: string; mount: string; type: string; total: number; used: number; available: number; usedPct: number }[];
}

export interface Network {
  interfaces: {
    name: string;
    state: string;
    mac: string;
    mtu?: number;
    ipv4: string[];
    ipv6: string[];
    rx: number;
    tx: number;
  }[];
  routes: { destination: string; gateway?: string; interface?: string }[];
}

export interface VMRuntime {
  state: string;
  uptimeS?: number;
}

export interface ConfiguredVM {
  host: string;
  ip: string;
  mem: number | null;
  vcpu: number | null;
  autostart: boolean;
  tcpPorts: number[];
  udpPorts: number[];
  volumes: { mountPoint: string | null; size: number | null }[];
}

export interface VMEntry {
  name: string;
  configured: ConfiguredVM;
  runtime: VMRuntime;
  health: string;
}

export interface FailedUnit {
  unit: string;
  load: string;
  active: string;
  sub: string;
  description: string;
}

export function formatBytes(b: number): string {
  if (b === 0) return "0 B";
  const k = 1024;
  const sizes = ["B", "KiB", "MiB", "GiB", "TiB"];
  const i = Math.floor(Math.log(b) / Math.log(k));
  const v = b / Math.pow(k, i);
  return `${v.toFixed(i === 0 ? 0 : 1)} ${sizes[i]}`;
}

export function formatUptime(s?: number): string {
  if (s == null) return "—";
  const d = Math.floor(s / 86400);
  const h = Math.floor((s % 86400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (d > 0) return `${d}d ${h}h ${m}m`;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

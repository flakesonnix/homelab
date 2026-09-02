import { useEffect, useState } from "react";
import { fetchHealth, fetchResources, fetchNetwork, fetchFailed } from "../api";
import type { HostHealth, Resources, Network, FailedUnit } from "../api/runtime";
import { formatBytes, formatUptime } from "../api/runtime";
import SystemdFailed from "./SystemdFailed";

function Metric({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="rounded border border-zinc-800 bg-zinc-900 px-3 py-2">
      <div className="text-xs uppercase tracking-wide text-zinc-500">{label}</div>
      <div className="text-sm font-medium text-zinc-100">{value}</div>
      {sub && <div className="text-xs text-zinc-500">{sub}</div>}
    </div>
  );
}

function Bar({ pct }: { pct: number }) {
  const c = pct > 90 ? "bg-red-500" : pct > 75 ? "bg-amber-500" : "bg-emerald-500";
  return (
    <div className="mt-1 h-1.5 w-full rounded bg-zinc-800">
      <div className={`h-1.5 rounded ${c}`} style={{ width: `${Math.min(100, pct)}%` }} />
    </div>
  );
}

export default function HostOverview({ host }: { host: string }) {
  const [health, setHealth] = useState<HostHealth | null>(null);
  const [res, setRes] = useState<Resources | null>(null);
  const [net, setNet] = useState<Network | null>(null);
  const [failed, setFailed] = useState<FailedUnit[] | null>(null);
  const [healthErr, setHealthErr] = useState<string | null>(null);
  const [resErr, setResErr] = useState<string | null>(null);
  const [netErr, setNetErr] = useState<string | null>(null);
  const [failedErr, setFailedErr] = useState<string | null>(null);

  useEffect(() => {
    fetchHealth(host).then(setHealth).catch((e) => setHealthErr(String(e)));
    fetchResources(host).then(setRes).catch((e) => setResErr(String(e)));
    fetchNetwork(host).then(setNet).catch((e) => setNetErr(String(e)));
    fetchFailed(host).then((r) => setFailed(r.failed)).catch((e) => setFailedErr(String(e)));
  }, [host]);

  const healthColor =
    health?.health === "healthy" ? "text-emerald-400 border-emerald-900/40 bg-emerald-950/20" :
    health?.health === "degraded" ? "text-amber-400 border-amber-900/40 bg-amber-950/20" :
    health?.health === "critical" ? "text-red-400 border-red-900/40 bg-red-950/20" :
    "text-zinc-500 border-zinc-800 bg-zinc-900";

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className={`rounded-lg border p-4 ${healthColor}`}>
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold tracking-tight">{host.toUpperCase()}</h2>
            <div className="text-xs text-zinc-400">
              {health ? (
                <>
                  <span className="font-mono">{health.hostname}</span> · {health.health} · agent {health.agent} · {formatUptime(health.uptimeS)} up · {health.kernel || "—"}
                </>
              ) : healthErr ? (
                <span className="text-amber-400">health unavailable: {healthErr}</span>
              ) : (
                "Loading health…"
              )}
            </div>
          </div>
          <div className="text-right text-xs text-zinc-500">
            {health?.osPretty || health?.os || "—"}
            <div className="font-mono">{health?.timestamp ? new Date(health.timestamp).toLocaleString() : ""}</div>
          </div>
        </div>
      </div>

      {/* Resources */}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {res ? (
          <>
            <Metric label="CPU" value={`${res.cpu.logical} cores`} sub={`load ${res.load.load1.toFixed(2)} / ${res.load.load5.toFixed(2)} / ${res.load.load15.toFixed(2)}${res.cpu.usagePct != null ? ` · ${res.cpu.usagePct.toFixed(1)}%` : ""}`} />
            <div className="rounded border border-zinc-800 bg-zinc-900 px-3 py-2">
              <div className="text-xs uppercase tracking-wide text-zinc-500">Memory</div>
              <div className="text-sm font-medium text-zinc-100">{formatBytes(res.memory.used)} / {formatBytes(res.memory.total)} · {res.memory.usedPct.toFixed(1)}%</div>
              <Bar pct={res.memory.usedPct} />
              <div className="text-xs text-zinc-500">avail {formatBytes(res.memory.available)}</div>
            </div>
            {res.storage.slice(0, 2).map((fs) => (
              <div key={fs.mount} className="rounded border border-zinc-800 bg-zinc-900 px-3 py-2">
                <div className="text-xs uppercase tracking-wide text-zinc-500">{fs.mount} · {fs.type}</div>
                <div className="text-sm font-medium text-zinc-100">{formatBytes(fs.used)} / {formatBytes(fs.total)} · {fs.usedPct.toFixed(1)}%</div>
                <Bar pct={fs.usedPct} />
                <div className="text-xs text-zinc-500">{fs.filesystem}</div>
              </div>
            ))}
          </>
        ) : resErr ? (
          <div className="col-span-full text-sm text-amber-400">resources unavailable: {resErr}</div>
        ) : (
          <div className="col-span-full text-sm text-zinc-500">Loading resources…</div>
        )}
      </div>

      {/* Network */}
      <div className="rounded border border-zinc-800 bg-zinc-900 p-3">
        <h3 className="mb-2 text-sm font-semibold text-zinc-200">Network</h3>
        {net ? (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="text-zinc-500">
                <tr>
                  <th className="px-2 py-1 font-medium">IF</th>
                  <th className="px-2 py-1 font-medium">State</th>
                  <th className="px-2 py-1 font-medium">MAC</th>
                  <th className="px-2 py-1 font-medium">IPv4</th>
                  <th className="px-2 py-1 font-medium">IPv6</th>
                  <th className="px-2 py-1 font-medium">RX/TX</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-800 font-mono">
                {net.interfaces.filter((i) => i.name !== "lo").slice(0, 12).map((iface) => (
                  <tr key={iface.name} className="hover:bg-zinc-800/40">
                    <td className="px-2 py-1 text-zinc-200">{iface.name}</td>
                    <td className="px-2 py-1"><span className={`rounded px-1.5 py-0.5 ${iface.state === "up" ? "bg-emerald-900/30 text-emerald-300" : "bg-zinc-800 text-zinc-400"}`}>{iface.state}</span></td>
                    <td className="px-2 py-1 text-zinc-500">{iface.mac || "—"}</td>
                    <td className="px-2 py-1 text-zinc-400">{iface.ipv4.join(", ") || "—"}</td>
                    <td className="px-2 py-1 text-zinc-400">{iface.ipv6.join(", ") || "—"}</td>
                    <td className="px-2 py-1 text-zinc-500">{formatBytes(iface.rx)} / {formatBytes(iface.tx)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {net.routes.length > 0 && (
              <div className="mt-2 text-xs text-zinc-500">
                Routes: {net.routes.slice(0, 4).map((r) => `${r.destination} via ${r.gateway || "—"} dev ${r.interface || "—"}`).join(" · ")}
              </div>
            )}
          </div>
        ) : netErr ? (
          <div className="text-sm text-amber-400">network unavailable: {netErr}</div>
        ) : (
          <div className="text-sm text-zinc-500">Loading network…</div>
        )}
      </div>

      {/* Systemd */}
      <div>
        <h3 className="mb-2 text-sm font-semibold text-zinc-200">systemd</h3>
        {failed !== null ? <SystemdFailed failed={failed} /> : <SystemdFailed failed={[]} loading={!failedErr} error={failedErr ?? undefined} />}
      </div>
    </div>
  );
}

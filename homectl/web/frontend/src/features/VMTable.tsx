import type { VMEntry } from "../api/runtime";

function Badge({ state }: { state: string }) {
  const color =
    state === "running" ? "bg-emerald-900/40 text-emerald-300 border-emerald-800" :
    state === "stopped" ? "bg-zinc-800 text-zinc-400 border-zinc-700" :
    "bg-amber-900/30 text-amber-300 border-amber-800";
  return (
    <span className={`inline-flex rounded border px-1.5 py-0.5 text-xs font-medium ${color}`}>
      {state}
    </span>
  );
}

function HealthDot({ health }: { health: string }) {
  const c =
    health === "healthy" ? "bg-emerald-500" :
    health === "degraded" ? "bg-amber-500" :
    health === "critical" ? "bg-red-500" : "bg-zinc-600";
  return <span className={`inline-block h-2 w-2 rounded-full ${c}`} />;
}

export default function VMTable({ vms, loading, error }: { vms: VMEntry[]; loading?: boolean; error?: string | null }) {
  if (loading) return <div className="text-sm text-zinc-500">Loading VMs…</div>;
  if (error) return <div className="text-sm text-amber-400">VMs unavailable: {error}</div>;
  if (vms.length === 0) return <div className="text-sm text-zinc-500">No VMs — manifest has no VMs for this host.</div>;

  return (
    <div className="overflow-x-auto rounded border border-zinc-800">
      <table className="w-full text-left text-sm">
        <thead className="bg-zinc-900 text-xs uppercase tracking-wide text-zinc-500">
          <tr>
            <th className="px-3 py-2 font-medium">Name</th>
            <th className="px-3 py-2 font-medium">IP</th>
            <th className="px-3 py-2 font-medium">State</th>
            <th className="px-3 py-2 font-medium">vCPU</th>
            <th className="px-3 py-2 font-medium">RAM</th>
            <th className="px-3 py-2 font-medium">Health</th>
            <th className="px-3 py-2 font-medium">Ports</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-zinc-800 bg-zinc-900/30">
          {vms.map((vm) => (
            <tr key={vm.name} className="hover:bg-zinc-800/40">
              <td className="px-3 py-2 font-mono text-zinc-200">{vm.name}</td>
              <td className="px-3 py-2 font-mono text-xs text-zinc-400">{vm.configured.ip || "—"}</td>
              <td className="px-3 py-2"><Badge state={vm.runtime.state} /></td>
              <td className="px-3 py-2 text-zinc-300">{vm.configured.vcpu ?? "—"}</td>
              <td className="px-3 py-2 text-zinc-300">{vm.configured.mem != null ? `${vm.configured.mem} MB` : "—"}</td>
              <td className="px-3 py-2"><span className="inline-flex items-center gap-1.5 text-xs text-zinc-400"><HealthDot health={vm.health} />{vm.health}</span></td>
              <td className="px-3 py-2 font-mono text-xs text-zinc-500">
                {[...vm.configured.tcpPorts, ...vm.configured.udpPorts].length > 0
                  ? [...vm.configured.tcpPorts, ...vm.configured.udpPorts].slice(0, 4).join(", ") + (vm.configured.tcpPorts.length + vm.configured.udpPorts.length > 4 ? "…" : "")
                  : "—"}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

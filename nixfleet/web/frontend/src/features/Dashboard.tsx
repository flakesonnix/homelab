import { useEffect, useState } from "react";
import type { Dashboard, HostInfo, VMInfo } from "../api/meta";
import type { VMEntry } from "../api/runtime";
import { fetchVMs } from "../api";
import HostOverview from "./HostOverview";
import VMTable from "./VMTable";

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded border border-zinc-800 bg-zinc-900 px-3 py-2">
      <div className="text-xs text-zinc-500">{label}</div>
      <div className="text-sm font-medium text-zinc-200">{value}</div>
    </div>
  );
}

export default function Dashboard({
  dashboard,
  hosts,
  vms,
}: {
  dashboard: Dashboard;
  hosts: Record<string, HostInfo>;
  vms: Record<string, VMInfo>;
}) {
  const [mireoVMs, setMireoVMs] = useState<VMEntry[] | null>(null);
  const [vmErr, setVmErr] = useState<string | null>(null);
  const [vmLoading, setVmLoading] = useState(true);

  useEffect(() => {
    if (!hosts["mireo"]) {
      setVmLoading(false);
      return;
    }
    fetchVMs("mireo")
      .then((r) => setMireoVMs(r.vms))
      .catch((e) => setVmErr(String(e)))
      .finally(() => setVmLoading(false));
  }, [hosts]);

  const hasMireo = !!hosts["mireo"];

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold text-zinc-100">Dashboard</h2>

      {hasMireo && (
        <>
          <HostOverview host="mireo" />
          <div>
            <h3 className="mb-2 text-sm font-semibold text-zinc-200">MicroVMs · mireo</h3>
            <VMTable vms={mireoVMs ?? []} loading={vmLoading} error={vmErr} />
          </div>
        </>
      )}

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {Object.entries(hosts).map(([name, host]) => (
          <section key={name} className="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
            <h3 className="mb-2 font-semibold text-zinc-100">{host.hostname}</h3>
            <div className="grid grid-cols-2 gap-2">
              <Stat label="Roles" value={host.roles.join(", ") || "—"} />
              <Stat label="Bundles" value={host.bundles.length.toString()} />
              <Stat label="Presets" value={host.presets.join(", ") || "—"} />
              <Stat
                label="VMs"
                value={Object.values(vms)
                  .filter((vm) => vm.host === name)
                  .map((vm) => vm.ip)
                  .join(", ") || "—"}
              />
            </div>
          </section>
        ))}
      </div>
      {dashboard.widgets.length === 0 && (
        <p className="text-sm text-zinc-500">
          No widgets declared in ui.json — the dashboard is entirely Nix-driven.
        </p>
      )}
    </div>
  );
}

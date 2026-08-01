import type { Dashboard, HostInfo, VMInfo } from "../api/meta";

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
  return (
    <div className="space-y-4">
      <h2 className="text-xl font-semibold text-zinc-100">Dashboard</h2>
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

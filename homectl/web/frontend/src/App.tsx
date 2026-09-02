import { useEffect, useState } from "react";
import { fetchMeta } from "./api";
import type { Meta } from "./api/meta";
import Dashboard from "./features/Dashboard";
import Hosts from "./features/Hosts";
import HostOverview from "./features/HostOverview";
import VMTable from "./features/VMTable";
import { fetchVMs } from "./api";
import type { VMEntry } from "./api/runtime";

function Placeholder({ page }: { page: string }) {
  return (
    <div className="rounded-lg border border-dashed border-zinc-800 p-8 text-center text-sm text-zinc-500">
      {page} — arrives in a later milestone. The page exists because ui.json
      declares it, not because the frontend decided to.
    </div>
  );
}

function VMsPage() {
  const [vms, setVms] = useState<VMEntry[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    fetchVMs("mireo")
      .then((r) => setVms(r.vms))
      .catch((e) => setErr(String(e)))
      .finally(() => setLoading(false));
  }, []);
  return (
    <div className="space-y-4">
      <h2 className="text-xl font-semibold text-zinc-100">MicroVMs · mireo</h2>
      <p className="text-sm text-zinc-500">
        Declarative inventory from <span className="font-mono">manifest.json</span> merged with runtime state from the mireo agent. No hardcoded VM names.
      </p>
      <VMTable vms={vms ?? []} loading={loading} error={err} />
    </div>
  );
}

export default function App() {
  const [meta, setMeta] = useState<Meta | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState("dashboard");

  useEffect(() => {
    fetchMeta().then(setMeta).catch((err) => setError(String(err)));
  }, []);

  if (error) {
    return (
      <div className="p-8 text-sm text-red-400">
        Failed to load /api/v1/meta: {error}
      </div>
    );
  }
  if (!meta) {
    return <div className="p-8 text-sm text-zinc-500">Loading meta…</div>;
  }

  return (
    <div className="flex min-h-screen bg-zinc-950 text-zinc-200">
      <nav className="w-52 shrink-0 border-r border-zinc-800 bg-zinc-900/50 p-3">
        <h1 className="mb-3 px-2 text-lg font-bold text-zinc-100">homectl</h1>
        <ul className="space-y-1">
          {meta.ui.navigation.map((item) => (
            <li key={item.page}>
              <button
                onClick={() => setPage(item.page)}
                className={`w-full rounded px-2 py-1.5 text-left text-sm ${
                  page === item.page
                    ? "bg-zinc-800 text-zinc-100"
                    : "text-zinc-400 hover:bg-zinc-800/60 hover:text-zinc-200"
                }`}
              >
                {item.label}
              </button>
            </li>
          ))}
        </ul>
      </nav>
      <main className="flex-1 p-6">
        {page === "dashboard" && (
          <Dashboard
            dashboard={meta.ui.dashboard}
            hosts={meta.manifest.hosts}
            vms={meta.manifest.vms}
          />
        )}
        {page === "hosts" && <Hosts hosts={meta.manifest.hosts} />}
        {page === "vms" && <VMsPage />}
        {page === "network" && <HostOverview host="mireo" />}
        {!["dashboard", "hosts", "vms", "network"].includes(page) && <Placeholder page={page} />}
      </main>
    </div>
  );
}

import type { FailedUnit } from "../api/runtime";

export default function SystemdFailed({ failed, loading, error }: { failed: FailedUnit[]; loading?: boolean; error?: string | null }) {
  if (loading) return <div className="text-sm text-zinc-500">Checking systemd…</div>;
  if (error) return <div className="text-sm text-amber-400">systemd unavailable: {error}</div>;
  if (failed.length === 0) {
    return (
      <div className="rounded border border-emerald-900/30 bg-emerald-950/20 px-3 py-2 text-sm text-emerald-300">
        <span className="font-medium">0 failed</span> — all systemd units healthy
      </div>
    );
  }
  return (
    <div className="space-y-2">
      <div className="text-sm font-medium text-amber-300">{failed.length} failed — click for details</div>
      <div className="overflow-x-auto rounded border border-amber-900/40">
        <table className="w-full text-left text-sm">
          <thead className="bg-zinc-900 text-xs uppercase tracking-wide text-zinc-500">
            <tr>
              <th className="px-3 py-2 font-medium">Unit</th>
              <th className="px-3 py-2 font-medium">Active</th>
              <th className="px-3 py-2 font-medium">Sub</th>
              <th className="px-3 py-2 font-medium">Description</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-800 bg-zinc-900/30">
            {failed.map((u) => (
              <tr key={u.unit} className="hover:bg-zinc-800/40">
                <td className="px-3 py-2 font-mono text-xs text-zinc-200">{u.unit}</td>
                <td className="px-3 py-2 text-xs"><span className="rounded bg-red-900/40 px-1.5 py-0.5 text-red-300">{u.active}/{u.sub}</span></td>
                <td className="px-3 py-2 text-xs text-zinc-400">{u.sub}</td>
                <td className="px-3 py-2 text-xs text-zinc-400">{u.description || "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

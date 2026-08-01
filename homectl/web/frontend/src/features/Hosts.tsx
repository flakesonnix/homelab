import type { ReactNode } from "react";
import type { HostInfo } from "../api/meta";

function Tag({ children }: { children: ReactNode }) {
  return (
    <span className="rounded bg-zinc-800 px-1.5 py-0.5 text-xs text-zinc-300">
      {children}
    </span>
  );
}

export default function Hosts({ hosts }: { hosts: Record<string, HostInfo> }) {
  return (
    <div className="grid gap-4 md:grid-cols-2">
      {Object.entries(hosts).map(([name, host]) => (
        <section key={name} className="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
          <h3 className="text-lg font-semibold text-zinc-100">{host.hostname}</h3>
          <dl className="mt-2 space-y-1 text-sm text-zinc-400">
            <div className="flex gap-2">
              <dt>Roles</dt>
              <dd className="flex flex-wrap gap-1">
                {host.roles.map((r) => (
                  <Tag key={r}>{r}</Tag>
                ))}
              </dd>
            </div>
            <div className="flex gap-2">
              <dt>Bundles</dt>
              <dd className="flex flex-wrap gap-1">
                {host.bundles.map((b) => (
                  <Tag key={b}>{b}</Tag>
                ))}
              </dd>
            </div>
            <div className="flex gap-2">
              <dt>Presets</dt>
              <dd className="flex flex-wrap gap-1">
                {host.presets.map((p) => (
                  <Tag key={p}>{p}</Tag>
                ))}
              </dd>
            </div>
            <div className="flex gap-2">
              <dt>Packages</dt>
              <dd className="flex flex-wrap gap-1">
                {Object.entries(host.packages).flatMap(([tag, pkgs]) =>
                  pkgs.map((p) => (
                    <Tag key={`${tag}:${p}`}>
                      {tag}:{p}
                    </Tag>
                  )),
                )}
              </dd>
            </div>
          </dl>
        </section>
      ))}
    </div>
  );
}

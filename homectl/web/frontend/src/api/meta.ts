export interface NavItem {
  label: string;
  path: string;
  page: string;
}

export interface DashboardWidget {
  type: string;
  host?: string;
  dataSource?: string;
  refreshMs?: number;
  config?: Record<string, unknown>;
}

export interface Dashboard {
  widgets: DashboardWidget[];
}

export interface UI {
  navigation: NavItem[];
  dashboard: Dashboard;
  featureFlags: Record<string, boolean>;
}

export interface HostInfo {
  hostname: string;
  roles: string[];
  bundles: string[];
  presets: string[];
  packageTags: string[];
  moduleFlags: Record<string, unknown>;
  packages: Record<string, string[]>;
}

export interface VMInfo {
  host: string;
  ip: string;
  mem: number;
  vcpu: number;
  autostart: boolean;
  tcpPorts: number[];
  udpPorts: number[];
  volumes: { mountPoint: string; size: number }[];
}

export interface Manifest {
  hosts: Record<string, HostInfo>;
  vms: Record<string, VMInfo>;
  deployNodes: Record<string, { hostname: string; sshUser: string }>;
  proxy: Record<string, { target: string }>;
}

export interface Meta {
  manifest: Manifest;
  ui: UI;
}

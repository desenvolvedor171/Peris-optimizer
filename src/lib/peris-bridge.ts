export interface SystemInfo {
  os: string; cpu: string; cpuCores: string; cpuThreads: string; cpuSocket: string; cpuTdp: string;
  cpuArch: string; gpu: string; gpuDriver: string; monitor: string; monitorRes: string; monitorHz: string;
  ramTotal: string; storage: string; manufacturer: string; bios: string; mbModel: string;
  disks: { letter: string; label: string; sizeGB: number; freeGB: number }[];
}

export interface HWStatus {
  cpuTemp: string; gpuTemp: string; gpuUse: string; gpuFan: string;
  ramUsed: string; ramTotal: string; vramUsed: string; vramTotal: string;
}

export interface LogEntry {
  level: "info" | "ok" | "warn" | "err" | "head";
  text: string;
  ts: number;
}

declare global {
  interface Window {
    electronAPI: {
      getSystemInfo: () => Promise<SystemInfo>;
      getHWStatus: () => Promise<HWStatus>;
      getCompleted: () => Promise<string[]>;
      saveCompleted: (ids: string[]) => void;
      getTweaksState: () => Promise<Record<string, boolean>>;
      saveTweaksState: (state: Record<string, boolean>) => void;
      runModule: (id: string, cb: (log: LogEntry) => void) => Promise<{ ok: boolean; restart?: boolean }>;
      closeApp: () => void;
      minimizeApp: () => void;
      restartPC: () => void;
    };
  }
}

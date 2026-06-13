import { useState, useEffect, useCallback, useRef } from "react";
import type { SystemInfo, HWStatus, LogEntry } from "./lib/peris-bridge";

const defaultSys: SystemInfo = {
  os: "Carregando...", cpu: "Carregando...", cpuCores: "Carregando...", cpuThreads: "Carregando...",
  cpuSocket: "Carregando...", cpuTdp: "Carregando...", cpuArch: "Carregando...", gpu: "Carregando...",
  gpuDriver: "Carregando...", monitor: "Carregando...", monitorRes: "Carregando...", monitorHz: "Carregando...",
  ramTotal: "Carregando...", storage: "Carregando...", manufacturer: "Carregando...", bios: "Carregando...", mbModel: "Carregando...",
  disks: []
};

const defaultHW: HWStatus = {
  cpuTemp: "--", gpuTemp: "--", gpuUse: "--", gpuFan: "--",
  ramUsed: "--", ramTotal: "--", vramUsed: "--", vramTotal: "--"
};

const Icon = ({ d, size = 20 }: { d: string; size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>
);

const icons: Record<string, string> = {
  backup: "M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10zM12 6v6l4 2",
  telemetria: "M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7zM12 9a3 3 0 100 6 3 3 0 000-6z",
  gaming: "M6 12h4m-2-2v4m5-1h.01M17 10h.01M6 18a2 2 0 01-2-2V8a2 2 0 012-2h12a2 2 0 012 2v8a2 2 0 01-2 2H6z",
  "desativar-apostado": "M18.36 6.64a9 9 0 11-12.73 0M12 2v10",
  bloatware: "M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16",
  power: "M13 2L3 14h9l-1 10 10-12h-9l1-10z",
  ui: "M4 6h16M4 12h16M4 18h16",
  menu: "M4 6h16M4 12h16M4 18h16",
  timer: "M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10zM12 6v6l3 3",
  inputlag: "M15 15l-2 5L9 9l11 4-5 2zm-2-2l7 7",
  ping: "M22 12h-4l-3 9L9 3l-3 9H2",
  cache: "M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15",
  gpu: "M4 4h16v16H4V4zm4 8h8m-8 4h4",
  memory: "M9 3v2m6-2v2M9 19v2m6-2v2M3 9h2m-2 6h2m14-6h2m-2 6h2M7 7h10v10H7V7z",
  disk: "M4 7V4h16v3M4 17v3h16v-3M4 7v10h16V7H4zm4 3h8m-8 4h4",
  gamemode: "M14.5 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V7.5L14.5 2zM12 18a2 2 0 100-4 2 2 0 000 4z",
  dns: "M12 2a10 10 0 100 20 10 10 0 000-20zM2 12h20M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z",
  scheduled: "M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z",
  spooler: "M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z",
  winupdate: "M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9",
  boot: "M13 2L3 14h9l-1 10 10-12h-9l1-10z",
  benchmark: "M16 8v8m-4-5v5m-4-2v2m-2 4h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z",
  profiles: "M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z",
  export: "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z",
  integrity: "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z",
  "defender-off": "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z",
};

const modules = [
  { id: "backup", name: "Ponto de RestauraÃ§Ã£o", desc: "Cria um restore point do sistema antes de aplicar qualquer tweak", color: "#3b82f6" },
  { id: "telemetria", name: "Telemetria", desc: "Desativa rastreamento Microsoft, Cortana, Widgets, Copilot e Teams", color: "#ef4444" },
  { id: "bloatware", name: "Bloatware", desc: "Remove Microsoft Edge, OneDrive, Teams e apps prÃ©-instalados do Windows", color: "#f97316" },
  { id: "power", name: "Plano de Energia", desc: "Ativa plano de alta performance e desativa hibernaÃ§Ã£o", color: "#eab308" },
  { id: "ui", name: "Interface", desc: "Desativa animaÃ§Ãµes, transparÃªncia, snapping e ativa modo noturno", color: "#ec4899" },
  { id: "startmenu-delay", name: "Menu Iniciar", desc: "Remove delay ao abrir menus e o menu iniciar", color: "#14b8a6" },
  { id: "monitor-05ms", name: "Timer 0.5ms", desc: "Ativa timer de alta precisÃ£o global e desativa HPET", color: "#06b6d4" },
  { id: "inputlag", name: "Input Lag", desc: "Otimiza prioridade de GPU, mouse e teclado para menor atraso", color: "#f43f5e" },
  { id: "ping", name: "Rede / TCP", desc: "Otimiza TCP/IP, reseta rede, configura DoH e desativa throttling", color: "#10b981" },
  { id: "cache", name: "Limpar Cache", desc: "Limpa temp, prefetch, DNS, crash dumps, Windows Update e lixeira", color: "#8b5cf6" },
  { id: "gpu-opt", name: "GPU", desc: "Ativa modo de performance mÃ¡xima na placa de vÃ­deo", color: "#d946ef" },
  { id: "memory", name: "MemÃ³ria RAM", desc: "Otimiza memÃ³ria, limpa standby e desativa compressÃ£o", color: "#6366f1" },
  { id: "disk-io", name: "Disco I/O", desc: "Otimiza TRIM, NTFS, verifica SMART e desativa indexaÃ§Ã£o", color: "#64748b" },
  { id: "gamemode", name: "Game Mode", desc: "Ativa modo jogo e configura Game Bar do Windows", color: "#84cc16" },
  { id: "dns-opt", name: "DNS RÃ¡pido", desc: "Configura DNS Cloudflare + Google para menor latÃªncia", color: "#0ea5e9" },
  { id: "scheduled", name: "Tarefas Agendadas", desc: "Desativa tarefas pesadas do Windows que consomem recursos", color: "#f59e0b" },
  { id: "spooler", name: "Spooler", desc: "Desativa serviÃ§o de impressÃ£o (libera recursos)", color: "#78716c" },
  { id: "winupdate", name: "Windows Update", desc: "Para e desativa atualizaÃ§Ãµes automÃ¡ticas do Windows", color: "#06b6d4" },
  { id: "boot", name: "Boot RÃ¡pido", desc: "Acelera inicializaÃ§Ã£o desativando timeout e log de boot", color: "#ef4444" },
  { id: "integrity", name: "Integridade", desc: "Executa SFC + DISM para verificar e corrigir arquivos do sistema", color: "#10b981" },
  { id: "defender-off", name: "Desativar Defender", desc: "Desativa Windows Defender completo incluindo Tamper Protection", color: "#ef4444" },
  { id: "gaming-services", name: "ServiÃ§os para apostado", desc: "Ativa serviÃ§os pra nÃ£o tomar W.O", color: "#a855f7" },
  { id: "desativar-apostado", name: "OtimizaÃ§Ã£o Agressiva", desc: "Desativa serviÃ§os pesados para mÃ¡ximo desempenho (pode causar W.O.)", color: "#f43f5e" },
];

type Tab = "sistema" | "tweaks";

function App() {
  const [tab, setTab] = useState<Tab>("sistema");
  const [tabAnim, setTabAnim] = useState<"in" | "out">("in");
  const [sys, setSys] = useState<SystemInfo>(defaultSys);
  const [hw, setHw] = useState<HWStatus>(defaultHW);
  const [completed, setCompleted] = useState<Set<string>>(new Set());
  const [running, setRunning] = useState<string | null>(null);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [needsRestart, setNeedsRestart] = useState(false);
  const [tooltip, setTooltip] = useState<{ mod: typeof modules[0]; x: number; y: number } | null>(null);
  const [clock, setClock] = useState("");
  const logEndRef = useRef<HTMLDivElement>(null);
  const pendingTab = useRef<Tab | null>(null);

  useEffect(() => {
    window.electronAPI.getSystemInfo().then(setSys).catch(() => {});
    window.electronAPI.getHWStatus().then(setHw).catch(() => {});
    window.electronAPI.getCompleted().then(c => {
      const validIds = new Set(modules.map(m => m.id));
      setCompleted(new Set(c.filter((id: string) => validIds.has(id))));
    }).catch(() => {});
    const iv = setInterval(() => { window.electronAPI.getHWStatus().then(setHw).catch(() => {}); }, 5000);
    const clockIv = setInterval(() => {
      const now = new Date();
      setClock(now.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" }));
    }, 1000);
    return () => { clearInterval(iv); clearInterval(clockIv); };
  }, []);

  useEffect(() => { logEndRef.current?.scrollIntoView({ behavior: "smooth" }); }, [logs]);

  const switchTab = useCallback((t: Tab) => {
    if (t === tab || tabAnim === "out") return;
    setTabAnim("out");
    pendingTab.current = t;
  }, [tab, tabAnim]);

  useEffect(() => {
    if (tabAnim === "out") {
      const t = setTimeout(() => {
        if (pendingTab.current) setTab(pendingTab.current);
        setTabAnim("in");
      }, 150);
      return () => clearTimeout(t);
    }
  }, [tabAnim]);

  const runModule = useCallback(async (id: string) => {
    if (running) return;
    const mod = modules.find(m => m.id === id);
    if (id === "desativar-apostado") {
      const confirmed = window.confirm(
        "Se vc joga apostado nÃ£o recomendo ativar, pois desliga os processos necessÃ¡rio e causa W.O, mas aumenta o desempenho e melhora a sensibilidade.\n\nDeseja continuar?"
      );
      if (!confirmed) return;
    } else if (id === "bloatware") {
      const confirmed = window.confirm(
        "SerÃ£o removidos do sistema:\n\n" +
        "â€¢ Microsoft Edge (remoÃ§Ã£o completa)\n" +
        "â€¢ Microsoft 3D Builder\n" +
        "â€¢ Bing Weather / News / Finance / Sports\n" +
        "â€¢ Get Help / Get Started\n" +
        "â€¢ SolitÃ¡rio Collection\n" +
        "â€¢ People / Skype\n" +
        "â€¢ Office Hub / OneConnect\n" +
        "â€¢ Windows Feedback Hub\n" +
        "â€¢ Zune Music / Video\n" +
        "â€¢ Windows Maps\n" +
        "â€¢ Mixed Reality Portal\n" +
        "â€¢ Xbox App / Game Overlay\n" +
        "â€¢ Your Phone / Alarms\n" +
        "â€¢ King.com / Disney / Spotify\n" +
        "â€¢ OneDrive\n\n" +
        "Deseja continuar?"
      );
      if (!confirmed) return;
    } else if (id === "defender-off") {
      const confirmed = window.confirm(
        "ATENÃ‡ÃƒO: Isso irÃ¡ desativar completamente o Windows Defender!\n\n" +
        "Seu sistema ficarÃ¡ sem proteÃ§Ã£o contra vÃ­rus e malware.\n" +
        "Recomendo instalar um antivÃ­rus alternativo antes de continuar.\n\n" +
        "Deseja continuar?"
      );
      if (!confirmed) return;
    } else if (completed.has(id)) {
      const confirmed = window.confirm(
        `"${mod?.name || id}" jÃ¡ foi aplicado!\n\nDeseja executar novamente?`
      );
      if (!confirmed) return;
    }
    setRunning(id);
    setLogs([]);
    const onLog = (log: LogEntry) => setLogs(prev => {
      if(log.level === "prog"){
        const updated = [...prev];
        if(updated.length > 0){ updated[updated.length - 1] = log; }
        else{ updated.push(log); }
        return updated;
      }
      return [...prev, log];
    });
    try {
      const result = await window.electronAPI.runModule(id, onLog);
      setCompleted(prev => {
        const nc = new Set(prev);
        nc.add(id);
        window.electronAPI.saveCompleted([...nc]);
        return nc;
      });
      if (result.restart) setNeedsRestart(true);
    } catch {
      setLogs(prev => [...prev, { level: "err", text: "Erro ao executar mÃ³dulo", ts: Date.now() }]);
    }
    setRunning(null);
  }, [running, completed]);

  const SysBlock = ({ title, items }: { title: string; items: { label: string; value: string }[] }) => (
    <div className="bg-[#12121c] border border-[#1e1e2e] rounded-xl p-4 hover:border-neon/20 transition-colors duration-300">
      <h3 className="text-neon font-bold text-xs mb-3 tracking-widest uppercase">{title}</h3>
      {items.map((item, i) => (
        <div key={i} className="flex justify-between items-center py-2 border-b border-[#1a1a2a] last:border-0">
          <span className="text-zinc-500 text-sm">{item.label}</span>
          <span className="text-white font-semibold text-sm text-right ml-4">{item.value}</span>
        </div>
      ))}
    </div>
  );

  return (
    <div className="h-screen flex flex-col select-none" style={{ background: "#08080f" }}>
      <div className="rgb-line h-[3px] shrink-0"></div>
      <header className="h-14 bg-[#0c0c14]/95 backdrop-blur-sm border-b border-[#1e1e2e] flex items-center justify-between px-5 shrink-0" style={{ WebkitAppRegion: "drag" } as any}>
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl flex items-center justify-center relative" style={{ background: "rgba(255,255,255,0.03)" }}>
            <div className="absolute inset-0 rounded-xl opacity-20" style={{ background: "radial-gradient(circle at center, #a855f7 0%, transparent 70%)" }}></div>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="relative z-10">
              <defs>
                <linearGradient id="rgb-bolt" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" stopColor="#ff0000"><animate attributeName="stop-color" values="#ff0000;#ff8800;#ffff00;#00ff00;#00ffff;#0088ff;#8800ff;#ff00ff;#ff0000" dur="3s" repeatCount="indefinite" /></stop>
                  <stop offset="25%" stopColor="#00ff00"><animate attributeName="stop-color" values="#00ff00;#00ffff;#0088ff;#8800ff;#ff00ff;#ff0000;#ff8800;#ffff00;#00ff00" dur="3s" repeatCount="indefinite" /></stop>
                  <stop offset="50%" stopColor="#0088ff"><animate attributeName="stop-color" values="#0088ff;#8800ff;#ff00ff;#ff0000;#ff8800;#ffff00;#00ff00;#00ffff;#0088ff" dur="3s" repeatCount="indefinite" /></stop>
                  <stop offset="75%" stopColor="#ff00ff"><animate attributeName="stop-color" values="#ff00ff;#ff0000;#ff8800;#ffff00;#00ff00;#00ffff;#0088ff;#8800ff;#ff00ff" dur="3s" repeatCount="indefinite" /></stop>
                  <stop offset="100%" stopColor="#ff8800"><animate attributeName="stop-color" values="#ff8800;#ffff00;#00ff00;#00ffff;#0088ff;#8800ff;#ff00ff;#ff0000;#ff8800" dur="3s" repeatCount="indefinite" /></stop>
                </linearGradient>
              </defs>
              <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" stroke="url(#rgb-bolt)" />
            </svg>
          </div>
          <div>
            <h1 className="text-lg font-black leading-none rgb-text tracking-widest" style={{ fontFamily: "'Segoe UI', sans-serif", letterSpacing: "0.15em" }}>PERIS FPS</h1>
            <p className="text-[10px] font-black tracking-[0.5em] rgb-text mt-0.5" style={{ fontFamily: "'Segoe UI', sans-serif" }}>OPTIMIZER</p>
          </div>
          <div className="h-6 w-px bg-[#2a2a3a] ml-2"></div>
          <span className="text-[10px] text-zinc-600 font-semibold tracking-wider">v2.2.0</span>
        </div>
        <div className="flex items-center gap-1.5" style={{ WebkitAppRegion: "no-drag" } as any}>
          <div className="flex items-center gap-1.5 px-2 py-1 rounded-lg bg-[#1a1a2a] border border-[#2a2a3a]">
            <svg width="13" height="13" viewBox="0 0 88 88" fill="none">
              <rect x="2" y="2" width="40" height="40" rx="2" fill="#a855f7"/>
              <rect x="46" y="2" width="40" height="40" rx="2" fill="#a855f7"/>
              <rect x="2" y="46" width="40" height="40" rx="2" fill="#a855f7"/>
              <rect x="46" y="46" width="40" height="40" rx="2" fill="#a855f7"/>
            </svg>
            <span className="text-[10px] text-zinc-400 font-bold tracking-wider">WINDOWS {sys.os !== "Carregando..." ? sys.os.match(/\d+/)?.[0] || "" : ""}</span>
          </div>
          <button onClick={() => window.electronAPI.minimizeApp()} className="w-7 h-7 rounded-lg bg-[#1a1a2a] hover:bg-[#25253a] flex items-center justify-center text-zinc-500 hover:text-white transition-all duration-200 border border-transparent hover:border-[#2a2a3a]">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="5" y1="12" x2="19" y2="12" /></svg>
          </button>
          <button onClick={() => window.electronAPI.closeApp()} className="w-7 h-7 rounded-lg bg-[#1a1a2a] hover:bg-red-600/80 flex items-center justify-center text-zinc-500 hover:text-white transition-all duration-200 border border-transparent hover:border-red-500/50">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
          </button>
        </div>
      </header>

      <nav className="flex gap-2 px-5 pt-3 pb-1 shrink-0">
        {([["sistema", "Sistema"], ["tweaks", "Tweaks"]] as [Tab, string][]).map(([t, label]) => (
          <button key={t} onClick={() => switchTab(t)}
            className={`px-5 py-2 rounded-lg text-sm font-bold tracking-wider transition-all duration-300 ${tab === t ? "bg-neon/15 text-neon border border-neon/30 shadow-[0_0_15px_rgba(168,85,247,0.15)]" : "text-zinc-500 hover:text-zinc-300 border border-transparent"}`}>
            {label}
          </button>
        ))}
      </nav>

      <main className="flex-1 overflow-y-auto px-5 pb-5 scroll-smooth" style={{ scrollBehavior: "smooth" }}>
        <div className={`transition-all duration-150 ${tabAnim === "in" ? "opacity-100 translate-y-0" : "opacity-0 translate-y-2"}`}>
          {tab === "sistema" && (
            <div className="space-y-3 pt-2">
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                <SysBlock title="Sistema Operacional" items={[
                  { label: "Sistema", value: sys.os },
                  { label: "Fabricante", value: sys.manufacturer },
                  { label: "Arquitetura", value: sys.cpuArch },
                ]} />
                <SysBlock title="Processador" items={[
                  { label: "CPU", value: sys.cpu },
                  { label: "NÃºcleos / Threads", value: `${sys.cpuCores} / ${sys.cpuThreads}` },
                  { label: "Socket", value: sys.cpuSocket },
                  { label: "FrequÃªncia", value: sys.cpuTdp },
                ]} />
                <SysBlock title="Placa de VÃ­deo" items={[
                  { label: "GPU", value: sys.gpu },
                  { label: "Driver", value: sys.gpuDriver },
                ]} />
                <SysBlock title="Monitor" items={[
                  { label: "Monitor", value: sys.monitor },
                  { label: "ResoluÃ§Ã£o", value: sys.monitorRes },
                  { label: "Taxa de AtualizaÃ§Ã£o", value: sys.monitorHz },
                ]} />
                <SysBlock title="MemÃ³ria RAM" items={[
                  { label: "Total", value: sys.ramTotal },
                ]} />
                <div className="bg-[#12121c] border border-[#1e1e2e] rounded-xl p-4 hover:border-neon/20 transition-colors duration-300">
                  <h3 className="text-neon font-bold text-xs mb-3 tracking-widest uppercase">Armazenamento</h3>
                  {sys.disks.length > 0 ? (
                    <div className="space-y-3">
                      {sys.disks.map((dk) => {
                        const usedPct = dk.sizeGB > 0 ? Math.round(((dk.sizeGB - dk.freeGB) / dk.sizeGB) * 100) : 0;
                        return (
                          <div key={dk.letter}>
                            <div className="flex justify-between items-center mb-1">
                              <span className="text-zinc-400 text-sm">{dk.letter}: {dk.label || "Disco Local"}</span>
                              <span className="text-white font-semibold text-sm">{dk.sizeGB} GB</span>
                            </div>
                            <div className="w-full h-1.5 bg-[#1a1a2a] rounded-full overflow-hidden">
                              <div className="h-full rounded-full transition-all duration-500" style={{ width: `${usedPct}%`, background: usedPct > 90 ? "#ef4444" : usedPct > 70 ? "#eab308" : "#a855f7" }} />
                            </div>
                            <div className="flex justify-between mt-0.5">
                              <span className="text-zinc-600 text-xs">{usedPct}% usado</span>
                              <span className="text-zinc-600 text-xs">{dk.freeGB} GB livre</span>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  ) : (
                    <div className="text-zinc-500 text-sm">{sys.storage}</div>
                  )}
                </div>
                <SysBlock title="Placa-MÃ£e" items={[
                  { label: "Modelo", value: sys.mbModel },
                  { label: "Fabricante", value: sys.manufacturer },
                  { label: "BIOS", value: sys.bios },
                ]} />
              </div>
            </div>
          )}

          {tab === "tweaks" && (
            <div className="flex gap-4 pt-2 h-full">
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between mb-3">
                  <p className="text-zinc-500 text-xs">{completed.size}/{modules.length} mÃ³dulos aplicados</p>
                  <div className="flex items-center gap-2">
                    {completed.size > 0 && (
                      <button onClick={async () => {
                        const modulesToRevert = [...completed];
                        const confirmed = window.confirm(
                          `SerÃ£o desfeitos ${modulesToRevert.length} mÃ³dulos aplicados:\n\n${modulesToRevert.map(id => modules.find(m => m.id === id)?.name || id).join(", ")}\n\nDeseja continuar?`
                        );
                        if (!confirmed) return;
                        setRunning("revert");
                        setLogs([]);
                        const onLog = (log: LogEntry) => setLogs(prev => [...prev, log]);
                        try {
                          const result = await window.electronAPI.revertModules(modulesToRevert, onLog);
                          setCompleted(new Set());
                          window.electronAPI.saveCompleted([]);
                          setNeedsRestart(!!result.restart);
                        } catch {
                          setLogs(prev => [...prev, { level: "err", text: "Erro ao desfazer mÃ³dulos", ts: Date.now() }]);
                        }
                        setRunning(null);
                      }}
                        disabled={!!running}
                        className="px-4 py-1.5 rounded-lg bg-red-950/30 border border-red-500/25 text-red-400 text-xs font-bold hover:bg-red-950/50 hover:border-red-500/40 transition-all duration-200 disabled:opacity-30">
                        Desfazer tudo
                      </button>
                    )}
                    <button onClick={async () => {
                      const excluded = ["desativar-apostado", "gaming-services", "defender-off", "integrity"];
                      let pending = modules.filter(m => !completed.has(m.id) && !excluded.includes(m.id));
                      if (pending.length === 0) { window.confirm("Todos os mÃ³dulos jÃ¡ foram aplicados!"); return; }

                      // Sempre garantir que backup rode primeiro
                      if(!completed.has("backup")){
                        const backupMod = modules.find(m => m.id === "backup")!;
                        pending = [backupMod, ...pending.filter(m => m.id !== "backup")];
                      }

                      const confirmed = window.confirm(
                        `SerÃ£o aplicados ${pending.length} mÃ³dulos.\n\nUm ponto de restauraÃ§Ã£o do sistema serÃ¡ criado automaticamente antes de iniciar.\n\nAs opÃ§Ãµes "OtimizaÃ§Ã£o Agressiva", "ServiÃ§os para apostado" e "Desativar Defender" nÃ£o serÃ£o usadas.\n\nDeseja continuar?`
                      );
                      if (!confirmed) return;

                      const currentCompleted = new Set(completed);

                      for(let i = 0; i < pending.length; i++){
                        const id = pending[i].id;
                        const mod = pending[i];

                        // Confirmacoes por modulo
                        if(id === "desativar-apostado"){
                          if(!window.confirm("Se vc joga apostado nÃ£o recomendo ativar...\n\nDeseja continuar?")) continue;
                        }else if(id === "bloatware"){
                          if(!window.confirm("SerÃ£o removidos: Edge, OneDrive, Teams, apps prÃ©-instalados...\n\nDeseja continuar?")) continue;
                        }else if(id === "defender-off"){
                          if(!window.confirm("ATENÃ‡ÃƒO: Isso irÃ¡ desativar completamente o Windows Defender!\n\nDeseja continuar?")) continue;
                        }else if(currentCompleted.has(id)){
                          if(!window.confirm(`"${mod.name}" jÃ¡ foi aplicado!\n\nDeseja executar novamente?`)) continue;
                        }

                        setRunning(id);
                        setLogs([]);
                        const onLog = (log: LogEntry) => setLogs(prev => {
                          if(log.level === "prog"){
                            const updated = [...prev];
                            if(updated.length > 0){ updated[updated.length - 1] = log; }
                            else{ updated.push(log); }
                            return updated;
                          }
                          return [...prev, log];
                        });
                        try{
                          const result = await window.electronAPI.runModule(id, onLog);
                          currentCompleted.add(id);
                          setCompleted(new Set(currentCompleted));
                          window.electronAPI.saveCompleted([...currentCompleted]);
                          if(result.restart) setNeedsRestart(true);
                        }catch{
                          setLogs(prev => [...prev, { level: "err", text: "Erro ao executar mÃ³dulo", ts: Date.now() }]);
                        }
                        setRunning(null);
                      }
                    }}
                      disabled={!!running}
                      className="px-4 py-1.5 rounded-lg bg-neon/10 border border-neon/25 text-neon text-xs font-bold hover:bg-neon/20 transition-all duration-200 disabled:opacity-30">
                      Usar todos os mÃ³dulos
                    </button>
                  </div>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2">
                  {modules.map(mod => {
                    const done = completed.has(mod.id);
                    const isRunning = running === mod.id;
                    return (
                      <button key={mod.id} onClick={() => runModule(mod.id)} disabled={!!running}
                        onContextMenu={(e) => {
                          e.preventDefault();
                          if(!done || running) return;
                          const confirmed = window.confirm(`Deseja desfazer o mÃ³dulo "${mod.name}"?`);
                          if(!confirmed) return;
                          setRunning("revert");
                          setLogs([]);
                          const onLog = (log: LogEntry) => setLogs(prev => [...prev, log]);
                          window.electronAPI.revertModules([mod.id], onLog).then((result) => {
                            setCompleted(prev => {
                              const nc = new Set(prev);
                              nc.delete(mod.id);
                              window.electronAPI.saveCompleted([...nc]);
                              return nc;
                            });
                            setNeedsRestart(!!result.restart);
                          }).catch(() => {
                            setLogs(prev => [...prev, { level: "err", text: "Erro ao desfazer mÃ³dulo", ts: Date.now() }]);
                          }).finally(() => setRunning(null));
                        }}
                        onMouseEnter={(e) => {
                          const rect = e.currentTarget.getBoundingClientRect();
                          const tooltipWidth = 280;
                          const centerX = window.innerWidth / 2;
                          const isRightHalf = rect.left > centerX;
                          setTooltip({ mod, x: isRightHalf ? rect.left - tooltipWidth - 12 : rect.right + 12, y: rect.top });
                        }}
                        onMouseMove={(e) => {
                          const rect = e.currentTarget.getBoundingClientRect();
                          const tooltipWidth = 280;
                          const centerX = window.innerWidth / 2;
                          const isRightHalf = rect.left > centerX;
                          setTooltip({ mod, x: isRightHalf ? rect.left - tooltipWidth - 12 : rect.right + 12, y: rect.top });
                        }}
                        onMouseLeave={() => setTooltip(null)}
                        className={`group relative flex items-center gap-3 p-3 rounded-xl border text-left transition-all duration-300
                          ${done ? "bg-emerald-950/20 border-emerald-500/30 hover:border-emerald-400/50" :
                            isRunning ? "bg-neon/5 border-neon/40 animate-pulse" :
                            "bg-[#11111b] border-[#1e1e2e] hover:border-[#2a2a3e] hover:bg-[#15151f]"}`}
                        style={!done && !isRunning ? { borderLeftColor: mod.color, borderLeftWidth: "3px" } : {}}>
                        {done && (
                          <div className="absolute top-2 right-2 w-4 h-4 rounded-full bg-emerald-500 flex items-center justify-center">
                            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3"><polyline points="20 6 9 17 4 12" /></svg>
                          </div>
                        )}
                        <div className="w-9 h-9 rounded-lg flex items-center justify-center shrink-0 transition-colors duration-200"
                          style={{ background: done ? "rgba(16,185,129,0.15)" : isRunning ? "rgba(168,85,247,0.15)" : `${mod.color}15` }}>
                          <span style={{ color: done ? "#10b981" : isRunning ? "#a855f7" : mod.color }}>
                            <Icon d={icons[mod.id] || icons.backup} size={18} />
                          </span>
                        </div>
                        <div className="flex-1 min-w-0">
                          <h4 className={`font-semibold text-sm leading-tight ${done ? "text-emerald-300" : "text-zinc-200"}`}>{mod.name}</h4>
                          <p className="text-zinc-400 text-xs mt-0.5 truncate">{mod.desc}</p>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>

              <div className="w-72 shrink-0 flex flex-col gap-3" style={{ maxHeight: "calc(100vh - 80px)" }}>
                {needsRestart && (
                  <div className="flex items-center gap-3 p-3 bg-red-950/30 border border-red-500/30 rounded-xl">
                    <div className="flex-1">
                      <p className="text-red-300 text-sm font-bold">Reiniciar</p>
                      <p className="text-red-400/60 text-[10px]">AlteraÃ§Ãµes sÃ³ terÃ£o efeito apÃ³s reiniciar</p>
                    </div>
                    <button onClick={() => {
                      if (window.confirm("Tem certeza que deseja reiniciar o PC agora?")) {
                        window.electronAPI.restartPC();
                      }
                    }}
                      className="px-4 py-2 rounded-lg bg-red-600 hover:bg-red-500 text-white text-xs font-bold transition-all duration-200 shadow-[0_0_20px_rgba(239,68,68,0.3)] hover:shadow-[0_0_30px_rgba(239,68,68,0.5)]">
                      Reiniciar PC
                    </button>
                  </div>
                )}

                <div className="bg-[#0c0c14] border border-[#1a1a2a] rounded-xl p-3 overflow-hidden flex flex-col" style={{ maxHeight: "calc(100vh - 120px)" }}>
                  <div className="flex items-center gap-2.5 pb-2 border-b border-[#1a1a2a]">
                    <div className={`w-2.5 h-2.5 rounded-full transition-all duration-300 ${running ? "bg-emerald-300 shadow-[0_0_10px_rgba(110,231,183,0.9),0_0_20px_rgba(52,211,153,0.5)]" : "bg-red-500 shadow-[0_0_10px_rgba(239,68,68,0.9),0_0_20px_rgba(220,38,38,0.5)]"}`}></div>
                    <h4 className="text-white font-bold text-xs tracking-wider uppercase">Log</h4>
                    {running && <span className="text-[10px] text-emerald-400/80 font-semibold ml-auto">{running === "revert" ? "revertendo..." : "executando..."}</span>}
                  </div>
                  <div className="flex-1 overflow-y-auto space-y-0.5" style={{ scrollBehavior: "smooth", maxHeight: "calc(100vh - 160px)" }}>
                    {logs.map((log, i) => (
                      <div key={i} className={`text-[11px] py-0.5 font-mono leading-relaxed transition-all duration-200 ${
                        log.level === "err" ? "text-red-400" : log.level === "warn" ? "text-yellow-400" :
                        log.level === "ok" ? "text-emerald-400" : log.level === "head" ? "text-neon font-bold" :
                        log.level === "prog" ? "text-cyan-400 log-progress" : "text-zinc-500"
                      }`} style={{ animation: log.level !== "prog" ? "fadeInLog 0.2s ease-out" : undefined }}>{log.text}</div>
                    ))}
                    <div ref={logEndRef} />
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </main>

      {tooltip && (
        <div
          className="fixed z-50 pointer-events-none"
          style={{ left: tooltip.x, top: tooltip.y }}
        >
          <div className="bg-[#12121c] border border-neon/30 rounded-xl p-4 shadow-[0_0_20px_rgba(168,85,247,0.2)] max-w-xs" style={{ animation: "fadeIn 0.15s ease-out" }}>
            <div className="flex items-center gap-2 mb-2">
              <div className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: `${tooltip.mod.color}20` }}>
                <span style={{ color: tooltip.mod.color }}>
                  <Icon d={icons[tooltip.mod.id] || icons.backup} size={14} />
                </span>
              </div>
              <h4 className="text-white font-bold text-sm">{tooltip.mod.name}</h4>
            </div>
            <p className="text-zinc-400 text-xs leading-relaxed">{tooltip.mod.desc}</p>
            <div className="mt-2 pt-2 border-t border-[#1e1e2e]">
              {completed.has(tooltip.mod.id) ? (
                <p className="text-red-400/80 text-[10px] font-semibold tracking-wider uppercase">Clique direito para desfazer</p>
              ) : (
                <p className="text-neon/60 text-[10px] font-semibold tracking-wider uppercase">Clique para executar</p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;

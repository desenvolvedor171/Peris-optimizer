const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("path");
const fs = require("fs");
const { spawn } = require("child_process");

let mainWindow;

const DATA = path.join(app.getPath("userData"));
const COMP = path.join(DATA, "completed.json");
const TWK = path.join(DATA, "tweaks.json");
const SCRIPTS = path.join(DATA, "scripts");

function ensureScripts() {
  if (!fs.existsSync(SCRIPTS)) fs.mkdirSync(SCRIPTS, { recursive: true });
  const src = __dirname;
  for (const f of ["sys-info.ps1", "hw-status.ps1", "peris-tweaks.ps1", "peris-revert.ps1"]) {
    const srcPath = path.join(src, f);
    const dstPath = path.join(SCRIPTS, f);
    if (fs.existsSync(srcPath)) fs.copyFileSync(srcPath, dstPath);
  }
}
ensureScripts();

function rj(f, d) { try { return JSON.parse(fs.readFileSync(f, "utf-8")); } catch { return d; } }
function wj(f, d) { if (!fs.existsSync(DATA)) fs.mkdirSync(DATA, { recursive: true }); fs.writeFileSync(f, JSON.stringify(d, null, 2)); }

function psFile(scriptPath) {
  return new Promise((resolve) => {
    let out = "";
    const p = spawn("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", scriptPath], { shell: true, windowsHide: true });
    p.stdout.on("data", (d) => { out += d.toString(); });
    p.on("close", () => resolve(out.trim()));
    p.on("error", () => resolve(""));
    setTimeout(() => { try { p.kill(); } catch {} resolve(""); }, 12000);
  });
}

function runPS(mod, ch) {
  return new Promise((resolve, reject) => {
    const psScript = path.join(SCRIPTS, "peris-tweaks.ps1");
    const p = spawn("powershell.exe", ["-ExecutionPolicy", "Bypass", "-NoProfile", "-File", psScript, "-Module", mod], { shell: true });
    let needsRestart = false;
    const listener = (d) => {
      const raw = d.toString();
      const clean = raw.replace(/\x1b\[[0-9;]*m/g, "");
      clean.split("\n").filter((l) => l.trim()).forEach((line) => {
        let level = "info";
        let text = line.trim();
        if (text === "[RESTART]") { needsRestart = true; return; }
        if (text.startsWith("[HEAD]")) { level = "head"; text = text.replace("[HEAD]", "").trim(); }
        else if (text.startsWith("[OK]")) { level = "ok"; text = text.replace("[OK]", "").trim(); }
        else if (text.startsWith("[WARN]")) { level = "warn"; text = text.replace("[WARN]", "").trim(); }
        else if (text.startsWith("[ERR]")) { level = "err"; text = text.replace("[ERR]", "").trim(); }
        if (text && mainWindow) mainWindow.webContents.send(ch, { level, text, ts: Date.now() });
      });
    };
    const errListener = (d) => {
      const text = d.toString().trim().replace(/\x1b\[[0-9;]*m/g, "");
      if (text && mainWindow) mainWindow.webContents.send(ch, { level: "err", text, ts: Date.now() });
    };
    p.stdout.on("data", listener);
    p.stderr.on("data", errListener);
    const cleanup = () => {
      p.stdout.off("data", listener);
      p.stderr.off("data", errListener);
    };
    p.on("close", (c) => { cleanup(); c === 0 ? resolve({ ok: true, restart: needsRestart }) : reject(new Error(`exit ${c}`)); });
    p.on("error", (e) => { cleanup(); reject(e); });
  });
}

const emptySys = {
  os: "N/A", cpu: "N/A", cpuCores: "N/A", cpuThreads: "N/A", cpuArch: "N/A", cpuSocket: "N/A", cpuTdp: "N/A",
  gpu: "N/A", gpuDriver: "N/A", monitor: "N/A", monitorRes: "N/A", monitorHz: "N/A",
  ramTotal: "N/A", storage: "N/A", manufacturer: "N/A", bios: "N/A", mbModel: "N/A", disks: [],
};
const emptyHW = { cpuTemp: "--", gpuTemp: "--", gpuUse: "--", gpuFan: "--", ramUsed: "--", ramTotal: "--", vramUsed: "--", vramTotal: "--" };

ipcMain.handle("getSystemInfo", async () => {
  const raw = await psFile(path.join(SCRIPTS, "sys-info.ps1"));
  try {
    const d = JSON.parse(raw);
    const archMap = { "9": "x64", "0": "x86", "12": "ARM64" };
    return {
      os: d.os || "N/A", cpu: d.cpu || "N/A", cpuCores: String(d.cores || "N/A"), cpuThreads: String(d.threads || "N/A"),
      cpuArch: archMap[String(d.arch)] || String(d.arch || "N/A"), cpuSocket: d.socket || "N/A", cpuTdp: d.tdp ? `${d.tdp} GHz` : "N/A",
      gpu: d.gpu || "N/A", gpuDriver: d.driver || "N/A",
      monitor: d.mon || "N/A", monitorRes: d.res || "N/A", monitorHz: d.hz || "N/A",
      ramTotal: d.ram ? `${d.ram} GB` : "N/A", storage: d.disk || "N/A", manufacturer: d.mfr || "N/A", bios: d.bios || "N/A",
      mbModel: d.mb || "N/A", disks: Array.isArray(d.disks) ? d.disks.map((dk) => ({ letter: dk.letter || "", label: dk.label || "", sizeGB: dk.sizeGB || 0, freeGB: dk.freeGB || 0 })) : [],
    };
  } catch { return emptySys; }
});

ipcMain.handle("getHWStatus", async () => {
  const raw = await psFile(path.join(SCRIPTS, "hw-status.ps1"));
  try {
    const d = JSON.parse(raw);
    return {
      cpuTemp: d.ct != null ? String(d.ct) : "--", gpuTemp: d.gt || "--", gpuUse: d.gu || "--", gpuFan: d.gf || "--",
      ramUsed: d.ramU != null ? String(d.ramU) : "--", ramTotal: d.ramT != null ? String(d.ramT) : "--",
      vramUsed: d.vu || "--", vramTotal: d.vt || "--",
    };
  } catch { return emptyHW; }
});

ipcMain.handle("getCompleted", () => rj(COMP, []));
ipcMain.on("saveCompleted", (_, ids) => wj(COMP, ids));
ipcMain.handle("getTweaksState", () => rj(TWK, {}));
ipcMain.on("saveTweaksState", (_, s) => wj(TWK, s));
ipcMain.handle("runModule", (_, id, ch) => runPS(id, ch));
ipcMain.handle("revertModules", async (_, modules, ch) => {
  return new Promise((resolve, reject) => {
    const psScript = path.join(SCRIPTS, "peris-revert.ps1");
    const args = ["-ExecutionPolicy", "Bypass", "-NoProfile", "-File", psScript, "-Modules"];
    modules.forEach(m => args.push(m));
    const p = spawn("powershell.exe", args, { shell: true });
    const listener = (d) => {
      const raw = d.toString("utf-8");
      const clean = raw.replace(/\x1b\[[0-9;]*m/g, "");
      clean.split("\n").filter((l) => l.trim()).forEach((line) => {
        let level = "info";
        let text = line.trim();
        if (text === "[RESTART]") return;
        if (text.startsWith("[HEAD]")) { level = "head"; text = text.replace("[HEAD]", "").trim(); }
        else if (text.startsWith("[OK]")) { level = "ok"; text = text.replace("[OK]", "").trim(); }
        else if (text.startsWith("[WARN]")) { level = "warn"; text = text.replace("[WARN]", "").trim(); }
        else if (text.startsWith("[ERR]")) { level = "err"; text = text.replace("[ERR]", "").trim(); }
        if (text && mainWindow) mainWindow.webContents.send(ch, { level, text, ts: Date.now() });
      });
    };
    const errListener = (d) => {
      const text = d.toString("utf-8").trim().replace(/\x1b\[[0-9;]*m/g, "");
      if (text && mainWindow) mainWindow.webContents.send(ch, { level: "err", text, ts: Date.now() });
    };
    p.stdout.on("data", listener);
    p.stderr.on("data", errListener);
    p.on("close", (c) => { p.stdout.off("data", listener); p.stderr.off("data", errListener); c === 0 ? resolve({ ok: true }) : reject(new Error(`exit ${c}`)); });
    p.on("error", (e) => { p.stdout.off("data", listener); p.stderr.off("data", errListener); reject(e); });
  });
});
ipcMain.on("closeApp", () => { if (mainWindow) mainWindow.close(); });
ipcMain.on("minimizeApp", () => { if (mainWindow) mainWindow.minimize(); });
ipcMain.on("restartPC", () => {
  spawn("shutdown", ["/r", "/t", "0"], { shell: true });
});

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280, height: 820, minWidth: 900, minHeight: 600, frame: false,
    transparent: true,
    backgroundColor: "#00000000",
    webPreferences: { preload: path.join(__dirname, "preload.cjs"), contextIsolation: true, nodeIntegration: false },
    icon: path.join(__dirname, "icon.ico"),
  });
  mainWindow.loadFile(path.join(__dirname, "..", "electron-dist", "index.html"));
  mainWindow.on("closed", () => { mainWindow = null; });
}

app.whenReady().then(createWindow);
app.on("window-all-closed", () => app.quit());

const { contextBridge, ipcRenderer } = require("electron");
contextBridge.exposeInMainWorld("electronAPI", {
  getSystemInfo: () => ipcRenderer.invoke("getSystemInfo"),
  getHWStatus: () => ipcRenderer.invoke("getHWStatus"),
  getCompleted: () => ipcRenderer.invoke("getCompleted"),
  saveCompleted: (ids) => ipcRenderer.send("saveCompleted", ids),
  getTweaksState: () => ipcRenderer.invoke("getTweaksState"),
  saveTweaksState: (state) => ipcRenderer.send("saveTweaksState", state),
  runModule: (id, cb) => {
    const ch = `log-${id}-${Date.now()}`;
    const handler = (_, log) => cb(log);
    ipcRenderer.on(ch, handler);
    return ipcRenderer.invoke("runModule", id, ch).finally(() => {
      ipcRenderer.removeListener(ch, handler);
    });
  },
  revertModules: (modules, cb) => {
    const ch = `log-revert-${Date.now()}`;
    const handler = (_, log) => cb(log);
    ipcRenderer.on(ch, handler);
    return ipcRenderer.invoke("revertModules", modules, ch).finally(() => {
      ipcRenderer.removeListener(ch, handler);
    });
  },
  closeApp: () => ipcRenderer.send("closeApp"),
  minimizeApp: () => ipcRenderer.send("minimizeApp"),
  restartPC: () => ipcRenderer.send("restartPC"),
});

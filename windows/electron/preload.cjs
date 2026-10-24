const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('studylab', {
  platform: process.platform,
  setProgress: fraction => ipcRenderer.send('progress', fraction),
  setKeepInTray: on => ipcRenderer.send('keep-in-tray', !!on),
  setLaunchAtLogin: on => ipcRenderer.send('launch-at-login', !!on),
  setTheme: theme => ipcRenderer.send('theme', theme)
})

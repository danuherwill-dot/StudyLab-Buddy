const { app, BrowserWindow, Tray, Menu, ipcMain, nativeImage, shell } = require('electron')
const fs = require('fs')
const path = require('path')

const isDev = !app.isPackaged && process.env.STUDYLAB_DEV === '1'
const THEME = { dark: { bg: '#070a18', symbol: '#c5cbe0' }, light: { bg: '#eef1fb', symbol: '#2a3350' } }

app.setAppUserModelId('pt.studylab.app')

if (!app.requestSingleInstanceLock()) {
  app.quit()
}

let win = null
let tray = null
let quitting = false
let keepInTray = true

function createWindow() {
  win = new BrowserWindow({
    width: 1240,
    height: 820,
    minWidth: 940,
    minHeight: 640,
    show: false,
    title: 'StudyLab',
    backgroundColor: THEME.dark.bg,
    icon: path.join(__dirname, 'icon.png'),
    autoHideMenuBar: true,
    titleBarStyle: 'hidden',
    titleBarOverlay: { color: '#00000000', symbolColor: THEME.dark.symbol, height: 40 },
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      backgroundThrottling: false // keep the study timer ticking while the window is hidden
    }
  })
  win.removeMenu()

  win.once('ready-to-show', () => win.show())
  win.on('close', event => {
    if (!quitting && keepInTray) {
      event.preventDefault()
      win.hide()
    }
  })
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:/.test(url)) shell.openExternal(url)
    return { action: 'deny' }
  })

  if (isDev) win.loadURL('http://127.0.0.1:5173')
  else win.loadFile(path.join(__dirname, '..', 'dist', 'index.html'))

  // Development helper: save a screenshot of the window and quit.
  if (process.env.STUDYLAB_SNAPSHOT) {
    win.webContents.once('did-finish-load', () => {
      setTimeout(async () => {
        const image = await win.webContents.capturePage()
        fs.writeFileSync(process.env.STUDYLAB_SNAPSHOT, image.toPNG())
        quitting = true
        app.quit()
      }, 1800)
    })
  }
}

function showWindow() {
  if (!win) return createWindow()
  if (win.isMinimized()) win.restore()
  win.show()
  win.focus()
}

function createTray() {
  const icon = nativeImage.createFromPath(path.join(__dirname, 'tray.png'))
  tray = new Tray(icon)
  tray.setToolTip('StudyLab')
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: 'Abrir StudyLab', click: showWindow },
    { type: 'separator' },
    { label: 'Sair', click: () => { quitting = true; app.quit() } }
  ]))
  tray.on('click', showWindow)
}

app.on('second-instance', showWindow)
app.on('before-quit', () => { quitting = true })
app.on('window-all-closed', () => { if (quitting) app.quit() })

app.whenReady().then(() => {
  Menu.setApplicationMenu(null)
  createWindow()
  if (!process.env.STUDYLAB_SNAPSHOT) createTray()
  app.on('activate', showWindow)
})

ipcMain.on('progress', (_event, fraction) => {
  if (win) win.setProgressBar(typeof fraction === 'number' && fraction >= 0 ? Math.min(1, fraction) : -1)
})
ipcMain.on('keep-in-tray', (_event, on) => { keepInTray = !!on })
ipcMain.on('launch-at-login', (_event, on) => {
  if (app.isPackaged) app.setLoginItemSettings({ openAtLogin: !!on, args: ['--hidden'] })
})
ipcMain.on('theme', (_event, theme) => {
  const t = THEME[theme] || THEME.dark
  if (win && process.platform === 'win32') {
    try { win.setTitleBarOverlay({ color: '#00000000', symbolColor: t.symbol, height: 40 }) } catch { /* not supported */ }
  }
  if (win) win.setBackgroundColor(t.bg)
})

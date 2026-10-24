interface Window {
  studylab?: {
    platform: string
    setProgress: (fraction: number) => void
    setKeepInTray: (on: boolean) => void
    setLaunchAtLogin: (on: boolean) => void
    setTheme: (theme: 'light' | 'dark') => void
  }
}

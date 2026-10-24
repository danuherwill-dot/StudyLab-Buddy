import { useEffect, useState } from 'react'
import { StoreProvider, useStore, useActions } from './store'
import { TimerProvider, useTimer } from './timer'
import { UI, type Page } from './ui-context'
import { Icon, type IconName } from './components/Icon'
import { cx } from './components/ui'
import { ensureNotificationPermission, notify, reminderPlan } from './notify'
import StudyPage from './pages/Study'
import TimetablePage from './pages/Timetable'
import TasksPage from './pages/Tasks'
import StatsPage from './pages/Stats'
import GradesPage from './pages/Grades'
import SettingsPage from './pages/Settings'
import { SubjectsModal } from './pages/Subjects'

const NAV: { page: Page; label: string; icon: IconName }[] = [
  { page: 'study', label: 'Estudo', icon: 'timer' },
  { page: 'timetable', label: 'Horário', icon: 'calendar' },
  { page: 'tasks', label: 'Tarefas', icon: 'checklist' },
  { page: 'stats', label: 'Estatísticas', icon: 'chart' },
  { page: 'grades', label: 'Notas', icon: 'cap' }
]

function useTheme(choice: 'system' | 'light' | 'dark') {
  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    const apply = () => {
      const resolved = choice === 'system' ? (mq.matches ? 'dark' : 'light') : choice
      document.documentElement.dataset.theme = resolved
      window.studylab?.setTheme(resolved)
    }
    apply()
    mq.addEventListener('change', apply)
    return () => mq.removeEventListener('change', apply)
  }, [choice])
}

/** Shows task reminders while the app (or its tray icon) is running. */
function useReminders() {
  const { db, update } = useStore()
  useEffect(() => {
    if (!db.settings.taskReminders) return
    const check = () => {
      const now = Date.now()
      const fired: { id: string; index: number }[] = []
      for (const task of db.tasks) {
        if (!task.remind || task.done) continue
        const due = new Date(task.due).getTime()
        reminderPlan(task.type).forEach((r, index) => {
          const at = due - r.lead
          if (now >= at && now - at < 12 * 3_600_000 && !task.notified.includes(index)) {
            const subject = db.subjects.find(s => s.id === task.subjectId)?.name
            notify(r.title, [subject, task.title].filter(Boolean).join(' · '))
            fired.push({ id: task.id, index })
          }
        })
      }
      if (fired.length) {
        update(d => ({
          ...d,
          tasks: d.tasks.map(t => {
            const mine = fired.filter(f => f.id === t.id).map(f => f.index)
            return mine.length ? { ...t, notified: [...new Set([...t.notified, ...mine])] } : t
          })
        }))
      }
    }
    check()
    const id = window.setInterval(check, 30_000)
    return () => window.clearInterval(id)
  }, [db.tasks, db.subjects, db.settings.taskReminders, update])
}

function Shell() {
  const { db } = useStore()
  const actions = useActions()
  const timer = useTimer()
  const [page, setPage] = useState<Page>('study')
  const [subjectsOpen, setSubjectsOpen] = useState(false)

  useTheme(db.settings.theme)
  useReminders()

  useEffect(() => { void ensureNotificationPermission() }, [])
  useEffect(() => {
    window.studylab?.setKeepInTray(db.settings.keepInTray)
    window.studylab?.setLaunchAtLogin(db.settings.launchAtLogin)
  }, [db.settings.keepInTray, db.settings.launchAtLogin])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!(e.ctrlKey || e.metaKey) || e.altKey) return
      const n = Number(e.key)
      if (n >= 1 && n <= NAV.length) { e.preventDefault(); setPage(NAV[n - 1].page) }
      if (e.key === ',') { e.preventDefault(); setPage('settings') }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  void actions
  const ctx = { page, go: setPage, openSubjects: () => setSubjectsOpen(true) }

  return (
    <UI.Provider value={ctx}>
      <div className="app">
        <div className="drag" />
        <aside className="sidebar">
          <div className="brand">
            <img src="./star.png" alt="" />
            <span>StudyLab Buddy</span>
          </div>
          <nav>
            {NAV.map((n, i) => (
              <button key={n.page} className={cx('nav-item', page === n.page && 'active')} onClick={() => setPage(n.page)} title={`Ctrl+${i + 1}`}>
                <Icon name={n.icon} size={20} />
                <span>{n.label}</span>
                {n.page === 'study' && timer.active && <i className="live-dot" />}
              </button>
            ))}
          </nav>
          <div className="grow" />
          <button className="nav-item" onClick={() => setSubjectsOpen(true)}>
            <Icon name="books" size={20} /><span>Disciplinas</span>
          </button>
          <button className={cx('nav-item', page === 'settings' && 'active')} onClick={() => setPage('settings')} title="Ctrl+,">
            <Icon name="gear" size={20} /><span>Definições</span>
          </button>
        </aside>
        <main className="main">
          <div className="page" key={page}>
            {page === 'study' && <StudyPage />}
            {page === 'timetable' && <TimetablePage />}
            {page === 'tasks' && <TasksPage />}
            {page === 'stats' && <StatsPage />}
            {page === 'grades' && <GradesPage />}
            {page === 'settings' && <SettingsPage />}
          </div>
        </main>
        {timer.toast && <div className="toast"><Icon name="check" size={18} />{timer.toast}</div>}
        {subjectsOpen && <SubjectsModal onClose={() => setSubjectsOpen(false)} />}
      </div>
    </UI.Provider>
  )
}

export default function App() {
  return (
    <StoreProvider>
      <TimerProvider>
        <Shell />
      </TimerProvider>
    </StoreProvider>
  )
}

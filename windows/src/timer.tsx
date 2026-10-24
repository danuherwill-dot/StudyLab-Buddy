import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { useStore } from './store'
import { notify } from './notify'
import { clock, shortDur, uid } from './format'

export type Mode = 'clock' | 'pomodoro' | 'stopwatch' | 'countdown'
export type Phase = 'focus' | 'short' | 'long'
export type RunState = 'idle' | 'running' | 'paused'
export interface ChecklistItem { id: string; title: string; done: boolean }

const MIN_LOGGABLE = 5

interface TimerCtx {
  mode: Mode; setMode: (m: Mode) => void
  subjectId: string | null; setSubjectId: (id: string | null) => void
  focusMin: number; shortMin: number; longMin: number; countdownMin: number
  setDuration: (key: 'focusMin' | 'shortMin' | 'longMin' | 'countdownMin', v: number) => void
  state: RunState; phase: Phase; completed: number
  elapsed: number; displaySeconds: number; ringProgress: number; statusLabel: string
  active: boolean
  checklist: ChecklistItem[]
  addItem: (t: string) => void; toggleItem: (id: string) => void; removeItem: (id: string) => void
  start: () => void; pause: () => void; finish: () => void; discard: () => void; skipBreak: () => void
  subjectRequired: boolean; dismissSubjectRequired: () => void
  toast: string | null
}

const Ctx = createContext<TimerCtx | null>(null)
export const useTimer = () => { const c = useContext(Ctx); if (!c) throw new Error('TimerProvider missing'); return c }

export function TimerProvider({ children }: { children: ReactNode }) {
  const { db, update } = useStore()
  const dbRef = useRef(db); dbRef.current = db

  const [mode, setModeState] = useState<Mode>('pomodoro')
  const [subjectId, setSubjectId] = useState<string | null>(null)
  const [dur, setDur] = useState({ focusMin: 25, shortMin: 5, longMin: 15, countdownMin: 30 })
  const [state, setState] = useState<RunState>('idle')
  const [phase, setPhase] = useState<Phase>('focus')
  const [completed, setCompleted] = useState(0)
  const [elapsed, setElapsed] = useState(0)
  const [checklist, setChecklist] = useState<ChecklistItem[]>([])
  const [subjectRequired, setSubjectRequired] = useState(false)
  const [toast, setToast] = useState<string | null>(null)

  const accumulated = useRef(0)
  const segmentStart = useRef<number | null>(null)
  const latest = useRef({ mode, phase, dur, subjectId, checklist, completed, state })
  latest.current = { mode, phase, dur, subjectId, checklist, completed, state }

  const phaseDuration = useCallback((m: Mode, p: Phase, d = latest.current.dur): number | null => {
    if (m === 'countdown') return d.countdownMin * 60
    if (m === 'pomodoro') return (p === 'focus' ? d.focusMin : p === 'short' ? d.shortMin : d.longMin) * 60
    return null
  }, [])

  const showToast = (message: string) => {
    setToast(message)
    window.setTimeout(() => setToast(cur => (cur === message ? null : cur)), 3500)
  }

  const logSession = (seconds: number) => {
    const { subjectId: sid, checklist: list } = latest.current
    const subject = dbRef.current.subjects.find(s => s.id === sid)
    if (seconds < MIN_LOGGABLE || !subject) return
    const notes = list.map(i => `${i.done ? '✓' : '○'} ${i.title}`).join('\n')
    update(d => ({
      ...d,
      sessions: [...d.sessions, { id: uid(), subjectId: subject.id, seconds: Math.round(seconds), date: new Date().toISOString(), notes }]
    }))
    showToast(`${shortDur(seconds)} registados em ${subject.name}`)
  }

  const resetTimer = () => {
    accumulated.current = 0; segmentStart.current = null
    setElapsed(0); setPhase('focus'); setCompleted(0); setState('idle')
  }
  const endSession = () => { resetTimer(); setChecklist([]) }

  const beginPhase = (p: Phase, autoStart: boolean) => {
    setPhase(p); accumulated.current = 0; setElapsed(0)
    if (autoStart) { segmentStart.current = Date.now(); setState('running') }
    else { segmentStart.current = null; setState('paused') }
  }

  const alerts = () => dbRef.current.settings.timerAlerts
  const phaseCompleted = (duration: number) => {
    const { mode: m, phase: p, completed: c } = latest.current
    const name = dbRef.current.subjects.find(s => s.id === latest.current.subjectId)?.name ?? 'estudo'
    if (m === 'countdown') {
      logSession(duration)
      if (alerts()) notify('Tempo esgotado ⏰', `A contagem de ${name} terminou.`)
      endSession()
    } else if (m === 'pomodoro') {
      if (p === 'focus') {
        logSession(duration)
        const next = c + 1
        setCompleted(next)
        if (alerts()) notify('Bloco de foco concluído 🎉', `Bom trabalho em ${name}. Hora de uma pausa.`)
        beginPhase(next % 4 === 0 ? 'long' : 'short', true)
      } else {
        if (alerts()) notify('A pausa terminou', `Pronto para outro bloco de foco em ${name}?`)
        beginPhase('focus', false)
      }
    }
  }

  // Tick while running
  useEffect(() => {
    if (state !== 'running') return
    const id = window.setInterval(() => {
      if (segmentStart.current == null) return
      const e = accumulated.current + (Date.now() - segmentStart.current) / 1000
      setElapsed(e)
      const d = phaseDuration(latest.current.mode, latest.current.phase)
      if (d != null && e >= d) phaseCompleted(d)
    }, 200)
    return () => window.clearInterval(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state])

  const duration = phaseDuration(mode, phase)
  const displaySeconds = duration != null ? Math.ceil(Math.max(0, duration - elapsed)) : Math.floor(elapsed)
  const ringProgress = duration != null && duration > 0 ? Math.min(1, elapsed / duration) : (elapsed % 60) / 60
  const active = mode !== 'clock' && state !== 'idle'
  const statusLabel = mode === 'pomodoro' ? (phase === 'focus' ? 'Foco' : phase === 'short' ? 'Pausa curta' : 'Pausa longa')
    : mode === 'stopwatch' ? 'Decorrido' : mode === 'countdown' ? 'Restante' : ''

  // Taskbar progress + window title
  useEffect(() => {
    window.studylab?.setProgress(active && duration ? ringProgress : -1)
    document.title = active ? `${clock(displaySeconds)} · StudyLab Buddy` : 'StudyLab Buddy'
  }, [active, ringProgress, duration, displaySeconds])

  const start = () => {
    if (mode === 'clock' || state === 'running') return
    if (!subjectId) { setSubjectRequired(true); return }
    segmentStart.current = Date.now(); setState('running')
  }
  const pause = () => {
    if (state !== 'running') return
    accumulated.current = accumulated.current + (Date.now() - (segmentStart.current ?? Date.now())) / 1000
    segmentStart.current = null; setElapsed(accumulated.current); setState('paused')
  }
  const finish = () => {
    if (state === 'idle') return
    const e = state === 'running' && segmentStart.current != null
      ? accumulated.current + (Date.now() - segmentStart.current) / 1000 : accumulated.current
    if (!(mode === 'pomodoro' && phase !== 'focus')) logSession(e)
    endSession()
  }
  const skipBreak = () => { if (mode === 'pomodoro' && phase !== 'focus') beginPhase('focus', state === 'running') }

  const setMode = (m: Mode) => { if (state === 'idle') { setModeState(m); resetTimer() } }

  const value: TimerCtx = useMemo(() => ({
    mode, setMode, subjectId, setSubjectId,
    ...dur, setDuration: (k, v) => setDur(d => ({ ...d, [k]: Math.max(1, v) })),
    state, phase, completed, elapsed, displaySeconds, ringProgress, statusLabel, active,
    checklist,
    addItem: t => { const title = t.trim(); if (title) setChecklist(c => [...c, { id: uid(), title, done: false }]) },
    toggleItem: id => setChecklist(c => c.map(i => (i.id === id ? { ...i, done: !i.done } : i))),
    removeItem: id => setChecklist(c => c.filter(i => i.id !== id)),
    start, pause, finish, discard: endSession, skipBreak,
    subjectRequired, dismissSubjectRequired: () => setSubjectRequired(false), toast
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [mode, subjectId, dur, state, phase, completed, elapsed, checklist, subjectRequired, toast])

  // If the selected subject is deleted, drop the selection.
  useEffect(() => {
    if (subjectId && !db.subjects.some(s => s.id === subjectId)) { setSubjectId(null); if (state !== 'idle') endSession() }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [db.subjects])

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

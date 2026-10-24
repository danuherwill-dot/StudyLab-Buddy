import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { emptyDB, defaultSettings, type DB } from './types'

const KEY = 'studylab.db.v1'

function load(): DB {
  try {
    const raw = localStorage.getItem(KEY)
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<DB>
      return { ...emptyDB(), ...parsed, settings: { ...defaultSettings, ...(parsed.settings ?? {}) } }
    }
  } catch { /* fall through to an empty database */ }
  return emptyDB()
}

interface Ctx {
  db: DB
  update: (fn: (db: DB) => DB) => void
}

const StoreContext = createContext<Ctx | null>(null)

export function StoreProvider({ children }: { children: ReactNode }) {
  const [db, setDb] = useState<DB>(load)
  const saveTimer = useRef<number | undefined>(undefined)

  useEffect(() => {
    window.clearTimeout(saveTimer.current)
    saveTimer.current = window.setTimeout(() => {
      try { localStorage.setItem(KEY, JSON.stringify(db)) } catch { /* storage full or unavailable */ }
    }, 150)
  }, [db])

  const update = useCallback((fn: (db: DB) => DB) => setDb(prev => fn(prev)), [])
  const value = useMemo(() => ({ db, update }), [db, update])
  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>
}

export function useStore() {
  const ctx = useContext(StoreContext)
  if (!ctx) throw new Error('StoreProvider missing')
  return ctx
}

/** Convenience helpers that change one collection. */
export function useActions() {
  const { update } = useStore()
  return useMemo(() => ({
    upsert<K extends 'subjects' | 'tasks' | 'classes' | 'sessions' | 'grades'>(key: K, item: DB[K][number]) {
      update(db => {
        const list = db[key] as { id: string }[]
        const exists = list.some(x => x.id === item.id)
        const next = exists ? list.map(x => (x.id === item.id ? item : x)) : [...list, item]
        return { ...db, [key]: next }
      })
    },
    remove(key: 'tasks' | 'classes' | 'sessions' | 'grades', id: string) {
      update(db => ({ ...db, [key]: (db[key] as { id: string }[]).filter(x => x.id !== id) }))
    },
    removeSubject(id: string) {
      update(db => ({
        ...db,
        subjects: db.subjects.filter(s => s.id !== id),
        tasks: db.tasks.filter(t => t.subjectId !== id),
        classes: db.classes.filter(c => c.subjectId !== id),
        sessions: db.sessions.filter(s => s.subjectId !== id),
        grades: db.grades.filter(g => g.subjectId !== id)
      }))
    },
    setSettings(patch: Partial<DB['settings']>) {
      update(db => ({ ...db, settings: { ...db.settings, ...patch } }))
    },
    clear(what: 'classes' | 'tasks' | 'grades' | 'sessions') {
      update(db => ({ ...db, [what]: [] }))
    },
    clearSubjects() {
      update(db => ({ ...db, subjects: [], tasks: [], classes: [], sessions: [], grades: [] }))
    },
    clearAll() {
      update(db => ({ ...emptyDB(), settings: db.settings }))
    },
    mutate(fn: (db: DB) => DB) { update(fn) }
  }), [update])
}

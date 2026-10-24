import type { Level } from './types'

const PT = 'pt-PT'

export const LEVELS: Record<Level, {
  title: string
  scale: [number, number]
  pass: number
  digits: number
  testScale: [number, number]
  description: string
}> = {
  basic: {
    title: 'Ensino Básico', scale: [1, 5], pass: 3, digits: 1, testScale: [0, 100],
    description: 'Testes 0–100% · nota de período 1–5 · positiva ≥ 3'
  },
  secondary: {
    title: 'Secundário / Superior', scale: [0, 20], pass: 10, digits: 2, testScale: [0, 20],
    description: 'Escala 0–20 · positiva ≥ 10'
  }
}

export const num = (v: number, max = 2, min = 0) =>
  v.toLocaleString(PT, { minimumFractionDigits: min, maximumFractionDigits: max })

export const fmtGrade = (level: Level, v: number) => num(v, LEVELS[level].digits, LEVELS[level].digits)
export const fmtTest = (level: Level, v: number) =>
  level === 'basic' ? `${num(v, 1)}%` : fmtGrade(level, v)

export const clock = (total: number) => {
  const s = Math.max(0, Math.floor(total))
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60
  const mm = String(m).padStart(2, '0'), ss = String(sec).padStart(2, '0')
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`
}

export const shortDur = (total: number) => {
  const s = Math.round(total)
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60)
  if (h > 0) return `${h} h ${m} min`
  if (m > 0) return `${m} min`
  return `${s}s`
}

export const hours = (v: number) => `${num(v, 1)} h`

export const minutesText = (m: number) =>
  `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`

export const WEEKDAYS = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom']
export const WEEKDAYS_LONG = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo']

/** 1 = Monday … 7 = Sunday */
export const isoWeekday = (d: Date) => ((d.getDay() + 6) % 7) + 1

export const startOfDay = (d: Date) => { const x = new Date(d); x.setHours(0, 0, 0, 0); return x }
export const addDays = (d: Date, n: number) => { const x = new Date(d); x.setDate(x.getDate() + n); return x }
export const startOfWeek = (d: Date) => addDays(startOfDay(d), -(isoWeekday(d) - 1))
export const sameDay = (a: Date, b: Date) => startOfDay(a).getTime() === startOfDay(b).getTime()

export const dateLong = (iso: string | Date) =>
  new Date(iso).toLocaleDateString(PT, { day: 'numeric', month: 'long', year: 'numeric' })
export const dayMonth = (d: Date) => d.toLocaleDateString(PT, { day: 'numeric', month: 'short' })
export const timeOf = (iso: string | Date) =>
  new Date(iso).toLocaleTimeString(PT, { hour: '2-digit', minute: '2-digit' })
export const weekdayLong = (d: Date) => d.toLocaleDateString(PT, { weekday: 'long' })

/** For <input type="datetime-local"> */
export const toLocalInput = (iso: string | Date) => {
  const d = new Date(iso)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`
}
export const toDateInput = (iso: string | Date) => toLocalInput(iso).slice(0, 10)

export const parseNumber = (text: string): number | null => {
  const v = Number(text.trim().replace(',', '.'))
  return text.trim() !== '' && Number.isFinite(v) ? v : null
}

export const uid = () => Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4)

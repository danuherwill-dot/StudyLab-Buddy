export type TaskType = 'homework' | 'test' | 'assignment'
export type Level = 'basic' | 'secondary'
export type GradeKind = 'test' | 'periodFinal'
export type ThemeChoice = 'system' | 'light' | 'dark'

export interface Subject {
  id: string
  name: string
  color: string
  targetHours: number
  /** Secundário years (10, 11, 12) in which the subject is taught. */
  years: number[]
}

export interface Task {
  id: string
  title: string
  subjectId: string | null
  type: TaskType
  due: string // ISO
  done: boolean
  remind: boolean
  notified: number[] // indexes of reminders already shown
}

export interface ClassSlot {
  id: string
  subjectId: string
  day: number // 1 = Monday … 7 = Sunday
  start: number // minutes since midnight
  end: number
  room: string
}

export interface Session {
  id: string
  subjectId: string
  seconds: number
  date: string // ISO
  notes: string
}

export interface Grade {
  id: string
  subjectId: string
  title: string
  score: number
  weight: number
  level: Level
  date: string // ISO
  kind: GradeKind
  period: number
  /** 10 | 11 | 12 for Secundário, 0 for Básico */
  year: number
}

export interface Settings {
  theme: ThemeChoice
  taskReminders: boolean
  timerAlerts: boolean
  weightByDuration: boolean
  level: Level
  year: number
  studentName: string
  showWeekend: boolean
  keepInTray: boolean
  launchAtLogin: boolean
}

export interface DB {
  subjects: Subject[]
  tasks: Task[]
  classes: ClassSlot[]
  sessions: Session[]
  grades: Grade[]
  settings: Settings
}

export const SUBJECT_COLORS = [
  '#4F6DF2', '#8B5CF6', '#EC4899', '#EF4444', '#F97316',
  '#EAB308', '#22C55E', '#14B8A6', '#06B6D4', '#64748B'
]

export const defaultSettings: Settings = {
  theme: 'system',
  taskReminders: true,
  timerAlerts: true,
  weightByDuration: true,
  level: 'secondary',
  year: 10,
  studentName: '',
  showWeekend: false,
  keepInTray: true,
  launchAtLogin: false
}

export const emptyDB = (): DB => ({
  subjects: [], tasks: [], classes: [], sessions: [], grades: [], settings: { ...defaultSettings }
})

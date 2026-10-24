import { createContext, useContext } from 'react'

export type Page = 'study' | 'timetable' | 'tasks' | 'stats' | 'grades' | 'settings'

export interface UIContext {
  page: Page
  go: (p: Page) => void
  openSubjects: () => void
}

export const UI = createContext<UIContext>({ page: 'study', go: () => {}, openSubjects: () => {} })
export const useUI = () => useContext(UI)

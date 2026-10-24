import type { DB, Grade, Level, Subject } from './types'
import { LEVELS } from './format'

// Port of the iOS GradeCalculator: Portuguese grading rules.

const weighted = (grades: Grade[]) => {
  const total = grades.reduce((s, g) => s + g.weight, 0)
  if (total <= 0) return null
  return grades.reduce((s, g) => s + g.score * g.weight, 0) / total
}

export const gradesOf = (db: DB, subjectId: string) => db.grades.filter(g => g.subjectId === subjectId)

export const testsOf = (db: DB, s: Subject, level: Level, year?: number) =>
  gradesOf(db, s.id).filter(g =>
    g.level === level && g.kind === 'test' && (level === 'basic' || year == null || g.year === year))

export const testAverage = (db: DB, s: Subject, level: Level, year?: number) =>
  weighted(testsOf(db, s, level, year))

export const termMark = (db: DB, s: Subject, period: number, level: Level = 'basic', year = 0) =>
  gradesOf(db, s.id)
    .filter(g => g.level === level && g.kind === 'periodFinal' && g.period === period && g.year === year)
    .sort((a, b) => +new Date(b.date) - +new Date(a.date))[0] ?? null

export const latestTermPeriod = (db: DB, subjects: Subject[], level: Level = 'basic', year = 0) => {
  const periods = db.grades
    .filter(g => subjects.some(s => s.id === g.subjectId) && g.level === level && g.kind === 'periodFinal' && g.year === year)
    .map(g => g.period)
  return periods.length ? Math.max(...periods) : null
}

/** A subject's grade for a Secundário year: its latest saved period. */
export const yearGrade = (db: DB, s: Subject, year: number) => {
  const marks = gradesOf(db, s.id)
    .filter(g => g.level === 'secondary' && g.kind === 'periodFinal' && g.year === year)
    .sort((a, b) => b.period - a.period || +new Date(b.date) - +new Date(a.date))
  return marks[0]?.score ?? null
}

/** Classificação final da disciplina: mean of its yearly grades. */
export const courseGrade = (db: DB, s: Subject) => {
  const v = s.years.map(y => yearGrade(db, s, y)).filter((x): x is number => x != null)
  return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null
}

export const average = (db: DB, s: Subject, level: Level, period?: number, year?: number) => {
  if (level === 'basic') {
    const p = period ?? latestTermPeriod(db, [s])
    return p == null ? null : termMark(db, s, p)?.score ?? null
  }
  return year != null ? yearGrade(db, s, year) : courseGrade(db, s)
}

export const overallAverage = (db: DB, subjects: Subject[], level: Level, period?: number, year?: number) => {
  if (level === 'basic') {
    const p = period ?? latestTermPeriod(db, subjects)
    if (p == null) return null
    const v = subjects.map(s => termMark(db, s, p)?.score).filter((x): x is number => x != null)
    return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null
  }
  if (year != null) {
    const v = subjects.filter(s => s.years.includes(year))
      .map(s => yearGrade(db, s, year)).filter((x): x is number => x != null)
    return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null
  }
  let total = 0, weights = 0
  for (const s of subjects) {
    const g = courseGrade(db, s)
    if (g == null) continue
    const w = db.settings.weightByDuration ? Math.max(1, s.years.length) : 1
    total += g * w; weights += w
  }
  return weights > 0 ? total / weights : null
}

export const isPassingValue = (level: Level, v: number) => v >= LEVELS[level].pass

export const isPassing = (g: Grade) =>
  g.level === 'basic' && g.kind === 'test' ? g.score >= 50 : isPassingValue(g.level, g.score)

/** Básico test percentages: below 50% red, 50–65% yellow, 65% and above green. */
export const testTone = (percent: number): 'bad' | 'warn' | 'good' =>
  percent < 50 ? 'bad' : percent < 65 ? 'warn' : 'good'

export const gradeTone = (g: Grade): 'bad' | 'warn' | 'good' =>
  g.level === 'basic' && g.kind === 'test' ? testTone(g.score) : isPassing(g) ? 'good' : 'bad'

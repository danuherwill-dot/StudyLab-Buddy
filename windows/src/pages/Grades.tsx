import { useState } from 'react'
import { useStore, useActions } from '../store'
import { useUI } from '../ui-context'
import { Icon } from '../components/Icon'
import { Ring } from '../components/charts'
import { Badge, Button, Card, Chip, Dot, Empty, Field, Modal, PageHeader, Segmented, SubjectSelect, cx } from '../components/ui'
import { average, courseGrade, gradeTone, isPassingValue, latestTermPeriod, overallAverage, termMark, testAverage, testTone, testsOf } from '../calc'
import { LEVELS, dateLong, fmtGrade, fmtTest, num, parseNumber, toDateInput, uid } from '../format'
import type { Grade, GradeKind, Level, Subject } from '../types'

type Tab = 'terms' | 'tests' | 'history'
interface Target { grade: Grade | null; subjectId: string | null; kind: GradeKind; period: number; year: number }

const toneColor = { good: 'var(--good)', warn: 'var(--warn)', bad: 'var(--bad)' }

function GradeForm({ target, level, onClose }: { target: Target; level: Level; onClose: () => void }) {
  const { db } = useStore()
  const actions = useActions()
  const g = target.grade
  const kind = target.kind
  const L = LEVELS[level]
  const [subjectId, setSubjectId] = useState<string | null>(g?.subjectId ?? target.subjectId)
  const [title, setTitle] = useState(g?.title ?? '')
  const [date, setDate] = useState(toDateInput(g?.date ?? new Date()))
  const [period, setPeriod] = useState(target.period)
  const [year, setYear] = useState(target.year || 10)
  const [nota, setNota] = useState(Math.round(g?.score ?? (level === 'basic' ? 3 : 10)))
  const [scoreText, setScoreText] = useState(g ? num(g.score, 2) : '')
  const [weightText, setWeightText] = useState(g ? num(g.weight, 2) : '')
  const isTerm = kind === 'periodFinal'

  const subjects = db.subjects
    .filter(s => level === 'basic' || s.years.includes(year) || s.id === subjectId)
    .sort((a, b) => a.name.localeCompare(b.name, 'pt'))

  const score = isTerm ? nota : parseNumber(scoreText)
  const weight = level === 'basic' || isTerm ? 1 : parseNumber(weightText)
  const range = isTerm ? L.scale : L.testScale
  const scoreError = !isTerm && scoreText && (score == null ? 'Introduz um número.'
    : score < range[0] || score > range[1] ? `Tem de estar entre ${num(range[0])} e ${num(range[1])}.` : null)
  const valid = !!subjectId && score != null && weight != null && score >= range[0] && score <= range[1] && weight > 0

  const save = () => {
    if (!valid) return
    const savedYear = level === 'secondary' ? year : 0
    const subject = db.subjects.find(s => s.id === subjectId)!
    const existing = !g && isTerm ? termMark(db, subject, period, level, savedYear) : null
    actions.upsert('grades', {
      id: g?.id ?? existing?.id ?? uid(), subjectId: subjectId!, title: isTerm ? '' : title.trim(), score: score!, weight: weight!,
      level, date: new Date(date + 'T12:00:00').toISOString(), kind, period, year: savedYear
    })
    onClose()
  }

  return (
    <Modal title={isTerm ? 'Nota de período' : g ? 'Editar teste' : 'Novo teste'} onClose={onClose}
           footer={<>
             {g && <Button variant="danger" icon="trash" style={{ marginRight: 'auto' }} onClick={() => { actions.remove('grades', g.id); onClose() }}>Eliminar</Button>}
             <Button variant="ghost" onClick={onClose}>Cancelar</Button>
             <Button variant="primary" onClick={save} disabled={!valid}>Guardar</Button></>}>
      {level === 'secondary' && (
        <Field label="Ano"><Segmented value={year} onChange={setYear} options={[10, 11, 12].map(y => ({ value: y, label: `${y}.º` }))} /></Field>
      )}
      <Field label="Disciplina"><SubjectSelect value={subjectId} onChange={setSubjectId} subjects={subjects} /></Field>
      {!isTerm && (
        <Field label="Nome (opcional)">
          <input className="input" value={title} placeholder={level === 'basic' ? `Por omissão “Teste ${db.subjects.find(s => s.id === subjectId)?.name ?? 'disciplina'}”` : 'Título (ex.: Teste 1)'}
                 onChange={e => setTitle(e.target.value)} />
        </Field>
      )}
      <Field label="Data"><input className="input" type="date" value={date} onChange={e => setDate(e.target.value)} /></Field>
      {isTerm ? (
        <>
          <Field label="Período"><Segmented value={period} onChange={setPeriod} options={[1, 2, 3].map(p => ({ value: p, label: `${p}.º` }))} /></Field>
          <Field label={level === 'basic' ? 'Nota de período (1–5)' : 'Nota de período (0–20)'}
                 hint={level === 'basic' ? 'A tua nota a esta disciplina no fim do período. Conta para a média geral.'
                   : 'A nota do ano é a do último período, e todos os anos contam para a média final.'}>
            {level === 'basic'
              ? <Segmented value={nota} onChange={setNota} options={[1, 2, 3, 4, 5].map(n => ({ value: n, label: String(n) }))} />
              : <div className="row" style={{ gap: 10 }}>
                  <div className="stepper"><button onClick={() => setNota(n => Math.max(0, n - 1))}>−</button><button onClick={() => setNota(n => Math.min(20, n + 1))}>+</button></div>
                  <b style={{ fontSize: 22 }}>{nota}</b>
                </div>}
          </Field>
        </>
      ) : (
        <div className={level === 'secondary' ? 'grid2' : ''}>
          <Field label={level === 'basic' ? 'Nota do teste (%)' : 'Classificação'} error={scoreError || null}
                 hint={!scoreError ? (level === 'basic' ? 'Guardada para a poderes consultar no histórico de testes.' : 'Escala 0–20') : undefined}>
            <input className="input" inputMode="decimal" value={scoreText} placeholder={level === 'basic' ? '0 – 100' : '0 – 20'} onChange={e => setScoreText(e.target.value)} />
          </Field>
          {level === 'secondary' && (
            <Field label="Peso (%)"><input className="input" inputMode="decimal" value={weightText} placeholder="ex.: 30" onChange={e => setWeightText(e.target.value)} /></Field>
          )}
        </div>
      )}
    </Modal>
  )
}

export default function GradesPage() {
  const { db } = useStore()
  const actions = useActions()
  const ui = useUI()
  const level = db.settings.level
  const year = db.settings.year
  const L = LEVELS[level]
  const [tab, setTab] = useState<Tab>('terms')
  const [selectedPeriod, setSelectedPeriod] = useState<number | null>(null)
  const [target, setTarget] = useState<Target | null>(null)

  const activeYear = level === 'secondary' ? year : 0
  const sortedSubjects = [...db.subjects].sort((a, b) => a.name.localeCompare(b.name, 'pt'))
  const visible = level === 'basic' ? sortedSubjects : sortedSubjects.filter(s => s.years.includes(year))
  const period = selectedPeriod ?? latestTermPeriod(db, db.subjects, level, activeYear) ?? 1
  const overall = overallAverage(db, db.subjects, level, level === 'basic' ? period : undefined)
  const fraction = overall == null ? 0 : (overall - L.scale[0]) / (L.scale[1] - L.scale[0])
  const passing = overall != null && isPassingValue(level, overall)
  const tone = overall == null ? 'var(--muted)' : passing ? 'var(--good)' : 'var(--bad)'
  const subjectOf = (g: Grade) => db.subjects.find(s => s.id === g.subjectId)

  const status = (v: number) => level === 'basic'
    ? `${isPassingValue(level, v) ? 'Positiva' : 'Negativa'} · Nível ${Math.round(v)}`
    : isPassingValue(level, v) ? 'Positiva (≥ 10)' : 'Negativa (< 10)'

  const rowTitle = (g: Grade) => g.kind === 'periodFinal'
    ? `${subjectOf(g)?.name ?? ''} · ${g.year > 0 ? `${g.year}.º ano, ` : ''}${g.period}.º período`
    : g.title || `Teste ${subjectOf(g)?.name ?? ''}`
  const rowSub = (g: Grade) => level === 'secondary' && g.kind === 'test'
    ? `${g.year}.º ano · peso ${num(g.weight)}% · ${dateLong(g.date)}` : dateLong(g.date)
  const scoreText = (g: Grade) => g.kind === 'periodFinal' ? fmtGrade(g.level, g.score) : fmtTest(g.level, g.score)

  const markCard = (g: Grade, showSubject: boolean) => {
    const t = gradeTone(g)
    return (
      <Card key={g.id} className="mark-card" onClick={() => setTarget({ grade: g, subjectId: g.subjectId, kind: g.kind, period: g.period, year: g.year })}>
        <div className="row" style={{ gap: 12 }}>
          {showSubject && <Dot color={subjectOf(g)?.color} size={12} />}
          <div className="grow"><div style={{ fontWeight: 650 }}>{rowTitle(g)}</div><div className="muted small">{rowSub(g)}</div></div>
          <span className={cx('score', t)}>{scoreText(g)}</span>
        </div>
        {g.level === 'basic' && g.kind === 'test' && <div className="progress" style={{ marginTop: 10, height: 6 }}><div style={{ width: `${Math.min(100, g.score)}%`, background: toneColor[t] }} /></div>}
      </Card>
    )
  }

  const duration = (s: Subject) => s.years.length === 3 ? 'Trienal · conta ×3' : s.years.length === 2 ? 'Bienal · conta ×2' : 'Anual · conta ×1'
  const allTests = db.grades.filter(g => g.level === level && g.kind === 'test').sort((a, b) => +new Date(b.date) - +new Date(a.date))

  return (
    <>
      <PageHeader title="Notas"
        actions={db.subjects.length > 0 && <>
          <Button icon="plus" onClick={() => setTarget({ grade: null, subjectId: null, kind: 'periodFinal', period, year: activeYear })}>Nota de período</Button>
          <Button variant="primary" icon="plus" onClick={() => setTarget({ grade: null, subjectId: null, kind: 'test', period, year: activeYear })}>Teste</Button>
        </>}>
        <Segmented value={level} onChange={v => { actions.setSettings({ level: v }); setTab('terms'); setSelectedPeriod(null) }}
                   options={[{ value: 'basic', label: 'Ensino Básico' }, { value: 'secondary', label: 'Secundário / Superior' }]} />
      </PageHeader>

      <div className="grades-wrap">
        <Card className="hero">
          <div className="row" style={{ gap: 26 }}>
            <Ring progress={fraction} color={tone} size={128}>
              <b style={{ fontSize: 30 }}>{overall == null ? '—' : fmtGrade(level, overall)}</b>
              <span className="muted small">/ {fmtGrade(level, L.scale[1])}</span>
            </Ring>
            <div className="col" style={{ gap: 8 }}>
              <span className="eyebrow">MÉDIA GERAL</span>
              {overall != null ? (
                <>
                  <Badge tone={passing ? 'good' : 'bad'}>{status(overall)}</Badge>
                  <span className="muted small">{level === 'basic' ? `Média das tuas notas de período, ${period}.º período` : `Média dos 3 anos · final ${Math.round(overall)}`}</span>
                </>
              ) : <span className="muted">Adiciona uma nota de período para veres a tua média</span>}
              <span className="muted small" style={{ opacity: .7 }}>{L.description}</span>
            </div>
          </div>
          {level === 'secondary' && (
            <div className="year-chips">
              {[10, 11, 12].map(y => {
                const avg = overallAverage(db, db.subjects, 'secondary', undefined, y)
                return (
                  <button key={y} className={cx('year-chip', y === year && 'on')} onClick={() => { actions.setSettings({ year: y }); setSelectedPeriod(null) }}>
                    <b>{y}.º ano</b><span>{avg == null ? '—' : fmtGrade('secondary', avg)}</span>
                  </button>
                )
              })}
            </div>
          )}
          <div className="row" style={{ gap: 8, marginTop: 14 }}>
            {[1, 2, 3].map(p => <Chip key={p} active={p === period} style={{ flex: 1 }} onClick={() => setSelectedPeriod(p)}>{p}.º período</Chip>)}
          </div>
        </Card>

        {db.subjects.length === 0 ? (
          <Empty icon="cap" title="Ainda sem disciplinas" text="Adiciona as tuas disciplinas e regista aqui as tuas notas."
                 action={<Button variant="primary" onClick={ui.openSubjects}>Adicionar disciplinas</Button>} />
        ) : (
          <>
            <div className="row" style={{ gap: 8, margin: '4px 0' }}>
              {([['terms', 'Notas de período'], ['tests', 'Testes'], ['history', 'Histórico']] as [Tab, string][]).map(([k, label]) =>
                <Chip key={k} active={tab === k} onClick={() => setTab(k)}>{label}</Chip>)}
            </div>

            {tab === 'terms' && (
              <section className="col" style={{ gap: 10 }}>
                <h3>{level === 'secondary' ? `${year}.º ano · ${period}.º período` : `Notas de período · ${period}.º período`}</h3>
                {visible.length === 0 && <p className="muted">Sem disciplinas no {year}.º ano. Adiciona disciplinas (botão “Disciplinas”) e assinala este ano.</p>}
                {visible.map(s => {
                  const mark = termMark(db, s, period, level, activeYear)
                  return (
                    <Card key={s.id} className="subject-row" onClick={() => setTarget(mark
                      ? { grade: mark, subjectId: s.id, kind: 'periodFinal', period, year: activeYear }
                      : { grade: null, subjectId: s.id, kind: 'periodFinal', period, year: activeYear })}>
                      <Dot color={s.color} size={12} />
                      <div className="grow"><div style={{ fontWeight: 650 }}>{s.name}</div>{level === 'secondary' && <div className="muted small">{duration(s)}</div>}</div>
                      {mark ? <span className={cx('score', mark.level === 'basic' || true ? (isPassingValue(level, mark.score) ? 'good' : 'bad') : '')}>{fmtGrade(level, mark.score)}</span>
                            : <span className="add-pill"><Icon name="plus" size={14} /> Adicionar</span>}
                    </Card>
                  )
                })}
                <p className="muted small">{level === 'secondary'
                  ? 'A tua nota de 0–20 a cada disciplina. O último período de cada ano é a nota desse ano; a nota final da disciplina é a média dos seus anos.'
                  : 'A tua nota de 1–5 a cada disciplina no fim do período. Estas notas contam para a média geral.'}</p>
              </section>
            )}

            {tab === 'tests' && visible.map(s => {
              const tests = testsOf(db, s, level, year).sort((a, b) => +new Date(b.date) - +new Date(a.date))
              const avg = testAverage(db, s, level, year)
              const totalW = tests.reduce((a, t) => a + t.weight, 0)
              return (
                <section key={s.id} className="col" style={{ gap: 10 }}>
                  <div className="row" style={{ gap: 10, marginTop: 8 }}>
                    <Dot color={s.color} size={12} /><h3>{s.name}</h3><span className="grow" />
                    {avg != null && <b style={{ color: level === 'basic' ? toneColor[testTone(avg)] : isPassingValue(level, avg) ? 'var(--good)' : 'var(--bad)' }}>média {fmtTest(level, avg)}</b>}
                  </div>
                  {tests.map(g => markCard(g, false))}
                  <Button icon="plus" onClick={() => setTarget({ grade: null, subjectId: s.id, kind: 'test', period, year: activeYear })}>Adicionar nota</Button>
                  {level === 'secondary' && tests.length > 0 && Math.abs(totalW - 100) > 0.01 &&
                    <p className="muted small">Os pesos somam {num(totalW)}%. A média é normalizada de acordo com os pesos introduzidos.</p>}
                </section>
              )
            })}

            {tab === 'history' && (
              <section className="col" style={{ gap: 10 }}>
                <h3>Todos os testes guardados <span className="count">{allTests.length}</span></h3>
                {allTests.length === 0 && <p className="muted">Ainda não há notas guardadas. Clica em “Teste” para adicionar a primeira.</p>}
                {allTests.map(g => markCard(g, true))}
              </section>
            )}
          </>
        )}
      </div>
      {target && <GradeForm target={target} level={level} onClose={() => setTarget(null)} />}
      <span hidden>{String(courseGrade)}{String(average)}</span>
    </>
  )
}

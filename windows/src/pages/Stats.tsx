import { useMemo, useRef, useState } from 'react'
import { toPng } from 'html-to-image'
import { useStore } from '../store'
import { Icon } from '../components/Icon'
import { BarChart, Donut, Ring } from '../components/charts'
import { Button, Card, Dot, Field, Modal, PageHeader, Progress, Segmented, Toggle } from '../components/ui'
import { overallAverage, average, isPassingValue } from '../calc'
import { LEVELS, addDays, dayMonth, fmtGrade, hours, num, shortDur, startOfWeek, WEEKDAYS } from '../format'
import type { DB } from '../types'

type Period = 'week' | 'month' | 'year'

function intervalFor(period: Period, offset: number) {
  const now = new Date()
  if (period === 'week') { const start = addDays(startOfWeek(now), offset * 7); return { start, end: addDays(start, 7) } }
  if (period === 'month') return { start: new Date(now.getFullYear(), now.getMonth() + offset, 1), end: new Date(now.getFullYear(), now.getMonth() + offset + 1, 1) }
  return { start: new Date(now.getFullYear() + offset, 0, 1), end: new Date(now.getFullYear() + offset + 1, 0, 1) }
}

const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)

function titleFor(period: Period, start: Date, end: Date) {
  if (period === 'week') return `${dayMonth(start)} – ${dayMonth(addDays(end, -1))}`
  if (period === 'month') return cap(start.toLocaleDateString('pt-PT', { month: 'long', year: 'numeric' }))
  return String(start.getFullYear())
}

export interface ReportData {
  periodTitle: string
  totalSeconds: number
  sessionCount: number
  buckets: { label: string; value: number }[]
  slices: { name: string; value: number; color: string }[]
  tasksDone: number
  tasksTotal: number
}

function computeStats(db: DB, period: Period, offset: number) {
  const { start, end } = intervalFor(period, offset)
  const inRange = (iso: string) => { const t = new Date(iso).getTime(); return t >= start.getTime() && t < end.getTime() }
  const sessions = db.sessions.filter(s => inRange(s.date))

  const buckets: { label: string; value: number; key: string }[] = []
  if (period === 'year') {
    for (let m = 0; m < 12; m++) buckets.push({ key: String(m), value: 0, label: cap(new Date(start.getFullYear(), m, 1).toLocaleDateString('pt-PT', { month: 'narrow' })) })
  } else {
    for (let d = new Date(start); d < end; d = addDays(d, 1)) {
      buckets.push({ key: d.toDateString(), value: 0, label: period === 'week' ? WEEKDAYS[(d.getDay() + 6) % 7].slice(0, 3) : String(d.getDate()) })
    }
  }
  for (const s of sessions) {
    const d = new Date(s.date)
    const key = period === 'year' ? String(d.getMonth()) : d.toDateString()
    const b = buckets.find(x => x.key === key)
    if (b) b.value += s.seconds / 3600
  }
  const slices = db.subjects.map(sub => ({
    name: sub.name, color: sub.color,
    value: sessions.filter(s => s.subjectId === sub.id).reduce((a, s) => a + s.seconds, 0) / 3600
  })).filter(s => s.value > 0).sort((a, b) => b.value - a.value)
  const tasks = db.tasks.filter(t => inRange(t.due))
  return {
    start, end, sessions, buckets, slices,
    totalSeconds: sessions.reduce((a, s) => a + s.seconds, 0),
    tasks, tasksDone: tasks.filter(t => t.done).length
  }
}

function ReportCard({ data, studentName, grades }: {
  data: ReportData; studentName: string
  grades: { name: string; color: string; avg: string; pass: boolean }[] | null
}) {
  const percent = data.tasksTotal ? Math.round((data.tasksDone / data.tasksTotal) * 100) : 0
  const max = Math.max(...data.slices.map(s => s.value), 1)
  return (
    <div className="report">
      <div className="report-head">
        <small>STUDYLAB</small>
        <h2>{studentName ? `Relatório de estudo de ${studentName}` : 'Relatório de estudo'}</h2>
        <span>{data.periodTitle}</span>
      </div>
      <div className="report-body">
        <div className="report-stats">
          <div><b>{shortDur(data.totalSeconds)}</b><span>Tempo de estudo</span></div>
          <div><b>{data.sessionCount}</b><span>Sessões</span></div>
          <div><b>{data.tasksTotal ? `${percent}%` : '—'}</b><span>Tarefas feitas</span></div>
        </div>
        <BarChart data={data.buckets} height={150} />
        {data.slices.length > 0 && (
          <div className="col" style={{ gap: 8 }}>
            <b>Por disciplina</b>
            {data.slices.map(s => (
              <div key={s.name}>
                <div className="row" style={{ justifyContent: 'space-between', fontSize: 13 }}><span>{s.name}</span><span style={{ color: '#667' }}>{hours(s.value)}</span></div>
                <div style={{ height: 8, borderRadius: 8, background: s.color, width: `${(s.value / max) * 100}%`, minWidth: 6 }} />
              </div>
            ))}
          </div>
        )}
        {grades && grades.length > 0 && (
          <div className="col" style={{ gap: 6 }}>
            <b>Notas</b>
            {grades.map(g => (
              <div key={g.name} className="row" style={{ justifyContent: 'space-between', fontSize: 14 }}>
                <span className="row" style={{ gap: 8 }}><Dot color={g.color} size={8} />{g.name}</span>
                <b style={{ color: g.pass ? '#16a34a' : '#dc2626' }}>{g.avg}</b>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

function ShareModal({ data, onClose }: { data: ReportData; onClose: () => void }) {
  const { db } = useStore()
  const [name, setName] = useState(db.settings.studentName)
  const [withGrades, setWithGrades] = useState(false)
  const [msg, setMsg] = useState('')
  const ref = useRef<HTMLDivElement>(null)
  const level = db.settings.level

  const grades = useMemo(() => {
    if (!withGrades) return null
    const lines = db.subjects.map(s => {
      const v = average(db, s, level)
      return v == null ? null : { name: s.name, color: s.color, avg: fmtGrade(level, v), pass: isPassingValue(level, v) }
    }).filter((x): x is NonNullable<typeof x> => !!x)
    const overall = overallAverage(db, db.subjects, level)
    return overall == null ? lines : [{ name: 'Média geral', color: '#4f6df2', avg: fmtGrade(level, overall), pass: isPassingValue(level, overall) }, ...lines]
  }, [withGrades, db, level])

  const text = () => {
    const lines = [`📚 Relatório StudyLab${name ? ` – ${name}` : ''}`, data.periodTitle, '',
      `⏱ Estudo: ${shortDur(data.totalSeconds)} em ${data.sessionCount} sessões`,
      ...data.slices.map(s => `  • ${s.name}: ${hours(s.value)}`)]
    if (data.tasksTotal) lines.push(`✅ Tarefas concluídas: ${data.tasksDone}/${data.tasksTotal} (${Math.round(data.tasksDone / data.tasksTotal * 100)}%)`)
    if (grades?.length) lines.push('', `🎓 Notas (${LEVELS[level].description})`, ...grades.map(g => `  • ${g.name}: ${g.avg}`))
    return lines.join('\n')
  }
  const render = () => toPng(ref.current!, { pixelRatio: 2, cacheBust: true })
  const flash = (m: string) => { setMsg(m); window.setTimeout(() => setMsg(''), 2500) }

  return (
    <Modal title="Partilhar com os pais" onClose={onClose} width={520}
           footer={<>
             <Button icon="text" onClick={async () => { await navigator.clipboard.writeText(text()); flash('Texto copiado') }}>Copiar texto</Button>
             <Button icon="image" onClick={async () => {
               const blob = await (await fetch(await render())).blob()
               await navigator.clipboard.write([new ClipboardItem({ 'image/png': blob })]); flash('Imagem copiada')
             }}>Copiar imagem</Button>
             <Button variant="primary" icon="share" onClick={async () => {
               const a = document.createElement('a'); a.href = await render(); a.download = `StudyLab-relatorio.png`; a.click(); flash('Imagem guardada')
             }}>Guardar imagem</Button></>}>
      <Field label="Nome do aluno (opcional)"><input className="input" value={name} onChange={e => setName(e.target.value)} /></Field>
      <Toggle checked={withGrades} onChange={setWithGrades} label="Incluir notas" />
      <div style={{ display: 'grid', placeItems: 'center' }}><div ref={ref}><ReportCard data={data} studentName={name} grades={grades} /></div></div>
      {msg && <div className="small" style={{ color: 'var(--good)', textAlign: 'center' }}>{msg}</div>}
    </Modal>
  )
}

export default function StatsPage() {
  const { db } = useStore()
  const [period, setPeriod] = useState<Period>('week')
  const [offset, setOffset] = useState(0)
  const [asPie, setAsPie] = useState(true)
  const [share, setShare] = useState(false)

  const s = useMemo(() => computeStats(db, period, offset), [db, period, offset])
  const title = titleFor(period, s.start, s.end)
  const totalHours = s.totalSeconds / 3600
  const week = useMemo(() => computeStats(db, 'week', 0), [db])

  const byType = (['homework', 'test', 'assignment'] as const).map(type => {
    const of = s.tasks.filter(t => t.type === type)
    return { type, total: of.length, done: of.filter(t => t.done).length, label: { homework: 'TPC', test: 'Testes', assignment: 'Trabalhos' }[type] }
  }).filter(x => x.total > 0)
  const pct = s.tasks.length ? Math.round(s.tasksDone / s.tasks.length * 100) : 0
  const report: ReportData = {
    periodTitle: title, totalSeconds: s.totalSeconds, sessionCount: s.sessions.length, buckets: s.buckets,
    slices: s.slices, tasksDone: s.tasksDone, tasksTotal: s.tasks.length
  }
  const maxSlice = Math.max(...s.slices.map(x => x.value), 1)

  return (
    <>
      <PageHeader title="Estatísticas"
        actions={<>
          <Segmented value={period} onChange={p => { setPeriod(p); setOffset(0) }}
                     options={[{ value: 'week', label: 'Semana' }, { value: 'month', label: 'Mês' }, { value: 'year', label: 'Ano' }]} />
          <Button icon="share" onClick={() => setShare(true)}>Partilhar</Button>
        </>} />
      <div className="stats-grid">
        <Card className="span2">
          <div className="row" style={{ justifyContent: 'space-between' }}>
            <button className="icon-btn" onClick={() => setOffset(o => o - 1)} aria-label="Anterior"><Icon name="left" size={18} /></button>
            <h3>{title}</h3>
            <button className="icon-btn" onClick={() => setOffset(o => o + 1)} disabled={offset >= 0} aria-label="Seguinte"><Icon name="right" size={18} /></button>
          </div>
          <div className="row" style={{ alignItems: 'baseline', margin: '14px 0 10px' }}>
            <span className="big-num">{shortDur(s.totalSeconds)}</span><span className="muted">de estudo</span>
            <span className="grow" /><span className="muted">{s.sessions.length} sessões</span>
          </div>
          <BarChart data={s.buckets} />
        </Card>

        <Card>
          <div className="row" style={{ marginBottom: 12 }}>
            <h3>Por disciplina</h3><span className="grow" />
            <Segmented value={asPie ? 'pie' : 'bar'} onChange={v => setAsPie(v === 'pie')} options={[{ value: 'pie', label: <Icon name="grid" size={16} /> }, { value: 'bar', label: <Icon name="chart" size={16} /> }]} />
          </div>
          {s.slices.length === 0 ? <p className="muted center">Sem sessões de estudo neste período.</p> : asPie ? (
            <div className="row" style={{ gap: 20, justifyContent: 'center', flexWrap: 'wrap' }}>
              <Donut slices={s.slices} center={hours(totalHours)} sub="total" />
              <div className="col" style={{ gap: 8 }}>{s.slices.map(x => <div key={x.name} className="row" style={{ gap: 8 }}><Dot color={x.color} />{x.name}<span className="muted small">{hours(x.value)}</span></div>)}</div>
            </div>
          ) : (
            <div className="col" style={{ gap: 12 }}>
              {s.slices.map(x => (
                <div key={x.name}>
                  <div className="row" style={{ justifyContent: 'space-between', marginBottom: 4 }}><span className="row" style={{ gap: 8 }}><Dot color={x.color} />{x.name}</span><span className="muted">{hours(x.value)}</span></div>
                  <Progress value={x.value / maxSlice} color={x.color} />
                </div>
              ))}
            </div>
          )}
        </Card>

        <Card>
          <h3 style={{ marginBottom: 12 }}>Esta semana vs. meta</h3>
          {db.subjects.filter(x => x.targetHours > 0).length === 0 ? <p className="muted">Define uma meta semanal numa disciplina para a acompanhares aqui.</p> : (
            <div className="col" style={{ gap: 14 }}>
              {db.subjects.filter(x => x.targetHours > 0).map(sub => {
                const h = week.sessions.filter(x => x.subjectId === sub.id).reduce((a, x) => a + x.seconds, 0) / 3600
                return (
                  <div key={sub.id}>
                    <div className="row" style={{ justifyContent: 'space-between', marginBottom: 5 }}><span>{sub.name}</span><span className="muted small">{hours(h)} / {hours(sub.targetHours)}</span></div>
                    <Progress value={h / sub.targetHours} color={sub.color} />
                  </div>
                )
              })}
            </div>
          )}
        </Card>

        <Card>
          <h3 style={{ marginBottom: 12 }}>Tarefas concluídas</h3>
          {s.tasks.length === 0 ? <p className="muted">Não há tarefas com entrega neste período.</p> : (
            <div className="row" style={{ gap: 22, alignItems: 'center' }}>
              <Ring progress={pct / 100} color="var(--good)" size={120}><b style={{ fontSize: 26 }}>{pct}%</b><span className="muted small">{s.tasksDone} de {s.tasks.length} concluídas</span></Ring>
              <div className="col grow" style={{ gap: 12 }}>
                {byType.map(t => (
                  <div key={t.type}><div className="row" style={{ justifyContent: 'space-between', marginBottom: 4 }}><span>{t.label}</span><span className="muted small">{t.done}/{t.total}</span></div><Progress value={t.done / t.total} color="var(--good)" /></div>
                ))}
              </div>
            </div>
          )}
        </Card>
      </div>
      {share && <ShareModal data={report} onClose={() => setShare(false)} />}
      <span hidden>{num(0)}</span>
    </>
  )
}

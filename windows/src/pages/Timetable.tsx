import { useMemo, useState } from 'react'
import { useStore, useActions } from '../store'
import { useNow } from '../hooks'
import { Icon } from '../components/Icon'
import { Button, Card, Empty, Field, Modal, PageHeader, Segmented, SubjectSelect, cx } from '../components/ui'
import type { ClassSlot } from '../types'
import { WEEKDAYS, WEEKDAYS_LONG, addDays, isoWeekday, minutesText, shortDur, startOfWeek, uid } from '../format'

const HOUR_H = 64
type Target = { slot: ClassSlot | null; day: number; start: number }

const toMinutes = (hhmm: string) => { const [h, m] = hhmm.split(':').map(Number); return h * 60 + m }

function SlotForm({ target, onClose }: { target: Target; onClose: () => void }) {
  const { db } = useStore()
  const actions = useActions()
  const slot = target.slot
  const [subjectId, setSubjectId] = useState<string | null>(slot?.subjectId ?? null)
  const [day, setDay] = useState(slot?.day ?? target.day)
  const [start, setStart] = useState(minutesText(slot?.start ?? target.start))
  const [end, setEnd] = useState(minutesText(slot?.end ?? Math.min(target.start + 60, 24 * 60 - 1)))
  const [room, setRoom] = useState(slot?.room ?? '')
  const invalidTime = !start || !end || toMinutes(end) <= toMinutes(start)
  const valid = !!subjectId && !invalidTime

  const save = () => {
    if (!valid) return
    actions.upsert('classes', { id: slot?.id ?? uid(), subjectId: subjectId!, day, start: toMinutes(start), end: toMinutes(end), room: room.trim() })
    onClose()
  }
  const subjects = [...db.subjects].sort((a, b) => a.name.localeCompare(b.name, 'pt'))

  return (
    <Modal title={slot ? 'Editar aula' : 'Nova aula'} onClose={onClose}
           footer={<>
             {slot && <Button variant="danger" icon="trash" onClick={() => { actions.remove('classes', slot.id); onClose() }} style={{ marginRight: 'auto' }}>Eliminar aula</Button>}
             <Button variant="ghost" onClick={onClose}>Cancelar</Button>
             <Button variant="primary" onClick={save} disabled={!valid}>Guardar</Button></>}>
      <Field label="Disciplina">
        <SubjectSelect value={subjectId} onChange={setSubjectId} subjects={subjects} placeholder={subjects.length ? 'Escolhe…' : 'Cria primeiro uma disciplina'} />
      </Field>
      <Field label="Dia">
        <select className="input" value={day} onChange={e => setDay(Number(e.target.value))}>
          {WEEKDAYS_LONG.map((d, i) => <option key={d} value={i + 1}>{d}</option>)}
        </select>
      </Field>
      <div className="grid2">
        <Field label="Início"><input className="input" type="time" value={start} onChange={e => setStart(e.target.value)} /></Field>
        <Field label="Fim" error={invalidTime ? 'A hora de fim tem de ser posterior à hora de início.' : null}>
          <input className="input" type="time" value={end} onChange={e => setEnd(e.target.value)} /></Field>
      </div>
      <Field label="Sala (opcional)"><input className="input" value={room} onChange={e => setRoom(e.target.value)} /></Field>
    </Modal>
  )
}

export default function TimetablePage() {
  const { db } = useStore()
  const actions = useActions()
  const now = useNow(30_000)
  const [mode, setMode] = useState<'week' | 'day'>('week')
  const [selected, setSelected] = useState(isoWeekday(new Date()))
  const [target, setTarget] = useState<Target | null>(null)

  const hasWeekend = db.classes.some(c => c.day >= 6)
  const days = db.settings.showWeekend || hasWeekend ? [1, 2, 3, 4, 5, 6, 7] : [1, 2, 3, 4, 5]
  const activeDay = days.includes(selected) ? selected : 1
  const todayIso = isoWeekday(now)
  const monday = startOfWeek(now)

  const { firstHour, lastHour } = useMemo(() => {
    const starts = db.classes.map(c => c.start), ends = db.classes.map(c => c.end)
    const first = Math.min(8, starts.length ? Math.floor(Math.min(...starts) / 60) : 8)
    const last = Math.min(24, Math.max(17, ends.length ? Math.ceil(Math.max(...ends) / 60) : 17))
    return { firstHour: first, lastHour: last }
  }, [db.classes])
  const hours = Array.from({ length: lastHour - firstHour }, (_, i) => firstHour + i)
  const nowMin = now.getHours() * 60 + now.getMinutes()
  const subjectOf = (id: string) => db.subjects.find(s => s.id === id)
  const openNew = (day: number, start = 8 * 60) => setTarget({ slot: null, day, start })

  const header = (
    <div className="day-head" style={{ gridTemplateColumns: `${mode === 'week' ? '44px ' : ''}repeat(${days.length}, 1fr)` }}>
      {mode === 'week' && <span />}
      {days.map(d => {
        const date = addDays(monday, d - 1)
        const isToday = d === todayIso
        const isSel = mode === 'day' && d === activeDay
        return (
          <button key={d} className={cx('day-chip', isSel && 'sel', isToday && 'today')} onClick={() => { setSelected(d); setMode('day') }}>
            <span>{WEEKDAYS[d - 1].toUpperCase()}</span><b>{date.getDate()}</b>
          </button>
        )
      })}
    </div>
  )

  return (
    <>
      <PageHeader title="Horário"
        actions={<>
          <Segmented value={mode} onChange={setMode} options={[{ value: 'week', label: 'Semana' }, { value: 'day', label: 'Dia' }]} />
          <Button onClick={() => actions.setSettings({ showWeekend: !db.settings.showWeekend })}>
            {db.settings.showWeekend ? 'Ocultar fim de semana' : 'Mostrar fim de semana'}</Button>
          <Button variant="primary" icon="plus" onClick={() => openNew(mode === 'day' ? activeDay : Math.min(todayIso, 5))}>Nova aula</Button>
        </>} />

      {header}

      {mode === 'week' ? (
        <div className="week-grid" style={{ gridTemplateColumns: `44px repeat(${days.length}, 1fr)` }}>
          <div className="gutter">{hours.map(h => <span key={h} style={{ height: HOUR_H }}>{String(h).padStart(2, '0')}</span>)}</div>
          {days.map(d => (
            <div key={d} className={cx('day-col', d === todayIso && 'today')} style={{ height: HOUR_H * hours.length }}
                 onClick={e => {
                   const rect = e.currentTarget.getBoundingClientRect()
                   const h = firstHour + Math.min(hours.length - 1, Math.max(0, Math.floor((e.clientY - rect.top) / HOUR_H)))
                   openNew(d, h * 60)
                 }}>
              {hours.map(h => <i key={h} style={{ top: (h - firstHour) * HOUR_H }} />)}
              {db.classes.filter(c => c.day === d).map(c => {
                const s = subjectOf(c.subjectId); const color = s?.color ?? '#64748b'
                const top = ((c.start - firstHour * 60) / 60) * HOUR_H
                const height = Math.max(26, ((c.end - c.start) / 60) * HOUR_H)
                return (
                  <div key={c.id} className="block" style={{ top: top + 1.5, height: height - 3, background: color + '38', borderLeftColor: color }}
                       onClick={e => { e.stopPropagation(); setTarget({ slot: c, day: c.day, start: c.start }) }}>
                    <b>{s?.name ?? '—'}</b>
                    {c.room && height > 44 && <span>{c.room}</span>}
                    {height > 70 && <span>{minutesText(c.start)}–{minutesText(c.end)}</span>}
                  </div>
                )
              })}
              {d === todayIso && nowMin >= firstHour * 60 && nowMin < lastHour * 60 && (
                <div className="now-line" style={{ top: ((nowMin - firstHour * 60) / 60) * HOUR_H }} />
              )}
            </div>
          ))}
        </div>
      ) : (
        <div className="col" style={{ gap: 10, maxWidth: 820, margin: '0 auto' }}>
          {db.classes.filter(c => c.day === activeDay).length === 0 && (
            <Empty icon="calendar" title={`Sem aulas: ${WEEKDAYS_LONG[activeDay - 1]}`} text="Aproveita o tempo livre ou adiciona uma aula."
                   action={<Button variant="primary" onClick={() => openNew(activeDay)}>Adicionar aula</Button>} />
          )}
          {[...db.classes].filter(c => c.day === activeDay).sort((a, b) => a.start - b.start).map(c => {
            const s = subjectOf(c.subjectId); const color = s?.color ?? '#64748b'
            const isNow = activeDay === todayIso && nowMin >= c.start && nowMin < c.end
            return (
              <Card key={c.id} className="class-card" onClick={() => setTarget({ slot: c, day: c.day, start: c.start })}>
                <div className="class-time"><b>{minutesText(c.start)}</b><span className="muted">{minutesText(c.end)}</span></div>
                <i className="bar" style={{ background: color }} />
                <div className="grow">
                  <h3>{s?.name ?? '—'}</h3>
                  <div className="muted small row" style={{ gap: 14, marginTop: 4 }}>
                    {c.room && <span className="row" style={{ gap: 5 }}><Icon name="pin" size={14} />{c.room}</span>}
                    <span className="row" style={{ gap: 5 }}><Icon name="clock" size={14} />{shortDur((c.end - c.start) * 60)}</span>
                  </div>
                </div>
                {isNow && <span className="pill" style={{ background: color, color: '#fff' }}>AGORA</span>}
              </Card>
            )
          })}
        </div>
      )}

      {db.classes.length === 0 && mode === 'week' && (
        <Empty icon="calendar" title="Ainda sem aulas" text="Clica em “Nova aula” ou num espaço vazio da grelha para adicionar uma aula." />
      )}
      {target && <SlotForm target={target} onClose={() => setTarget(null)} />}
    </>
  )
}

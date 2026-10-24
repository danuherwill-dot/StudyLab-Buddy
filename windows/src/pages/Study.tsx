import { useState } from 'react'
import { useStore } from '../store'
import { useTimer, type Mode } from '../timer'
import { useNow } from '../hooks'
import { useUI } from '../ui-context'
import { Icon, type IconName } from '../components/Icon'
import { TickRing } from '../components/charts'
import { Button, Card, Modal, PageHeader, cx } from '../components/ui'
import { clock, weekdayLong } from '../format'

const MODES: { mode: Mode; label: string; icon: IconName }[] = [
  { mode: 'clock', label: 'Relógio', icon: 'clock' },
  { mode: 'pomodoro', label: 'Pomodoro', icon: 'timer' },
  { mode: 'stopwatch', label: 'Cronómetro', icon: 'stopwatch' },
  { mode: 'countdown', label: 'Contagem', icon: 'hourglass' }
]

function StepperRow({ label, value, onChange, max }: { label: string; value: number; onChange: (v: number) => void; max: number }) {
  return (
    <div className="stepper-row">
      <span>{label}</span>
      <span className="grow" />
      <span className="muted mono">{value} min</span>
      <div className="stepper">
        <button onClick={() => onChange(Math.max(1, value - 1))} aria-label="Menos">−</button>
        <button onClick={() => onChange(Math.min(max, value + 1))} aria-label="Mais">+</button>
      </div>
    </div>
  )
}

function ClockFace({ tint }: { tint: string }) {
  const now = useNow(1000)
  return (
    <TickRing progress={(now.getSeconds() + 1) / 60} tint={tint}>
      <div className="time-big">{now.toLocaleTimeString('pt-PT', { hour: '2-digit', minute: '2-digit' })}</div>
      <div style={{ fontWeight: 700, textTransform: 'capitalize' }}>{weekdayLong(now)}</div>
      <div className="muted">{now.toLocaleDateString('pt-PT', { day: 'numeric', month: 'long' })}</div>
    </TickRing>
  )
}

export default function StudyPage() {
  const { db } = useStore()
  const t = useTimer()
  const ui = useUI()
  const [item, setItem] = useState('')
  const subject = db.subjects.find(s => s.id === t.subjectId)
  const isBreak = t.mode === 'pomodoro' && t.phase !== 'focus'
  const tint = isBreak ? '#22c55e' : subject?.color ?? '#4f6df2'
  const subjects = [...db.subjects].sort((a, b) => a.name.localeCompare(b.name, 'pt'))
  const done = t.checklist.filter(i => i.done).length

  const addItem = () => { t.addItem(item); setItem('') }

  return (
    <>
      <PageHeader title="Estudar" actions={<Button icon="books" onClick={ui.openSubjects} disabled={t.active}>Disciplinas</Button>} />
      <div className="study-grid">
        <div className="study-left">
          {t.mode === 'clock' ? <ClockFace tint={tint} /> : (
            <TickRing progress={t.ringProgress} tint={tint}>
              <span className="pill" style={{ background: tint + '38' }}>{t.statusLabel.toUpperCase()}</span>
              <div className="time-big">{clock(t.displaySeconds)}</div>
              {t.mode === 'pomodoro' && (
                <div className="dots">{[0, 1, 2, 3].map(i => <i key={i} style={i < t.completed % 4 ? { background: tint } : undefined} />)}</div>
              )}
            </TickRing>
          )}

          {t.mode !== 'clock' && (
            <div className="controls">
              {t.state === 'idle' ? (
                <Button variant="primary" icon="play" className="start-btn" onClick={t.start}>Iniciar</Button>
              ) : (
                <div className="round-controls">
                  <div><button className="round red" onClick={t.discard} title="Descartar"><Icon name="x" size={22} /></button><span>Descartar</span></div>
                  <div>
                    <button className="round big" style={{ background: tint }} onClick={t.state === 'running' ? t.pause : t.start}>
                      <Icon name={t.state === 'running' ? 'pause' : 'play'} size={30} /></button>
                    <span>{t.state === 'running' ? 'Pausar' : 'Retomar'}</span>
                  </div>
                  <div><button className="round green" onClick={t.finish} title="Terminar"><Icon name="check" size={22} /></button><span>Terminar</span></div>
                </div>
              )}
              {isBreak && <Button variant="ghost" onClick={t.skipBreak}>Saltar pausa</Button>}
            </div>
          )}
        </div>

        <div className="study-right">
          <div className="mode-tiles">
            {MODES.map(m => (
              <button key={m.mode} className={cx('mode-tile', t.mode === m.mode && 'on')} disabled={t.state !== 'idle'} onClick={() => t.setMode(m.mode)}>
                <Icon name={m.icon} size={22} /><span>{m.label}</span>
              </button>
            ))}
          </div>

          <div className={cx('subject-pick', !t.subjectId && 'missing')}>
            <span className="dot" style={{ background: subject?.color ?? '#94a3b8', width: 12, height: 12 }} />
            <select value={t.subjectId ?? ''} disabled={t.active}
                    onChange={e => { if (e.target.value === '__manage') ui.openSubjects(); else t.setSubjectId(e.target.value || null) }}>
              <option value="">{db.subjects.length ? 'Escolhe uma disciplina' : 'Adiciona uma disciplina para começar'}</option>
              {subjects.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
              <option value="__manage">Gerir disciplinas…</option>
            </select>
            <Icon name="down" size={16} />
          </div>

          {t.state === 'idle' && (t.mode === 'pomodoro' || t.mode === 'countdown') && (
            <Card className="steppers">
              {t.mode === 'pomodoro' ? (
                <>
                  <StepperRow label="Foco" value={t.focusMin} max={120} onChange={v => t.setDuration('focusMin', v)} />
                  <StepperRow label="Pausa curta" value={t.shortMin} max={30} onChange={v => t.setDuration('shortMin', v)} />
                  <StepperRow label="Pausa longa" value={t.longMin} max={60} onChange={v => t.setDuration('longMin', v)} />
                </>
              ) : <StepperRow label="Duração" value={t.countdownMin} max={240} onChange={v => t.setDuration('countdownMin', v)} />}
            </Card>
          )}

          {t.mode !== 'clock' && (
            <Card>
              <div className="row" style={{ marginBottom: 12 }}>
                <Icon name="checklist" size={20} /><h3>Lista de foco</h3>
                <span className="grow" />
                {t.checklist.length > 0 && <span className="muted mono">{done}/{t.checklist.length}</span>}
              </div>
              <div className="row" style={{ gap: 8 }}>
                <input className="input" placeholder="Adicionar uma tarefa rápida…" value={item}
                       onChange={e => setItem(e.target.value)} onKeyDown={e => e.key === 'Enter' && addItem()} />
                <button className="icon-btn accent" onClick={addItem} disabled={!item.trim()} aria-label="Adicionar"><Icon name="plus" size={19} /></button>
              </div>
              <div className="col" style={{ gap: 6, marginTop: 12 }}>
                {t.checklist.map(i => (
                  <div key={i.id} className="check-row">
                    <button className={cx('check', i.done && 'on')} style={i.done ? { background: tint, borderColor: tint } : undefined}
                            onClick={() => t.toggleItem(i.id)} aria-label="Concluir">{i.done && <Icon name="check" size={14} />}</button>
                    <span className={cx('grow', i.done && 'struck')}>{i.title}</span>
                    <button className="plain" onClick={() => t.removeItem(i.id)} aria-label="Remover"><Icon name="x" size={14} /></button>
                  </div>
                ))}
              </div>
            </Card>
          )}
        </div>
      </div>

      {t.subjectRequired && (
        <Modal title="Escolhe primeiro uma disciplina" onClose={t.dismissSubjectRequired} width={420}
               footer={<Button variant="primary" onClick={t.dismissSubjectRequired}>OK</Button>}>
          <p className="muted" style={{ margin: 0, lineHeight: 1.5 }}>
            Cada sessão de estudo fica associada a uma disciplina, para aparecer corretamente nas estatísticas.
          </p>
        </Modal>
      )}
    </>
  )
}

import { useMemo, useState } from 'react'
import { useStore, useActions } from '../store'
import { Icon } from '../components/Icon'
import { Badge, Button, Card, Chip, Dot, Empty, Field, Modal, PageHeader, Segmented, SubjectSelect, Toggle, cx } from '../components/ui'
import { reminderDescription } from '../notify'
import type { Task, TaskType } from '../types'
import { addDays, sameDay, startOfDay, timeOf, toLocalInput, uid, dayMonth } from '../format'

const FILTERS: { key: 'all' | TaskType; label: string }[] = [
  { key: 'all', label: 'Todas' }, { key: 'homework', label: 'TPC' }, { key: 'test', label: 'Testes' }, { key: 'assignment', label: 'Trabalhos' }
]
const TYPE_LABEL: Record<TaskType, string> = { homework: 'TPC', test: 'Teste', assignment: 'Trabalho' }
const TYPE_ICON = { homework: 'book', test: 'test', assignment: 'doc' } as const

const isOverdue = (t: Task) => !t.done && new Date(t.due).getTime() < Date.now()

function dueLabel(t: Task) {
  const due = new Date(t.due)
  const days = Math.round((startOfDay(due).getTime() - startOfDay(new Date()).getTime()) / 86_400_000)
  if (isOverdue(t)) return days === 0 ? 'Em atraso' : `Em atraso ${-days}d`
  if (days === 0) return 'Hoje'
  if (days === 1) return 'Amanhã'
  if (days >= 2 && days <= 6) return due.toLocaleDateString('pt-PT', { weekday: 'long' })
  return dayMonth(due)
}

function TaskForm({ task, onClose }: { task: Task | null; onClose: () => void }) {
  const { db } = useStore()
  const actions = useActions()
  const tomorrow9 = useMemo(() => { const d = addDays(new Date(), 1); d.setHours(9, 0, 0, 0); return d }, [])
  const [title, setTitle] = useState(task?.title ?? '')
  const [type, setType] = useState<TaskType>(task?.type ?? 'homework')
  const [subjectId, setSubjectId] = useState<string | null>(task?.subjectId ?? null)
  const [due, setDue] = useState(toLocalInput(task?.due ?? tomorrow9))
  const [remind, setRemind] = useState(task?.remind ?? true)
  const subjects = [...db.subjects].sort((a, b) => a.name.localeCompare(b.name, 'pt'))

  const save = () => {
    if (!title.trim() || !due) return
    const dueIso = new Date(due).toISOString()
    // A changed due date or type restarts the reminders.
    const keepNotified = task && task.due === dueIso && task.type === type ? task.notified : []
    actions.upsert('tasks', { id: task?.id ?? uid(), title: title.trim(), type, subjectId, due: dueIso, remind, done: task?.done ?? false, notified: keepNotified })
    onClose()
  }

  return (
    <Modal title={task ? 'Editar tarefa' : 'Nova tarefa'} onClose={onClose}
           footer={<>
             {task && <Button variant="danger" icon="trash" style={{ marginRight: 'auto' }} onClick={() => { actions.remove('tasks', task.id); onClose() }}>Eliminar tarefa</Button>}
             <Button variant="ghost" onClick={onClose}>Cancelar</Button>
             <Button variant="primary" onClick={save} disabled={!title.trim()}>Guardar</Button></>}>
      <Field label="Título"><input className="input" autoFocus value={title} onChange={e => setTitle(e.target.value)} onKeyDown={e => e.key === 'Enter' && save()} /></Field>
      <Field label="Tipo">
        <Segmented value={type} onChange={setType} options={[{ value: 'homework', label: 'TPC' }, { value: 'test', label: 'Teste' }, { value: 'assignment', label: 'Trabalho' }]} />
      </Field>
      <Field label="Disciplina"><SubjectSelect value={subjectId} onChange={setSubjectId} subjects={subjects} allowNone /></Field>
      <Field label="Entrega"><input className="input" type="datetime-local" value={due} onChange={e => setDue(e.target.value)} /></Field>
      <Toggle checked={remind} onChange={setRemind} label="Lembrar-me" hint={remind ? reminderDescription(type) : undefined} />
    </Modal>
  )
}

function TaskCard({ task, onToggle, onEdit }: { task: Task; onToggle: () => void; onEdit: () => void }) {
  const { db } = useStore()
  const subject = db.subjects.find(s => s.id === task.subjectId)
  const accent = subject?.color ?? 'var(--accent)'
  const overdue = isOverdue(task)
  const today = sameDay(new Date(task.due), new Date())
  return (
    <Card className={cx('task-card', task.done && 'done')} onClick={onEdit}>
      <button className={cx('check big', task.done && 'on')} style={{ borderColor: accent, background: task.done ? accent : 'transparent' }}
              onClick={e => { e.stopPropagation(); onToggle() }} aria-label="Concluir">{task.done && <Icon name="check" size={16} />}</button>
      <div className="grow">
        <div className={cx('task-title', task.done && 'struck')}>{task.title}</div>
        <div className="row" style={{ gap: 10, marginTop: 6, flexWrap: 'wrap' }}>
          {subject && <Badge color={subject.color}><Dot color={subject.color} size={7} />{subject.name}</Badge>}
          <span className="muted small row" style={{ gap: 5 }}><Icon name={TYPE_ICON[task.type]} size={14} />{TYPE_LABEL[task.type]}</span>
        </div>
      </div>
      <div className="task-due">
        <b style={{ color: task.done ? 'var(--muted)' : overdue ? 'var(--bad)' : today ? '#fb923c' : undefined }}>{dueLabel(task)}</b>
        <span className="muted small row" style={{ gap: 4, justifyContent: 'flex-end' }}>
          {task.remind && !task.done && <Icon name="bell" size={12} />}{timeOf(task.due)}
        </span>
      </div>
    </Card>
  )
}

export default function TasksPage() {
  const { db } = useStore()
  const actions = useActions()
  const [filter, setFilter] = useState<'all' | TaskType>('all')
  const [editing, setEditing] = useState<Task | 'new' | null>(null)

  const sorted = [...db.tasks].sort((a, b) => +new Date(a.due) - +new Date(b.due))
  const filtered = sorted.filter(t => filter === 'all' || t.type === filter)
  const open = filtered.filter(t => !t.done)
  const overdue = open.filter(isOverdue)
  const today = open.filter(t => !isOverdue(t) && sameDay(new Date(t.due), new Date()))
  const weekEnd = addDays(startOfDay(new Date()), 7).getTime()
  const week = open.filter(t => !isOverdue(t) && !sameDay(new Date(t.due), new Date()) && new Date(t.due).getTime() < weekEnd)
  const later = open.filter(t => new Date(t.due).getTime() >= weekEnd)
  const completed = filtered.filter(t => t.done).reverse()

  const toggle = (t: Task) => actions.upsert('tasks', { ...t, done: !t.done })

  const section = (title: string, items: Task[], tint?: string) => items.length > 0 && (
    <section className="task-section" key={title}>
      <h3 style={tint ? { color: tint } : undefined}>{title}<span className="count">{items.length}</span></h3>
      <div className="col" style={{ gap: 10 }}>{items.map(t => <TaskCard key={t.id} task={t} onToggle={() => toggle(t)} onEdit={() => setEditing(t)} />)}</div>
    </section>
  )

  return (
    <>
      <PageHeader title="Tarefas" actions={<Button variant="primary" icon="plus" onClick={() => setEditing('new')}>Nova tarefa</Button>} />
      <div className="tiles">
        <Card className="tile"><Icon name="alert" size={22} style={{ color: 'var(--bad)' }} /><b>{overdue.length}</b><span className="muted small">Em atraso</span></Card>
        <Card className="tile"><Icon name="sun" size={22} style={{ color: '#fb923c' }} /><b>{today.length}</b><span className="muted small">Hoje</span></Card>
        <Card className="tile"><Icon name="calendar" size={22} style={{ color: 'var(--accent)' }} /><b>{week.length}</b><span className="muted small">Esta semana</span></Card>
      </div>
      <div className="row" style={{ gap: 8, margin: '18px 0 6px', flexWrap: 'wrap' }}>
        {FILTERS.map(f => <Chip key={f.key} active={filter === f.key} onClick={() => setFilter(f.key)}>{f.label}</Chip>)}
      </div>
      <div style={{ maxWidth: 900 }}>
        {section('Em atraso', overdue, 'var(--bad)')}
        {section('Hoje', today, 'var(--accent)')}
        {section('Esta semana', week)}
        {section('Mais tarde', later)}
        {section('Concluídas', completed)}
        {filtered.length === 0 && <Empty icon="check" title="Tudo em dia" text="Clica em “Nova tarefa” para adicionar TPC, um teste ou um trabalho." />}
      </div>
      {editing && <TaskForm task={editing === 'new' ? null : editing} onClose={() => setEditing(null)} />}
    </>
  )
}

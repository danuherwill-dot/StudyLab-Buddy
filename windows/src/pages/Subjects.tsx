import { useState } from 'react'
import { useStore, useActions } from '../store'
import { Modal, Button, Field, Dot, Chip, IconButton, Empty, Confirm } from '../components/ui'
import { SUBJECT_COLORS, type Subject } from '../types'
import { uid, num, parseNumber } from '../format'

function SubjectForm({ subject, onClose }: { subject: Subject | null; onClose: () => void }) {
  const { db } = useStore()
  const actions = useActions()
  const [name, setName] = useState(subject?.name ?? '')
  const [color, setColor] = useState(subject?.color ?? SUBJECT_COLORS[0])
  const [years, setYears] = useState<number[]>(subject?.years ?? [10, 11, 12])
  const [target, setTarget] = useState(num(subject?.targetHours ?? 3, 1))
  const secondary = db.settings.level === 'secondary'
  const targetNum = parseNumber(target)
  const valid = name.trim() !== '' && years.length > 0 && targetNum != null && targetNum >= 0

  const save = () => {
    if (!valid) return
    actions.upsert('subjects', {
      id: subject?.id ?? uid(), name: name.trim(), color, targetHours: targetNum!, years: [...years].sort()
    })
    onClose()
  }

  return (
    <Modal title={subject ? 'Editar disciplina' : 'Nova disciplina'} onClose={onClose}
           footer={<><Button variant="ghost" onClick={onClose}>Cancelar</Button><Button variant="primary" onClick={save} disabled={!valid}>Guardar</Button></>}>
      <Field label="Nome"><input className="input" autoFocus value={name} placeholder="ex.: Matemática"
                                  onChange={e => setName(e.target.value)} onKeyDown={e => e.key === 'Enter' && save()} /></Field>
      <Field label="Cor">
        <div className="swatches">
          {SUBJECT_COLORS.map(c => (
            <button key={c} className={c === color ? 'swatch on' : 'swatch'} style={{ background: c }} onClick={() => setColor(c)} aria-label={c} />
          ))}
        </div>
      </Field>
      {secondary && (
        <Field label="Anos do Secundário"
               hint="Escolhe os anos em que a disciplina é lecionada. Português, Matemática e Educação Física costumam ter 10.º, 11.º e 12.º; as disciplinas de um só ano pesam menos na média final.">
          <div className="row" style={{ gap: 8 }}>
            {[10, 11, 12].map(y => (
              <Chip key={y} active={years.includes(y)}
                    onClick={() => setYears(cur => cur.includes(y) ? cur.filter(v => v !== y) : [...cur, y])}>{y}.º</Chip>
            ))}
          </div>
        </Field>
      )}
      <Field label="Meta semanal de estudo (horas)">
        <input className="input" value={target} inputMode="decimal" onChange={e => setTarget(e.target.value)} />
      </Field>
    </Modal>
  )
}

export function SubjectsModal({ onClose }: { onClose: () => void }) {
  const { db } = useStore()
  const actions = useActions()
  const [editing, setEditing] = useState<Subject | 'new' | null>(null)
  const [deleting, setDeleting] = useState<Subject | null>(null)
  const subjects = [...db.subjects].sort((a, b) => a.name.localeCompare(b.name, 'pt'))

  return (
    <>
      <Modal title="Disciplinas" onClose={onClose} width={520}
             footer={<><Button variant="ghost" onClick={onClose}>Concluído</Button><Button variant="primary" icon="plus" onClick={() => setEditing('new')}>Nova disciplina</Button></>}>
        {subjects.length === 0 && <Empty icon="books" title="Ainda sem disciplinas" text="Adiciona as tuas disciplinas para associar sessões de estudo, tarefas e notas." />}
        <div className="col" style={{ gap: 8 }}>
          {subjects.map(s => (
            <div key={s.id} className="list-row">
              <Dot color={s.color} size={14} />
              <div className="grow">
                <div style={{ fontWeight: 600 }}>{s.name}</div>
                <div className="muted small">
                  {db.settings.level === 'secondary' ? `${s.years.map(y => `${y}.º`).join(' · ')} · ` : ''}{num(s.targetHours, 1)} h/semana
                </div>
              </div>
              <IconButton icon="gear" title="Editar" onClick={() => setEditing(s)} />
              <IconButton icon="trash" title="Eliminar" onClick={() => setDeleting(s)} />
            </div>
          ))}
        </div>
      </Modal>
      {editing && <SubjectForm subject={editing === 'new' ? null : editing} onClose={() => setEditing(null)} />}
      {deleting && (
        <Confirm title={`Eliminar ${deleting.name}?`}
                 message="Também serão eliminadas as aulas, tarefas, notas e sessões de estudo associadas a esta disciplina."
                 onCancel={() => setDeleting(null)}
                 onConfirm={() => { actions.removeSubject(deleting.id); setDeleting(null) }} />
      )}
    </>
  )
}

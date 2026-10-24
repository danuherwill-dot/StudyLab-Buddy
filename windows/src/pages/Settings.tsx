import { useState, type ReactNode } from 'react'
import { useStore, useActions } from '../store'
import { Button, Card, Confirm, PageHeader, Segmented, Toggle } from '../components/ui'
import { ensureNotificationPermission, notify } from '../notify'

type Clear = 'classes' | 'tasks' | 'grades' | 'sessions' | 'subjects' | 'everything'

const COPY: Record<Clear, { title: string; message: string }> = {
  classes: { title: 'Apagar o horário?', message: 'Todas as aulas do teu horário serão eliminadas.' },
  tasks: { title: 'Apagar todas as tarefas?', message: 'Todos os TPC, testes e trabalhos serão eliminados e os respetivos lembretes cancelados.' },
  grades: { title: 'Apagar todas as notas?', message: 'Todas as notas de teste e de período serão eliminadas.' },
  sessions: { title: 'Apagar o histórico de estudo?', message: 'Todas as sessões de estudo registadas serão eliminadas, pelo que as Estatísticas serão repostas.' },
  subjects: { title: 'Apagar todas as disciplinas?', message: 'Todas as disciplinas serão eliminadas, juntamente com as aulas, tarefas, notas e sessões de estudo associadas.' },
  everything: { title: 'Apagar TODOS os dados?', message: 'Disciplinas, horário, tarefas, notas e histórico de estudo serão eliminados. Esta ação não pode ser anulada.' }
}

function Section({ title, children, footer }: { title: string; children: ReactNode; footer?: string }) {
  return (
    <section className="settings-section">
      <h3 className="eyebrow">{title.toUpperCase()}</h3>
      <Card style={{ padding: '6px 20px' }}>{children}</Card>
      {footer && <p className="muted small" style={{ margin: '8px 6px 0' }}>{footer}</p>}
    </section>
  )
}

export default function SettingsPage() {
  const { db } = useStore()
  const actions = useActions()
  const s = db.settings
  const [pending, setPending] = useState<Clear | null>(null)

  const counts: Record<Exclude<Clear, 'everything'>, number> = {
    classes: db.classes.length, tasks: db.tasks.length, grades: db.grades.length, sessions: db.sessions.length, subjects: db.subjects.length
  }
  const rows: [Exclude<Clear, 'everything'>, string][] = [
    ['classes', 'Apagar horário'], ['tasks', 'Apagar tarefas'], ['grades', 'Apagar notas'],
    ['sessions', 'Apagar histórico de estudo'], ['subjects', 'Apagar disciplinas']
  ]

  const confirm = () => {
    if (!pending) return
    if (pending === 'everything') actions.clearAll()
    else if (pending === 'subjects') actions.clearSubjects()
    else actions.clear(pending)
    setPending(null)
  }

  return (
    <>
      <PageHeader title="Definições" />
      <div className="settings">
        <Section title="Aparência">
          <div className="toggle-row"><div className="toggle-label">Tema</div>
            <Segmented value={s.theme} onChange={theme => actions.setSettings({ theme })}
                       options={[{ value: 'system', label: 'Sistema' }, { value: 'light', label: 'Claro' }, { value: 'dark', label: 'Escuro' }]} />
          </div>
        </Section>

        <Section title="Notificações"
                 footer="Os lembretes de tarefas abrangem TPC, trabalhos e testes com “Lembrar-me” ativado. Os alertas do temporizador disparam quando um bloco de foco, uma pausa ou uma contagem termina.">
          <Toggle checked={s.taskReminders} onChange={v => actions.setSettings({ taskReminders: v })} label="Lembretes de tarefas e testes" />
          <Toggle checked={s.timerAlerts} onChange={v => actions.setSettings({ timerAlerts: v })} label="Alertas do temporizador" />
          <div className="toggle-row">
            <div className="toggle-label">Notificação de teste</div>
            <Button onClick={async () => { await ensureNotificationPermission(); notify('As notificações do StudyLab estão ativas', 'Vais receber lembretes como este.') }}>Enviar</Button>
          </div>
        </Section>

        <Section title="Windows" footer="Com a app em segundo plano, os lembretes de tarefas continuam a aparecer mesmo com a janela fechada. Para sair de vez, usa o ícone da área de notificação.">
          <Toggle checked={s.keepInTray} onChange={v => actions.setSettings({ keepInTray: v })} label="Manter em segundo plano ao fechar a janela" />
          <Toggle checked={s.launchAtLogin} onChange={v => actions.setSettings({ launchAtLogin: v })} label="Iniciar com o Windows" />
        </Section>

        <Section title="Média do Secundário"
                 footer="Ativado: na média do curso, uma disciplina de 3 anos conta ×3, de 2 anos ×2 e de 1 ano ×1 (regras atuais para quem começou o 10.º em 2023/24 ou depois). Desativado: todas as disciplinas contam o mesmo.">
          <Toggle checked={s.weightByDuration} onChange={v => actions.setSettings({ weightByDuration: v })} label="Ponderar disciplinas pela duração" />
        </Section>

        <Section title="Os teus dados" footer="Os dados ficam guardados apenas neste computador. Apagar disciplinas também remove tudo o que está associado a elas.">
          {rows.map(([key, label]) => (
            <div className="toggle-row" key={key}>
              <div className="toggle-label">{label}</div>
              <div className="row"><span className="muted mono">{counts[key]}</span>
                <Button variant="danger" disabled={counts[key] === 0} onClick={() => setPending(key)}>Apagar</Button></div>
            </div>
          ))}
          <div className="toggle-row">
            <div className="toggle-label">Apagar todos os dados</div>
            <Button variant="danger" onClick={() => setPending('everything')}
                    disabled={Object.values(counts).every(c => c === 0)}>Apagar tudo</Button>
          </div>
        </Section>

        <Section title="Atalhos">
          <div className="toggle-row"><span>Navegar entre secções</span><span className="muted mono">Ctrl + 1 … 5</span></div>
          <div className="toggle-row"><span>Definições</span><span className="muted mono">Ctrl + ,</span></div>
        </Section>
        <p className="muted small" style={{ textAlign: 'center' }}>StudyLab 1.0 · O teu planeador de estudo</p>
      </div>
      {pending && <Confirm title={COPY[pending].title} message={COPY[pending].message} onCancel={() => setPending(null)} onConfirm={confirm} />}
    </>
  )
}

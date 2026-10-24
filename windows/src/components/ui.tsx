import { useEffect, type CSSProperties, type ReactNode } from 'react'
import { Icon, type IconName } from './Icon'

export const cx = (...c: (string | false | null | undefined)[]) => c.filter(Boolean).join(' ')

export function Card({ children, className, style, onClick }: {
  children: ReactNode; className?: string; style?: CSSProperties; onClick?: () => void
}) {
  return <div className={cx('card', onClick && 'clickable', className)} style={style} onClick={onClick}>{children}</div>
}

export function Button({ children, variant = 'default', icon, onClick, disabled, title, className, type = 'button', style }: {
  children?: ReactNode; variant?: 'default' | 'primary' | 'danger' | 'ghost' | 'success'; icon?: IconName
  onClick?: () => void; disabled?: boolean; title?: string; className?: string; type?: 'button' | 'submit'; style?: CSSProperties
}) {
  return (
    <button type={type} className={cx('btn', variant, className)} onClick={onClick} disabled={disabled} title={title} style={style}>
      {icon && <Icon name={icon} size={18} />}
      {children}
    </button>
  )
}

export function IconButton({ icon, onClick, title, className, disabled }: {
  icon: IconName; onClick?: () => void; title: string; className?: string; disabled?: boolean
}) {
  return <button className={cx('icon-btn', className)} onClick={onClick} title={title} aria-label={title} disabled={disabled}><Icon name={icon} size={19} /></button>
}

export function Chip({ active, onClick, children, disabled, style }: {
  active?: boolean; onClick?: () => void; children: ReactNode; disabled?: boolean; style?: CSSProperties
}) {
  return <button className={cx('chip', active && 'active')} onClick={onClick} disabled={disabled} style={style}>{children}</button>
}

export function Segmented<T extends string | number>({ value, options, onChange, className }: {
  value: T; options: { value: T; label: ReactNode }[]; onChange: (v: T) => void; className?: string
}) {
  return (
    <div className={cx('segmented', className)} role="tablist">
      {options.map(o => (
        <button key={String(o.value)} role="tab" aria-selected={o.value === value}
                className={cx(o.value === value && 'active')} onClick={() => onChange(o.value)}>{o.label}</button>
      ))}
    </div>
  )
}

export function Badge({ children, tone = 'neutral', color }: {
  children: ReactNode; tone?: 'neutral' | 'good' | 'warn' | 'bad' | 'accent'; color?: string
}) {
  return <span className={cx('badge', tone)} style={color ? { background: color + '2e', color } : undefined}>{children}</span>
}

export function Dot({ color, size = 10 }: { color?: string; size?: number }) {
  return <span className="dot" style={{ width: size, height: size, background: color ?? '#64748b' }} />
}

export function Progress({ value, color }: { value: number; color?: string }) {
  return <div className="progress"><div style={{ width: `${Math.min(100, Math.max(0, value * 100))}%`, background: color }} /></div>
}

export function Empty({ icon, title, text, action }: { icon: IconName; title: string; text?: string; action?: ReactNode }) {
  return (
    <div className="empty">
      <Icon name={icon} size={44} />
      <h3>{title}</h3>
      {text && <p>{text}</p>}
      {action}
    </div>
  )
}

export function Modal({ title, onClose, children, footer, width = 460 }: {
  title: string; onClose: () => void; children: ReactNode; footer?: ReactNode; width?: number
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])
  return (
    <div className="overlay" onMouseDown={e => { if (e.target === e.currentTarget) onClose() }}>
      <div className="modal" style={{ width }} role="dialog" aria-modal aria-label={title}>
        <div className="modal-head">
          <h2>{title}</h2>
          <IconButton icon="x" title="Fechar" onClick={onClose} />
        </div>
        <div className="modal-body">{children}</div>
        {footer && <div className="modal-foot">{footer}</div>}
      </div>
    </div>
  )
}

export function Confirm({ title, message, confirmLabel = 'Apagar', onConfirm, onCancel }: {
  title: string; message: string; confirmLabel?: string; onConfirm: () => void; onCancel: () => void
}) {
  return (
    <Modal title={title} onClose={onCancel} width={420}
           footer={<><Button variant="ghost" onClick={onCancel}>Cancelar</Button><Button variant="danger" onClick={onConfirm}>{confirmLabel}</Button></>}>
      <p className="muted" style={{ margin: 0, lineHeight: 1.5 }}>{message}</p>
    </Modal>
  )
}

export function Field({ label, children, hint, error }: { label: string; children: ReactNode; hint?: string; error?: string | null }) {
  return (
    <label className="field">
      <span className="field-label">{label}</span>
      {children}
      {error ? <span className="field-error">{error}</span> : hint ? <span className="field-hint">{hint}</span> : null}
    </label>
  )
}

export function Toggle({ checked, onChange, label, hint }: { checked: boolean; onChange: (v: boolean) => void; label: string; hint?: string }) {
  return (
    <div className="toggle-row">
      <div>
        <div className="toggle-label">{label}</div>
        {hint && <div className="muted small">{hint}</div>}
      </div>
      <button className={cx('switch', checked && 'on')} role="switch" aria-checked={checked} onClick={() => onChange(!checked)}><span /></button>
    </div>
  )
}

export function PageHeader({ title, actions, children }: { title: string; actions?: ReactNode; children?: ReactNode }) {
  return (
    <header className="page-header">
      <h1>{title}</h1>
      {children}
      <div className="grow" />
      {actions}
    </header>
  )
}

export function SubjectSelect({ value, onChange, subjects, allowNone, placeholder = 'Escolhe…' }: {
  value: string | null; onChange: (id: string | null) => void
  subjects: { id: string; name: string }[]; allowNone?: boolean; placeholder?: string
}) {
  return (
    <select className="input" value={value ?? ''} onChange={e => onChange(e.target.value || null)}>
      <option value="">{allowNone ? 'Nenhuma' : placeholder}</option>
      {subjects.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
    </select>
  )
}

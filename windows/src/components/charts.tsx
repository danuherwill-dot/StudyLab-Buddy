// Small hand-drawn SVG charts (no chart library needed).

export function BarChart({ data, color = 'var(--accent)', height = 180, unit = 'h' }: {
  data: { label: string; value: number }[]; color?: string; height?: number; unit?: string
}) {
  const max = Math.max(0.5, ...data.map(d => d.value))
  const top = niceCeil(max)
  const W = 640, padL = 8, padR = 40, padT = 12, padB = 26
  const chartW = W - padL - padR, chartH = height - padT - padB
  const slot = chartW / Math.max(1, data.length)
  const bar = Math.min(48, slot * 0.62)
  const lines = [0, 0.5, 1].map(f => f * top)
  const skip = data.length > 16 ? Math.ceil(data.length / 12) : 1
  return (
    <svg viewBox={`0 0 ${W} ${height}`} width="100%" role="img" aria-label="Gráfico de barras">
      <defs>
        <linearGradient id="barGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={color} stopOpacity="1" /><stop offset="1" stopColor={color} stopOpacity="0.65" />
        </linearGradient>
      </defs>
      {lines.map(v => {
        const y = padT + chartH - (v / top) * chartH
        return (
          <g key={v}>
            <line x1={padL} x2={W - padR} y1={y} y2={y} stroke="var(--grid)" strokeDasharray="3 4" />
            <text x={W - padR + 6} y={y + 4} fontSize="11" fill="var(--muted)">{v.toLocaleString('pt-PT', { maximumFractionDigits: 1 })}{unit === 'h' ? '' : unit}</text>
          </g>
        )
      })}
      {data.map((d, i) => {
        const h = (d.value / top) * chartH
        const x = padL + slot * i + (slot - bar) / 2
        return (
          <g key={i}>
            <rect x={x} y={padT + chartH - h} width={bar} height={Math.max(0, h)} rx="6" fill="url(#barGrad)">
              <title>{`${d.label}: ${d.value.toLocaleString('pt-PT', { maximumFractionDigits: 1 })} h`}</title>
            </rect>
            {i % skip === 0 && <text x={x + bar / 2} y={height - 8} fontSize="11" textAnchor="middle" fill="var(--muted)">{d.label}</text>}
          </g>
        )
      })}
    </svg>
  )
}

const niceCeil = (v: number) => {
  const steps = [0.5, 1, 1.5, 2, 3, 4, 5, 6, 8, 10, 15, 20, 30, 40, 50, 100]
  return steps.find(s => s >= v) ?? Math.ceil(v / 10) * 10
}

export function Donut({ slices, center, sub, size = 220 }: {
  slices: { name: string; value: number; color: string }[]; center: string; sub: string; size?: number
}) {
  const total = slices.reduce((s, x) => s + x.value, 0)
  const r = 80, stroke = 28, c = 2 * Math.PI * r
  let offset = 0
  return (
    <svg viewBox="0 0 220 220" width={size} height={size} role="img" aria-label="Gráfico circular por disciplina">
      <circle cx="110" cy="110" r={r} fill="none" stroke="var(--grid)" strokeWidth={stroke} />
      {total > 0 && slices.map(s => {
        const len = (s.value / total) * c
        const gap = slices.length > 1 ? 3 : 0
        const el = (
          <circle key={s.name} cx="110" cy="110" r={r} fill="none" stroke={s.color} strokeWidth={stroke}
                  strokeDasharray={`${Math.max(0, len - gap)} ${c - Math.max(0, len - gap)}`}
                  strokeDashoffset={-offset} transform="rotate(-90 110 110)" strokeLinecap="butt">
            <title>{`${s.name}: ${s.value.toLocaleString('pt-PT', { maximumFractionDigits: 1 })} h`}</title>
          </circle>
        )
        offset += len
        return el
      })}
      <text x="110" y="108" textAnchor="middle" fontSize="26" fontWeight="700" fill="var(--text)">{center}</text>
      <text x="110" y="130" textAnchor="middle" fontSize="12" fill="var(--muted)">{sub}</text>
    </svg>
  )
}

/** A circular progress ring with content in the middle. */
export function Ring({ progress, size = 116, stroke = 12, color, children, track }: {
  progress: number; size?: number; stroke?: number; color: string; children?: React.ReactNode; track?: string
}) {
  const r = (size - stroke) / 2, c = 2 * Math.PI * r
  const p = Math.min(1, Math.max(0, progress))
  return (
    <div className="ring" style={{ width: size, height: size }}>
      <svg width={size} height={size}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={track ?? 'var(--grid)'} strokeWidth={stroke} />
        {p > 0 && <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} strokeWidth={stroke} strokeLinecap="round"
                          strokeDasharray={`${p * c} ${c}`} transform={`rotate(-90 ${size / 2} ${size / 2})`}
                          style={{ transition: 'stroke-dasharray .4s ease' }} />}
      </svg>
      <div className="ring-center">{children}</div>
    </div>
  )
}

/** 60 ticks around a circle; the first `progress × 60` glow in the tint colour. */
export function TickRing({ progress, tint, size = 340, children }: {
  progress: number; tint: string; size?: number; children?: React.ReactNode
}) {
  const lit = Math.floor(Math.min(1, Math.max(0, progress)) * 60)
  const radius = size / 2 - 14
  return (
    <div className="tick-ring" style={{ width: size, height: size }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        {Array.from({ length: 60 }, (_, i) => {
          const major = i % 5 === 0
          const len = major ? 16 : 9
          const a = (i * 6 - 90) * Math.PI / 180
          const x1 = size / 2 + Math.cos(a) * radius, y1 = size / 2 + Math.sin(a) * radius
          const x2 = size / 2 + Math.cos(a) * (radius - len), y2 = size / 2 + Math.sin(a) * (radius - len)
          const on = i < lit
          return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} strokeLinecap="round"
                       strokeWidth={major ? 3.5 : 2.5} stroke={on ? tint : 'var(--tick)'}
                       style={on ? { filter: `drop-shadow(0 0 4px ${tint})` } : undefined} />
        })}
      </svg>
      <div className="tick-disc" style={{ inset: 28 }}>{children}</div>
    </div>
  )
}

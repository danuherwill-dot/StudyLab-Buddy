import type { Task } from './types'

export async function ensureNotificationPermission() {
  if (!('Notification' in window)) return false
  if (Notification.permission === 'default') await Notification.requestPermission()
  return Notification.permission === 'granted'
}

export function notify(title: string, body = '') {
  if (!('Notification' in window) || Notification.permission !== 'granted') return
  new Notification(title, { body, silent: false })
}

const HOUR = 3_600_000
const DAY = 24 * HOUR

/** Reminder schedule per task type: how long before the due time, and what to say. */
export const reminderPlan = (type: Task['type']): { lead: number; title: string }[] => {
  switch (type) {
    case 'homework':
      return [{ lead: DAY, title: 'TPC para amanhã' }, { lead: HOUR, title: 'TPC para daqui a 1 hora' },
              { lead: 0, title: 'TPC para entregar agora' }]
    case 'assignment':
      return [{ lead: 3 * DAY, title: 'Trabalho para daqui a 3 dias' }, { lead: DAY, title: 'Trabalho para amanhã' },
              { lead: 0, title: 'Trabalho para entregar agora' }]
    case 'test':
      return [{ lead: 7 * DAY, title: 'Teste daqui a 1 semana — começa a rever a matéria' },
              { lead: 3 * DAY, title: 'Teste daqui a 3 dias' }, { lead: DAY, title: 'Teste amanhã' },
              { lead: 2 * HOUR, title: 'Teste daqui a 2 horas' }]
  }
}

export const reminderDescription = (type: Task['type']) => ({
  homework: 'Lembretes: 1 dia antes, 1 hora antes e à hora de entrega.',
  assignment: 'Lembretes: 3 dias antes, 1 dia antes e à hora de entrega.',
  test: 'Lembretes: 1 semana, 3 dias, 1 dia e 2 horas antes do teste.'
}[type])

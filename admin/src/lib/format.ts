import { CURRENCY_LABEL } from '../constants';

const numberFormatter = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 });

export function formatAmount(value: number): string {
  return `${numberFormatter.format(Math.round(value))} ${CURRENCY_LABEL}`;
}

export function formatSignedAmount(value: number): string {
  const sign = value > 0 ? '+' : '';
  return `${sign}${numberFormatter.format(Math.round(value))} ${CURRENCY_LABEL}`;
}

export function formatMultiplier(value: number | null | undefined): string {
  if (value === null || value === undefined) return '—';
  return `${value.toFixed(2)}x`;
}

export function formatRoundNumber(value: number): string {
  return `#${value}`;
}

const dateFormatter = new Intl.DateTimeFormat('fr-FR', {
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
});

export function formatDate(value: string | null | undefined): string {
  if (!value) return '—';
  try {
    return dateFormatter.format(new Date(value));
  } catch {
    return '—';
  }
}

const rtf = new Intl.RelativeTimeFormat('fr-FR', { numeric: 'auto' });

/** Human relative time, e.g. "dans 3 heures" or "il y a 2 jours". */
export function formatRelativeTime(value: string | null | undefined): string {
  if (!value) return '—';
  const target = new Date(value).getTime();
  if (Number.isNaN(target)) return '—';
  const diffMs = target - Date.now();
  const diffSec = Math.round(diffMs / 1000);
  const abs = Math.abs(diffSec);

  const units: [Intl.RelativeTimeFormatUnit, number][] = [
    ['year', 31536000],
    ['month', 2592000],
    ['week', 604800],
    ['day', 86400],
    ['hour', 3600],
    ['minute', 60],
    ['second', 1],
  ];

  for (const [unit, secondsInUnit] of units) {
    if (abs >= secondsInUnit || unit === 'second') {
      const value2 = Math.round(diffSec / secondsInUnit);
      return rtf.format(value2, unit);
    }
  }
  return '—';
}

export function isPast(value: string | null | undefined): boolean {
  if (!value) return false;
  return new Date(value).getTime() < Date.now();
}

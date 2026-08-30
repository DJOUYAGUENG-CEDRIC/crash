import { useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
} from 'recharts';
import { useToast, errorMessage } from '../context/ToastContext';
import { getStatistics } from '../services/statistics';
import type { StatisticsData } from '../services/statistics';
import { formatAmount } from '../lib/format';

// Dark-theme chart palette (validated categorical order, dark steps).
const COLOR_BLUE = '#3987e5';
const COLOR_ORANGE = '#d95926';
const COLOR_VIOLET = '#9085e9';
const COLOR_AQUA = '#199e70';
const GRID_COLOR = '#27272a'; // zinc-800
const AXIS_COLOR = '#71717a'; // zinc-500

const tooltipStyle = {
  backgroundColor: '#18181b',
  border: '1px solid #3f3f46',
  borderRadius: 8,
  fontSize: 12,
  color: '#e4e4e7',
};

export function StatisticsPage() {
  const { showError } = useToast();
  const [data, setData] = useState<StatisticsData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    async function load() {
      try {
        const stats = await getStatistics();
        if (mounted) setData(stats);
      } catch (err) {
        showError(errorMessage(err));
      } finally {
        if (mounted) setLoading(false);
      }
    }
    void load();
    return () => {
      mounted = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-zinc-50">Statistiques</h1>
        <p className="text-sm text-zinc-500">Activité de jeu sur les 14 derniers jours.</p>
      </div>

      {loading || !data ? (
        <p className="text-sm text-zinc-500">Chargement des statistiques…</p>
      ) : (
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <ChartCard title="Manches par jour">
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={data.roundsPerDay} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke={GRID_COLOR} vertical={false} />
                <XAxis dataKey="date" tick={{ fill: AXIS_COLOR, fontSize: 11 }} tickLine={false} axisLine={{ stroke: GRID_COLOR }} />
                <YAxis tick={{ fill: AXIS_COLOR, fontSize: 11 }} tickLine={false} axisLine={false} allowDecimals={false} />
                <Tooltip contentStyle={tooltipStyle} cursor={{ fill: 'rgba(255,255,255,0.04)' }} />
                <Bar dataKey="rounds" name="Manches" fill={COLOR_AQUA} radius={[4, 4, 0, 0]} maxBarSize={28} />
              </BarChart>
            </ResponsiveContainer>
          </ChartCard>

          <ChartCard title="Misé vs payé (FCFA)">
            <ResponsiveContainer width="100%" height={260}>
              <LineChart data={data.wageredVsPaid} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke={GRID_COLOR} vertical={false} />
                <XAxis dataKey="date" tick={{ fill: AXIS_COLOR, fontSize: 11 }} tickLine={false} axisLine={{ stroke: GRID_COLOR }} />
                <YAxis tick={{ fill: AXIS_COLOR, fontSize: 11 }} tickLine={false} axisLine={false} />
                <Tooltip contentStyle={tooltipStyle} formatter={(v) => formatAmount(Number(v))} />
                <Legend wrapperStyle={{ fontSize: 12, color: AXIS_COLOR }} />
                <Line type="monotone" dataKey="wagered" name="Total misé" stroke={COLOR_BLUE} strokeWidth={2} dot={false} />
                <Line type="monotone" dataKey="paidOut" name="Total payé" stroke={COLOR_ORANGE} strokeWidth={2} dot={false} />
              </LineChart>
            </ResponsiveContainer>
          </ChartCard>

          <ChartCard title="Distribution des multiplicateurs de crash">
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={data.multiplierBuckets} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke={GRID_COLOR} vertical={false} />
                <XAxis dataKey="bucket" tick={{ fill: AXIS_COLOR, fontSize: 11 }} tickLine={false} axisLine={{ stroke: GRID_COLOR }} />
                <YAxis tick={{ fill: AXIS_COLOR, fontSize: 11 }} tickLine={false} axisLine={false} allowDecimals={false} />
                <Tooltip contentStyle={tooltipStyle} cursor={{ fill: 'rgba(255,255,255,0.04)' }} />
                <Bar dataKey="count" name="Manches" fill={COLOR_BLUE} radius={[4, 4, 0, 0]} maxBarSize={40} />
              </BarChart>
            </ResponsiveContainer>
          </ChartCard>

          <ChartCard title="Top joueurs par total misé">
            {data.topPlayers.length === 0 ? (
              <p className="py-10 text-center text-sm text-zinc-600">Aucune donnée sur la période.</p>
            ) : (
              <ResponsiveContainer width="100%" height={260}>
                <BarChart
                  data={data.topPlayers}
                  layout="vertical"
                  margin={{ top: 8, right: 16, left: 8, bottom: 0 }}
                >
                  <CartesianGrid strokeDasharray="3 3" stroke={GRID_COLOR} horizontal={false} />
                  <XAxis type="number" tick={{ fill: AXIS_COLOR, fontSize: 11 }} tickLine={false} axisLine={{ stroke: GRID_COLOR }} />
                  <YAxis
                    type="category"
                    dataKey="displayName"
                    width={110}
                    tick={{ fill: AXIS_COLOR, fontSize: 11 }}
                    tickLine={false}
                    axisLine={false}
                  />
                  <Tooltip contentStyle={tooltipStyle} formatter={(v) => formatAmount(Number(v))} />
                  <Bar dataKey="totalWagered" name="Total misé" fill={COLOR_VIOLET} radius={[0, 4, 4, 0]} maxBarSize={18} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </ChartCard>
        </div>
      )}
    </div>
  );
}

function ChartCard({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-5">
      <h2 className="mb-3 text-sm font-semibold text-zinc-300">{title}</h2>
      {children}
    </div>
  );
}

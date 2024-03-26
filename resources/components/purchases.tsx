import { Bar, BarChart, ResponsiveContainer, XAxis, YAxis } from "recharts"
import { purchasesRaw } from '../lib/api'

export function Purchases() {
    const purchases = purchasesRaw()
    return (
        <>
            <ResponsiveContainer width="100%" height={350}>
                <BarChart data={purchases}>
                    <XAxis
                        dataKey="name"
                        stroke="#888888"
                        fontSize={12}
                        tickLine={false}
                        axisLine={false}
                    />
                    <YAxis
                        stroke="#888888"
                        fontSize={12}
                        tickLine={false}
                        axisLine={false}
                        tickFormatter={(value) => `$${value}`}
                    />
                    <Bar
                        dataKey="total"
                        fill="currentColor"
                        radius={[4, 4, 0, 0]}
                        className="fill-primary"
                    />
                </BarChart>
            </ResponsiveContainer>
        </>
    )
}

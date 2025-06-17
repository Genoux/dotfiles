import { Variable } from "astal"

// Widget Logic - 100% State & Business Logic
export const time = Variable("").poll(1000, () => {
    const now = new Date()
    return new Date(now.toLocaleString('en-US', { timeZone: 'America/Montreal' }))
        .toLocaleTimeString('en-US', { 
            hour: '2-digit', 
            minute: '2-digit',
            hour12: false,
            timeZone: 'America/Montreal'
        })
}) 
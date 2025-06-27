import { Variable } from "astal"

// Widget Logic - 100% State & Business Logic
export const time = Variable("").poll(1000, () => {
    const now = new Date()
    return now.toLocaleTimeString('en-US', { 
        hour: '2-digit', 
        minute: '2-digit',
        hour12: false,
        timeZone: 'America/Montreal'
    })
}) 
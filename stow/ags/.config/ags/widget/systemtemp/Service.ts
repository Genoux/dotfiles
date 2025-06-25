import { Variable } from "astal"
import { execAsync } from "astal/process"

interface SystemTempData {
    cpu: number;
    gpu: number;
    avgTemp: number;
    status: 'normal' | 'warm' | 'hot';
}

// Get CPU temperature from k10temp sensor
async function getCPUTemp(): Promise<number> {
    try {
        // Parse sensors output for k10temp Tctl value
        const result = await execAsync(['sensors', 'k10temp-pci-00c3']);
        const lines = result.split('\n');
        
        for (const line of lines) {
            if (line.includes('Tctl:')) {
                const match = line.match(/\+(\d+\.\d+)°C/);
                if (match) {
                    return Math.round(parseFloat(match[1]));
                }
            }
        }
        return 0;
    } catch (error) {
        console.error('Failed to get CPU temperature:', error);
        return 0;
    }
}

// Get GPU temperature from nvidia-smi
async function getGPUTemp(): Promise<number> {
    try {
        const result = await execAsync(['nvidia-smi', '--query-gpu=temperature.gpu', '--format=csv,noheader,nounits']);
        const temp = parseInt(result.trim());
        return isNaN(temp) ? 0 : temp;
    } catch (error) {
        console.error('Failed to get GPU temperature:', error);
        return 0;
    }
}

// Get temperature status based on max temp
function getTempStatus(cpuTemp: number, gpuTemp: number): 'normal' | 'warm' | 'hot' {
    const maxTemp = Math.max(cpuTemp, gpuTemp);
    
    if (maxTemp >= 85) {
        return 'hot'; // Critical temps
    } else {
        return 'normal'; // Normal operation
    }
}

// Fetch system temperatures
async function fetchSystemTemps(): Promise<SystemTempData> {
    try {
        const [cpuTemp, gpuTemp] = await Promise.all([
            getCPUTemp(),
            getGPUTemp()
        ]);
        
        const avgTemp = Math.round((cpuTemp + gpuTemp) / 2);
        const status = getTempStatus(cpuTemp, gpuTemp);
        
        return {
            cpu: cpuTemp,
            gpu: gpuTemp,
            avgTemp: avgTemp,
            status: status
        };
    } catch (error) {
        console.error('Failed to fetch system temperatures:', error);
        return {
            cpu: 0,
            gpu: 0,
            avgTemp: 0,
            status: 'normal'
        };
    }
}

// Create a variable that polls system temperatures every 3 seconds
export const systemTemps = Variable<SystemTempData>({
    cpu: 0,
    gpu: 0,
    avgTemp: 0,
    status: 'normal'
}).poll(3000, fetchSystemTemps); // Poll every 3 seconds for real-time monitoring 
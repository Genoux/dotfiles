import { Variable } from "astal"
import { exec, execAsync } from "astal/process"

interface WeatherData {
    temperature: number;
    feelsLike: number;
    location: string;
    condition: string;
    icon: string;
}

// Get location using IP geolocation with curl and timeout
async function getLocation(): Promise<{ lat: number; lon: number; city: string }> {
    try {
        const result = await execAsync(['curl', '-s', '--max-time', '10', '--connect-timeout', '5', 'http://ip-api.com/json/']);
        const data = JSON.parse(result);
        return {
            lat: data.lat,
            lon: data.lon,
            city: data.city
        };
    } catch (error) {
        console.error('Failed to get location:', error);
        // Fallback to a default location (Montreal)
        return { lat: 45.5017, lon: -73.5673, city: 'Montreal' };
    }
}

// Fetch weather data from Open-Meteo (more accurate, no API key required)
async function fetchWeather(): Promise<WeatherData> {
    try {
        const location = await getLocation();
        
        // Using Open-Meteo API with curl (no API key required, more accurate)
        const url = `https://api.open-meteo.com/v1/forecast?latitude=${location.lat}&longitude=${location.lon}&current=temperature_2m,apparent_temperature,weather_code&timezone=auto`;
        const result = await execAsync(['curl', '-s', '--max-time', '15', '--connect-timeout', '8', url]);
        const data = JSON.parse(result);
        
        const current = data.current;
        const temp = Math.round(current.temperature_2m);
        const feelsLike = Math.round(current.apparent_temperature);
        const weatherCode = current.weather_code;
        
        return {
            temperature: temp,
            feelsLike: feelsLike,
            location: location.city,
            condition: getWeatherCondition(weatherCode),
            icon: getWeatherIconFromWMOCode(weatherCode)
        };
    } catch (error) {
        console.error('Failed to fetch weather:', error);
        return {
            temperature: 0,
            feelsLike: 0,
            location: 'Unknown',
            condition: 'unavailable',
            icon: '🌡️'
        };
    }
}

// Map WMO weather codes (used by Open-Meteo) to simple text icons
function getWeatherIconFromWMOCode(weatherCode: number): string {
    // WMO weather codes from Open-Meteo
    if (weatherCode === 0) return '☀️';  // Clear sky
    if (weatherCode <= 3) return '⛅';   // Partly cloudy
    if (weatherCode <= 48) return '🌫️'; // Fog
    if (weatherCode <= 57) return '🌦️'; // Drizzle
    if (weatherCode <= 67) return '🌧️'; // Rain
    if (weatherCode <= 77) return '❄️'; // Snow
    if (weatherCode <= 82) return '🌧️'; // Rain showers
    if (weatherCode <= 86) return '❄️'; // Snow showers
    if (weatherCode <= 99) return '⛈️'; // Thunderstorm
    
    return '🌡️';  // Default weather icon
}

// Get weather condition description from WMO code
function getWeatherCondition(weatherCode: number): string {
    if (weatherCode === 0) return 'clear sky';
    if (weatherCode <= 3) return 'partly cloudy';
    if (weatherCode <= 48) return 'foggy';
    if (weatherCode <= 57) return 'drizzle';
    if (weatherCode <= 67) return 'rainy';
    if (weatherCode <= 77) return 'snowy';
    if (weatherCode <= 82) return 'rain showers';
    if (weatherCode <= 86) return 'snow showers';
    if (weatherCode <= 99) return 'thunderstorm';
    
    return 'unknown';
}

// Create weather variables without automatic polling
export const weather = Variable<WeatherData>({
    temperature: 0,
    feelsLike: 0,
    location: '',
    condition: '',
    icon: ''
});

export const weatherDisplay = Variable("🌡️ --°C");

// Lazy loading state
let weatherInitialized = false;
let weatherInterval: any | null = null;

// Initialize weather loading (call this when widget becomes visible)
export function initializeWeather() {
    if (weatherInitialized) return;
    
    weatherInitialized = true;
    
    // Initial fetch
    fetchWeather().then(data => {
        weather.set(data);
        weatherDisplay.set(`${data.icon} ${data.feelsLike}°C`);
    }).catch(error => {
        console.error("Weather: Initial fetch failed:", error);
        weatherDisplay.set("");
    });
    
    // Start polling every 10 minutes
    weatherInterval = setInterval(async () => {
        try {
            const data = await fetchWeather();
            weather.set(data);
            weatherDisplay.set(`${data.icon} ${data.feelsLike}°C`);
        } catch (error) {
            console.error("Weather: Polling failed:", error);
            weatherDisplay.set("🌡️ --°C");
        }
    }, 600000); // 10 minutes
}
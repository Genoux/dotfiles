import Quickshell.Io
import QtQuick
import qs
import qs.config

Rectangle {
    id: root

    property string weatherIcon: ""
    property string temperature: "--°C"

    implicitWidth: content.implicitWidth + 8
    implicitHeight: Style.pillHeight
    radius: Style.radiusSm
    color: mouse.containsMouse ? Style.alphaLight : Style.transparent

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 2

        Text {
            visible: root.weatherIcon.length > 0
            text: root.weatherIcon
            color: Colors.base05
            font.family: "Noto Color Emoji"
            font.pixelSize: Style.fontSizeSm
        }

        Text {
            text: root.temperature
            color: Colors.base05
            font.family: Style.fontSans
            font.pixelSize: Style.fontSizeSm
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: clickProcess.running = true
    }

    Process {
        id: weatherProcess

        command: ["bash", "-lc", "set -a; [ -f \"$HOME/.config/hypr/secrets.lua\" ] && OPENWEATHERMAP_API_KEY=$(grep -oP 'OPENWEATHERMAP_API_KEY\", \"\\K[^\"]+' \"$HOME/.config/hypr/secrets.lua\" | head -1); export OPENWEATHERMAP_API_KEY; export WEATHER_CITY=\"${WEATHER_CITY:-Montreal}\"; python3 -c \"import json,os,urllib.parse,urllib.request; key=os.getenv('OPENWEATHERMAP_API_KEY'); city=os.getenv('WEATHER_CITY','Montreal');\\nif not key:\\n print('|--°C'); raise SystemExit\\nurl='https://api.openweathermap.org/data/2.5/weather?q='+urllib.parse.quote(city)+'&appid='+key+'&units=metric'\\ntry:\\n data=json.load(urllib.request.urlopen(url, timeout=4)); code=data['weather'][0]['id']; temp=round(data['main']['feels_like']); icon='☀️' if code==800 else '🌤️' if code==801 else '⛅' if code==802 else '☁️' if code in (803,804) or 700<=code<800 else '⛈️' if 200<=code<300 else '🌦️' if 300<=code<400 else '🌧️' if 500<=code<600 else '❄️' if 600<=code<=622 else ''; print(f'{icon}|{temp}°C')\\nexcept Exception:\\n print('|--°C')\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("|");
                root.weatherIcon = parts[0] ?? "";
                root.temperature = parts[1] || "--°C";
            }
        }
    }

    Process {
        id: clickProcess

        command: ["bash", "-lc", "wego >/dev/null 2>&1 || true"]
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: weatherProcess.running = true
    }
}

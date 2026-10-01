pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    function list(value) {
        if (Array.isArray(value)) return value;
        try {
            const parsed = JSON.parse(JSON.stringify(value));
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) { return []; }
    }

    readonly property alias o: adapter

    FileView {
        id: file
        path: Paths.state + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        onLoaded: {
            let idle = {};
            if (idle.screenOff !== undefined && idle.screenAc === undefined) {
                adapter.idle.screenAc = idle.screenOff;
                adapter.idle.screenBattery = idle.screenOff;
            }
            if (idle.lockAc !== undefined && idle.lock === undefined)
                adapter.idle.lock = Math.min(idle.lockAc, idle.lockBattery ?? idle.lockAc);
        }

        JsonAdapter {
            id: adapter

            property JsonObject bar: JsonObject {
                property bool autohide: false
                property bool corners: true
                property bool title: true
                property bool tray: true
                property bool layout: true
                property bool date: true
                property var left: ["launcher", "workspaces", "title"]
                property var center: ["live"]
                property var right: ["tray", "status", "control"]
                property string style: "islands"
                property string position: "top"
                property bool seconds: false
                property string workspaces: "pills"
                property bool volume: true
                property bool percent: true
                property bool mediaTitle: true
            }

            property JsonObject notifications: JsonObject {
                property int timeout: 7
                property string position: "right"
            }

            property JsonObject lock: JsonObject {
                property string clock: "stack"
                property bool weather: true
                property bool live: true
                property bool user: true
                property bool blur: true
            }

            property JsonObject control: JsonObject {
                property var hidden: []
                property var hiddenCards: []
            }

            property JsonObject idle: JsonObject {
                property int screenAc: 5
                property int screenBattery: 5
                property int lock: 10
                property int suspendAc: 0
                property int suspendBattery: 20
                property bool lockOnLogin: true
            }

            property JsonObject weather: JsonObject {
                property string city: "Белград"
                property real lat: 44.8176
                property real lon: 20.4633
            }

            property JsonObject night: JsonObject {
                property string mode: "off"
                property int temp: 3600
            }

            property JsonObject motion: JsonObject {
                property real speed: 1.0
            }

            property JsonObject wallpaper: JsonObject {
                property bool span: false
                property real scale: 1.0
                property bool animated: false
                property real pace: 1.0
            }

            property JsonObject theme: JsonObject {
                property string schedule: "off"
                property string darkAt: "21:00"
                property string lightAt: "07:00"
                property bool walls: true
            }

            property JsonObject desktop: JsonObject {
                property bool enabled: true
                property bool grid: true
                property int gridSize: 24
                property var positions: ({})
                property var variants: ({})
                property var scales: ({})
                property var only: ({})
                property bool clock: true
                property bool glance: true
                property bool battery: true
                property bool media: true
                property bool forecast: true
                property bool calendar: true
                property bool system: false
                property bool usage: false
            }

            property JsonObject dock: JsonObject {
                property bool enabled: true
                property bool autohide: true
                property real size: 48
                property bool magnify: true
                property bool running: true
                property var pinned: []
                property bool seeded: false
            }

            property JsonObject eq: JsonObject {
                property bool on: false
                property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            }

            property JsonObject capture: JsonObject {
                property bool system: true
                property bool mic: false
            }

            property JsonObject osd: JsonObject {
                property string position: "bar"
            }

            property JsonObject launcher: JsonObject {
                property string engine: "google"
                property bool files: true
            }

            property JsonObject screenTime: JsonObject {
                property bool enabled: true
            }

            property JsonObject privacy: JsonObject {
                property bool mode: false
                property bool autoOnCast: true
                property bool dndWhenActive: true
            }
        }
    }
}

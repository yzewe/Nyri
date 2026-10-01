pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var chosen: null
    readonly property var player: (chosen && players.indexOf(chosen) >= 0 ? chosen : null) ?? players.find(p => p.isPlaying) ?? players[0] ?? null

    readonly property string rawArt: player?.trackArtUrl ?? ""
    property string art: ""
    onRawArtChanged: refreshArt()
    Component.onCompleted: refreshArt()
    Connections {
        target: root.player
        function onTrackArtUrlChanged() { root.refreshArt(); }
    }

    function refreshArt() {
        const url = rawArt;
        if (!url) { art = ""; return; }
        let src = url;
        if (url.startsWith("file:")) {
            src = url.slice("file://".length);
            try { src = decodeURIComponent(src); } catch (e) {}
            if (/\.(png|jpe?g|webp|gif|bmp|avif)$/i.test(src)) { art = "file://" + src; return; }
        } else if (!url.startsWith("http://") && !url.startsWith("https://")) {
            art = url;
            return;
        }
        artJob.running = false;
        artJob.path = src;
        artJob.rev++;
        artJob.running = true;
    }

    Process {
        id: artJob
        property string path: ""
        property int rev: 0
        command: ["python3", "-c", "
import os, sys, shutil, subprocess
src, folder, rev = sys.argv[1], sys.argv[2], sys.argv[3]

def ext_of(b):
    if b[:4] == bytes([137, 80, 78, 71]): return '.png'
    if b[:3] == bytes([255, 216, 255]): return '.jpg'
    if len(b) >= 12 and b[8:12] == b'WEBP': return '.webp'
    if b[:4] == b'GIF8': return '.gif'
    return ''

def publish(data):
    ext = ext_of(data[:16])
    if not ext:
        return False
    os.makedirs(folder, exist_ok=True)
    for old in os.listdir(folder):
        if old.startswith('nyri-cover-') and not old.endswith(rev + ext):
            try: os.remove(os.path.join(folder, old))
            except OSError: pass
    dest = os.path.join(folder, 'nyri-cover-' + rev + ext)
    with open(dest, 'wb') as out:
        out.write(data)
    print(dest)
    return True

if src.startswith('http://') or src.startswith('https://'):
    ident = src.split('?', 1)[0].rstrip('/').rsplit('/', 1)[-1]
    urls = [src]
    if len(ident) >= 16 and all(c in '0123456789abcdef' for c in ident.lower()):
        alt = 'https://image-cdn-fa.spotifycdn.com/image/' + ident
        urls = [alt, src] if 'i.scdn.co' in src else [src, alt]
    for url in urls:
        try:
            data = subprocess.check_output(['curl', '-fsSL', '--connect-timeout', '3', '--max-time', '8', '-A', 'Nyri', url], stderr=subprocess.DEVNULL)
        except (OSError, subprocess.CalledProcessError):
            continue
        if publish(data):
            sys.exit(0)
    sys.exit(1)

data = open(src, 'rb').read()
if not publish(data):
    sys.exit(1)
", path, (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"), String(rev)]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.indexOf("/nyri-cover-" + artJob.rev) >= 0) root.art = "file://" + path;
            }
        }
    }
}

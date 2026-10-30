"""Runs the Library state machine of BarWidget.qml under Node.

The QML cannot run without Quickshell, so this takes the real functions and the
property defaults out of BarWidget.qml and evaluates them with the QML-only
parts (timers, processes) replaced by recorders. Properties become fields of one
object that the functions reach as free variables, the way QML scopes them.
"""

import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "BarWidget.qml").read_text(encoding="utf-8")


def matching_brace(text, start):
    """The index of the brace that closes the one at ``start``, skipping strings, comments and regexes."""

    depth = 0
    index = start
    while index < len(text):
        character = text[index]
        if character in "\"'`":
            quote = character
            index += 1
            while text[index] != quote:
                index += 2 if text[index] == "\\" else 1
        elif text.startswith("//", index):
            index = text.index("\n", index)
            continue
        elif text.startswith("/*", index):
            index = text.index("*/", index) + 1
        elif character == "/" and re.search(r"[(,=:!&|?{};]\s*$", text[max(0, index - 40):index]):
            index += 1  # a regex literal: skip to its closing slash
            while text[index] != "/":
                index += 2 if text[index] == "\\" else 1
        elif character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    raise ValueError("unbalanced braces")


def functions(source):
    found = []
    for match in re.finditer(r"^  function (\w+)\(", source, re.M):
        brace = source.index("{", source.index(")", match.end()))
        found.append(source[match.start():matching_brace(source, brace) + 1])
    return found


def properties(source):
    """(name, readonly, expression) of the property declarations of the root item."""

    result = []
    pattern = re.compile(r"^  (readonly )?property (?:\w+) (\w+):", re.M)
    for match in pattern.finditer(source):
        rest = source[match.end():]
        # A binding ends at the next declaration or comment; a closing ] or } at the
        # same indentation still belongs to it.
        end = re.search(r"\n  (?=\w|//)", rest)
        expression = rest[:end.start()] if end else rest
        result.append((match.group(2), bool(match.group(1)), expression.strip()))
    return result


def prelude():
    lines = [
        "const assert = require('node:assert/strict');",
        "const log = [];",
        "const timer = (name) => ({ name, running: false, interval: 0, restart() { this.running = true; log.push(name + '.restart'); }, stop() { this.running = false; log.push(name + '.stop'); } });",
        "const proc = (name) => ({ name, running: false, command: [], launchPending: false, signal(n) { log.push(name + '.signal' + n); } });",
        "const libraryScanTimer = timer('libraryScanTimer'), libraryWatchdog = timer('libraryWatchdog'), libraryKill = timer('libraryKill'),",
        "  libraryScanWatchdog = timer('libraryScanWatchdog'), libraryScanKill = timer('libraryScanKill'), providerWatchdog = timer('providerWatchdog'),",
        "  actionRefresh = timer('actionRefresh'), queueRefresh = timer('queueRefresh'), providerKill = timer('providerKill');",
        "const libraryProcess = proc('libraryProcess'), libraryScanProcess = proc('libraryScanProcess'), providerProcess = proc('providerProcess');",
        "const Qt = { callLater(fn) { fn(); }, resolvedUrl(p) { return 'file:///bundle/' + p; } };",
        "const Quickshell = { env() { return ''; } };",
        "const panelLoader = { item: { opened: true, libraryTab: 'library' } };",
        "const root = {};",
    ]
    for name, readonly, expression in properties(SOURCE):
        if not expression:
            continue
        if readonly or expression.startswith("{") and "return" in expression:
            body = expression[1:-1] if expression.startswith("{") and expression.endswith("}") else "return (" + expression + ")"
            lines.append(
                f"Object.defineProperty(root, {name!r}, {{ enumerable: true, get() {{ with (root) {{ {body} }} }} }});"
            )
        else:
            lines.append(f"try {{ root.{name} = ({expression}); }} catch (e) {{ root.{name} = undefined; }}")
    lines.append("with (root) {")
    lines.extend(functions(SOURCE))
    lines.append("}")
    lines.append("root.sessionReady = true; root.destroying = false;")
    return "\n".join(lines)


HELPERS = """
// The stubs mark a process as running when it is started; a scenario that wants the
// next request to start calls settle() first, as the exit of a process would.
function settle() {
  libraryProcess.running = false; libraryScanProcess.running = false; providerProcess.running = false;
  libraryHelperQueue = []; libraryHelperCurrent = null; libraryHelperBusy = false;
  ipcQueue = []; ipcCurrent = null; ipcBusy = false;
}
function helperRequests() { return [libraryHelperCurrent, ...libraryHelperQueue].filter(Boolean).map(i => i.request); }
function ipcRequests() { return [ipcCurrent, ...ipcQueue].filter(Boolean).map(i => i.request); }
"""


def run(script):
    completed = subprocess.run(
        ["node", "-e", prelude() + "\nwith (root) {\n" + HELPERS + script + "\n}"], capture_output=True, text=True, timeout=60
    )
    if completed.returncode != 0:
        raise AssertionError(completed.stderr[-3000:])
    return completed.stdout


@unittest.skipUnless(shutil.which("node"), "Node is needed to exercise QML JavaScript")
class LibraryLogicTests(unittest.TestCase):
    def test_the_extractor_finds_the_library_code(self):
        names = {re.match(r"  function (\w+)", f).group(1) for f in functions(SOURCE)}
        for name in ("applyLibraryResult", "applyLibraryScan", "scanLibraryStep", "enqueueLibraryHelper", "finishLibraryWrite"):
            self.assertIn(name, names)
        self.assertIn("libraryView", {p[0] for p in properties(SOURCE)})

    def test_folders_first_run_scan_and_lists(self):
        run("""
// A library with no folder opens on Folders, once.
assert.equal(libraryView, 'artists');
applyLibraryResult('libRoots', { op: 'roots' }, { ok: true, roots: [], scanning: false });
assert.equal(libraryView, 'folders'); assert.equal(libraryTop, 'folders');
assert.equal(libraryRootsLoaded, true); assert.equal(libraryScanning, false);
// The user moves on; a later look does not bring them back.
libraryTop = 'artists'; libraryView = 'artists';
applyLibraryResult('libRoots', { op: 'roots' }, { ok: true, roots: [], scanning: false });
assert.equal(libraryView, 'artists');

// Adding a folder asks the helper, and the helper's reply starts the scan.
settle();
addLibraryRoot('/mnt/nas/music');
assert.equal(libraryHelperCurrent.request.op, 'add_root');
assert.deepEqual(JSON.parse(libraryProcess.command[3]), { op: 'add_root', path: '/mnt/nas/music' });
assert.deepEqual(libraryProcess.command.slice(0, 3), ['/usr/bin/python3', '-I', '/bundle/cliamped_library.py']);
assert.equal(libraryScanning, false, 'nothing scans until the helper accepted the folder');
const roots = [{ path: '/mnt/nas/music', tracks: 0, available: true }];
applyLibraryResult('libRoots', { op: 'add_root', path: '/mnt/nas/music' }, { ok: true, roots, scanning: true });
assert.equal(libraryScanning, true); assert.equal(libraryScanFresh, false);
assert.equal(libraryScanTimer.running, true);

// A step asks the helper to scan within a budget, and nothing else.
libraryScanTimer.running = false;
scanLibraryStep();
assert.deepEqual(libraryScanProcess.command.slice(0, 3), ['/usr/bin/python3', '-I', '/bundle/cliamped_library.py']);
assert.deepEqual(JSON.parse(libraryScanProcess.command[3]), { op: 'scan', budget: 8 });
assert.equal(libraryScanProcess.launchPending, true); assert.equal(libraryScanProcess.running, true);
assert.equal(libraryScanWatchdog.running, true);
libraryScanProcess.running = false;
// While scanning, the lists catch up and the next step is scheduled.
libraryView = 'artists';
libraryHelperQueue = []; libraryHelperBusy = false;
settle();
applyLibraryScan({ ok: true, scanning: true, phase: 'tags', dirs: 0, pending: 40, tracks: 24, roots });
assert.equal(libraryScanning, true); assert.equal(libraryScanTimer.interval, 100);
assert.equal(libraryScanSummary, 'READING TAGS… 40 FILES LEFT, 24 TRACKS INDEXED');
assert.deepEqual(helperRequests().map(r => r.op), ['artists'], 'new tracks reload the visible list');
// The same count again does not reload it.
settle();
applyLibraryScan({ ok: true, scanning: true, phase: 'tags', dirs: 0, pending: 30, tracks: 24, roots });
assert.deepEqual(helperRequests(), []);
// A busy reply (another step is running) waits longer.
applyLibraryScan({ ok: true, scanning: true, busy: true, phase: 'tags', dirs: 0, pending: 30, tracks: 24, roots });
assert.equal(libraryScanTimer.interval, 2000);
// The end of the scan reads the lists once more and stops the steps.
libraryScanTimer.running = false;
applyLibraryScan({ ok: true, scanning: false, phase: 'idle', dirs: 0, pending: 0, tracks: 40, roots: [{ path: '/mnt/nas/music', tracks: 40, available: true }] });
assert.equal(libraryScanning, false); assert.equal(libraryScanTimer.running, false);
assert.equal(libraryRoots[0].tracks, 40);
assert.deepEqual(helperRequests().map(r => r.op), ['artists'], 'the end of a scan reads the list once more');
""")

    def test_a_scan_is_bounded_and_failures_stop_it(self):
        run("""
startLibraryScan(true);
assert.equal(libraryScanFresh, true); assert.equal(libraryScanStepsLeft, 4000);
scanLibraryStep();
assert.equal(JSON.parse(libraryScanProcess.command[3]).fresh, true, 'the first step begins a new scan');
assert.equal(libraryScanFresh, false);
libraryScanProcess.running = false;
scanLibraryStep();
assert.equal(JSON.parse(libraryScanProcess.command[3]).fresh, undefined, 'later steps continue it');
// Steps are counted: when they run out the scan stops.
libraryScanProcess.running = false; libraryScanStepsLeft = 0; libraryScanning = true;
const before = libraryScanProcess.command;
scanLibraryStep();
assert.equal(libraryScanning, false); assert.equal(libraryScanProcess.command, before);
// A step cannot start while another runs.
libraryScanStepsLeft = 5; libraryScanProcess.running = true;
scanLibraryStep(); assert.equal(libraryScanStepsLeft, 5);
// A step that fails to start ends the scan with a message.
libraryScanning = true; handleLibraryScanStartFailure();
assert.equal(libraryScanning, false); assert.match(libraryError, /could not start/i);
// Nothing starts after teardown.
libraryScanProcess.running = false; destroying = true; libraryScanStepsLeft = 5;
scanLibraryStep(); assert.equal(libraryScanStepsLeft, 5);
""")

    def test_helper_requests_are_serialized_bounded_and_deduplicated(self):
        run("""
// One at a time, in order.
settle();
assert.equal(enqueueLibraryHelper('libArtists', { op: 'artists', offset: 0, limit: 60 }), true);
assert.equal(libraryHelperBusy, true);
libraryProcess.running = true;
enqueueLibraryHelper('libAlbums', { op: 'albums', offset: 0, limit: 60 });
assert.equal(libraryHelperQueue.length, 1);
libraryProcess.running = false;
finishLibraryHelper();
assert.equal(libraryHelperCurrent.request.op, 'albums');
// Only the newest search waits.
libraryProcess.running = true;
enqueueLibraryHelper('libSearch', { op: 'search', query: 'a', limit: 50 });
enqueueLibraryHelper('libSearch', { op: 'search', query: 'ab', limit: 50 });
assert.deepEqual(libraryHelperQueue.map(i => i.request.query), ['ab']);
// The queue is bounded.
libraryHelperQueue = [];
for (let i = 0; i < 40; ++i) enqueueLibraryHelper('libAlbums', { op: 'albums', offset: i, limit: 60 });
assert.equal(libraryHelperQueue.length, 12);
assert.match(libraryError, /busy/);
// An oversized request is refused, not truncated.
libraryHelperQueue = [];
assert.equal(enqueueLibraryHelper('libSearch', { op: 'search', query: 'x'.repeat(20000), limit: 5 }), false);
// Nothing is queued after teardown, and a start failure frees the queue.
destroying = true; assert.equal(enqueueLibraryHelper('libRoots', { op: 'roots' }), false); destroying = false;
libraryHelperBusy = true; libraryProcess.running = false;
handleLibraryHelperStartFailure();
assert.equal(libraryHelperBusy, false); assert.match(libraryError, /could not start/i);
""")

    def test_pages_append_in_order_and_stale_pages_are_dropped(self):
        run("""
libraryView = 'artists';
const artists = n => Array.from({ length: n }, (_, i) => ({ id: 'a' + i, name: 'Artist ' + i, album_count: 1 }));
applyLibraryResult('libArtists', { op: 'artists', offset: 0, limit: 60 }, { ok: true, artists: artists(60), total: 150 });
assert.equal(libraryArtists.length, 60); assert.equal(libraryArtistsMore, true); assert.equal(libraryLoaded, true);
// The next page appends only when it follows the list.
applyLibraryResult('libArtists', { op: 'artists', offset: 60, limit: 60 }, { ok: true, artists: artists(60), total: 150 });
assert.equal(libraryArtists.length, 120);
applyLibraryResult('libArtists', { op: 'artists', offset: 30, limit: 60 }, { ok: true, artists: artists(60), total: 150 });
assert.equal(libraryArtists.length, 120, 'a page that does not follow the list is dropped');
applyLibraryResult('libArtists', { op: 'artists', offset: 120, limit: 60 }, { ok: true, artists: artists(30), total: 150 });
assert.equal(libraryArtists.length, 150); assert.equal(libraryArtistsMore, false);
// A reply for a view that was left is dropped.
libraryView = 'albums'; libraryAlbums = [];
applyLibraryResult('libArtists', { op: 'artists', offset: 0, limit: 60 }, { ok: true, artists: artists(5), total: 5 });
assert.equal(libraryArtists.length, 150);
// The list is capped.
libraryView = 'artists'; libraryArtists = [];
applyLibraryResult('libArtists', { op: 'artists', offset: 0, limit: 60 }, { ok: true, artists: artists(200), total: 5000 });
applyLibraryResult('libArtists', { op: 'artists', offset: 200, limit: 60 }, { ok: true, artists: artists(200), total: 5000 });
applyLibraryResult('libArtists', { op: 'artists', offset: 400, limit: 60 }, { ok: true, artists: artists(200), total: 5000 });
applyLibraryResult('libArtists', { op: 'artists', offset: 600, limit: 60 }, { ok: true, artists: artists(200), total: 5000 });
assert.equal(libraryArtists.length, maxLibraryItems); assert.equal(libraryArtistsMore, false);
// Hostile items are skipped.
libraryArtists = []; libraryView = 'artists';
applyLibraryResult('libArtists', { op: 'artists', offset: 0, limit: 60 }, { ok: true, total: 3,
  artists: [null, 5, 'x', { id: '', name: 'No id' }, { id: 'ok', name: 'Fine', album_count: 2 }, { id: 'a\\u0000b', name: 'Control' }] });
assert.deepEqual(libraryArtists.map(a => a.id), ['ok']);
""")

    def test_album_search_and_back_navigation(self):
        run("""
// A search, then an album opened from a result: Back searches again.
searchLibrary('  money  ');
assert.deepEqual(libraryHelperCurrent.request, { op: 'search', query: 'money', limit: 50 });
applyLibraryResult('libSearch', libraryHelperCurrent.request, { ok: true, tracks: [
  { path: '/m/a.mp3', title: 'Money', artist: 'Pink Floyd', album: 'Dark Side', provider_meta: { 'library.album': 'alb1', 'library.artist': 'art1' } }] });
assert.equal(libraryTracks.length, 1); assert.equal(libraryLoaded, true);
assert.equal(trackLink(libraryTracks[0], 'library.album'), 'alb1');
settle();
openTrackAlbum(libraryTracks[0]);
assert.equal(libraryView, 'tracks'); assert.equal(libraryReturnView, 'search');
assert.equal(libraryHelperCurrent.request.op, 'album_tracks'); assert.equal(libraryHelperCurrent.request.album, 'alb1');
applyLibraryResult('libTracks', libraryHelperCurrent.request, { ok: true, tracks: [{ path: '/m/a.mp3', title: 'Speak to Me' }, { path: '/m/b.mp3', title: 'Money' }] });
assert.equal(libraryTracks.length, 2);
settle();
libraryBack();
assert.equal(libraryView, 'search'); assert.deepEqual(helperRequests().map(r => r.op), ['search'], 'Back reads the results again');
// The artist of a result, then an album of that artist, then Back twice.
applyLibraryResult('libSearch', libraryHelperCurrent.request, { ok: true, tracks: [{ path: '/m/a.mp3', title: 'Money', artist: 'Pink Floyd', provider_meta: { 'library.artist': 'art1' } }] });
settle();
openTrackArtist(libraryTracks[0]);
assert.equal(libraryView, 'artistAlbums'); assert.equal(libraryArtistReturn, 'search'); assert.equal(libraryArtistName, 'Pink Floyd');
applyLibraryResult('libAlbums', libraryHelperCurrent.request, { ok: true, total: 1, albums: [{ id: 'alb1', name: 'Dark Side', artist: 'Pink Floyd', track_count: 2 }] });
assert.equal(libraryAlbums.length, 1);
settle();
openLibraryAlbum('alb1', 'Dark Side'); assert.equal(libraryReturnView, 'artistAlbums');
libraryBack(); assert.equal(libraryView, 'artistAlbums'); assert.equal(libraryAlbums.length, 1, 'the albums are still there');
settle();
libraryBack(); assert.equal(libraryView, 'search');
// A reply for a search that was replaced is dropped.
settle();
searchLibrary('abc');
applyLibraryResult('libSearch', { op: 'search', query: 'old', limit: 50 }, { ok: true, tracks: [{ path: '/old.mp3' }] });
assert.notEqual(libraryTracks[0] && libraryTracks[0].path, '/old.mp3');
// A track without links does nothing.
libraryView = 'search'; openTrackAlbum({ path: '/x.mp3', provider_meta: {} }); assert.equal(libraryView, 'search');
// The sort cycles and reloads.
libraryView = 'albums'; librarySorts = [{ id: 'a', label: 'A' }, { id: 'b', label: 'B' }, { id: 'c', label: 'C' }];
librarySort = ''; cycleLibrarySort(); assert.equal(librarySort, 'b', 'the default is the first, so the next is the second');
cycleLibrarySort(); assert.equal(librarySort, 'c'); cycleLibrarySort(); assert.equal(librarySort, 'a');
""")

    def test_playing_an_album_goes_through_a_queue_file(self):
        run("""
settle();
libraryAlbumId = 'alb1';
playLibraryAlbum(3);
assert.deepEqual(libraryHelperCurrent.request, { op: 'queue_file', album: 'alb1' });
assert.equal(libraryPendingIndex, 3);
// The helper's file is loaded by CLIAMP in one request, after the queue is cleared.
applyLibraryResult('libQueueFile', libraryHelperCurrent.request, { ok: true, path: '/run/user/1000/cliamped/queue-ab.m3u8', count: 10 });
const sent = ipcRequests();
assert.deepEqual(sent.map(r => r.cmd), ['queue.clear', 'url.load']);
assert.deepEqual(sent[1], { cmd: 'url.load', path: '/run/user/1000/cliamped/queue-ab.m3u8', play: true });
// When it is loaded, playback moves to the chosen track.
settle();
libraryPendingIndex = 3;
// Emulates the libLoad branch of the response handler.
{
  const startAt = libraryPendingIndex; libraryPendingIndex = 0;
  if (startAt > 0) enqueueIpc('play', { cmd: 'queue.play', index: startAt }, []);
}
assert.deepEqual(ipcCurrent.request, { cmd: 'queue.play', index: 3 });
// Without a session the failure is shown, not swallowed.
settle(); sessionReady = false; libraryError = '';
applyLibraryResult('libQueueFile', { op: 'queue_file', album: 'alb1' }, { ok: true, path: '/q.m3u8', count: 1 });
assert.match(libraryError, /not ready/);
""")

    def test_playlist_writes_are_counted_and_only_a_clean_run_succeeds(self):
        run("""
const tracks = Array.from({ length: 50 }, (_, i) => ({ path: '/m/' + i + '.mp3', title: 'T' + i }));
openLibraryPicker(tracks, 'An album');
assert.equal(libraryPickerOpen, true); assert.equal(libraryPickerTracks.length, 50);
settle();
createLibraryPlaylist('  Road trip  ');
const cmds = ipcRequests();
assert.deepEqual(cmds.map(r => r.cmd), ['playlist.create', 'playlist.add_many', 'playlist.add_many', 'playlist.add_many']);
assert.equal(cmds[0].playlist, 'Road trip'); assert.equal(cmds[0].provider, 'local');
assert.deepEqual(cmds.slice(1).map(r => r.tracks.length), [24, 24, 2]);
assert.equal(libraryWritesPending, 4);
// All four succeed: the notice shows and the picker closes.
for (let i = 0; i < 4; ++i) finishLibraryWrite(true);
assert.equal(libraryPickerOpen, false); assert.match(libraryNotice, /Added 50 tracks to “Road trip”/);
// One failure: no success notice, the picker stays open for another try.
libraryNotice = ''; settle();
openLibraryPicker(tracks.slice(0, 1), 'One');
settle();
addToLibraryPlaylist('Road trip', 'Road trip');
assert.equal(libraryWritesPending, 1);
finishLibraryWrite(false);
assert.equal(libraryPickerOpen, true); assert.equal(libraryNotice, ''); assert.equal(libraryWritesPending, 0);
// A second batch cannot start while one is pending.
settle(); libraryError = '';
addToLibraryPlaylist('Road trip', 'Road trip'); assert.equal(libraryWritesPending, 1);
addToLibraryPlaylist('Road trip', 'Road trip'); assert.match(libraryError, /busy/); assert.equal(libraryWritesPending, 1);
finishLibraryWrite(true);
// An empty name is refused; Favorites cannot be a target.
libraryError = ''; createLibraryPlaylist('   '); assert.match(libraryError, /name/);
libraryPlaylists = [{ id: 'Favorites', name: 'Favorites' }, { id: 'Recently Played', name: 'Recently Played' }, { id: 'Mine', name: 'Mine' }];
assert.deepEqual(libraryTargetPlaylists.map(p => p.id), ['Mine']);
""")

    def test_favorites_set_drives_the_stars(self):
        run("""
settle();
refreshLibraryFavorites();
assert.deepEqual(ipcCurrent.request, { cmd: 'provider.tracks', provider: 'local', playlist: 'Favorites', offset: 0, limit: 256 });
assert.equal(isLibraryFavorite({ path: '/m/a.mp3' }), false);
libraryFavorites = { '/m/a.mp3': true };
assert.equal(isLibraryFavorite({ path: '/m/a.mp3' }), true);
assert.equal(isLibraryFavorite(null), false);
// Toggling asks CLIAMP with a validated track.
settle();
toggleTrackFavorite({ path: '/m/b.mp3', title: 'B', provider_meta: { 'library.id': 'x' } });
assert.equal(ipcCurrent.request.cmd, 'playlist.bookmark'); assert.equal(ipcCurrent.request.provider, 'local');
assert.equal(ipcCurrent.request.track.path, '/m/b.mp3');
toggleTrackFavorite({ title: 'no path' });
""")

    def test_normalizers_reject_hostile_input(self):
        run("""
assert.deepEqual(normalizeLibraryAlbums([null, 3, { id: 'a', name: 'N', artist: 'A', year: 99999, track_count: -4 }, { name: 'no id' }]),
  [{ id: 'a', name: 'N', artist: 'A', year: 9999, track_count: 0 }]);
assert.deepEqual(normalizeLibraryRoots([{ path: '/a', tracks: 3, available: true }, { path: '', tracks: 1 }, { path: '/b\\n', tracks: 1 }, 'x']),
  [{ path: '/a', tracks: 3, available: true }]);
assert.equal(normalizeLibraryRoots(Array.from({ length: 100 }, (_, i) => ({ path: '/r' + i, tracks: 1, available: true }))).length, 64);
assert.deepEqual(normalizeLibrarySorts([{ id: 'x', label: 'X' }, { id: 'y'.repeat(100), label: 'no' }, null]), [{ id: 'x', label: 'X' }]);
assert.deepEqual(normalizeLibraryArtists('nope'), []);
// The folder a user picked must be sendable, or the user is told.
// (Zero-width characters pass here and are refused by the helper and the chooser.)
addLibraryRoot('/bad\\u202ename'); assert.match(libraryError, /control or invisible/);
""")


if __name__ == "__main__":
    unittest.main()

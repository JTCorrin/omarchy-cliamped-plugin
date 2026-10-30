import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.majesticio.cliamped"

  readonly property var stations: [
    { name: "Lofi", url: "https://radio.cliamp.stream/lofi/stream" },
    { name: "Synthwave", url: "https://radio.cliamp.stream/synthwave/stream" },
    { name: "EDM", url: "https://radio.cliamp.stream/edm/stream" },
    { name: "NCS", url: "https://radio.cliamp.stream/ncs/stream" },
    { name: "House", url: "https://radio.cliamp.stream/ncs-house/stream" },
    { name: "Dubstep", url: "https://radio.cliamp.stream/ncs-dubstep/stream" },
    { name: "Drum & Bass", url: "https://radio.cliamp.stream/ncs-dnb/stream" },
    { name: "Trap", url: "https://radio.cliamp.stream/ncs-trap/stream" },
    { name: "Phonk", url: "https://radio.cliamp.stream/ncs-phonk/stream" },
    { name: "Pop", url: "https://radio.cliamp.stream/ncs-pop/stream" },
    { name: "Chill", url: "https://radio.cliamp.stream/ncs-chill/stream" }
  ]

  property bool sessionReady: false
  property bool ownsDaemon: false
  property bool startingDaemon: false
  property bool probeInFlight: false
  property bool modeKnown: false
  property string sessionMode: "unknown"
  property string state: "stopped"
  property string trackTitle: "CLIAMPed"
  property string trackArtist: ""
  property string trackAlbum: ""
  property string trackStation: ""
  property string trackPath: ""
  property real positionSeconds: 0
  property real durationSeconds: 0
  property real volumeDb: 0
  property bool shuffle: false
  property string repeatMode: "Off"
  property bool mono: false
  property real playbackSpeed: 1
  property string eqPreset: "Flat"
  readonly property var panelVisualizers: ["Spectrum", "Canyon", "Pulse"]
  property int panelVisualizerIndex: 0
  readonly property string panelVisualizerName: panelVisualizers[panelVisualizerIndex]
  property int currentIndex: 0
  property int trackTotal: 0
  property string errorText: ""
  property string queuedUrl: ""
  property var providers: []
  property var providerPlaylists: []
  property var providerResults: []
  property var searchFavorites: []
  property bool searchFavoritesBusy: false
  property string selectedProviderKey: ""
  property string loadedProviderPlaylistId: ""
  property string providerRequestKind: ""
  property bool providerBusy: false
  property bool providerSearchAttempted: false
  // The Library is CLIAMP's indexed folders, such as a share on a NAS. Its
  // views never touch the Browse state above.
  readonly property string libraryProviderKey: "library"
  readonly property int libraryPageSize: 60
  readonly property int maxLibraryItems: 600
  property string libraryTop: "artists"
  property string libraryView: "artists"
  property string libraryReturnView: "artists"
  property var libraryArtists: []
  property var libraryAlbums: []
  property var libraryTracks: []
  property var librarySorts: []
  property string librarySort: ""
  property string libraryArtistId: ""
  property string libraryArtistName: ""
  property string libraryAlbumId: ""
  property string libraryAlbumName: ""
  property string librarySearchQuery: ""
  property bool librarySearchAttempted: false
  property bool libraryArtistsMore: false
  property bool libraryAlbumsMore: false
  property bool libraryLoaded: false
  property int libraryPendingIndex: 0
  property string libraryError: ""
  property string libraryNotice: ""
  property var libraryRoots: []
  property bool libraryRootsLoaded: false
  property var libraryPlaylists: []
  property string libraryPlaylistId: ""
  property string libraryPlaylistName: ""
  property bool libraryPickerOpen: false
  property var libraryPickerTracks: []
  property string libraryPickerLabel: ""
  property int libraryWritesPending: 0
  property string libraryWriteNotice: ""
  property bool libraryScanning: false
  property bool libraryArtistsStale: false
  property bool libraryWriteFailed: false
  property int libraryPollsLeft: 0
  property int libraryPollTracks: -1
  property int radioCatalogOffset: 0
  property bool radioCatalogHasMore: true
  property bool radioCatalogRequested: false
  property string providerError: ""
  property var queueTracks: []
  property var historyItems: []
  property var lyricLines: []
  property var audioDevices: []
  property var ipcQueue: []
  property var ipcCurrent: null
  property bool ipcBusy: false
  property bool volumeDirty: false
  property real pendingVolumeDelta: 0
  property var pendingAfterStart: null
  property int startupAttempts: 0
  property bool providerTimedOut: false
  property bool searchFavoritesTimedOut: false
  property bool destroying: false
  property int daemonStartFailures: 0
  property double daemonRetryNotBefore: 0
  property double daemonStartedAt: 0

  readonly property int maxIpcQueueItems: 24
  readonly property int maxProviderItems: 32
  readonly property int maxPlaylistItems: 128
  readonly property int maxTrackItems: 128
  readonly property int maxFavoriteItems: 128
  readonly property int maxHistoryItems: 24
  readonly property int maxLyricItems: 256
  readonly property int maxDeviceItems: 32
  readonly property int maxModelCharacters: 131072
  readonly property int maxDaemonStartFailures: 3
  readonly property var processEnvironment: ({
    "PATH": "/usr/bin",
    "HOME": Quickshell.env("HOME"),
    "XDG_CONFIG_HOME": Quickshell.env("XDG_CONFIG_HOME"),
    "XDG_RUNTIME_DIR": Quickshell.env("XDG_RUNTIME_DIR"),
    "DBUS_SESSION_BUS_ADDRESS": Quickshell.env("DBUS_SESSION_BUS_ADDRESS"),
    "WAYLAND_DISPLAY": Quickshell.env("WAYLAND_DISPLAY"),
    "DISPLAY": Quickshell.env("DISPLAY"),
    "LANG": Quickshell.env("LANG") || "C.UTF-8",
    "PIPEWIRE_REMOTE": Quickshell.env("PIPEWIRE_REMOTE"),
    "PULSE_SERVER": Quickshell.env("PULSE_SERVER")
  })

  readonly property bool playing: state === "playing"
  readonly property bool libraryAvailable: {
    for (var i = 0; i < providers.length; ++i) {
      var entry = providers[i]
      if (entry.key === libraryProviderKey && entry.browse_artists && entry.browse_albums) return true
    }
    return false
  }
  // The cards of the Library view that lists artists or albums.
  readonly property var libraryCards: {
    var cards = []
    if (libraryView === "artists") {
      for (var i = 0; i < libraryArtists.length; ++i) {
        var artist = libraryArtists[i]
        cards.push({
          kind: "artist", id: artist.id, title: artist.name,
          detail: artist.album_count + (artist.album_count === 1 ? " ALBUM" : " ALBUMS")
        })
      }
    } else if (libraryView === "playlists") {
      for (var k = 0; k < libraryPlaylists.length; ++k) {
        var saved = libraryPlaylists[k]
        cards.push({
          kind: "playlist", id: saved.id, title: saved.name,
          detail: saved.track_count ? saved.track_count + (saved.track_count === 1 ? " TRACK" : " TRACKS") : ""
        })
      }
    } else if (libraryView === "albums" || libraryView === "artistAlbums") {
      for (var j = 0; j < libraryAlbums.length; ++j) {
        var album = libraryAlbums[j]
        var parts = []
        if (libraryView === "albums" && album.artist) parts.push(album.artist)
        if (album.year) parts.push(String(album.year))
        if (album.track_count) parts.push(album.track_count + (album.track_count === 1 ? " TRACK" : " TRACKS"))
        cards.push({ kind: "album", id: album.id, title: album.name, detail: parts.join("  ·  ") })
      }
    }
    return cards
  }
  // The playlists that tracks can be added to. Favorites and Recently Played
  // are lists CLIAMP keeps itself; it rejects adds to them.
  readonly property var libraryTargetPlaylists: {
    var targets = []
    for (var i = 0; i < libraryPlaylists.length; ++i) {
      var id = libraryPlaylists[i].id
      if (id !== "Favorites" && id !== "Recently Played") targets.push(libraryPlaylists[i])
    }
    return targets
  }
  readonly property int libraryTotalTracks: {
    var total = 0
    for (var i = 0; i < libraryRoots.length; ++i) total += libraryRoots[i].tracks
    return total
  }
  // Whether the list on screen has another page. The lists keep their own
  // flags, so returning to a fully loaded list never offers a stale page.
  readonly property bool libraryHasMore: libraryView === "artists" ? libraryArtistsMore
    : (libraryView === "albums" || libraryView === "artistAlbums") ? libraryAlbumsMore : false
  readonly property string librarySortLabel: {
    // An empty sort is CLIAMP's default. The Library provider lists its
    // default, by name, first; this tab only talks to that provider.
    for (var i = 0; i < librarySorts.length; ++i)
      if (librarySorts[i].id === librarySort) return librarySorts[i].label
    return librarySorts.length ? librarySorts[0].label : ""
  }
  readonly property var providerCollections: {
    var collections = []
    for (var i = 0; i < providerPlaylists.length && collections.length < maxPlaylistItems; ++i) {
      var item = providerPlaylists[i]
      // CLIAMP's built-in radio entry is an M3U index. The panel exposes its
      // resolved channels separately so it is never presented as a dead card.
      // Favorite aliases (`f:`) belong exclusively in Favorites; CLIAMP also
      // returns their starred catalog (`c:`) entries, so showing both here
      // would duplicate each favorited station in Browse.
      if (selectedProviderKey === "radio") {
        var itemId = String(item.id || "")
        if (itemId === "l:0" || itemId.indexOf("f:") === 0) continue
      }
      collections.push(item)
    }
    return collections
  }
  readonly property var providerFavorites: {
    var favorites = []
    for (var i = 0; i < providerPlaylists.length && favorites.length < maxFavoriteItems; ++i) {
      var item = providerPlaylists[i]
      if (String(item.id || "").indexOf("f:") === 0) favorites.push(item)
    }
    return favorites
  }
  readonly property var favoriteItems: {
    var favorites = []
    // Untrusted titles must not collide with inherited Object prototype keys.
    var nativeNames = Object.create(null)
    for (var i = 0; i < providerFavorites.length && favorites.length < maxFavoriteItems; ++i) {
      var item = providerFavorites[i]
      var cleanName = cleanText(item.name || item.id, 256).replace(/^★\s*/, "")
      nativeNames[cleanName.toLowerCase()] = true
      favorites.push({ kind: "provider", id: item.id, name: cleanName })
    }
    for (var j = 0; j < searchFavorites.length && favorites.length < maxFavoriteItems; ++j) {
      var track = searchFavorites[j]
      var title = cleanText(track.title || track.path, 256)
      if (nativeNames[title.toLowerCase()]) continue
      favorites.push({ kind: "search", id: "search:" + cleanText(track.path, 4096), name: title, track: track })
    }
    return favorites
  }
  readonly property string sessionLabel: sessionMode === "headless" ? "BACKGROUND"
    : sessionMode === "tui" ? "CLIAMP TUI" : "CONNECTING"
  readonly property string selectedStation: trackStation || stationNameFor(trackPath)
  readonly property string trackSubtitle: [trackArtist, trackAlbum,
    selectedStation !== trackTitle ? selectedStation : ""].filter(function(value) { return !!value }).join("  ·  ")
  readonly property var bands: bandStream.bands
  readonly property string barLabel: sessionReady
    ? ((playing ? "󰝚" : "󰏤") + "  " + plainLabel(trackTitle || "CLIAMP", 256))
    : "󰝚  CLIAMP"

  function cleanText(value, limit) {
    if (typeof value !== "string") return ""
    var result = value
    try { if (result.normalize) result = result.normalize("NFC") } catch (e) {}
    result = result.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/g, " ")
    return result.slice(0, Math.max(0, limit))
  }

  // Paths, provider IDs, and provider metadata are protocol tokens, not
  // display strings. Preserve their code points exactly while rejecting
  // controls, malformed UTF-16, and values over the Python byte boundary.
  function opaqueText(value, maximumBytes) {
    if (typeof value !== "string" || !value) return ""
    if (/[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/.test(value)) return ""
    var encoded = ""
    try { encoded = encodeURIComponent(value) } catch (e) { return "" }
    var bytes = 0
    for (var i = 0; i < encoded.length; ++i) {
      if (encoded.charAt(i) === "%") i += 2
      bytes += 1
      if (bytes > maximumBytes) return ""
    }
    return value
  }

  // Some host-shell labels are outside this component and may use AutoText.
  function plainLabel(value, limit) {
    return cleanText(value, limit).replace(/&/g, "＆").replace(/</g, "‹").replace(/>/g, "›")
  }

  function cleanNumber(value, minimum, maximum, fallback) {
    if (typeof value !== "number" || !isFinite(value)) return fallback
    return Math.max(minimum, Math.min(maximum, value))
  }

  function cleanInteger(value, minimum, maximum, fallback) {
    var number = cleanNumber(value, minimum, maximum, fallback)
    return number < 0 ? Math.ceil(number) : Math.floor(number)
  }

  function normalizeTrack(item) {
    if (!item || typeof item !== "object" || Array.isArray(item)) return null
    var path = opaqueText(item.path, 4096)
    if (!path) return null
    // A null-prototype object preserves even special opaque keys such as
    // "__proto__" without invoking Object.prototype setters.
    var providerMeta = Object.create(null)
    var metadataCost = 0
    if (item.provider_meta && typeof item.provider_meta === "object" && !Array.isArray(item.provider_meta)) {
      var metadataKeys = Object.keys(item.provider_meta)
      for (var i = 0; i < Math.min(metadataKeys.length, 16); ++i) {
        var metadataKey = opaqueText(metadataKeys[i], 128)
        var metadataValue = opaqueText(item.provider_meta[metadataKeys[i]], 512)
        if (!metadataKey || metadataCost + metadataKey.length + metadataValue.length > 8192) break
        metadataCost += metadataKey.length + metadataValue.length
        providerMeta[metadataKey] = metadataValue
      }
    }
    return {
      title: cleanText(item.title, 256),
      artist: cleanText(item.artist, 256),
      album: cleanText(item.album, 256),
      genre: cleanText(item.genre, 128),
      path: path,
      album_art_url: opaqueText(item.album_art_url, 4096),
      stream_title: cleanText(item.stream_title, 256),
      station: cleanText(item.station, 256),
      year: cleanInteger(item.year, 0, 9999, 0),
      track_number: cleanInteger(item.track_number, 0, 9999, 0),
      duration_secs: cleanInteger(item.duration_secs, 0, 31536000, 0),
      index: cleanInteger(item.index, -1, 1000000, -1),
      queue_position: cleanInteger(item.queue_position, 0, 1000000, 0),
      stream: item.stream === true,
      realtime: item.realtime === true,
      feed: item.feed === true,
      bookmark: item.bookmark === true,
      unplayable: item.unplayable === true,
      dir_sourced: item.dir_sourced === true,
      provider_meta: providerMeta
    }
  }

  function normalizeTracks(value, limit) {
    if (!Array.isArray(value)) return []
    var result = []
    var used = 0
    var count = Math.min(value.length, limit)
    for (var i = 0; i < count; ++i) {
      var track = normalizeTrack(value[i])
      if (!track) continue
      var cost = trackCharacterCost(track)
      if (used + cost > maxModelCharacters) break
      used += cost
      result.push(track)
    }
    return result
  }

  function metadataText(value) {
    return value.replace(/\s+/g, " ").trim()
  }

  function nowPlayingMetadata(track) {
    var title = metadataText(track.title)
    var artist = metadataText(track.artist)
    var station = metadataText(track.station) || stationNameFor(track.path)
    var liveTitle = metadataText(track.stream_title)
    // Live metadata is provider-independent. Preserve an unsplit show title;
    // only interpret the conventional separator when both sides are present.
    if (liveTitle) {
      var separator = liveTitle.indexOf(" - ")
      var liveArtist = separator >= 0 ? liveTitle.slice(0, separator).trim() : ""
      var song = separator >= 0 ? liveTitle.slice(separator + 3).trim() : ""
      title = liveArtist && song ? song : liveTitle
      artist = liveArtist && song ? liveArtist : ""
    }
    var fallback = track.path.split("/").pop().replace(/\.[^.]+$/, "")
    return {
      title: title || station || cleanText(fallback, 256) || "CLIAMPed",
      artist: artist,
      album: metadataText(track.album),
      station: station
    }
  }

  function trackCharacterCost(track) {
    return track.title.length + track.artist.length + track.album.length + track.genre.length
      + track.path.length + track.album_art_url.length + track.stream_title.length + track.station.length
      + JSON.stringify(track.provider_meta).length
  }

  function normalizeProviders(value) {
    if (!Array.isArray(value)) return []
    var result = []
    var used = 0
    for (var i = 0; i < Math.min(value.length, maxProviderItems); ++i) {
      var item = value[i]
      if (!item || typeof item !== "object" || Array.isArray(item)) continue
      var key = opaqueText(item.key, 128)
      if (!key || !/^[A-Za-z0-9_.:-]+$/.test(key)) continue
      var name = cleanText(item.name, 128) || key
      if (used + key.length + name.length > maxModelCharacters) break
      used += key.length + name.length
      result.push({
        key: key,
        name: name,
        searchable: item.searchable === true,
        browse_artists: item.browse_artists === true,
        browse_albums: item.browse_albums === true,
        catalog: item.catalog === true
      })
    }
    return result
  }

  function normalizePlaylists(value) {
    if (!Array.isArray(value)) return []
    var result = []
    var used = 0
    for (var i = 0; i < Math.min(value.length, maxPlaylistItems); ++i) {
      var item = value[i]
      if (!item || typeof item !== "object" || Array.isArray(item)) continue
      var id = opaqueText(item.id, 512)
      if (!id) continue
      var name = cleanText(item.name, 256) || id
      var provider = opaqueText(item.provider, 128)
      var section = cleanText(item.section, 128)
      var cost = id.length + name.length + provider.length + section.length
      if (used + cost > maxModelCharacters) break
      used += cost
      result.push({
        id: id,
        name: name,
        provider: provider,
        section: section,
        track_count: cleanInteger(item.track_count, 0, 1000000, 0),
        duration_secs: cleanInteger(item.duration_secs, 0, 315360000, 0),
        favoritable: item.favoritable === true,
        favorite: item.favorite === true
      })
    }
    return result
  }

  function normalizeLibraryArtists(value) {
    if (!Array.isArray(value)) return []
    var result = []
    var used = 0
    for (var i = 0; i < Math.min(value.length, 200); ++i) {
      var item = value[i]
      if (!item || typeof item !== "object" || Array.isArray(item)) continue
      var id = opaqueText(item.id, 512)
      if (!id) continue
      var name = cleanText(item.name, 256) || id
      if (used + id.length + name.length > maxModelCharacters) break
      used += id.length + name.length
      result.push({ id: id, name: name, album_count: cleanInteger(item.album_count, 0, 1000000, 0) })
    }
    return result
  }

  function normalizeLibraryAlbums(value) {
    if (!Array.isArray(value)) return []
    var result = []
    var used = 0
    for (var i = 0; i < Math.min(value.length, 200); ++i) {
      var item = value[i]
      if (!item || typeof item !== "object" || Array.isArray(item)) continue
      var id = opaqueText(item.id, 512)
      if (!id) continue
      var name = cleanText(item.name, 256) || id
      var artist = cleanText(item.artist, 256)
      if (used + id.length + name.length + artist.length > maxModelCharacters) break
      used += id.length + name.length + artist.length
      result.push({
        id: id,
        name: name,
        artist: artist,
        year: cleanInteger(item.year, 0, 9999, 0),
        track_count: cleanInteger(item.track_count, 0, 1000000, 0)
      })
    }
    return result
  }

  function normalizeLibraryRoots(value) {
    if (!Array.isArray(value)) return []
    var result = []
    var used = 0
    for (var i = 0; i < Math.min(value.length, 64); ++i) {
      var item = value[i]
      if (!item || typeof item !== "object" || Array.isArray(item)) continue
      var path = opaqueText(item.path, 4096)
      if (!path) continue
      if (used + path.length > maxModelCharacters) break
      used += path.length
      result.push({
        path: path,
        tracks: cleanInteger(item.tracks, 0, 1000000000, 0),
        available: item.available === true
      })
    }
    return result
  }

  function normalizeLibrarySorts(value) {
    if (!Array.isArray(value)) return []
    var result = []
    for (var i = 0; i < Math.min(value.length, 16); ++i) {
      var item = value[i]
      if (!item || typeof item !== "object" || Array.isArray(item)) continue
      var id = opaqueText(item.id, 64)
      if (id) result.push({ id: id, label: cleanText(item.label, 64) || id })
    }
    return result
  }

  function normalizeHistory(value) {
    if (!Array.isArray(value)) return []
    var result = []
    var used = 0
    for (var i = 0; i < Math.min(value.length, maxHistoryItems); ++i) {
      var item = value[i]
      if (!item || typeof item !== "object" || Array.isArray(item)) continue
      var track = normalizeTrack(item.track)
      if (!track) continue
      var playedAt = cleanText(item.played_at, 64)
      var cost = trackCharacterCost(track) + playedAt.length
      if (used + cost > maxModelCharacters) break
      used += cost
      result.push({ track: track, played_at: playedAt })
    }
    return result
  }

  function normalizeLyrics(value) {
    if (!Array.isArray(value)) return []
    var result = []
    var used = 0
    for (var i = 0; i < Math.min(value.length, maxLyricItems); ++i) {
      var item = value[i]
      if (!item || typeof item !== "object" || Array.isArray(item)) continue
      var lyric = cleanText(item.text, 1024)
      if (!lyric || used + lyric.length > 65536) break
      used += lyric.length
      result.push({ start: cleanNumber(item.start, 0, 31536000, 0), text: lyric })
    }
    return result
  }

  function normalizeDevices(value) {
    if (!Array.isArray(value)) return []
    var result = []
    for (var i = 0; i < Math.min(value.length, maxDeviceItems); ++i) {
      var item = value[i]
      if (!item || typeof item !== "object" || Array.isArray(item)) continue
      var name = opaqueText(item.name, 512)
      if (name) result.push({ name: name, active: item.active === true })
    }
    return result
  }

  function stationNameFor(path) {
    var clean = cleanText(path, 4096).replace(/^https?:/i, "").replace(/\/$/, "")
    for (var i = 0; i < stations.length; ++i) {
      if (String(stations[i].url).replace(/^https?:/i, "").replace(/\/$/, "") === clean)
        return stations[i].name
    }
    return ""
  }

  function catalogSize(playlists) {
    var count = 0
    for (var i = 0; i < playlists.length; ++i)
      if (/^c:/.test(String(playlists[i].id || ""))) count += 1
    return count
  }

  function ipcHelperPath() {
    return String(Qt.resolvedUrl("cliamp_ipc.py")).replace(/^file:\/\//, "")
  }

  function searchFavoritesHelperPath() {
    return String(Qt.resolvedUrl("cliamped_search_favorites.py")).replace(/^file:\/\//, "")
  }

  function processHelperPath() {
    return String(Qt.resolvedUrl("cliamped_process.py")).replace(/^file:\/\//, "")
  }

  function isSearchFavorite(track) {
    var path = opaqueText(track && track.path, 4096)
    for (var i = 0; i < searchFavorites.length; ++i)
      if (String(searchFavorites[i].path || "") === path) return true
    return false
  }

  function refreshSearchFavorites() {
    if (searchFavoriteProcess.running) return
    searchFavoritesBusy = true
    searchFavoritesTimedOut = false
    searchFavoriteProcess.command = ["/usr/bin/python3", "-I", searchFavoritesHelperPath(), "list"]
    searchFavoriteProcess.launchPending = true
    searchFavoriteWatchdog.restart()
    searchFavoriteProcess.running = true
  }

  function toggleSearchFavorite(track) {
    var safeTrack = normalizeTrack(track)
    if (!safeTrack || searchFavoriteProcess.running) return
    searchFavoritesBusy = true
    searchFavoritesTimedOut = false
    searchFavoriteProcess.command = ["/usr/bin/python3", "-I", searchFavoritesHelperPath(),
      "toggle", JSON.stringify(safeTrack)]
    searchFavoriteProcess.launchPending = true
    searchFavoriteWatchdog.restart()
    searchFavoriteProcess.running = true
  }

  function playFavorite(item) {
    if (!item) return
    if (item.kind === "search") playProviderTrack(item.track)
    else loadProviderPlaylist(item.id)
  }

  function removeFavorite(item) {
    if (!item) return
    if (item.kind === "search") toggleSearchFavorite(item.track)
    else toggleProviderFavorite(item.id)
  }

  function isLibraryKind(kind) {
    return kind === "libArtists" || kind === "libAlbums" || kind === "libTracks"
      || kind === "libSearch" || kind === "libLoad" || kind === "libFavorite"
      || kind === "libRoots" || kind === "libPlaylists" || kind === "libPlaylistWrite"
  }

  function isProviderKind(kind) {
    return kind === "providers" || kind === "playlists" || kind === "catalog"
      || kind === "favorite" || kind === "search" || kind === "load" || kind === "urlLoad"
      || isLibraryKind(kind)
  }

  function syncProviderBusy() {
    if (ipcCurrent && isProviderKind(ipcCurrent.kind)) {
      providerBusy = true
      return
    }
    for (var i = 0; i < ipcQueue.length; ++i) {
      if (isProviderKind(ipcQueue[i].kind)) {
        providerBusy = true
        return
      }
    }
    providerBusy = false
  }

  function enqueueIpc(kind, request, fallbackArgs) {
    if (destroying) return false
    if (!sessionReady && kind !== "status") return false
    if (!request || typeof request !== "object" || Array.isArray(request)) return false
    var encoded = ""
    try { encoded = JSON.stringify(request) } catch (e) { return false }
    if (!encoded || encoded.length > 32768) {
      errorText = "The CLIAMP request exceeded the plugin limit."
      return false
    }
    var pending = ipcQueue.slice()
    // Polls and slider updates are snapshots. Keep only their newest pending
    // value so an unavailable peer cannot grow the resident work queue.
    if (["status", "queueList", "history", "lyrics", "devices", "volumeAction", "search", "libSearch"].indexOf(kind) >= 0) {
      var compacted = []
      for (var i = 0; i < pending.length; ++i)
        if (pending[i].kind !== kind) compacted.push(pending[i])
      pending = compacted
    }
    if (pending.length >= maxIpcQueueItems) {
      errorText = "CLIAMP is busy; wait for the pending request to finish."
      return false
    }
    pending.push({ kind: cleanText(kind, 32), request: request })
    ipcQueue = pending
    syncProviderBusy()
    pumpIpc()
    return true
  }

  function enqueueVolume(target, delta) {
    if (!delta) return
    if (enqueueIpc("volumeAction", { cmd: "volume", value: target }, [])) volumeDirty = true
  }

  function volumeRequestPending() {
    if (ipcCurrent && ipcCurrent.kind === "volumeAction") return true
    for (var i = 0; i < ipcQueue.length; ++i)
      if (ipcQueue[i].kind === "volumeAction") return true
    return false
  }

  function settleVolumeRequest(kind) {
    if (kind !== "volumeAction") return
    volumeDirty = false
    for (var i = 0; i < ipcQueue.length; ++i) {
      if (ipcQueue[i].kind === "volumeAction") {
        volumeDirty = true
        break
      }
    }
  }

  function pumpIpc() {
    if (destroying || ipcBusy || providerProcess.running || !ipcQueue.length) return
    var pending = ipcQueue.slice()
    ipcCurrent = pending.shift()
    ipcQueue = pending
    ipcBusy = true
    providerTimedOut = false
    providerRequestKind = ipcCurrent.kind
    syncProviderBusy()
    providerProcess.command = ["/usr/bin/python3", "-I", ipcHelperPath(), JSON.stringify(ipcCurrent.request)]
    providerWatchdog.interval = isProviderKind(ipcCurrent.kind) || ipcCurrent.kind === "play" ? 72000 : 13500
    providerProcess.launchPending = true
    providerWatchdog.restart()
    providerProcess.running = true
  }

  function finishIpc() {
    ipcBusy = false
    ipcCurrent = null
    syncProviderBusy()
    Qt.callLater(pumpIpc)
  }

  function handleIpcStartFailure() {
    providerWatchdog.stop()
    providerKill.stop()
    providerTimedOut = false
    var current = ipcCurrent
    var kind = current ? current.kind : providerRequestKind
    settleVolumeRequest(kind)
    if (kind === "status") {
      probeInFlight = false
      sessionReady = false
      modeKnown = false
      if (!daemon.running && !startingDaemon && !destroying) startOwnedDaemon(false)
    } else if (isLibraryKind(kind)) {
      libraryError = "Could not start the bounded CLIAMP helper."
      if (kind === "libPlaylistWrite") finishLibraryWrite(false)
    } else if (isProviderKind(kind)) {
      providerError = "Could not start the bounded CLIAMP helper."
    } else {
      errorText = "Could not start the bounded CLIAMP helper."
    }
    finishIpc()
  }

  function handleFavoriteStartFailure() {
    searchFavoriteWatchdog.stop()
    searchFavoriteKill.stop()
    searchFavoritesBusy = false
    searchFavoritesTimedOut = false
    if (!destroying) providerError = "Could not start the favorites helper."
  }

  function runProviderRequest(kind, request) {
    providerError = ""
    return enqueueIpc(kind, request, [])
  }

  function refreshProviders() {
    runProviderRequest("providers", { cmd: "provider.list" })
  }

  function selectProvider(key) {
    var safeKey = opaqueText(key, 128)
    if (safeKey && !/^[A-Za-z0-9_.:-]+$/.test(safeKey)) return
    selectedProviderKey = safeKey
    loadedProviderPlaylistId = ""
    providerPlaylists = []
    providerResults = []
    providerSearchAttempted = false
    radioCatalogOffset = 0
    radioCatalogHasMore = true
    radioCatalogRequested = false
    if (selectedProviderKey)
      runProviderRequest("playlists", { cmd: "provider.playlists", provider: selectedProviderKey })
  }

  function searchProvider(query) {
    var value = cleanText(query, 256).trim()
    if (!value || !selectedProviderKey) return
    providerResults = []
    providerSearchAttempted = true
    runProviderRequest("search", {
      cmd: "provider.search", provider: selectedProviderKey, query: value, limit: 18
    })
  }

  function loadRadioCatalog() {
    if (selectedProviderKey !== "radio" || !radioCatalogHasMore) return
    radioCatalogRequested = true
    runProviderRequest("catalog", {
      cmd: "provider.catalog", provider: "radio", offset: radioCatalogOffset, limit: 18
    })
  }

  function toggleProviderFavorite(playlistId) {
    if (selectedProviderKey !== "radio" || !playlistId) return
    var safeId = opaqueText(playlistId, 512)
    if (!safeId) return
    runProviderRequest("favorite", {
      cmd: "provider.favorite", provider: "radio", playlist: safeId
    })
  }

  function runLibraryRequest(kind, request) {
    libraryError = ""
    return enqueueIpc(kind, request, [])
  }

  // True when a response still belongs to what the Library view shows. The
  // queue is serial, but the user can change the view while a request waits.
  function libraryRequestIsCurrent(item) {
    if (!item || !item.request) return false
    var request = item.request
    if (request.cmd === "provider.artists") return libraryView === "artists"
    if (request.cmd === "provider.albums")
      return libraryView === "albums" && String(request.sort || "") === librarySort
    if (request.cmd === "provider.artist_albums")
      return libraryView === "artistAlbums" && request.artist === libraryArtistId
    if (request.cmd === "provider.album_tracks")
      return libraryView === "tracks" && request.album === libraryAlbumId
    if (request.cmd === "provider.tracks")
      return libraryView === "playlistTracks" && request.playlist === libraryPlaylistId
    if (request.cmd === "provider.search")
      return libraryView === "search" && request.query === librarySearchQuery
    return false
  }

  function showLibrary(force) {
    if (!providers.length) {
      refreshProviders()
      return
    }
    if (!libraryAvailable) return
    if (force || !libraryRootsLoaded) refreshLibraryRoots()
    if (libraryView === "artists" || libraryView === "albums") {
      if (force || (libraryView === "artists" ? !libraryArtists.length : !libraryAlbums.length))
        loadLibraryPage(true)
    } else if (libraryView === "playlists") {
      refreshLibraryPlaylists()
    }
  }

  function loadLibraryPage(reset) {
    if (!libraryAvailable) return
    var view = libraryView
    var offset = 0
    if (!reset) offset = view === "artists" ? libraryArtists.length : libraryAlbums.length
    var request = null
    if (view === "artists") {
      request = { cmd: "provider.artists", provider: libraryProviderKey, offset: offset, limit: libraryPageSize }
    } else if (view === "albums") {
      request = { cmd: "provider.albums", provider: libraryProviderKey, offset: offset, limit: libraryPageSize }
      if (librarySort) request.sort = librarySort
    } else if (view === "artistAlbums" && libraryArtistId) {
      request = {
        cmd: "provider.artist_albums", provider: libraryProviderKey,
        artist: libraryArtistId, offset: offset, limit: libraryPageSize
      }
    }
    if (!request) return
    if (reset) {
      libraryLoaded = false
      if (view === "artists") {
        libraryArtistsMore = false
        libraryArtistsStale = false
      } else {
        libraryAlbumsMore = false
      }
    }
    runLibraryRequest(view === "artists" ? "libArtists" : "libAlbums", request)
  }

  function showLibraryTop(top) {
    libraryTop = ["albums", "playlists", "folders"].indexOf(top) >= 0 ? top : "artists"
    libraryView = libraryTop
    librarySearchAttempted = false
    libraryError = ""
    libraryNotice = ""
    libraryPickerOpen = false
    if (libraryTop === "folders") {
      refreshLibraryRoots()
    } else if (libraryTop === "playlists") {
      libraryLoaded = false
      refreshLibraryPlaylists()
    } else if (libraryTop === "artists") {
      libraryLoaded = libraryArtists.length > 0 && !libraryArtistsStale
      if (!libraryArtists.length || libraryArtistsStale) loadLibraryPage(true)
    } else {
      libraryAlbums = []
      loadLibraryPage(true)
    }
  }

  function openLibraryArtist(id, name) {
    var safeId = opaqueText(id, 512)
    if (!safeId) return
    libraryArtistId = safeId
    libraryArtistName = cleanText(name, 256)
    libraryNotice = ""
    libraryView = "artistAlbums"
    libraryAlbums = []
    loadLibraryPage(true)
  }

  function openLibraryAlbum(id, name) {
    var safeId = opaqueText(id, 512)
    if (!safeId) return
    libraryAlbumId = safeId
    libraryAlbumName = cleanText(name, 256)
    libraryNotice = ""
    libraryReturnView = libraryView
    libraryView = "tracks"
    libraryTracks = []
    libraryLoaded = false
    runLibraryRequest("libTracks", {
      cmd: "provider.album_tracks", provider: libraryProviderKey,
      album: safeId, offset: 0, limit: 200
    })
  }

  function libraryBack() {
    libraryError = ""
    if (libraryView === "tracks") {
      libraryView = libraryReturnView
      libraryLoaded = true
    } else if (libraryView === "playlistTracks") {
      libraryView = "playlists"
      libraryLoaded = true
    } else if (libraryView === "artistAlbums") {
      libraryView = "artists"
      libraryLoaded = libraryArtists.length > 0
    } else if (libraryView === "search") {
      librarySearchAttempted = false
      showLibraryTop(libraryTop)
    }
  }

  function searchLibrary(query) {
    var value = cleanText(query, 256).trim()
    if (!value || !libraryAvailable) return
    librarySearchQuery = value
    libraryView = "search"
    libraryTracks = []
    libraryLoaded = false
    librarySearchAttempted = true
    runLibraryRequest("libSearch", {
      cmd: "provider.search", provider: libraryProviderKey, query: value, limit: 50
    })
  }

  // A refresh in the background must not wipe the error of an action, so the
  // folder and playlist lists load without clearing it.
  function refreshLibraryRoots() {
    enqueueIpc("libRoots", { cmd: "library.roots" }, [])
  }

  // Looks at the folder sizes every few seconds while CLIAMP scans, so the
  // lists catch up, until CLIAMP says that the scan ended. The count of looks
  // is the bound: about thirteen minutes, and none are sent while the panel is
  // closed.
  function startLibraryPolling() {
    libraryPollsLeft = 200
    libraryPollTracks = -1
    libraryPollTimer.restart()
  }

  function pollLibrary() {
    if (destroying || libraryPollsLeft <= 0) {
      libraryPollTimer.stop()
      return
    }
    libraryPollsLeft -= 1
    if (panelLoader.item && panelLoader.item.opened === true) refreshLibraryRoots()
  }

  function addLibraryRoot(path) {
    var safePath = opaqueText(path, 4096)
    if (!safePath) {
      libraryError = "CLIAMPed cannot send that folder: its name has control or invisible characters."
      return
    }
    libraryNotice = ""
    runLibraryRequest("libRoots", { cmd: "library.add_root", path: safePath })
  }

  function removeLibraryRoot(path) {
    var safePath = opaqueText(path, 4096)
    if (!safePath) return
    libraryNotice = ""
    runLibraryRequest("libRoots", { cmd: "library.remove_root", path: safePath })
  }

  function rescanLibrary() {
    libraryNotice = ""
    runLibraryRequest("libRoots", { cmd: "library.scan" })
  }

  function refreshLibraryPlaylists() {
    enqueueIpc("libPlaylists", { cmd: "provider.playlists", provider: libraryProviderKey }, [])
  }

  // Marks the lists that were read before the index changed as out of date.
  function staleLibraryLists() {
    libraryArtistsStale = true
    if (libraryView === "artists" || libraryView === "albums") loadLibraryPage(true)
  }

  function openLibraryPlaylist(id, name) {
    var safeId = opaqueText(id, 512)
    if (!safeId) return
    libraryPlaylistId = safeId
    libraryPlaylistName = cleanText(name, 256)
    libraryNotice = ""
    libraryView = "playlistTracks"
    libraryTracks = []
    libraryLoaded = false
    runLibraryRequest("libTracks", {
      cmd: "provider.tracks", provider: libraryProviderKey,
      playlist: safeId, offset: 0, limit: 200
    })
  }

  // Loads the open playlist into the queue and plays it from startIndex.
  function playLibraryPlaylist(startIndex) {
    if (!libraryPlaylistId) return
    libraryPendingIndex = cleanInteger(startIndex, 0, 1000000, 0)
    loadedProviderPlaylistId = ""
    runLibraryRequest("libLoad", {
      cmd: "provider.load", provider: libraryProviderKey, playlist: libraryPlaylistId
    })
  }

  // Opens the list of playlists to add tracks to.
  function openLibraryPicker(tracks, label) {
    var safeTracks = normalizeTracks(tracks, 200)
    if (!safeTracks.length) return
    libraryPickerTracks = safeTracks
    libraryPickerLabel = cleanText(label, 128)
    libraryPickerOpen = true
    libraryNotice = ""
    refreshLibraryPlaylists()
  }

  function closeLibraryPicker() {
    libraryPickerOpen = false
    libraryPickerTracks = []
  }

  // The requests that append tracks to a saved playlist, a few at a time so
  // that each stays well under the request size limit.
  function playlistWriteRequests(playlistId, tracks) {
    var requests = []
    if (tracks.length === 1) {
      requests.push({ cmd: "playlist.add", provider: libraryProviderKey, playlist: playlistId, track: tracks[0] })
    } else {
      for (var i = 0; i < tracks.length; i += 24)
        requests.push({
          cmd: "playlist.add_many", provider: libraryProviderKey,
          playlist: playlistId, tracks: tracks.slice(i, i + 24)
        })
    }
    return requests
  }

  function writeToLibraryPlaylist(playlistId, playlistName, create) {
    var safeId = opaqueText(playlistId, 512)
    var tracks = libraryPickerTracks
    if (!safeId || !tracks.length) return
    var requests = playlistWriteRequests(safeId, tracks)
    if (create) requests.unshift({ cmd: "playlist.create", provider: libraryProviderKey, playlist: safeId })
    if (libraryWritesPending > 0 || ipcQueue.length + requests.length > maxIpcQueueItems - 4) {
      libraryError = "CLIAMP is busy; try again in a moment."
      return
    }
    libraryError = ""
    libraryWriteFailed = false
    libraryWriteNotice = (tracks.length === 1 ? "Added 1 track to “" : "Added " + tracks.length + " tracks to “")
      + cleanText(playlistName, 128) + "”."
    for (var i = 0; i < requests.length; ++i) {
      if (enqueueIpc("libPlaylistWrite", requests[i], [])) {
        libraryWritesPending += 1
      } else {
        // A request that was not queued is a write that did not happen.
        libraryWriteFailed = true
      }
    }
    if (libraryWritesPending === 0) libraryError = libraryError || "Could not send the request to CLIAMP."
  }

  // Counts one playlist write as done. The notice and the closing of the
  // picker wait for the last write, and only a clean run earns them.
  function finishLibraryWrite(succeeded) {
    if (!succeeded) libraryWriteFailed = true
    libraryWritesPending = Math.max(0, libraryWritesPending - 1)
    if (libraryWritesPending > 0) return
    if (!libraryWriteFailed) {
      libraryNotice = libraryWriteNotice
      closeLibraryPicker()
    }
    refreshLibraryPlaylists()
  }

  function addToLibraryPlaylist(playlistId, playlistName) {
    writeToLibraryPlaylist(playlistId, playlistName, false)
  }

  function createLibraryPlaylist(name) {
    var clean = cleanText(name, 128).trim()
    if (!clean) {
      libraryError = "Give the playlist a name."
      return
    }
    writeToLibraryPlaylist(clean, clean, true)
  }

  // Toggles the favorite heart of a track. CLIAMP keeps the hearts of every
  // provider in one list, shown as Favorites under Browse.
  function toggleTrackFavorite(track) {
    var safeTrack = normalizeTrack(track)
    if (!safeTrack) return
    runLibraryRequest("libFavorite", {
      cmd: "playlist.bookmark", provider: libraryProviderKey, track: safeTrack
    })
  }

  // Returns the tracks with the heart of the track at path flipped.
  function flipFavorite(tracks, path) {
    var result = []
    for (var i = 0; i < tracks.length; ++i) {
      var track = tracks[i]
      if (track.path === path) {
        var copy = Object.assign({}, track)
        copy.bookmark = !track.bookmark
        result.push(copy)
      } else {
        result.push(track)
      }
    }
    return result
  }

  function cycleLibrarySort() {
    if (librarySorts.length < 2 || libraryView !== "albums") return
    var index = 0
    for (var i = 0; i < librarySorts.length; ++i)
      if (librarySorts[i].id === librarySort) index = i
    librarySort = librarySorts[(index + 1) % librarySorts.length].id
    libraryAlbums = []
    loadLibraryPage(true)
  }

  // Loads the open album into the queue and plays it from startIndex.
  function playLibraryAlbum(startIndex) {
    if (!libraryAlbumId) return
    libraryPendingIndex = cleanInteger(startIndex, 0, 1000000, 0)
    loadedProviderPlaylistId = ""
    runLibraryRequest("libLoad", {
      cmd: "provider.load_album", provider: libraryProviderKey, album: libraryAlbumId
    })
  }

  function showFavorites() {
    if (!providers.length) refreshProviders()
    else if (selectedProviderKey !== "radio") selectProvider("radio")
    else runProviderRequest("playlists", { cmd: "provider.playlists", provider: "radio" })
  }

  function loadProviderPlaylist(playlistId) {
    if (!selectedProviderKey || !playlistId) return
    var safeId = opaqueText(playlistId, 512)
    if (!safeId) return
    runProviderRequest("load", {
      cmd: "provider.load", provider: selectedProviderKey, playlist: safeId
    })
  }

  function playProviderTrack(track) {
    var safeTrack = normalizeTrack(track)
    if (!safeTrack) return
    loadedProviderPlaylistId = ""
    enqueueIpc("play", { cmd: "track.play", track: safeTrack }, [])
  }

  function playLocalFile(filePath) {
    var path = opaqueText(filePath, 4096)
    if (!path) return
    loadedProviderPlaylistId = ""
    enqueueIpc("play", { cmd: "track.play", track: { path: path } }, [])
  }

  function playLocalFiles(paths) {
    if (!Array.isArray(paths) || !paths.length || paths.length > maxTrackItems) return
    loadedProviderPlaylistId = ""
    for (var i = 0; i < Math.min(paths.length, maxTrackItems); ++i) {
      var path = opaqueText(paths[i], 4096)
      if (!path) continue
      enqueueIpc(i === 0 ? "play" : "queueMutation", {
        cmd: i === 0 ? "track.play" : "track.queue", track: { path: path }
      }, [])
    }
  }

  function refreshQueue() { enqueueIpc("queueList", { cmd: "queue.list" }, []) }
  function playQueueIndex(index) { enqueueIpc("queueMutation", { cmd: "queue.play", index: index }, []) }
  function enqueueQueueIndex(index) { enqueueIpc("queueMutation", { cmd: "queue.enqueue", index: index }, []) }
  function removeQueueIndex(index) { enqueueIpc("queueMutation", { cmd: "queue.remove", index: index }, []) }
  function clearQueue() { enqueueIpc("queueMutation", { cmd: "queue.clear" }, []) }
  function refreshHistory() { enqueueIpc("history", { cmd: "history", limit: 24 }, []) }
  function playHistoryItem(item) {
    var track = item && normalizeTrack(item.track)
    if (track) {
      loadedProviderPlaylistId = ""
      enqueueIpc("play", { cmd: "track.play", track: track }, [])
    }
  }
  function refreshLyrics() { enqueueIpc("lyrics", { cmd: "lyrics" }, []) }
  function refreshDevices() { enqueueIpc("devices", { cmd: "device", name: "list" }, ["device", "list"]) }
  function selectDevice(name) {
    var safeName = opaqueText(name, 512)
    if (safeName) enqueueIpc("deviceSet", { cmd: "device", name: safeName }, [])
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function probe() {
    if (destroying || probeInFlight) return
    probeInFlight = enqueueIpc("status", { cmd: "status" }, [])
  }

  function parseStatus(raw) {
    try {
      var value = typeof raw === "string" ? JSON.parse(raw) : raw
      if (!value || !value.ok) return false
      sessionReady = true
      startingDaemon = false
      daemonStartupDeadline.stop()
      errorText = ""
      var statusMode = cleanText(value.session_mode, 16)
      if (statusMode === "headless" || statusMode === "tui") {
        sessionMode = statusMode
        modeKnown = true
      } else {
        sessionMode = "unknown"
        modeKnown = false
      }
      var nextState = cleanText(value.state, 16).toLowerCase()
      state = ["playing", "paused", "stopped"].indexOf(nextState) >= 0 ? nextState : "stopped"
      if (value.volume !== undefined && !volumeDirty && !volumeRequestPending())
        volumeDb = cleanNumber(value.volume, -30, 6, 0)
      shuffle = value.shuffle === true
      repeatMode = cleanText(value.repeat, 16) || "Off"
      mono = value.mono === true
      playbackSpeed = cleanNumber(value.speed, 0.25, 2, 1)
      eqPreset = cleanText(value.eq_preset, 64) || "Flat"
      currentIndex = cleanInteger(value.index, -1, 1000000, -1)
      trackTotal = cleanInteger(value.total, 0, 1000000, 0)
      positionSeconds = cleanNumber(value.position, 0, 31536000, 0)
      durationSeconds = cleanNumber(value.duration, 0, 31536000, 0)
      var statusTrack = normalizeTrack(value.track)
      if (statusTrack) {
        var metadata = nowPlayingMetadata(statusTrack)
        trackTitle = metadata.title
        trackArtist = metadata.artist
        trackAlbum = metadata.album
        trackStation = metadata.station
        trackPath = statusTrack.path
      } else {
        trackTitle = "CLIAMPed"
        trackArtist = ""
        trackAlbum = ""
        trackStation = ""
        trackPath = ""
      }
      return true
    } catch (e) {
      return false
    }
  }

  function handleDaemonExit(exitCode, failedToStart) {
    daemonKill.stop()
    daemonStartupDeadline.stop()
    startupProbe.stop()
    sessionReady = false
    sessionMode = "unknown"
    modeKnown = false
    startingDaemon = false
    if (!ownsDaemon) return
    ownsDaemon = false
    if (destroying) return
    // Only a minute of stable ownership replenishes the automatic retry
    // budget. Short-lived starts therefore stop after three attempts.
    if (Date.now() - daemonStartedAt >= 60000) daemonStartFailures = 0
    daemonStartFailures = Math.min(maxDaemonStartFailures, daemonStartFailures + 1)
    daemonRetryNotBefore = Date.now() + Math.min(30000,
      2000 * Math.pow(2, daemonStartFailures - 1))
    errorText = failedToStart ? "Could not start the supervised CLIAMP daemon."
      : exitCode === 0 ? "CLIAMP stopped." : "CLIAMP daemon exited unexpectedly."
  }

  function startOwnedDaemon(userInitiated) {
    if (destroying || daemon.running || startingDaemon) return false
    if (userInitiated === true) {
      daemonStartFailures = 0
      daemonRetryNotBefore = 0
    } else if (daemonStartFailures >= maxDaemonStartFailures
        || Date.now() < daemonRetryNotBefore) {
      return false
    }
    ownsDaemon = true
    sessionMode = "headless"
    modeKnown = true
    startingDaemon = true
    daemonStartedAt = Date.now()
    startupAttempts = 0
    errorText = "Starting a private CLIAMP session…"
    daemon.command = ["/usr/bin/python3", "-I", processHelperPath(), "daemon"]
    daemon.launchPending = true
    daemonStartupDeadline.restart()
    startupProbe.restart()
    daemon.running = true
    return true
  }

  function stopOwnedDaemon(message) {
    if (!ownsDaemon || !daemon.running) return
    startingDaemon = false
    if (message) errorText = cleanText(message, 512)
    daemon.signal(15)
    daemonKill.restart()
  }

  function runAction(args) {
    if (!args || !args.length) return false
    var cmd = String(args[0])
    var request = { cmd: cmd }
    if (cmd === "volume" || cmd === "speed" || cmd === "seek") request.value = Number(args[1])
    else if (cmd === "shuffle" || cmd === "repeat" || cmd === "mono" || cmd === "vis" || cmd === "eq")
      request.name = cleanText(args[1], 64)
    return enqueueIpc("action", request, args)
  }

  function togglePlayback() {
    if (!sessionReady) {
      pendingAfterStart = { kind: "action", request: { cmd: "play" }, fallback: ["play"] }
      startOwnedDaemon(true)
      delayedSelection.restart()
      return
    }
    runAction([state === "stopped" ? "play" : "toggle"])
  }

  function next() { if (sessionReady) runAction(["next"]) }
  function previous() { if (sessionReady) runAction(["prev"]) }
  function stop() { if (sessionReady) runAction(["stop"]) }
  function adjustVolume(delta) {
    if (!sessionReady) return
    var target = Math.max(-30, Math.min(6, volumeDb + Number(delta || 0)))
    if (target === volumeDb) return
    volumeDirty = true
    pendingVolumeDelta += target - volumeDb
    volumeDb = target
    volumeCommit.restart()
  }
  function toggleShuffle() { if (sessionReady) runAction(["shuffle", "toggle"]) }
  function cycleRepeat() { if (sessionReady) runAction(["repeat", "cycle"]) }
  function toggleMono() { if (sessionReady) runAction(["mono", "toggle"]) }
  function nextVisualizer() {
    panelVisualizerIndex = (panelVisualizerIndex + 1) % panelVisualizers.length
  }
  function selectPanelVisualizer(name) {
    var requested = String(name || "").trim().toLowerCase()
    for (var i = 0; i < panelVisualizers.length; ++i) {
      if (panelVisualizers[i].toLowerCase() === requested) {
        panelVisualizerIndex = i
        return panelVisualizers[i]
      }
    }
    return "invalid visualizer"
  }
  function setSpeed(value) { if (sessionReady) runAction(["speed", String(value)]) }
  function setEqPreset(value) { if (sessionReady) runAction(["eq", String(value)]) }
  function seekTo(seconds) {
    if (sessionReady && durationSeconds > 0)
      runAction(["seek", String(Math.max(0, Math.min(durationSeconds, seconds)) - positionSeconds)])
  }
  function queueMedia(value) {
    var target = opaqueText(value, 4096)
    if (!target) return
    if (!sessionReady) {
      queuedUrl = target
      pendingAfterStart = {
        kind: "queueMutation", request: { cmd: "track.queue", track: { path: target } },
        fallback: ["queue", target]
      }
      startOwnedDaemon(true)
      delayedSelection.restart()
      return
    }
    enqueueIpc("queueMutation", { cmd: "track.queue", track: { path: target } }, ["queue", target])
  }

  function selectStation(station) {
    if (!station || !station.url) return
    loadedProviderPlaylistId = ""
    errorText = ""
    providerError = ""
    if (!sessionReady) {
      queuedUrl = station.url
      pendingAfterStart = { kind: "play", request: { cmd: "track.play", track: {
        title: station.name + " Stream", path: station.url, stream: true
      } }, fallback: [] }
      startOwnedDaemon(true)
      delayedSelection.restart()
      return
    }
    enqueueIpc("queueMutation", { cmd: "queue.clear" }, [])
    enqueueIpc("play", { cmd: "track.play", track: {
      title: station.name + " Stream", path: station.url, stream: true
    } }, [])
  }

  function togglePanel() {
    if (!panelLoader.item || !panelLoader.item.toggle) return
    var opening = panelLoader.item.opened !== true
    panelLoader.item.toggle()
    if (opening && panelLoader.item.libraryTab === "favorites") showFavorites()
  }
  function openTab(tab) {
    var target = panelLoader.item
    if (!target) return "unavailable"
    var requested = String(tab || "favorites")
    requested = requested === "radio" || requested === "browse" ? "providers" : requested
    // The Files tab moved into Queue; keep the old name working for scripts.
    requested = requested === "files" ? "queue" : requested
    if (["favorites", "providers", "queue", "library", "more"].indexOf(requested) < 0)
      return "invalid tab"
    target.libraryTab = requested
    if (target.libraryTab === "favorites") showFavorites()
    else if (target.libraryTab === "providers" && !providers.length) refreshProviders()
    else if (target.libraryTab === "queue") refreshQueue()
    else if (target.libraryTab === "library") showLibrary(true)
    else if (target.libraryTab === "more") {
      refreshHistory()
      refreshLyrics()
      refreshDevices()
    }
    target.open()
    return "ok"
  }
  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) {
      panelLoader.item.openFromHotkey()
      if (panelLoader.item.libraryTab === "favorites") showFavorites()
    }
  }
  function close() { if (panelLoader.item && panelLoader.item.close) panelLoader.item.close() }
  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  BandStream { id: bandStream; enabled: root.sessionReady; fps: 30 }

  Loader {
    id: panelLoader
    active: true
    // Keep this query aligned with manifest.json so Qt drops stale panel components on updates.
    source: Qt.resolvedUrl("Panel.qml") + "?v=1.3.0"
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "radio"
    active: root.opened
    horizontalMargin: 9
    keepSpace: true
    labelVisible: false
    fixedWidth: barContent.implicitWidth + Style.space(18)
    tooltipText: root.sessionReady
      ? ((root.playing ? "Playing " : "Paused ") + root.plainLabel(root.trackTitle || "CLIAMP", 256)
        + (root.trackSubtitle ? " · " + root.plainLabel(root.trackSubtitle, 768) : "")
        + " · left: panel · middle: play/pause · right: next")
      : "CLIAMPed is starting…"

    Row {
      id: barContent
      anchors.centerIn: parent
      spacing: Style.space(7)
      SafeText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.playing ? "󰝚" : "󰏤"
        color: root.playing ? root.bar.barForeground : Qt.darker(root.bar.barForeground, 1.4)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
      }
      DesertVisualizer {
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 13
        bands: root.bands
        playing: root.playing
        mode: root.panelVisualizerIndex
        compact: true
        turquoise: Color.accent
        sand: root.bar.barForeground
        adobe: root.bar.urgent
        sky: root.bar ? root.bar.background : Color.background
        onCycleRequested: root.nextVisualizer()
      }
      SafeText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.trackTitle || root.selectedStation || "Radio"
        color: root.bar.barForeground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        maximumLineCount: 1
        width: Math.min(implicitWidth, 120)
      }
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.togglePlayback()
      else if (b === Qt.RightButton) root.next()
      else root.togglePanel()
    }

    // The bar adds its own left-button gesture layer for module reordering.
    // Keep middle-button playback independent of that layered dispatch so it
    // remains reliable as the bar's pointer handling evolves.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      onPressed: root.togglePlayback()
    }
  }

  IpcHandler {
    target: root.moduleName

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function tab(name: string): string { return root.openTab(name) }
    function visualizer(name: string): string { return root.selectPanelVisualizer(name) }
  }

  Process {
    id: providerProcess
    property bool launchPending: false
    command: ["/usr/bin/true"]
    clearEnvironment: true
    environment: root.processEnvironment
    stdout: StdioCollector { id: providerOut; waitForEnd: true }
    onStarted: launchPending = false
    onRunningChanged: {
      if (!running && launchPending) {
        launchPending = false
        root.handleIpcStartFailure()
      }
    }
    onExited: function(exitCode) {
      launchPending = false
      providerWatchdog.stop()
      providerKill.stop()
      var current = root.ipcCurrent
      var kind = current ? current.kind : root.providerRequestKind
      var response = null
      try { response = JSON.parse(String(providerOut.text || "")) } catch (e) {}
      if (root.providerTimedOut || exitCode !== 0 || !response || !response.ok) {
        var message = response && response.error
          ? root.cleanText(response.error, 1024)
          : root.providerTimedOut ? "CLIAMP request exceeded its deadline." : "CLIAMP IPC request failed."
        root.settleVolumeRequest(kind)
        if (kind === "status") {
          root.probeInFlight = false
          root.sessionReady = false
          root.modeKnown = false
          if (!daemon.running && !root.startingDaemon && !root.destroying) root.startOwnedDaemon(false)
        } else if (root.isLibraryKind(kind)) {
          root.libraryError = message
          if (kind === "libPlaylistWrite") root.finishLibraryWrite(false)
        } else if (kind === "providers" || kind === "playlists" || kind === "catalog"
            || kind === "favorite" || kind === "search" || kind === "load" || kind === "urlLoad") {
          root.providerError = message
        } else {
          root.errorText = message
        }
        root.finishIpc()
        return
      }
      if (kind === "status") {
        root.probeInFlight = false
        root.parseStatus(response)
      } else if (kind === "providers") {
        root.providerError = ""
        root.providers = root.normalizeProviders(response.providers)
        if (root.providers.length) {
          var nextProvider = root.providers[0].key
          for (var providerIndex = 0; providerIndex < root.providers.length; ++providerIndex) {
            if (root.providers[providerIndex].key === root.selectedProviderKey) {
              nextProvider = root.selectedProviderKey
              break
            }
          }
          // Always refresh the selected source's collections after listing
          // providers. This also repairs state after a shell/plugin reload.
          root.selectProvider(nextProvider)
          if (panelLoader.item && panelLoader.item.libraryTab === "library") root.showLibrary(false)
        }
      } else if (kind === "playlists") {
        root.providerError = ""
        root.providerPlaylists = root.normalizePlaylists(response.playlists)
        if (root.selectedProviderKey === "radio") {
          root.radioCatalogOffset = root.catalogSize(root.providerPlaylists)
          if (root.radioCatalogOffset === 0 && !root.radioCatalogRequested)
            root.loadRadioCatalog()
        }
      } else if (kind === "catalog") {
        root.providerError = ""
        root.providerPlaylists = root.normalizePlaylists(response.playlists)
        var added = root.cleanInteger(response.total, 0, root.maxPlaylistItems, 0)
        root.radioCatalogOffset = root.catalogSize(root.providerPlaylists)
        root.radioCatalogHasMore = added > 0 && root.providerPlaylists.length < root.maxPlaylistItems
      } else if (kind === "favorite") {
        root.providerError = ""
        root.runProviderRequest("playlists", { cmd: "provider.playlists", provider: "radio" })
      } else if (kind === "search") {
        root.providerError = ""
        root.providerResults = root.normalizeTracks(response.tracks, 64)
      } else if (kind === "load") {
        root.providerError = ""
        root.loadedProviderPlaylistId = current && current.request
          ? String(current.request.playlist || "") : ""
        var loadedTracks = root.normalizeTracks(response.tracks, root.maxTrackItems)
        var radioIndex = loadedTracks.length === 1
          && /\.m3u8?(?:$|\?)/i.test(String(loadedTracks[0].path || ""))
          && root.selectedProviderKey === "radio"
        if (radioIndex) {
          root.queueTracks = []
        } else {
          root.queueTracks = loadedTracks
        }
        root.currentIndex = root.queueTracks.length ? 0 : -1
        if (radioIndex) {
          root.enqueueIpc("queueMutation", { cmd: "queue.clear" }, [])
          root.enqueueIpc("urlLoad", { cmd: "url.load", path: loadedTracks[0].path }, [])
        } else if (root.queueTracks.length) {
          root.enqueueIpc("action", { cmd: "play" }, ["play"])
        }
        actionRefresh.restart()
      } else if (kind === "urlLoad") {
        root.providerError = ""
        root.queueTracks = root.normalizeTracks(response.tracks, root.maxTrackItems)
        root.currentIndex = root.queueTracks.length ? 0 : -1
        actionRefresh.restart()
      } else if (kind === "libArtists") {
        // A later page is dropped when the list was reset while it waited.
        if (root.libraryRequestIsCurrent(current)
            && (current.request.offset === 0 || current.request.offset === root.libraryArtists.length)) {
          var artistPage = root.normalizeLibraryArtists(response.artists)
          var artistOffset = current.request.offset
          root.libraryArtists = (artistOffset > 0 ? root.libraryArtists : [])
            .concat(artistPage).slice(0, root.maxLibraryItems)
          root.libraryArtistsMore = artistPage.length > 0
            && artistOffset + artistPage.length < root.cleanInteger(response.total, 0, 1000000000, 0)
            && root.libraryArtists.length < root.maxLibraryItems
          root.libraryLoaded = true
        }
      } else if (kind === "libAlbums") {
        if (root.libraryRequestIsCurrent(current)
            && (current.request.offset === 0 || current.request.offset === root.libraryAlbums.length)) {
          var albumPage = root.normalizeLibraryAlbums(response.albums)
          var albumOffset = current.request.offset
          root.libraryAlbums = (albumOffset > 0 ? root.libraryAlbums : [])
            .concat(albumPage).slice(0, root.maxLibraryItems)
          if (response.sorts) root.librarySorts = root.normalizeLibrarySorts(response.sorts)
          // CLIAMP's album list reports the size of the page, not the library,
          // so a full page is the only sign that more albums follow.
          var moreAlbums = current.request.cmd === "provider.albums"
            ? albumPage.length >= root.libraryPageSize
            : albumOffset + albumPage.length < root.cleanInteger(response.total, 0, 1000000000, 0)
          root.libraryAlbumsMore = moreAlbums && albumPage.length > 0
            && root.libraryAlbums.length < root.maxLibraryItems
          root.libraryLoaded = true
        }
      } else if (kind === "libTracks") {
        if (root.libraryRequestIsCurrent(current)) {
          root.libraryTracks = root.normalizeTracks(response.tracks, 200)
          root.libraryLoaded = true
        }
      } else if (kind === "libSearch") {
        if (root.libraryRequestIsCurrent(current)) {
          root.libraryTracks = root.normalizeTracks(response.tracks, 50)
          root.libraryLoaded = true
        }
      } else if (kind === "libRoots") {
        var firstRoots = !root.libraryRootsLoaded
        var wasScanning = root.libraryScanning
        var command = current && current.request ? current.request.cmd : ""
        if (Array.isArray(response.roots)) root.libraryRoots = root.normalizeLibraryRoots(response.roots)
        root.libraryRootsLoaded = true
        root.libraryScanning = response.scanning === true
        // A library with no folder has nothing to browse: the first time that
        // this is learned, show where to add one. Later looks do not move the user.
        if (firstRoots && !root.libraryRoots.length && (root.libraryView === "artists" || root.libraryView === "albums")) {
          root.libraryTop = "folders"
          root.libraryView = "folders"
        }
        if (command === "library.remove_root") {
          root.libraryArtists = []
          root.libraryAlbums = []
          root.libraryTracks = []
          root.libraryArtistsStale = false
          if (root.libraryView === "artists" || root.libraryView === "albums") root.loadLibraryPage(true)
        }
        if (root.libraryScanning) {
          // Only a successful add or scan reaches this branch, so a refused
          // folder never starts the polling.
          if (!libraryPollTimer.running) root.startLibraryPolling()
          var total = root.libraryTotalTracks
          if (total !== root.libraryPollTracks) {
            root.libraryPollTracks = total
            root.staleLibraryLists()
          }
        } else if (wasScanning || command === "library.add_root" || command === "library.scan") {
          // The scan ended, or was over before the first look: read the lists again.
          root.libraryPollsLeft = 0
          libraryPollTimer.stop()
          root.staleLibraryLists()
        }
      } else if (kind === "libPlaylists") {
        root.libraryPlaylists = root.normalizePlaylists(response.playlists)
        if (root.libraryView === "playlists") root.libraryLoaded = true
      } else if (kind === "libPlaylistWrite") {
        root.finishLibraryWrite(true)
      } else if (kind === "libFavorite") {
        var heartPath = current && current.request && current.request.track
          ? current.request.track.path : ""
        if (heartPath) {
          root.libraryTracks = root.flipFavorite(root.libraryTracks, heartPath)
          root.providerResults = root.flipFavorite(root.providerResults, heartPath)
        }
        // Browse lists the hearts as a collection, so its count is now stale.
        if (root.selectedProviderKey === root.libraryProviderKey)
          root.runProviderRequest("playlists", { cmd: "provider.playlists", provider: root.libraryProviderKey })
      } else if (kind === "libLoad") {
        root.queueTracks = root.normalizeTracks(response.tracks, root.maxTrackItems)
        root.currentIndex = root.queueTracks.length ? 0 : -1
        var startAt = root.libraryPendingIndex
        root.libraryPendingIndex = 0
        // The resident queue keeps at most maxTrackItems, but CLIAMP holds the
        // whole album, and the tracks view lists up to 200 of it.
        if (startAt > 0)
          root.enqueueIpc("play", { cmd: "queue.play", index: startAt }, [])
        else if (root.queueTracks.length)
          root.enqueueIpc("action", { cmd: "play" }, ["play"])
        actionRefresh.restart()
      } else if (kind === "queueList" || kind === "queueMutation") {
        root.queueTracks = root.normalizeTracks(response.tracks, root.maxTrackItems)
        if (response.index !== undefined)
          root.currentIndex = root.cleanInteger(response.index, -1, 1000000, -1)
      } else if (kind === "play") {
        if (response.tracks) root.queueTracks = root.normalizeTracks(response.tracks, root.maxTrackItems)
        if (response.index !== undefined)
          root.currentIndex = root.cleanInteger(response.index, -1, 1000000, -1)
        actionRefresh.restart()
      } else if (kind === "history") {
        root.historyItems = root.normalizeHistory(response.history)
      } else if (kind === "lyrics") {
        root.lyricLines = root.normalizeLyrics(response.lyrics)
      } else if (kind === "devices") {
        root.audioDevices = root.normalizeDevices(response.devices)
      } else if (kind === "action" || kind === "deviceSet" || kind === "volumeAction") {
        root.settleVolumeRequest(kind)
        actionRefresh.restart()
      }
      root.providerTimedOut = false
      if (kind === "load" || kind === "libLoad" || kind === "play" || kind === "queueMutation") queueRefresh.restart()
      root.finishIpc()
    }
  }

  Process {
    id: daemon
    property bool launchPending: false
    command: ["/usr/bin/python3", "-I", root.processHelperPath(), "daemon"]
    clearEnvironment: true
    environment: root.processEnvironment
    running: false
    onStarted: launchPending = false
    onRunningChanged: {
      if (!running && launchPending) {
        launchPending = false
        root.handleDaemonExit(-1, true)
      }
    }
    onExited: function(exitCode) {
      launchPending = false
      root.handleDaemonExit(exitCode, false)
    }
  }

  Process {
    id: searchFavoriteProcess
    property bool launchPending: false
    command: ["/usr/bin/true"]
    clearEnvironment: true
    environment: root.processEnvironment
    stdout: StdioCollector { id: searchFavoriteOut; waitForEnd: true }
    onStarted: launchPending = false
    onRunningChanged: {
      if (!running && launchPending) {
        launchPending = false
        root.handleFavoriteStartFailure()
      }
    }
    onExited: function(exitCode) {
      launchPending = false
      searchFavoriteWatchdog.stop()
      searchFavoriteKill.stop()
      root.searchFavoritesBusy = false
      try {
        var response = JSON.parse(String(searchFavoriteOut.text || ""))
        if (!root.searchFavoritesTimedOut && exitCode === 0 && response && response.ok) {
          root.searchFavorites = root.normalizeTracks(response.favorites, root.maxFavoriteItems)
          return
        }
        root.providerError = root.searchFavoritesTimedOut ? "Favorites request exceeded its deadline."
          : root.cleanText(response && response.error, 1024) || "Could not update favorite."
      } catch (e) {
        root.providerError = root.searchFavoritesTimedOut
          ? "Favorites request exceeded its deadline." : "Could not update favorite."
      }
      root.searchFavoritesTimedOut = false
    }
  }

  Timer { id: startupProbe; interval: 700; onTriggered: root.probe() }
  Timer {
    id: delayedSelection
    interval: 900
    onTriggered: {
      if (root.sessionReady && root.pendingAfterStart) {
        var pending = root.pendingAfterStart
        root.pendingAfterStart = null
        root.enqueueIpc(pending.kind, pending.request, pending.fallback)
      }
      else if (root.pendingAfterStart && root.startupAttempts < 12) {
        root.startupAttempts += 1
        delayedSelection.restart()
      } else if (root.pendingAfterStart) {
        root.pendingAfterStart = null
        root.startingDaemon = false
        root.stopOwnedDaemon("CLIAMP did not become ready. Start CLIAMP and try again.")
      }
    }
  }
  Timer { id: actionRefresh; interval: 250; onTriggered: root.probe() }
  Timer {
    id: libraryPollTimer
    interval: 4000
    repeat: true
    onTriggered: root.pollLibrary()
  }
  Timer {
    id: volumeCommit
    interval: 90
    onTriggered: {
      var delta = root.pendingVolumeDelta
      root.pendingVolumeDelta = 0
      root.enqueueVolume(root.volumeDb, delta)
    }
  }
  Timer { id: queueRefresh; interval: 350; onTriggered: root.refreshQueue() }
  Timer {
    id: providerWatchdog
    interval: 12000
    repeat: false
    onTriggered: {
      if (!providerProcess.running) return
      root.providerTimedOut = true
      providerProcess.signal(15)
      providerKill.restart()
    }
  }
  Timer {
    id: providerKill
    interval: 1500
    repeat: false
    onTriggered: if (providerProcess.running) providerProcess.signal(9)
  }
  Timer {
    id: searchFavoriteWatchdog
    interval: 6000
    repeat: false
    onTriggered: {
      if (!searchFavoriteProcess.running) return
      root.searchFavoritesTimedOut = true
      searchFavoriteProcess.signal(15)
      searchFavoriteKill.restart()
    }
  }
  Timer {
    id: searchFavoriteKill
    interval: 1500
    repeat: false
    onTriggered: if (searchFavoriteProcess.running) searchFavoriteProcess.signal(9)
  }
  Timer {
    id: daemonStartupDeadline
    interval: 12000
    repeat: false
    onTriggered: {
      if (root.startingDaemon && !root.sessionReady)
        root.stopOwnedDaemon("CLIAMP did not become ready before the startup deadline.")
    }
  }
  Timer {
    id: daemonKill
    interval: 2500
    repeat: false
    onTriggered: if (root.ownsDaemon && daemon.running) daemon.signal(9)
  }
  Timer {
    interval: 2200
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.probe()
  }
  Timer {
    interval: 250
    running: root.playing && root.durationSeconds > 0
    repeat: true
    onTriggered: root.positionSeconds = Math.min(root.durationSeconds, root.positionSeconds + interval / 1000)
  }
  Component.onCompleted: refreshSearchFavorites()
  Component.onDestruction: {
    root.destroying = true
    libraryPollTimer.stop()
    root.ipcQueue = []
    root.ipcCurrent = null
    root.pendingAfterStart = null
    root.providers = []
    root.providerPlaylists = []
    root.providerResults = []
    root.searchFavorites = []
    root.queueTracks = []
    root.historyItems = []
    root.lyricLines = []
    root.audioDevices = []
    // Destruction also destroys watchdog timers, so use a terminal signal.
    // The daemon supervisor's guardian tears down CLIAMP's process group.
    if (providerProcess.running) providerProcess.signal(9)
    if (searchFavoriteProcess.running) searchFavoriteProcess.signal(9)
    if (root.ownsDaemon && daemon.running) daemon.signal(9)
  }
}

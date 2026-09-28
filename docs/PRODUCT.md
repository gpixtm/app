# Accepted mobile product decisions

## Central map and walking UX

The home screen is the central map. Imported trails are not drawn until selected: each one with a visible portion is marked by a pin. The selected trail alone is drawn and stays drawn while panning or zooming, until another trail is selected or it is closed. User-facing text calls them **trails** (“parcours”), never “GPX”; the file format is only mentioned where a file is picked or rejected. A focused/browsed trail is separate from the actively followed trail.

There is no bottom navigation bar. A menu button at the top left opens a drawer to My trails, History, Offline and Settings; each page has a back action to the map, and Android back returns to the map. My trails is a secondary, searchable list (case- and accent-insensitive) that keeps view, day planning, start and deletion.

Trails are discovered on the map, as in AllTrails. A pin marks each unselected trail with a visible portion (also while another trail is selected, so the walker can switch; pins are hidden during day planning and active tracking), at the middle of its longest visible portion on the shared distance axis (not its start); segment gaps never join portions. Pins overlapping on screen merge into an “N trails” pin whose trails are listed in the bottom panel. A pin stays where it is while it remains on screen, even when the map moves; only a trail whose pin left the view (or that enters it) gets a new pin when the camera stops. Touching a pin selects its trail (hidden lines are not touch targets): the map fits the whole trail and enters itinerary mode.

Exploration mode shows a place search field (town, address, place) that moves the map. It uses OpenStreetMap geocoding through a Photon server behind the `PlaceSearch` port: the public server is free but fair-use, a self-hosted Photon can replace it through configuration, and search requires a connection. Itinerary mode hides the search field and shows the existing bottom panel with the trail statistics, a single start action and an explicit Google Maps action; the top card closes the trail unless it is being actively followed.

Starting or recentering navigation uses walking proximity (currently zoom 16), even for a 100 km trail. Apply it at the first valid GPS fix if none is available yet. Manual panning suspends camera following until recentering; ordinary following preserves user zoom. The intent is nearby paths, roughly kilometre scale, rather than a rigid one-kilometre radius on every screen.

Use compact trail/offline information with accessible details, an unobstructed compass and a draggable, collapsible metrics/elevation panel. Display the real GPS location and visibly degrade stale/inaccurate fixes; never snap the user marker onto the GPX. The marker shows phone heading even at rest. Circular smoothing must handle 359° → 1° and suppress arm jitter without hiding a deliberate turn. The marker responds faster than the camera. Hide stale headings.

Preserve visual/vibration off-trail alerts and muting until tracking resumes. Use the existing domain thresholds. Following can start mid-route or in reverse. Remaining distance and elevation follow the selected direction; planned days do not silently change the navigation destination. Missing elevations stay missing, estimated elevations are identified, and elevation service failure does not block navigation. Contours are desirable, not a prerequisite for a usable map.

## Maps and offline behavior

MapLibre renders OpenFreeMap areas loaded automatically while moving, panning or zooming out online. Importing a GPX starts preparation of its corridor; existing trails are backfilled at startup. No manual download action is required for each area. A durable queue deduplicates work, retries and preserves completed resources. Offline access includes only received areas. Readiness includes all required map resources, with partial progress and storage/network errors reported honestly.

Preserve the legacy offline-package path and attribution. Maps are device files, not account-sync payloads. Changing phones restores account data, then downloads the necessary maps on that device.

## Planning days

Choose two points interactively on the selected GPX, highlight the portion, then save a numbered day. Support multiple ordered days, edits and deletion. Store distance-along-trail boundaries; use the existing minimum-length validation (10 metres), preserve reverse portions and segment gaps, and disambiguate overlapping passages at different distances. Save through the repository/outbox, not only in widget state.

## Recording, effort and history

Record walks both with and without a GPX. History makes actual visited places easy to see on the map. Live and historical metrics share the same definitions: distance, active/elapsed duration, average pace/speed, GPS maximum speed, ascent/descent and altitude. Missing measurements are not zero or invented watch data.

Persist `RecordWalk` checkpoints locally. Filter inaccurate fixes and jumps; pauses/GPS gaps separate recorded segments. Android foreground location recording and its notification support screen-off walks. Stop following, pause and finish are distinct. Interruption restores a paused recording; completed walks sync to the API, while in-progress checkpoints are local and are not promised to resume on another phone.

"Start a route" replaces the former free-walk button: a walk without a GPX draws itself on the map and, when finished, also becomes a reusable route (named "Route of <date>" in the app language), visible with the other trails and synced like an imported GPX. It is not created when every recorded point stays within 30 m of an existing route (GPS noise, between vertices included); any detour or extension beyond that is a new route. Walks shorter than 50 m stay in history only, and walks guided by a GPX never create a route. The route is saved before the walk is finished, so a retried interrupted finish finds it instead of duplicating it. Pause, resume and finish are available from the map panel as well as history.

## Joining a GPX

There is no separate “join the trail” action. Starting a trail follows it directly when the walker is already on it (within 25 m with a precise fix); otherwise it computes and starts the internal walking approach. If the approach cannot be calculated (offline without a saved route), the trail itself is followed and the distance to it stays visible, with an explicit notice.

The latest request is to join the nearest point on an actual GPX segment, including between vertices, not the file's start. Following direction does not change this joining point. Use a fresh reliable GPS fix and recompute the nearest point on manual recalculation.

The internal pedestrian approach uses the API's Valhalla adapter. Keep its blue route separate from the original green GPX and place the R marker at the real joining point. Validate arrival through GPS/proximity/progression before offering to follow the GPX from there, preserving reverse direction. If routing ends short of the target, display the final unguided gap rather than inventing a traversable connection.

Initial calculation and recalculation require a connection. A saved approach is usable offline within its existing validity criteria. Cache instructions by language so a request for English cannot silently reuse French directions. Avoid routing on every location update; respect provider limits. Public routing is for low-volume use and a dedicated provider can be configured for scale. Turn-by-turn voice guidance applies to the approach route geometry as to any followed route (see below); perpetual automatic rerouting is not currently promised.

Google Maps is an explicit fallback (driving, transit or walking, chosen in Google Maps) offered by the trail panel and receives the same nearest joining point. Show routing privacy information. Historical names referring to “departure” do not override the nearest-point behavior.

## Turn-by-turn guidance

While a GPX or approach route is followed, each direction change is announced about 100 metres ahead, then again when immediate (about 20 metres), including screen-off through the recording foreground service. Turns are detected geometrically inside each GPX segment on the shared distance axis (25-metre bearing windows, at least 35°, classified slight/turn/sharp/U-turn) and mirrored in reverse; segment gaps never create a turn. The next turn is always the one ahead, so a closer turn is announced only after the previous one has been passed. Leaving the trail and reaching the end of the trail or the approach route are also announced; arrival requires real progress so a loop does not announce it at the start.

Voice uses the phone's own Android text-to-speech engine (offline, no paid service) in the app language, with navigation-guidance audio focus that ducks other audio. Voice is a device preference in Settings, on by default. A high-importance notification with a direction pictogram and localized text is posted only while Gpix is not visible; the visible map shows the same instruction in its top card and reopening the app removes the notification. Android 13+ asks for notification permission when navigation starts; refusal leaves voice guidance working. Delivery failures never interrupt tracking. Geometric turns cannot know about unmapped forks, and gradual bends may be announced as slight turns: field validation on real trails is required.

## Kilometre summaries and usual-route comparison

Every recorded kilometre, with or without a GPX, produces a summary. It contains distance walked, active walking time, current speed (over the last kilometre), average speed since the start, and elevation gain when altitudes exist. It also gives the time of day. When a GPX is followed it adds remaining distance and an estimated arrival time at the current average; an approach route has no remaining GPX distance of its own. The voice reads only the items selected in Settings: a device preference, on by default for distance, time, average speed, comparison and remaining distance. It is spoken after any direction change in progress, which always takes priority. The notification lists every available item on its own lower-importance "Kilometre summary" channel, posted only while Gpix is not visible. Missing values are omitted, never spoken as zero. A restored recording resumes counting without inventing a current speed for the interrupted kilometre.

A route walked several times has running statistics stored in the API: number of walks, total distance and active time per GPX. They are updated incrementally when a finished walk syncs, not recomputed. The summary compares the current average speed with the usual one ("0.2 km/h faster than your usual 5.0 km/h") and says how many times the route was walked before. A walk counts for the GPX it followed, or, when free, for the route it created or stayed on (`walk.routeId`). History still labels such a walk as free. Walks under 500 m or 60 active seconds do not count. The app caches statistics after each sync and counts a walk finished offline until the next refresh. A free walk on a route not yet created has no comparison, remaining distance or arrival. The rule and the API contract are described in the API repository's `docs/STATISTICS.md`.

## Watches and health

The user's watch is an Amazfit Active Max with Zepp; support should cover as many compatible models as possible. The path is Zepp → Health Connect → Gpix, subject to actual exports and permissions, not a direct live Bluetooth watch connection.

Use `HealthDataSource` and the Android adapter. Read heart rate, steps and active calories for the walk period only on explicit request. Settings shows install/update requirements, partial permissions and availability. Authorized access does not prove that a watch is connected or that measurements exist. Retain sources and read time, sync imported summaries with the walk, and never fabricate absent data. Permissions are device-specific. Background health reads and Health Connect writes are outside the current scope. Validate physical watch behavior separately from mocked tests.

The earlier phrase “binary ready” was not understood or defined by the user. It is not an accepted Garmin integration or binary-format requirement.

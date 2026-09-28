# Accepted mobile product decisions

## Central map and walking UX

The home screen is the central map. Imported trails are not drawn until selected: each one with a visible portion is marked by a pin. The selected trail alone is drawn and stays drawn while panning or zooming, until another trail is selected or it is closed. User-facing text calls them **trails** (“parcours”), never “GPX”; the file format is only mentioned where a file is picked or rejected. A focused/browsed trail is separate from the actively followed trail.

There is no bottom navigation bar. A menu button at the top left opens a drawer to Trails (the whole catalogue), My trails, History, Offline and Settings; each page has a back action to the map, and Android back returns to the map. My trails is a secondary, searchable list (case- and accent-insensitive) that keeps view, day planning, start and deletion.

Trails are discovered on the map, as in AllTrails. A pin marks each unselected trail with a visible portion (catalogue trails: those the server returns for the visible area, see below) (also while another trail is selected, so the walker can switch; pins are hidden during day planning and active tracking), at the middle of its longest visible portion on the shared distance axis (not its start); segment gaps never join portions. Pins are map layers drawn and clustered by MapLibre itself, as on AllTrails or Airbnb, so hundreds of trails keep the map fluid. Nothing is recomputed while the map moves.

- **Two pin styles, the same on the map, in lists and in the legend.** The walker's trails (imported, created or kept offline) are solid forest green with a white "saved" mark; catalogue trails are white with a purple rim and walker. Both have a white or purple rim and a soft shadow so they read on any background.
- **Length labels.** Each pin carries its trail's length ("4.5 km", "12 km") beneath it wherever there is room; the map hides colliding labels, never pins.
- **Clusters.** Overlapping pins become a counted bubble in the same style, with a soft halo marking it as a group and a size growing with the count. Own and catalogue trails cluster separately. Touching a bubble zooms in until it splits; pins sharing one spot are listed in the bottom panel.
- **List under the map.** While exploring, a draggable sheet lists every trail pinned on screen, nearest to the map centre first, 30 at a time as it scrolls. Lowered, only its bar remains: "N trails in this area", import and start-a-route actions, and the legend. On a first visit, with an empty library, it shows a full import button. Each row repeats the pin, then name, length, ascent when known, reference, rating and a "My trail" or "Offline" tag. When the server capped the area, the end of the list says to zoom in for more. A pin stays where it is while it remains on screen, even when the map moves; only a trail whose pin left the view (or that enters it) gets a new pin when the camera stops. Touching a pin selects its trail (hidden lines are not touch targets): the map fits the whole trail and enters itinerary mode. Its panel starts with the trail's length and ascent; remaining distance and distance to the trail replace them while following.

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

"Start a route" replaces the former free-walk button: a walk without a GPX draws itself on the map and, when finished, also becomes a reusable route. The finish dialog asks for its name, suggesting "Route of <date>" in the app language, and an optional description; the walk in history takes the same name. The route is visible with the other trails and synced like an imported GPX. It is not created when every recorded point stays within 30 m of an existing route (GPS noise, between vertices included); any detour or extension beyond that is a new route. Walks shorter than 50 m stay in history only, and walks guided by a GPX never create a route. The route is saved before the walk is finished, so a retried interrupted finish finds it instead of duplicating it. Pause, resume and finish are available from the map panel as well as history.

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

Steps and active calories are part of the live and history statistics and of the summary (spoken by default):

- **Steps** come from the phone's hardware step counter (`TYPE_STEP_COUNTER`, Activity recognition permission requested when recording starts). It keeps counting screen-off and costs little battery. Only active periods count, and a counter reset after a phone restart continues from the last value. A missing sensor or refused permission leaves steps unknown, never zero.
- **Active calories** are estimated from the recorded track and the moved mass: the walker's weight plus backpack, set in Settings. Oxygen cost per ~100 m comes from speed and slope. Level and uphill ground use the ACSM walking equation, and speeds above 8 km/h the ACSM running equation. Descents use the level cost scaled by Minetti's (2002) gradient-cost ratio. GPS altitudes are smoothed over ±40 m, and stops and GPS gaps add nothing. When no weight is entered, the latest weight another app (e.g. Samsung Health) wrote to Health Connect in the last two years is used. It is read at startup, when a walk starts and after granting access, and it is kept on this phone only, never copied into the account. A weight entered in Gpix always wins. With no weight at all, the estimate is absent and Settings is suggested.
- **Watch measurements** imported from Health Connect replace the phone's steps and estimate in history, while both stay stored on the walk (`walk.steps`, `walk.estimatedCalories`).
- **The walker profile** (weight, backpack) is account data: it is cached in the account database, sent to `/api/profile` at sync, and restored on another phone. The latest saved change wins.

Every spoken announcement (direction or summary) starts with a short synthesized bell, then one second of silence, then the words. All three are queued in the text-to-speech engine, so a direction change still interrupts a summary.

A route walked several times has running statistics stored in the API: number of walks, total distance and active time per GPX. They are updated incrementally when a finished walk syncs, not recomputed. The summary compares the current average speed with the usual one ("0.2 km/h faster than your usual 5.0 km/h") and says how many times the route was walked before. A walk counts for the GPX it followed, or, when free, for the route it created or stayed on (`walk.routeId`). History still labels such a walk as free. Walks under 500 m or 60 active seconds do not count. The app caches statistics after each sync and counts a walk finished offline until the next refresh. A free walk on a route not yet created has no comparison, remaining distance or arrival. The rule and the API contract are described in the API repository's `docs/STATISTICS.md`.

## Watches and health

The user's watch is an Amazfit Active Max with Zepp; support should cover as many compatible models as possible. The path is Zepp → Health Connect → Gpix, subject to actual exports and permissions, not a direct live Bluetooth watch connection.

Use `HealthDataSource` and the Android adapter. Read heart rate, steps and active calories for the walk period only on explicit request. Settings shows install/update requirements, partial permissions and availability. Authorized access does not prove that a watch is connected or that measurements exist. Retain sources and read time, sync imported summaries with the walk, and never fabricate absent data. Permissions are device-specific. Background health reads are outside the current scope. When "Share walks with Health Connect" is on (a device preference, since permissions are per phone), each finished walk is written as one exercise session: walking, or hiking from 100 m of ascent. It includes the recorded route (if the route permission is granted), distance, elevation gain, and the phone's steps and estimated active calories. A walk can also be sent manually from its history page. Values that came from the watch through Health Connect are never written back. Stable client record identifiers make a repeated export an update, not a duplicate. A failed export never loses the walk; it is reported so it can be resent. Validate physical watch behavior separately from mocked tests.

The earlier phrase “binary ready” was not understood or defined by the user. It is not an accepted Garmin integration or binary-format requirement.

## Collaborative trails

Decision of 28 September 2026: every trail is shared. A trail added in any way (GPX import, a route created by a free walk) is stored once on the API and visible to every account; trails already in existing libraries were published by the API migration. Walks, speeds, averages, running statistics, health data and planned days stay private to their owner. My trails states this rule, and deleting a trail only removes the walker's own copy: the shared trail stays visible to others.

A shared trail is identified by its line only (points quantized to about one metre, consecutive duplicates collapsed; names, descriptions, elevations and places ignored). The phone derives the same SHA-256 fingerprint and version 5 identifier as the API, so importing a line already in the library or already shared reuses it instead of creating a duplicate, offline included; the API keeps a unique fingerprint and links any other private copy to the first shared trail, whose name is kept. The reverse direction is another line.

The catalogue of shared trails is never copied to the phone (decision of 28 September 2026, superseding the earlier offline catalogue): see "Trail catalogue" below.

The trail panel shows the average rating (1 to 5 stars), the reviews and who shared the trail. One review per walker and trail, editable and deletable, with an optional comment of at most 2,000 characters. The absolute rule: a walker reviews a trail only after one recorded walk covered at least 90 % of it (within 50 m, either direction; a free walk counts for the route it created). The API checks it against the walker's synced walks, so the phone pushes pending walks before publishing a review and shows the best coverage reached otherwise. Reviews are readable offline from the last copy; writing needs a connection. The API contract is described in the API repository's `docs/PUBLIC_TRAILS.md`.

## Places added on a trail

Decision of 28 September 2026: from where they stand on a trail, a walker adds a place (a viewpoint, a spring, a shelter…) with a name and an optional comment, from the trail panel, including while following the trail. The place takes a fresh precise GPS fix, its real position (never snapped to the line), and must be within 100 m of the trail. Places are shared with every walker like the trail itself, shown on the map with the trail's points, and touching one shows its comment, author and date. Only its author edits or deletes it. Adding, editing and deleting work offline: the change is kept on the phone and sent on the next sync, after the trail itself is shared; a refused change (too far, invalid) is dropped. The API contract is in the API repository's `docs/PUBLIC_TRAILS.md`.

## Points imported onto a trail

Decision of 28 September 2026: a GPX file holding only waypoints (hostels, springs, churches along a Way of St James) becomes a "points file" in the library. Attaching it to a trail turns its points into public places of that trail, shared and synced like the places added on site, so the trail and its points appear together. There is no private grouping of files.

- **Origin.** Every place records whether it was added on site or imported. The place sheet says "Seen on site" or "Imported from a GPX file". An imported place may lie up to 5 km from the line, since a hostel in the village can be off the path; a place added on site stays within 100 m.
- **No duplicates.** A point within 30 m of a place the trail already has, with an equivalent name (case, accents and punctuation ignored), is not added again. The phone checks what it knows; the API checks again and returns the existing place, which replaces the phone's pending copy.
- **Nothing lost.** Points more than 5 km from the trail, or without a name or description, stay in their file, which stays in the library with only those points. A file entirely attached leaves the library. The places and the file change in one local transaction.
- **Importing.** Files chosen together are imported together. When they include points files, the map previews attaching them to the tracks imported with them, or else to the trail with most points within reach. Each point goes to the nearest of these trails.
- **Library.** A points file shows "Not attached to a trail". A banner counts these files and filters the list to them. "Attach to a trail" previews the file on the best trail. A trail's menu offers "Add points", from a GPX file on the phone or from a points file of the library. A trail card shows how many places it has.
- **Preview.** A panel over the map shows the trail, the points that become places (green), those already on the trail (blue) and those that stay in the file (grey). "Change trail" lists the library's trails and the shared trails around the points, ranked by points within reach; a shared trail is downloaded before attaching. Nothing is shared before the walker confirms that the places will be visible to everyone and that they may share them. After attaching, "Undo" withdraws the places and restores the file.
- **Walking.** Imported places are only shown on the map; they are not announced.

A route made of several tracks (stages, variants) uses the existing itinerary groups; the points of a file imported with several tracks go to the nearest one. Creating the group from the import is not automated yet.

## Trail catalogue

Decision of 28 September 2026: besides the trails walkers share, the API acquires trails from open data country by country, starting with the whole of France (OpenStreetMap walking routes, ODbL), then neighbouring countries and the world. Commercial sites are never scraped. The acquisition, groups and search are described in the API repository's `docs/CATALOGUE.md`.

- **Nothing of the catalogue is stored on the phone.** On the map, the phone asks the server for the catalogue trails of the visible area when the camera stops, longest first. Pins are clustered as before. Offline, the last area stays pinned until the app closes, and the walker's own trails are always there. Opening a catalogue trail downloads it into memory only.
- **Colours.** The walker's trails (imported, created by a walk, or made available offline) keep the forest green of pins and lines. Catalogue trails not on the phone are purple, on pins, cluster lists, the selected line and list icons. A pin never mixes both kinds; Trails shows the legend.
- **Offline copies.** A catalogue trail is stored only when the walker taps "Make available offline", or automatically when they start walking it: the trail, its details and its maps' preparation, so guidance survives a lost connection or the app being closed. An offline copy can be removed again, except while it is being walked. It is not a private copy until the walker changes it, for example by planning days. My trails marks such copies.
- **Trails menu.** A drawer entry lists the whole catalogue, searched on the server page by page with infinite scrolling. The search ignores accents and case, reads references without separators ("GR 20" = "gr20"), treats Compostelle, Santiago, Saint-Jacques and Jakobsweg as the same word, tolerates typos, and finds a stage by the names of its groups. Groups come first: editorial collections, then itineraries from sources, then walkers' groups; trails follow.
- **Groups.** An itinerary is ordered (main route, numbered stages, variants, links, excursions, access routes; GR 20, Via Podiensis). A collection is a set of trails or groups in no particular order. Groups nest. The Ways of St James are an editorial collection whose name the app translates. A group page lists its members in order, shows where it belongs and its source, and can make its trails available offline, up to 150. Walkers create their own groups, public at once like trails, from Trails or from a trail's panel ("Add to a group"). Only their author renames, reorders, removes members or deletes them. Creating or changing a group needs a connection. Trails not synced yet are sent first.
- **Trail panel.** Besides reviews, the panel shows:
  - where the trail belongs ("Stage 3 of" Via Podiensis › Ways of St James), with each group opening its page;
  - its reference, waymarks drawn from the OSM symbol and network level;
  - from/to and loop;
  - its description in the app language when the source has one, otherwise as given (never translated);
  - website and Wikipedia links;
  - the licence attribution with a link to OpenStreetMap.
- **History.** A guided walk keeps a simplified line of the trail it followed (`walk.reference`, at most 5,000 points), so history still draws it once the trail is no longer on the phone.


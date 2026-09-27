# Accepted mobile product decisions

## Central map and walking UX

The home screen is the central map. All imported GPX tracks are overlaid without opening a file. My trails provides view/recenter, day planning and Go. Map, My trails, History, Offline and Settings retain distinct roles. A focused/browsed trail is separate from the actively followed trail.

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

## Joining a GPX

The latest request is to join the nearest point on an actual GPX segment, including between vertices, not the file's start. Following direction does not change this joining point. Use a fresh reliable GPS fix and recompute the nearest point on manual recalculation.

The internal pedestrian approach uses the API's Valhalla adapter. Keep its blue route separate from the original green GPX and place the R marker at the real joining point. Validate arrival through GPS/proximity/progression before offering to follow the GPX from there, preserving reverse direction. If routing ends short of the target, display the final unguided gap rather than inventing a traversable connection.

Initial calculation and recalculation require a connection. A saved approach is usable offline within its existing validity criteria. Cache instructions by language so a request for English cannot silently reuse French directions. Avoid routing on every location update; respect provider limits. Public routing is for low-volume use and a dedicated provider can be configured for scale. Voice guidance and perpetual automatic rerouting are not currently promised.

Google Maps is an explicit walking/driving fallback and receives the same nearest joining point. Show routing privacy information. Historical names referring to “departure” do not override the nearest-point behavior.

## Watches and health

The user's watch is an Amazfit Active Max with Zepp; support should cover as many compatible models as possible. The path is Zepp → Health Connect → Gpix, subject to actual exports and permissions, not a direct live Bluetooth watch connection.

Use `HealthDataSource` and the Android adapter. Read heart rate, steps and active calories for the walk period only on explicit request. Settings shows install/update requirements, partial permissions and availability. Authorized access does not prove that a watch is connected or that measurements exist. Retain sources and read time, sync imported summaries with the walk, and never fabricate absent data. Permissions are device-specific. Background health reads and Health Connect writes are outside the current scope. Validate physical watch behavior separately from mocked tests.

The earlier phrase “binary ready” was not understood or defined by the user. It is not an accepted Garmin integration or binary-format requirement.

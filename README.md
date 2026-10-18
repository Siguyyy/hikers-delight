# Hiker's Delight

Hiker's Delight is a focused iPhone map and route-planning app for hiking and mountaineering when service is unreliable or unavailable. The app keeps the useful offline-first ideas from [Organic Maps](https://github.com/organicmaps/organicmaps)—OpenStreetMap data, downloadable map regions, privacy, and GPX tracks—but uses a smaller native SwiftUI product surface designed around the trail.

## Product surface

- **Explore** — modern map-first home screen with quick actions for trails, route planning, and downloads.
- **Plan** — tap-to-place route builder that follows locally loaded OSM trail geometry when available, with distance, waypoints, elevation, save, and GPX export.
- **Saved** — routes stored locally on the iPhone plus GPX import.
- **Offline** — download the visible map area for use without service. Map packs remain managed by MapLibre's offline storage.
- **Hiking layers** — trails, campsites, alpine huts, water, parking, viewpoints, and peaks from OpenStreetMap.

The app intentionally excludes driving navigation, public transit, social feeds, reviews, accounts, ads, and unrelated points of interest. It is an independent implementation; it does not include AllTrails or Organic Maps proprietary assets or databases.

## Data and offline behavior

- Basemap: [OpenFreeMap Liberty](https://tiles.openfreemap.org/styles/liberty), based on OpenMapTiles and OpenStreetMap.
- Trail and outdoor feature refresh: [OpenStreetMap](https://www.openstreetmap.org/) through the [Overpass API](https://overpass-api.de/).
- Elevation: [USGS 3DEP EPQS](https://epqs.nationalmap.gov/v1/docs) for routes in supported regions.
- Route data and downloaded map packs stay on-device. Live OSM refreshes and elevation lookups need a connection.
- The offline downloader limits a visible-area pack to roughly 2,700 tiles so it stays under the provider's 3,000-tile limit.

Map and OSM attribution is shown in the app and must remain with redistributed map data.

## Build locally on macOS

1. Install Xcode and XcodeGen: `brew install xcodegen`.
2. Run `xcodegen generate` from the repository root.
3. Open `HikersDelight.xcodeproj`, choose a signing team, and build the `HikersDelight` target for an iPhone or simulator.

The deployment target is iOS 17.0. MapLibre is pulled from Swift Package Manager by `project.yml`.

## GitHub Actions IPA

Every push to `main` and every pull request runs the macOS build in `.github/workflows/ios.yml` and uploads `hikers-delight-unsigned-ipa`. That package is useful for CI inspection but is not installable until signed.

To produce an installable ad hoc IPA, add these repository Actions secrets:

- `APPLE_CERTIFICATE_P12_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_PROVISIONING_PROFILE_BASE64`
- `APPLE_TEAM_ID`

The provisioning profile must target bundle identifier `com.siguyyy.hikersdelight` and include the destination device UDIDs. Never commit certificates, profiles, or tokens.

## License and upstream note

App source is MIT. MapLibre is BSD-2-Clause. OpenStreetMap/OpenMapTiles data and style terms apply to redistributed map data. The Organic Maps repository is tracked as an architectural reference for offline map UX and OSM-powered hiking features; its source and GPL licensing are not copied into this repository.


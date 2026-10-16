# Trailwise

Trailwise is an iPhone hiking map and route planner built around open map data. The repository was empty when work began; this is the first app scaffold.

## Current MVP scope

- MapLibre vector map using OpenFreeMap styles, with map-style switching.
- OpenStreetMap trail and outdoor point-of-interest overlays for the map area you are viewing. Campgrounds, huts, trail paths, water, parking, peaks, and viewpoints are included when mapped in OSM.
- Tap-to-draw route planning with undo and a distance/elevation profile.
- Elevation samples from the USGS Elevation Point Query Service for U.S. routes.
- Offline map packs for a selected map area, and local storage for saved route data.
- iOS GitHub Actions build. The workflow packages an **unsigned** IPA; it is not installable until signed with an Apple Developer certificate and provisioning profile.

This is an independent open-data app. It does not include AllTrails or Gaia GPS proprietary trail databases, reviews, account features, or map assets. OSM coverage varies; "all campsites" means every matching campsite mapped in OpenStreetMap in the selected area, not a guarantee that every real-world site is present.

## Map and data sources

- Basemap: [OpenFreeMap Liberty](https://tiles.openfreemap.org/styles/liberty), based on OpenMapTiles and OpenStreetMap. The app shows attribution. OpenFreeMap permits mobile offline downloads up to 3,000 tiles or 50 MB per download, with at most 4 concurrent requests. The offline downloader is limited to the currently visible area at hiking detail levels; larger downloads need a separately contracted/self-hosted tile service.
- Trails and campsite/landmark overlays: [OpenStreetMap](https://www.openstreetmap.org/) via the [Overpass API](https://overpass-api.de/). Feature coverage and names depend on OSM contributors. OSM data is licensed under ODbL; attribution is shown in the app.
- Elevation: [USGS 3DEP EPQS](https://epqs.nationalmap.gov/v1/docs). Elevation lookups require a network connection; routes and their last saved profile remain on device.

Offline maps are map-style data only. OSM trail and campsite overlays are refreshed from Overpass when online and are not bundled nationally. Save or export routes before heading offline.

## Build locally on macOS

1. Install Xcode and XcodeGen (`brew install xcodegen`).
2. Run `xcodegen generate` from this directory.
3. Open `Trailwise.xcodeproj`, select the Trailwise target and a signing team, then build to a connected iPhone or device archive.

## GitHub Actions IPA

Each push to `main` runs the macOS build and uploads an unsigned IPA as `trailwise-unsigned-ipa`. To produce an installable ad hoc IPA, add these repository Actions secrets: `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_PROVISIONING_PROFILE_BASE64`, and `APPLE_TEAM_ID`. The certificate must be an Apple Distribution `.p12`; the profile must be an ad hoc profile for `com.siguyyy.trailwise` and include the target device UDIDs. The workflow then also uploads `trailwise-signed-ipa`. Do not commit certificates, provisioning profiles, or tokens to the repository. The unsigned package is for CI inspection and cannot be installed on a physical iPhone.

## License

App source: MIT. MapLibre Native: BSD-2-Clause. Map data attribution and share-alike terms are provided by OpenStreetMap/OpenMapTiles; see the linked provider terms before redistributing map data.


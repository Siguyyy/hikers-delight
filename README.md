# Hiker's Delight

Hiker's Delight is an iPhone map for hiking and mountaineering when service is
unreliable or unavailable. It is built from a pinned checkout of the actual
[Organic Maps](https://github.com/organicmaps/organicmaps) iOS source, not from
a MapLibre demo or a remote-tile mock.

## What is included

- Organic Maps' native offline map renderer and downloaded regional map data.
- Hiking and outdoor map layers enabled by default.
- GPS location, local bookmarks, GPX tracks, route planning, elevation data,
  and Organic Maps' map downloader.
- A reduced hiker-first surface with Explore, Plan, Saved, and Offline actions.
- A full-screen-safe iPhone layout intended to work as a normal IPA and inside
  LiveContainer.

The product layer removes the old Trailwise prototype entirely. It does not
use AllTrails' proprietary data, reviews, account system, or assets. Trail and
place coverage comes from OpenStreetMap and varies by region.

## How the build works

`ORGANIC_MAPS_COMMIT` pins the upstream source revision. GitHub Actions checks
out that revision with its submodules, applies
`scripts/customize_organicmaps.py`, and builds the upstream `OMaps` workspace
with the Hiker's Delight product identifier. The resulting package contains
the actual Organic Maps C++ map/storage core and iOS app target.

This repository deliberately keeps the upstream source fetched at build time
so updates can be reviewed against the upstream revision instead of silently
copying a large generated checkout into this repository.

## Build locally on macOS

```sh
scripts/prepare_organicmaps.sh
```

The script prints the prepared checkout path. From that path, build the
workspace with Xcode:

```sh
xcodebuild build \
  -workspace xcode/omim.xcworkspace \
  -scheme OMaps \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  BUNDLE_IDENTIFIER=com.siguyyy.hikersdelight \
  PRODUCT_BUNDLE_IDENTIFIER=com.siguyyy.hikersdelight
```

The GitHub workflow uploads an **unsigned** IPA. It must be signed with an
Apple certificate and a provisioning profile before a physical iPhone can
install it.

## Licensing

Organic Maps is GPLv3; its source, dependencies, and OpenStreetMap/OpenMapTiles
data terms apply to this derived build. Keep the required attribution and
license notices when redistributing the app.

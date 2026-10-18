#!/usr/bin/env python3
"""Apply the Hiker's Delight product layer to a pinned Organic Maps checkout.

The upstream checkout remains the map and storage engine. This script only makes
the product-specific iOS changes that are intentionally kept outside that engine:
outdoor defaults, a full-screen-safe map surface, and a compact hiker-first UI.
"""

from __future__ import annotations

import pathlib
import sys


def replace_once(path: pathlib.Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"Expected one match in {path}: {count}")
    path.write_text(text.replace(old, new), encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: customize_organicmaps.py <organicmaps-checkout>")

    root = pathlib.Path(sys.argv[1]).resolve()
    map_controller = root / "iphone/Maps/UI/Map/MapViewController.mm"
    overlay_manager = root / "iphone/CoreApi/CoreApi/Traffic/MWMMapOverlayManager.h"
    tab_bar = root / "iphone/Maps/UI/BottomMenu/TabBar/BottomTabBarViewController.swift"
    maps_project = root / "iphone/Maps/Maps.xcodeproj/project.pbxproj"

    if not map_controller.exists() or not overlay_manager.exists() or not tab_bar.exists() or not maps_project.exists():
        raise RuntimeError(f"Not an Organic Maps checkout: {root}")

    # iOS sideloaders require every embedded extension identifier to be nested
    # under the main application identifier. Upstream uses app.organicmaps.*
    # identifiers, which are valid for the upstream app but are rejected when
    # the rebuilt app is com.siguyyy.hikersdelight.
    project_text = maps_project.read_text(encoding="utf-8")
    old_project_text = project_text
    project_text = project_text.replace(
        "PRODUCT_BUNDLE_IDENTIFIER = app.organicmaps.debug.widgetextension;",
        "PRODUCT_BUNDLE_IDENTIFIER = com.siguyyy.hikersdelight.OMapsWidgetExtension;",
    )
    project_text = project_text.replace(
        "PRODUCT_BUNDLE_IDENTIFIER = app.organicmaps.widgetextension;",
        "PRODUCT_BUNDLE_IDENTIFIER = com.siguyyy.hikersdelight.OMapsWidgetExtension;",
    )
    if project_text == old_project_text:
        raise RuntimeError("Could not find Organic Maps widget bundle identifiers")
    maps_project.write_text(project_text, encoding="utf-8")

    replace_once(
        map_controller,
        '#import "MWMMapViewControlsManager.h"\n',
        '#import "MWMMapViewControlsManager.h"\n#import <CoreApi/MWMMapOverlayManager.h>\n',
    )
    replace_once(
        map_controller,
        "@property(nonatomic, readwrite) BOOL isMapVisible;\n",
        """@property(nonatomic, readwrite) BOOL isMapVisible;
@property(nonatomic, strong) UIView * hikersHeader;
@property(nonatomic, strong) UIView * hikersBottomBar;
""",
    )
    replace_once(
        map_controller,
        "- (void)viewDidLoad\n{\n  [super viewDidLoad];\n  [self setupPlacePageContainer];\n",
        """- (void)viewDidLoad
{
  [super viewDidLoad];
  [MWMMapOverlayManager setOutdoorEnabled:YES];
  [MWMMapOverlayManager setHikingEnabled:YES];
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  [self setupPlacePageContainer];
""",
    )
    replace_once(
        map_controller,
        "  [self setupPlacePageContainer];\n  [self setupSearchContainer];\n",
        """  [self setupPlacePageContainer];
  [self setupSearchContainer];
  [self setupHikersInterface];
""",
    )
    replace_once(
        map_controller,
        "#pragma mark - Open controllers\n",
        r'''#pragma mark - Hiker's Delight surface

- (UIButton *)hikersButtonWithTitle:(NSString *)title symbol:(NSString *)symbol
{
  UIButton * button = [UIButton buttonWithType:UIButtonTypeSystem];
  [button setTitle:title forState:UIControlStateNormal];
  [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
  button.tintColor = UIColor.labelColor;
  button.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
  button.titleLabel.adjustsFontSizeToFitWidth = YES;
  button.titleLabel.minimumScaleFactor = 0.75;
  button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.92];
  button.layer.cornerRadius = 20;
  button.layer.masksToBounds = YES;
  button.translatesAutoresizingMaskIntoConstraints = NO;
  return button;
}

- (void)hikersSearch
{
  [self performAction:@"app.organicmaps.3daction.search"];
}

- (void)hikersPlan
{
  [self performAction:@"app.organicmaps.3daction.route"];
}

- (void)hikersSaved
{
  [self performAction:@"app.organicmaps.3daction.bookmarks"];
}

- (void)hikersDownloads
{
  [self openMapsDownloader:MWMMapDownloaderModeAvailable];
}

- (void)setupHikersInterface
{
  self.controlsManager.tabBarController.isHidden = YES;

  UIView * header = [[UIView alloc] init];
  header.translatesAutoresizingMaskIntoConstraints = NO;
  header.backgroundColor = [UIColor colorWithWhite:1 alpha:0.94];
  header.layer.cornerRadius = 22;
  header.layer.shadowColor = UIColor.blackColor.CGColor;
  header.layer.shadowOpacity = 0.14;
  header.layer.shadowRadius = 14;
  header.layer.shadowOffset = CGSizeMake(0, 5);
  self.hikersHeader = header;

  UILabel * eyebrow = [[UILabel alloc] init];
  eyebrow.text = @"HIKER'S DELIGHT";
  eyebrow.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBlack];
  eyebrow.textColor = [UIColor colorWithRed:0.13 green:0.40 blue:0.25 alpha:1];
  eyebrow.translatesAutoresizingMaskIntoConstraints = NO;

  UILabel * title = [[UILabel alloc] init];
  title.text = @"Find your next line";
  title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
  title.textColor = UIColor.labelColor;
  title.translatesAutoresizingMaskIntoConstraints = NO;

  UIButton * search = [UIButton buttonWithType:UIButtonTypeSystem];
  [search setImage:[UIImage systemImageNamed:@"magnifyingglass"] forState:UIControlStateNormal];
  search.tintColor = UIColor.labelColor;
  search.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
  search.layer.cornerRadius = 18;
  search.translatesAutoresizingMaskIntoConstraints = NO;
  [search addTarget:self action:@selector(hikersSearch) forControlEvents:UIControlEventTouchUpInside];

  [self.view addSubview:header];
  [header addSubview:eyebrow];
  [header addSubview:title];
  [header addSubview:search];
  [NSLayoutConstraint activateConstraints:@[
    [header.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
    [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14],
    [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14],
    [header.heightAnchor constraintEqualToConstant:66],
    [eyebrow.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
    [eyebrow.topAnchor constraintEqualToAnchor:header.topAnchor constant:11],
    [title.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
    [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:1],
    [search.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-10],
    [search.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
    [search.widthAnchor constraintEqualToConstant:36],
    [search.heightAnchor constraintEqualToConstant:36]
  ]];

  UIView * bottom = [[UIView alloc] init];
  bottom.translatesAutoresizingMaskIntoConstraints = NO;
  bottom.backgroundColor = [UIColor colorWithWhite:1 alpha:0.94];
  bottom.layer.cornerRadius = 25;
  bottom.layer.shadowColor = UIColor.blackColor.CGColor;
  bottom.layer.shadowOpacity = 0.16;
  bottom.layer.shadowRadius = 16;
  bottom.layer.shadowOffset = CGSizeMake(0, -3);
  self.hikersBottomBar = bottom;

  UIStackView * actions = [[UIStackView alloc] init];
  actions.axis = UILayoutConstraintAxisHorizontal;
  actions.alignment = UIStackViewAlignmentCenter;
  actions.distribution = UIStackViewDistributionFillEqually;
  actions.spacing = 8;
  actions.translatesAutoresizingMaskIntoConstraints = NO;

  UIButton * plan = [self hikersButtonWithTitle:@"Plan" symbol:@"point.topleft.down.curvedto.point.bottomright.up"];
  UIButton * saved = [self hikersButtonWithTitle:@"Saved" symbol:@"bookmark.fill"];
  UIButton * offline = [self hikersButtonWithTitle:@"Offline" symbol:@"arrow.down.circle.fill"];
  [plan addTarget:self action:@selector(hikersPlan) forControlEvents:UIControlEventTouchUpInside];
  [saved addTarget:self action:@selector(hikersSaved) forControlEvents:UIControlEventTouchUpInside];
  [offline addTarget:self action:@selector(hikersDownloads) forControlEvents:UIControlEventTouchUpInside];
  [actions addArrangedSubview:plan];
  [actions addArrangedSubview:saved];
  [actions addArrangedSubview:offline];
  [self.view addSubview:bottom];
  [bottom addSubview:actions];
  [NSLayoutConstraint activateConstraints:@[
    [bottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14],
    [bottom.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14],
    [bottom.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
    [bottom.heightAnchor constraintEqualToConstant:58],
    [actions.leadingAnchor constraintEqualToAnchor:bottom.leadingAnchor constant:8],
    [actions.trailingAnchor constraintEqualToAnchor:bottom.trailingAnchor constant:-8],
    [actions.topAnchor constraintEqualToAnchor:bottom.topAnchor constant:7],
    [actions.bottomAnchor constraintEqualToAnchor:bottom.bottomAnchor constant:-7]
  ]];
  [self.view bringSubviewToFront:header];
  [self.view bringSubviewToFront:bottom];
}

#pragma mark - Open controllers
''',
    )

    replace_once(
        tab_bar,
        "class BottomTabBarViewController",
        """import UIKit

class BottomTabBarViewController""",
    )
    replace_once(
        tab_bar,
        "    view.alpha = 0 // Hide the view until it receives a first available area update.\n",
        """    view.alpha = 0 // Hide the view until it receives a first available area update.
    view.backgroundColor = .clear
    view.layer.cornerRadius = 26
    view.layer.shadowColor = UIColor.black.cgColor
    view.layer.shadowOpacity = 0.14
    view.layer.shadowRadius = 14
    view.layer.shadowOffset = CGSize(width: 0, height: 4)
""",
    )


if __name__ == "__main__":
    main()


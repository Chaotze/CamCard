# app-shell

## Purpose

Defines the app entry point, root window container, and the Home surface exactly as it exists in the current project skeleton: a single SwiftUI screen with placeholder content and no navigation.

## Requirements

### Requirement: App launches into the Home surface

The app SHALL launch into a single Home surface that occupies the whole app window.

#### Scenario: Cold launch

- **WHEN** the app is launched on a fresh install
- **THEN** the Home surface is the root screen and no modal, sheet, onboarding, or permission prompt is presented

#### Scenario: Relaunch

- **WHEN** the app is terminated and launched again
- **THEN** the Home surface is shown as the root screen again

### Requirement: Home surface content

The Home surface SHALL show only placeholder content: a globe symbol above the text "Hello, world!", centered in the window.

#### Scenario: Welcome content

- **WHEN** the user opens the Home surface
- **THEN** a globe icon and the text "Hello, world!" are displayed centered on screen

### Requirement: App shell navigation scope

The app shell SHALL expose exactly one screen with no navigation bar, tab bar, toolbar actions, detail routes, or secondary surfaces.

#### Scenario: Navigation affordances

- **WHEN** the user interacts with the Home surface
- **THEN** no navigation bar, tab bar, toolbar action, list, camera entry, or detail route is available

### Requirement: Supported orientations

The app SHALL support portrait, landscape left, and landscape right on iPhone, and all four orientations on iPad.

#### Scenario: Rotation keeps content visible

- **WHEN** the device rotates to a supported orientation
- **THEN** the Home surface remains visible and its placeholder content stays centered

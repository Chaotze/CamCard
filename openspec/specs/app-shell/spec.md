# app-shell

## Purpose

Defines the app entry point, root window container, and the Home surface exactly as it exists in the current project skeleton: a single SwiftUI screen with placeholder content and no navigation.

## Requirements

### Requirement: App launches into the Home surface

The app SHALL launch into a single Home surface that occupies the whole app window and presents the card holder.

#### Scenario: Cold launch

- **WHEN** the app is launched on a fresh install with no saved cards
- **THEN** the Home surface is the card holder showing its empty state, with no modal, sheet, onboarding, or permission prompt presented

#### Scenario: Relaunch

- **WHEN** the app is terminated and launched again after cards were saved
- **THEN** the Home surface shows the card holder with those saved cards in the same order as before termination

### Requirement: Home surface content

The Home surface SHALL present the card holder: a card list when cards exist, and an empty state with a title, explanation, "拍摄名片" and "从相册导入" actions when no cards exist. The placeholder globe and "Hello, world!" text SHALL no longer appear.

#### Scenario: Welcome content

- **WHEN** the user opens the Home surface with no saved cards
- **THEN** the empty card holder is shown, and neither the globe icon nor the text "Hello, world!" is displayed

#### Scenario: Welcome content with saved cards

- **WHEN** the user opens the Home surface with saved cards
- **THEN** the card list is shown instead of the empty state, with no placeholder content mixed into the list

### Requirement: App shell navigation scope

The app shell SHALL provide navigation limited to the card slice: the card holder, the capture entry, the processing and verification flow, and the card detail and edit surfaces. It SHALL NOT expose tabs, panels, or routes for registration, membership, subscription, ads, cloud sync, team library, CRM sync, digital business card design, QR exchange, email signature, AI company intelligence, or meeting recording.

#### Scenario: Navigation affordances

- **WHEN** the user interacts with the Home surface
- **THEN** search, tag filtering, sort, capture, and photo import are reachable, while no out-of-scope feature entry is available

#### Scenario: Slice-only navigation

- **WHEN** the user navigates the app from launch to export
- **THEN** every reachable surface belongs to the ten-feature card slice

#### Scenario: Capture flow is reachable from Home

- **WHEN** the user triggers capture or photo import from the Home surface
- **THEN** the processing then verification flow is presented as a navigation destination over the card holder, and the user returns to the card holder after save or abandon

#### Scenario: Detail opens over the card holder

- **WHEN** the user taps a card row
- **THEN** the detail surface is pushed over the card holder, and back navigation returns to the same list state

### Requirement: Supported orientations

The app SHALL support portrait, landscape left, and landscape right on iPhone, and all four orientations on iPad, including during capture, verification, detail, and card holder use.

#### Scenario: Rotation keeps content visible

- **WHEN** the device rotates to a supported orientation while the card holder, verification, or detail surface is open
- **THEN** the current surface remains visible with its content laid out within the screen

#### Scenario: Capture uses the camera orientation

- **WHEN** the user captures a card in a supported landscape orientation
- **THEN** the resulting image is processed without orientation loss and the detail surface remains usable after rotation

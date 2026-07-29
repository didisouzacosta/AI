# Apple Platform Engineering Rules

These instructions apply to the entire repository. They define a reusable baseline for Xcode application projects targeting iOS, macOS, or both.

## Contract and precedence

- Treat this file as the repository-wide engineering contract.
- Project-specific instructions may extend this contract through explicitly referenced rule documents or more deeply nested `AGENTS.md` files.
- A nested `AGENTS.md` applies only to its directory subtree. When instructions conflict, the more specific nested instruction wins within that scope.
- Arbitrary Markdown files are not automatically part of this contract. Read them only when this file, a scoped `AGENTS.md`, or a direct instruction explicitly references them.
- Direct system, developer, and user instructions take precedence over repository instruction files.
- When a project-specific rule intentionally overrides this baseline, document the scope and reason clearly.

## Mandatory workflow

- Classify every Swift task before editing and state which relevant skill is being used.
- Use `swiftui-expert-skill` for every SwiftUI implementation, refactor, and review.
- For iOS and shared Apple-platform SwiftUI work:
  - Use `build-ios-apps:swiftui-ui-patterns` for navigation, state ownership, layout, controls, and component composition.
  - Use `build-ios-apps:swiftui-view-refactor` for every interface implementation or structural refactor.
  - Use `build-ios-apps:swiftui-liquid-glass` to audit every interface implementation or refactor for correct iOS 26 design-system behavior.
  - Use `build-ios-apps:swiftui-performance-audit` for performance work, beginning with a code-first audit.
  - Use the capabilities provided by the [@build-ios-apps](plugin://build-ios-apps@openai-curated-remote) plugin for Xcode, Simulator, build, test, debug, and profiling workflows.
- For macOS SwiftUI work:
  - Use the [@Build macOS Apps](plugin://build-macos-apps@openai-curated-remote) plugin.
  - Use `build-macos-apps:swiftui-patterns` for scenes, windows, commands, toolbars, settings, split views, and inspectors.
  - Use `build-macos-apps:view-refactor` for interface implementation and structural refactors.
  - Use `build-macos-apps:liquid-glass` to audit interfaces for native macOS materials and Liquid Glass behavior.
  - Use `build-macos-apps:appkit-interop` only when SwiftUI cannot express a required desktop behavior cleanly.
  - Use `build-macos-apps:build-run-debug` for macOS build, launch, debug, and runtime validation.
- This contract's MVVM rules override any selected skill's default preference for MV or view-owned feature logic.
- Use App Intents guidance only for Siri, Shortcuts, Spotlight, widgets, controls, or other system surfaces.
- Always use the [@github](plugin://github@openai-curated-remote) plugin for GitHub operations, including repositories, issues, pull requests, reviews, comments, checks, and releases.
- Before starting a spec, explain in simple language its objective, expected changes, user-visible impact, main risks, and expected result.
- After finishing a spec, explain in simple language what changed, how it was validated, residual risks, and the next step.

## Spec execution workflow

- Execute each spec directly in the active task. Do not create or delegate work to sub-agents.
- Before implementing architecture, concurrency, security, cryptography, media pipelines, performance, persistence, networking, migrations, or other high-risk state transitions, perform a sequential technical preflight.
- A technical preflight must freeze the scope, data flow, invariants, ownership, queue and buffer limits, lifecycle transitions, failure behavior, required TDD cases, expected files, validation commands, and completion criteria.
- Skip the preflight for documentation-only, organization-only, purely visual, or straightforward low-risk changes unless uncertainty could materially change the implementation.
- Implement against the frozen contract. If implementation reveals a necessary contract change, stop and update the preflight before continuing.
- Complete self-review and validation against the current diff before requesting review or publishing changes.
- A new implementation change invalidates any earlier review verdict. Review the complete current state again.
- Do not commit, push, create a pull request, publish a release, or otherwise mutate remote state unless the user explicitly requests it.

## Platform baseline and modern APIs

- Use Swift 6 language mode with strict concurrency checking.
- Every project must explicitly declare its deployment targets.
- For a new application without an explicitly requested compatibility target, default to iOS 26 and/or macOS 26 as applicable.
- Use the latest stable Xcode toolchain and SDK compatible with the project's declared targets. Do not adopt beta-only APIs unless the user explicitly requests a beta target.
- Always use the newest stable, non-deprecated API available to the declared deployment targets.
- Never introduce a deprecated API. When editing nearby legacy code, replace deprecated usage within the safe scope of the task.
- Before choosing an API or compatibility strategy, inspect the effective minimum target of every affected app, extension, framework, and package target.
- Use availability checks and fallback implementations only when an affected target can actually run on an earlier OS version.
- Do not add defensive `#available` branches, legacy alternatives, duplicate code paths, or visual fallbacks when the effective minimum target already provides the selected API.
- When targets differ, place compatibility handling at the narrowest shared boundary instead of scattering checks throughout Views.
- Prefer modern SwiftUI APIs, including `@Observable`, `foregroundStyle`, `NavigationStack`, typed `navigationDestination`, the modern `Tab` API, `.sheet(item:)`, modern `onChange`, format styles, and `.scrollIndicators`.
- Prefer `Button` to tap gestures when the interaction is a button. Use gestures only when gesture-specific data or behavior is required.
- Build layouts without `GeometryReader` whenever possible. Treat it as a last resort after container-relative sizing, layout containers, `visualEffect`, and other modern APIs cannot satisfy a necessary requirement.
- Do not use `UIScreen.main.bounds`, fixed screen assumptions, or iPhone-specific navigation patterns in shared or macOS code.

## Required project structure

Xcode application projects must use this filesystem-backed structure:

```text
<ProjectRoot>/
├── Resources/
│   ├── Assets.xcassets
│   ├── Localization/
│   ├── Fonts/
│   ├── Audio/
│   ├── Video/
│   └── Preview Content/
├── Sources/
│   ├── App/
│   │   ├── <AppName>App.swift
│   │   ├── AppRouter.swift
│   │   └── AppContainer.swift
│   ├── Core/
│   │   ├── Data/
│   │   ├── Helpers/
│   │   ├── Integrations/
│   │   ├── Managers/
│   │   ├── Network/
│   │   ├── Persistence/
│   │   ├── Platform/
│   │   └── Services/
│   └── Features/
│       └── <FeatureName>/
│           ├── <FeatureName>View.swift
│           ├── <FeatureName>ViewModel.swift
│           └── Components/
└── Tests/
    ├── Core/
    └── Features/
        └── <FeatureName>/
```

- `Resources/` contains bundled non-source assets only: asset catalogs, images, localization catalogs, fonts, audio, video, bundled data files, and preview resources.
- `Sources/App/` contains the app entry point, root composition, dependency graph, cross-feature routing, app lifecycle integration, and global configuration.
- `Sources/Core/` contains reusable application infrastructure and shared operational behavior:
  - `Data/` contains shared domain values, DTOs, repository protocols, and data mapping primitives.
  - `Helpers/` contains small, cohesive, stateless utilities that are genuinely reused.
  - `Integrations/` contains adapters around third-party packages and external SDKs.
  - `Managers/` contains injected coordinators for shared resource or lifecycle ownership.
  - `Network/` contains transport primitives, endpoint descriptions, request construction, response decoding, and network client implementations.
  - `Persistence/` contains SwiftData models, versioned schemas, migration plans, configurations, and container construction.
  - `Platform/` contains narrow iOS- or macOS-specific implementations.
  - `Services/` contains shared application operations and service implementations.
- `Sources/Core/` is not a miscellaneous folder. Keep feature-specific code inside its feature until it becomes a stable, genuinely shared abstraction.
- `Sources/Features/` organizes presentation code by product capability, such as `Home`, `Profile`, or `SignIn`.
- Every feature folder must contain its main View, its ViewModel, and a `Components/` folder.
- A feature may add narrowly scoped presentation models or support types when needed, but it must not hide shared infrastructure or third-party integration code.
- `Tests/` mirrors the production `Core/` and `Features/` organization.
- Swift Packages must preserve SwiftPM's required target layout while maintaining the same logical boundaries inside each target.
- Organize Xcode project content with filesystem-backed folders using `PBXFileSystemSynchronizedRootGroup`, never virtual `PBXGroup` content folders.
- Only Xcode-required structural containers such as the root `mainGroup`, `Products`, and SDK or package reference containers may remain groups because they do not represent project content.

## MVVM, ownership, and dependency injection

- MVVM is mandatory for screens and behavioral components.
- A screen or component that owns state, performs an action, handles a gesture, starts asynchronous work, transforms data, or makes a decision must have a dedicated ViewModel.
- A purely visual leaf View may receive ready-to-render values and callbacks without a ViewModel.
- Views must not contain business logic or access services, managers, persistence, repositories, database abstractions, network clients, or third-party SDKs.
- Views must not create a ViewModel or any of its dependencies.
- ViewModels own presentation state, user actions, validation, data transformation, and coordination with injected service and repository abstractions.
- Use `@Observable` for new ViewModels and shared observable state. Isolate UI-facing ViewModels to `@MainActor`.
- The composition root creates long-lived dependencies and feature graphs through a required app-level dependency container named `AppContainer`.
- `AppContainer` owns production dependency construction and creates or supplies the ViewModels required by each feature.
- Cross-feature navigation belongs to a required app-level Router named `AppRouter`, exposed through an `AppRouting` abstraction.
- Views and ViewModels navigate only through the routing abstraction. They never instantiate destination Views or destination ViewModels.
- Only the root composition View may observe the concrete Router, and it may render only the route state supplied by that Router.
- Services, repositories, managers, helpers with dependencies, persistence implementations, and third-party adapters must be injected.
- Do not hide dependencies in convenience initializers, default production arguments, service locators, or global singletons.
- Prefer initializer injection. Use environment injection only for dependencies that are truly shared by the active view hierarchy.

## Navigation and action placement

- Use `NavigationStack` for every stack-based navigation flow. Never use `NavigationView`, destination-based `NavigationLink` initializers, ad hoc boolean navigation, or manual root-View swapping.
- Use typed route values and `navigationDestination(for:)`.
- `AppRouter` owns the navigation path, presented routes, route transitions, and cross-feature navigation decisions.
- `AppContainer` owns dependency construction and supplies `AppRouter`, routing abstractions, services, repositories, and feature ViewModels.
- The root composition View binds `NavigationStack(path:)` to the route state owned by `AppRouter` and resolves destinations from typed routes.
- Feature Views and ViewModels request navigation only through `AppRouting`. They do not mutate a `NavigationPath` directly.
- Keep route state explicit and stable for each navigation domain, including independent paths for tabs or windows when the product requires them.
- On macOS and regular-width interfaces, `NavigationSplitView` may be the native structural container for sidebar-detail or inspector layouts. Use `NavigationStack` inside the relevant column whenever that column supports deeper stack navigation.
- Add primary screen actions with the `.toolbar` modifier and semantic `ToolbarItem` placements.
- Use platform-appropriate toolbar placements. On iOS, top and bottom bar placements may be used as appropriate; on macOS, preserve native toolbar, command, and window conventions.
- Never recreate primary action chrome as a custom header, footer, top bar, bottom bar, overlay, or fixed `HStack`.
- Semantic content headers and footers, such as `Section` labels or explanatory text, are allowed when they describe content rather than duplicate navigation or primary actions.
- Use `.safeAreaInset(edge:)` for non-toolbar content that must remain attached to the top or bottom safe area while scrollable content moves behind or alongside it.
- Do not simulate safe-area accessories with hard-coded padding, manual safe-area measurements, or a `ZStack` overlay that obscures scrollable content.
- A persistent custom top or bottom accessory must have a content-specific reason, such as a composer, playback control, or status surface. Primary actions still belong in `.toolbar`.
- Every `Button` must make its entire visible bounds interactive, not only its text or icon.
- Build the Button label so its padding, frame, and shape define the full hit region. Use `contentShape` when a custom label does not naturally expose the intended interactive shape.
- On touch platforms, meet the minimum comfortable hit target. On macOS, preserve the appropriate native control size and pointer behavior.
- Do not attach `onTapGesture` to a styled container to imitate a Button.

## Concurrency

- Prefer actor isolation over locks for shared mutable state.
- Use an `actor` when a service, repository, cache, manager, or coordinator owns mutable state accessed across concurrency domains.
- Keep UI-facing state and actions on `MainActor`.
- Prefer structured concurrency, child tasks, task groups, and automatic cancellation.
- Avoid `Task.detached`, unstructured fire-and-forget tasks, unchecked `Sendable` conformances, and manual thread hopping unless a documented requirement makes them necessary.
- Values crossing isolation boundaries must be safely `Sendable`.
- Do not hold a lock across suspension points or use blocking synchronization from asynchronous code.
- `NSLock` or another lock is allowed only for a proven synchronous or low-level constraint that actor isolation cannot satisfy. Document the reason, protected invariant, ownership, and validation.
- Never choose a lock only to avoid designing correct isolation.

## Persistence and SwiftData

- Use SwiftData whenever the application requires local persistent model storage.
- Hide SwiftData behind injected repository protocols. Views must not use `@Query`, `ModelContext`, or `ModelContainer` directly.
- Keep all SwiftData implementation details in `Sources/Core/Persistence/`.
- Create a dedicated persistence container and configuration boundary rather than constructing containers throughout the app.
- Define a `VersionedSchema` from the first persisted release and a `SchemaMigrationPlan` that records schema evolution.
- Treat schema changes as migrations. Never edit a released schema in place without a new version.
- Build migration and repository behavior with TDD, including migration-path and failure cases.
- Provide deterministic in-memory configurations for unit tests and previews.
- Create production containers in the composition root and inject repositories or persistence abstractions downstream.
- Use another persistence technology only when an explicit product or platform requirement makes SwiftData unsuitable and the user approves the exception.

## Third-party packages

- Import a third-party package only inside its dedicated adapter boundary under `Sources/Core/Integrations/<PackageName>/`.
- Expose local protocols, errors, and value types from the adapter. Do not leak third-party types into App, Features, domain values, ViewModels, or Views.
- App, Core consumers, and Features depend on the local abstraction, never directly on the package.
- Construct and inject the concrete adapter from the composition root.
- Keep package-specific configuration, mapping, error translation, and lifecycle handling inside the adapter.
- System frameworks are not third-party packages and do not require artificial wrappers, but their stateful or side-effecting APIs must still respect architecture and injection rules.

## View and component rules

- Keep exactly one primary `View` type per source file.
- A secondary View may remain in the same file only when it is `private`, stateless, action-free, used once by that primary View, and represents a trivial visual accessory.
- Move every non-trivial composition, reusable element, independently meaningful section, stateful element, or behavioral element into its own file under the feature's `Components/` folder.
- A component file follows the same ViewModel and preview requirements as a screen.
- All View stored and computed properties are `private` unless a real external API requires broader visibility.
- `body` may read UI-ready values prepared by the ViewModel and call named ViewModel actions.
- Do not place ternaries, comparisons, optional fallbacks, formatting, filtering, sorting, `Binding(get:set:)`, service calls, or business decisions inline in a component declaration.
- Prefer a UI-ready ViewModel property. When adaptation is exclusively visual, use a descriptively named private computed property on the View.
- Localized `if` or `switch` composition is allowed only when it renders an already prepared presentation state and does not perform a business decision.
- Prefer modifiers and stable containers over swapping the root View hierarchy.
- Keep `body` pure, small, stable, and free of side effects, object construction, and heavy derived work.
- Button, gesture, task, lifecycle, refresh, and change handlers call named ViewModel actions or injected leaf-component callbacks. Do not embed non-trivial logic in closures.
- Primary View actions must be surfaced through `.toolbar` rather than custom action headers or footers.
- Use `.safeAreaInset(edge:)` for persistent content accessories that are not toolbar actions and must participate correctly in safe-area layout.
- Use `@State` only for private, view-owned visual value state. Never use it to store an injected ViewModel or dependency, and do not use it as a computation cache.
- Use `@Binding` only when a child must mutate parent-owned value state and `@Bindable` when an injected `@Observable` needs bindings.
- Prefer dedicated View types over large computed `some View` properties or `@ViewBuilder` helpers.
- Never use `AnyView` to work around composition or type-design problems.
- Use stable identity in `ForEach`. Never use collection indices as identity for dynamic data.
- Precompute filtered, sorted, or formatted presentation data outside `body`.
- Use relative and adaptive layouts that work across supported window, device, orientation, Dynamic Type, and accessibility configurations.

## Preview rules

- Every View and component source file must include functional `#Preview` declarations without a surrounding `#if DEBUG`.
- Cover every meaningful state that applies, including loading, empty, content, error, disabled, selected, and permission-denied states.
- Do not create redundant previews for meaningless combinations of state.
- Give preview scenarios descriptive names and keep their fixtures deterministic.
- Every preview suite must declare at least one `@Previewable @State` value.
- Use preview-safe dependencies and in-memory persistence.
- A preview must not require network access, production credentials, camera hardware, persistent user data, or another external side effect.
- Do not force a background or padding from the preview block. The View must define its own intended presentation.

## Liquid Glass and platform design

- Audit every SwiftUI interface implementation and refactor with the applicable Liquid Glass skill.
- Prefer standard SwiftUI structures and controls, which receive native platform styling automatically.
- When the effective minimum target supports Liquid Glass, prefer native glass and glass-prominent styles over legacy bordered, custom material, or hand-built translucent styles.
- Prefer `.glass` for standard eligible actions and `.glassProminent` for the primary action when hierarchy calls for emphasis.
- Toolbar and other standard system controls may already receive native glass treatment. Do not stack a redundant custom `glassEffect` on top of system-provided styling.
- Custom glass must still serve hierarchy, interaction, or product design; do not cover ordinary content surfaces with decorative glass.
- Prefer native `glassEffect`, `GlassEffectContainer`, and glass button styles over custom blur implementations.
- Apply custom glass after layout and appearance modifiers.
- Wrap nearby custom glass elements in one `GlassEffectContainer`.
- Use interactive glass only for elements that actually respond to touch, pointer, or focus.
- Use `glassEffectID` with a local namespace only for intentional morphing transitions.
- If an affected target's effective minimum version predates Liquid Glass, provide one availability-gated native fallback at the narrowest boundary. Do not add a fallback when every affected target already supports Liquid Glass.
- On macOS, preserve native sidebars, toolbars, sheets, inspectors, search placement, pointer behavior, keyboard access, commands, window semantics, and system materials.
- Do not force iPhone navigation, tab, search, or touch interaction patterns onto macOS.

## Performance

- Start performance work with a code-first audit before collecting runtime traces.
- Classify the symptom: slow rendering, janky scrolling, high CPU, memory growth, hangs, or excessive invalidation.
- Inspect observation scope, state fan-out, list identity, layout complexity, image decoding, animation scope, and main-actor work.
- Pass only the values a child View needs.
- Keep expensive transformation, decoding, sorting, filtering, and formatting out of `body`.
- Use lazy containers for large collections and stable identity for every dynamic element.
- Downsample large images before rendering and never perform image decoding synchronously on the main actor.
- Avoid deep layout hierarchies, excessive preference propagation, broad animations, and frequent ungated geometry updates.
- When code review is inconclusive, capture the smallest relevant Instruments or ETTrace evidence and compare the same interaction before and after the fix.

## Testing and Simulator policy

- Use TDD for every behavior change: add a failing unit test, implement the smallest production change, make the test pass, then refactor.
- Test ViewModels, services, repositories, adapters, migrations, state machines, and pure transformations.
- Never create or run View tests, UI tests, XCUITest, `XCUIApplication`, element queries, snapshot tests, rendered-view assertions, UI hierarchy inspection, or automated screenshots.
- Do not add artificial tests for documentation-only, organization-only, or purely visual changes. Validate them with static review, previews when applicable, and a non-launching build.
- The iOS Simulator or a macOS test destination may be used for unit tests, non-UI debugging, and profiling.
- Use a Simulator by default for iOS behavior. Use a physical device only for end-user validation or behavior that inherently requires device-only hardware.
- Keep DerivedData and package caches in writable temporary directories when the environment requires it.
- For `xcodebuild test`, validate the generated `.xcresult` with `xcresulttool` or an equivalent structured result reader.
- A test run is Green only when the structured result reports zero failures and zero unexpected failures.
- Treat every new compiler or test warning as a failure unless it is proven to be preexisting or environmental and documented.
- Before review, derive the changed-file list from the actual base-to-HEAD diff and ensure documentation, validation results, warnings, and reviewable revision match the current state.

## Swift organization

- Use the following exact `// MARK: -` names and ordering.
- Views use, when applicable: `Environments`, `Bindables`, `Bindings`, `App Storage`, `Scene Storage`, `Focus State`, `Gesture State`, `Namespaces`, `States`, `Public Properties`, `Body`, `Private Properties`, `Initializer`, `Public Methods`, `Private Methods`.
- Non-View types use, when applicable: `Public Properties`, `Private Properties`, `Initializer`, `Public Methods`, `Private Methods`.
- Every stored property wrapper must be directly preceded by its matching View `// MARK: -` section. For example, `@Environment` uses `Environments`, `@Bindable` uses `Bindables`, `@Binding` uses `Bindings`, and `@State` or `@StateObject` uses `States`.
- If a local `@Bindable` is required inside `body`, place `// MARK: - Bindables` immediately before it in that scope.
- Omit empty sections, but never reorder or rename applicable sections.
- Every explicit initializer uses an unlabeled first parameter.
- Default callbacks and implementation details to `private`; expose only real API.
- Use exactly one blank line before and after every `// MARK: -` declaration, even when it is the first or last item in its scope.
- Keep exactly one blank line at the start and end of each nonempty type, initializer, and function declaration when that boundary is adjacent to another declaration or `// MARK: -` section.
- Do not introduce a blank line solely inside an otherwise single-expression declaration.
- Prefer Swift's implicit return for a single-expression property, closure, subscript getter, or function.
- When an explicit `return` is required after preceding work or control flow in the same scope, place exactly one blank line immediately before it.
- Do not add a blank line before a `return` that is the sole statement inside an `if`, `guard`, `switch`, loop, `do`, `catch`, or `defer` block.
- Use exactly one blank line before and after every `guard`, `if`, `switch`, loop, `do`, `catch`, and `defer` declaration only when another nonblank code line exists before or after it in the same scope.
- Keep consecutive stored `let` and `var` properties in one contiguous group within the same visibility or property-wrapper section.
- Except for required declaration spacing, do not add a blank line immediately after an opening brace or immediately before a closing brace.
- Write empty scopes as `{}`.

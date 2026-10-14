# Service planner revamp: status (branch `playlist`)

The "playlist (service/date)" screens are the Service planner (More → Tools → Service planner): `Extras/ServicePlannerView.swift`. The model (`ServicePlan`, `ServicePlanner`, key `service.plans.v1`) and analytics events are unchanged.

The build succeeds with **no warnings** (Xcode 27.1, iPhone 17 Pro simulator, iOS 27).

## Plan screen (`ServicePlanDetailView`)

- **One header.** The nav bar has no title, only Back and Edit. The name is an inline text field in the serif hymn-title face. Under it is a tappable date chip ("Saturday, 17 October · In 3 days ⌄") that opens a graphical date picker in a popover; picking a date closes it. The separate Name/Date rows are gone.
- **The hymns are the hero.**
  - Each row has a brass number tile, the role as a small evergreen eyebrow ("OPENING HYMN"), and the title in serif.
  - The ⋯ menu keeps Role / Open in reader / Pitch pipe. Open and Pitch pipe are hidden for numbers missing from the hymnal.
  - Edit reorders and swipe deletes, as before. Edit is disabled when the plan is empty.
- **Empty state:** "No hymns yet" in place of the list.
- **Add hymns** is its own section:
  - "The hymn you're reading" suggestion with a + button.
  - The add-by-number field, with a "#" tile and the matching title (or "No hymn N in …") previewed inline under the field. The + is enabled only for a valid number.
  - The keyboard's Add button is kept.
- **Start in church mode** floats at the bottom in a glass container: `dsGlass`, which is Liquid Glass on iOS 26 and material + hairline + shadow on iOS 17–25. The button inside is the prominent tint (not glass on glass).
  - With no playable hymns it is disabled, with the hint "Add a hymn to start church mode." (or "None of these hymns are in <hymnal>.").
  - It hides while the keyboard is up for the name or the number.

## Plans list (`ServicePlansView`)

- **Next service** card at the top: the earliest plan dated today or later, on a tinted ground. It shows "IN 3 DAYS / TODAY / TOMORROW", the name in serif, the date, and up to 5 hymn-number tiles (+N).
- **Create:**
  - a "New service plan" row with a filled evergreen + and "Starts with hymn N, title"
  - a toolbar +
  - Both keep the old behaviour (a new plan for next Sabbath with the open hymn, which opens it).
- **Coming up** (ascending) and **Past** sections. Rows have a calendar tile (OCT / 23), the name, and "3 hymns · 5 · 30 · 45". Undated plans count as coming up.
- Swipe to Delete as before. Touch and hold adds Start in church mode and Delete.
- **Empty state:** "Plan this week's service" with a primary New service plan button. The toolbar + is hidden while it shows.
- Both screens draw on the reading surface (hidden list background, 5 % row fills), so they follow Paper/…/Black like the other tool sheets.

## Also changed

- **`GlassButton` (all screens):** a *disabled* primary button now uses `surface.secondary` for its label instead of `onTint`. On dark surfaces `onTint` is black, and on iOS 26 the disabled label vanished into the grey fill.
- **DEBUG launch args:**
  - `-uiDebugSeedPlans YES|empty` uses sample plans, or none. Nothing is saved.
  - `-uiDebugPlan "<name>"` opens a plan.
  - Use both with `-uiDebugSheet planner`.

## Screenshots: `build/shots/playlist/`

- `list-filled-{light,dark}.png`
- `list-empty-{light,dark}.png`
- `detail-filled-{light,dark}.png`
- `detail-empty-{light,dark}.png`

Light is the Paper surface and dark is Black. `before/` has the old list and plan screens.

## Not checked

- **Nothing was driven by touch** (there was no tap automation): the date popover, Edit mode reordering, swipe and context menus, typing a number, and the bar hiding with the keyboard. All use standard SwiftUI APIs, but they're worth a manual pass.
- iPad and the iOS 17–25 fallback compile but weren't run, because the simulators are iOS 27 only.
- No tests were added. The new strings are not yet translated.

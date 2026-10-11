# App Store listing — Advent Praise 7.0

Paste into App Store Connect → App Information / 7.0 version page (English (U.S.) or
English (U.K.), whichever is primary for id1015021132). Character counts were checked
with `python3 -c 'print(len(...))'`; keyword count is in bytes, which is what Apple limits.

Everything here describes only what 7.0 (1) actually does. **Do not mention hymn
playback or accompaniment** — no MIDI files ship in 7.0, so the play button is hidden
(Guideline 2.3.1, accurate metadata).

---

## App name (30 max)

```
Advent Praise
```
13 chars. Keep the existing name so search rank and reviews carry over.

## Subtitle (30 max)

```
Christ In Song in 23 languages
```
30 chars. "23 languages" is exact: 24 hymnals, with English having two
(Christ In Song and the SDA Hymnal). Ndebele and isiZulu share one book.

Alternative if you'd rather lead with the use case: `Hymnal for church & home` (24).

## Promotional text (170 max, can be changed without a new build)

```
New in 7.0: Church mode shows one verse at a time in large, bright text, so the whole congregation can follow. Plus large print, reading themes and Siri.
```
153 chars.

## Description (4000 max)

```
Advent Praise puts Christ In Song and the SDA Hymnal in your pocket, along with 22 more hymnals in languages from Shona and isiXhosa to Spanish and French.

Find a hymn in seconds. Type its number on the large number pad and the title appears before you tap Go. Or search by the words you remember: search covers titles and lyrics and ignores accents, capitals and apostrophes.

CHURCH MODE
Show one verse at a time in large white text on black, sized to fill the screen. The chorus comes back after every verse. Tap or swipe to move on, and at the last verse go straight to the next hymn. The screen stays awake for the whole service.

READ IT YOUR WAY
• Five reading themes: Paper, Parchment, Sepia, Muted and Black
• Serif or sans-serif text, adjustable size, spacing and alignment
• Large print for easier reading
• Option to repeat the chorus after every verse
• Full Dynamic Type and VoiceOver support

PLAN THE SERVICE
• Favourites for each hymnal
• Playlists that are saved between launches, so you can prepare the order of service ahead of time
• Recent hymns, one tap away

SIRI AND SHORTCUTS
Say "Open hymn in Advent Praise", then the number. You can also go to the next hymn in your playlist or start Church mode with your voice or from the Shortcuts app.

IPAD
On iPad, the hymn list and the reader sit side by side.

HYMNALS
Christ In Song (English) is free. Other hymnals can be bought once each as an in-app purchase and are yours to keep. Hymnals you bought in an earlier version are included: if one doesn't show as yours, tap Restore purchases.

• Christ In Song — English
• SDA Hymnal — English
• Keresete Mo Kopelong — Tswana
• Keresete Pineng — Sotho
• Kreste Ka Kopelo — Sepedi
• UKrestu Esihlabelelweni — Ndebele / isiZulu
• UKristu Engomeni — isiXhosa
• Risima Ra Vuyimbeleri — Xitsonga
• Ngosha YaDzingosha — Venda
• Kristu MuNzwiyo — Shona
• Khristu Mu Nyimbo — Chichewa
• Kristu Mu Nyimbo — Tonga
• Kristu Mu Nyimbo — Icibemba
• Nyimbo za Mpingo wa SDA — Tumbuka
• Nyimbo Za Kristo — Swahili
• Nyimbo cia Agendi — Kikuyu
• Ogotera kw'ogotogia Nyasae — Abagusii
• Wende Nyasaye — Dholuo
• Indirimbo Zo Guhimbaza Imana — Kinyarwanda
• SDA Twi Hymnal — Twi
• Hinário Adventista do Sétimo Dia — Português
• Himnario Adventista — Español
• Donnez-Lui Gloire — Français
• Гимн адвентистов седьмого дня — Русский

FOUND A MISTAKE?
Use Send a correction in the app. It opens an email with the hymn already filled in, so you only need to tell us what's wrong.

Advent Praise has no ads and no account to sign up for. It collects only anonymous usage statistics and what it needs to restore your purchases, and none of it is linked to you.
```

2,611 chars (well under 4,000).

> The Portuguese title was "Hinàrio Adventista Do Sétiomo Dia" in the source data. It
> is now corrected to "Hinário Adventista do Sétimo Dia" in the app
> (`TITLE_NAMES` in `Tools/convert_hymnals.py`, `hymnals.json`, `pt.json`), so the
> app matches this list.

## Keywords (100 bytes max, comma-separated, no spaces)

```
hymnal,hymnbook,sda,adventist,church,worship,lyrics,zulu,shona,ndebele,tswana,sotho,swahili,xhosa
```
97 bytes. Words already in the name or subtitle (advent, praise, christ, song,
languages) are left out because Apple indexes those anyway. Other languages
(chichewa, kikuyu, twi, venda…) are left out because they're a lower search volume;
swap them in after a month of App Analytics data.

## What's New in this version (4000 max)

```
Advent Praise 7 is a complete rebuild.

• Church mode: one verse at a time in large, bright text, with the chorus after every verse. Tap to move on; the screen stays awake.
• All 24 hymnals in one place, with your earlier purchases restored.
• Large print, five reading themes, and adjustable font, size, spacing and alignment.
• Find hymns by number with live title preview, or search the words of any hymn.
• Favourites for each hymnal, and playlists that are kept between launches.
• Siri and Shortcuts: "Open hymn in Advent Praise".
• A side-by-side layout on iPad.
• Send a correction straight from any hymn.

Thank you for singing with us.
```

## Other App Information fields

| Field | Value |
|---|---|
| Primary category | Music (matches `LSApplicationCategoryType = public.app-category.music`). Use **Reference** instead if the live 6.x app is already in Reference; don't change it without a reason. |
| Secondary category | Reference |
| Age rating | 4+. Every questionnaire answer is "None" / "No": no user-generated content, no web browsing, no gambling, no contests, no medical content, no unrestricted web access. Answer **Yes** to "in-app purchases". |
| Copyright | `2026 mDev` (use the legal name of the seller on the account) |
| Price | Free (the app), with in-app purchases |
| Content rights | "Yes, it contains third-party content, and I have the rights" — only if you have that documentation. See `review-notes.md` → Content rights. |
| Support URL | see `urls-checklist.md` |
| Marketing URL | optional — see `urls-checklist.md` |
| Privacy Policy URL | see `urls-checklist.md` (it must match `AppInfo.privacyPolicyURL`) |

## In-app purchase display names

Each non-consumable needs a display name and description (en) in App Store Connect.
Pattern (description max 45 chars):

| Field | Example (Shona) |
|---|---|
| Reference name | `Hymnal – Shona` |
| Display name | `Kristu MuNzwiyo` |
| Description | `Shona hymnal, yours to keep` |

Use the hymnal title from `hymnals.json` as the display name, so it matches the
Hymnals panel. The product IDs must be the **live 6.3 IDs**. See STATUS.md, blocker 1.

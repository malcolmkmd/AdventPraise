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
Christ In Song in 9 languages
```
29 chars. "9 languages" is exact: the nine hymnals 6.3 listed. Zulu and Ndebele
share one book (UKrestu Esihlabelelweni) and are listed under both languages, as in 6.3.

Alternative if you'd rather lead with the use case: `Hymnal for church & home` (24).

## Promotional text (170 max, can be changed without a new build)

```
New in 7.0: Church mode shows one verse at a time in large, bright text, so the whole congregation can follow. Plus large print, reading themes and Siri.
```
153 chars.

## Description (4000 max)

```
Advent Praise puts Christ In Song in your pocket in English, Chichewa, Tswana, Xhosa, Sotho, Shona, Venda, Zulu and Ndebele.

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
Every hymnal is free.

• Christ In Song — English
• Khristu Mu Nyimbo — Chichewa
• Keresete Mo Kopelong — Tswana
• UKristu Engomeni — Xhosa
• Keresete Pineng — Sotho
• Kristu MuNzwiyo — Shona
• Ngosha YaDzingosha — Venda
• UKrestu Esihlabelelweni — Zulu
• UKrestu Esihlabelelweni — Ndebele

Advent Praise has no ads and no account to sign up for. It collects only anonymous usage statistics and what it needs to restore your purchases, and none of it is linked to you.
```

1,921 chars (well under 4,000).

> 7.0 ships only the nine hymnals 6.3 listed (see LANGS_STATUS.md). The other cis-v2
> hymnals (SDA Hymnal, Swahili, Twi, Português, Español…) can be rebuilt with
> `Tools/convert_hymnals.py --all` if they come back; add them to this list then.

## Keywords (100 bytes max, comma-separated, no spaces)

```
hymnal,hymnbook,sda,adventist,church,worship,lyrics,zulu,shona,ndebele,tswana,sotho,xhosa,venda
```
95 bytes. Words already in the name or subtitle (advent, praise, christ, song,
languages) are left out because Apple indexes those anyway. Chichewa doesn't fit
(104 bytes); swap it in for a weaker word after a month of App Analytics data.

## What's New in this version (4000 max)

```
Advent Praise 7 is a complete rebuild.

• Church mode: one verse at a time in large, bright text, with the chorus after every verse. Tap to move on; the screen stays awake.
• All nine hymnals in one place, and every one is free.
• Large print, five reading themes, and adjustable font, size, spacing and alignment.
• Find hymns by number with live title preview, or search the words of any hymn.
• Favourites for each hymnal, and playlists that are kept between launches.
• Siri and Shortcuts: "Open hymn in Advent Praise".
• A side-by-side layout on iPad.

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
| Privacy Policy URL | see `urls-checklist.md` (a public copy of the in-app policy) |

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

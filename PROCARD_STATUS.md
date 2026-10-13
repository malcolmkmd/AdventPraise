# PROCARD_STATUS — a compact Pro card at the top of More

Branch `procard`, merged into `main`. Not pushed.

## What changed (`Store/ProMoreCard.swift`)
The Pro card at the top of More is now one compact row, about 72pt tall at default
text size (it used to be a tall card with scenery, four feature lines, a meter, a button
and Restore):

- **Tile:** a 48pt rounded square of the paywall's ground, gold light and glowing church
  logo (`PaywallLight`, `PaywallLogo`). It scales with Dynamic Type up to 64pt, so the row
  stays a row.
- **Title:** "Advent Praise Pro" (serif `rowTitle`). Pro users also get a brass
  `checkmark.seal.fill`.
- **One line:** free users see the free plays of the piano left ("3 of 5 free plays of
  the piano left", "1 free play of the piano left", "Your free plays of the piano are
  used"). Pro users see "Thank you. Pro is yours for good."
- **Chevron**, styled like the other More rows.
- **No CTA button.** The whole card is one `Button` (plain style, `contentShape` on the
  card shape) that opens the paywall, as before (`model.paywall = .support`). VoiceOver
  reads it as one element: label "Advent Praise Pro, <line>", hint "Opens Advent Praise
  Pro".
- Brand styling is kept: brass hairline border on the row fill, on both paper and black.

Removed from the card: the hands strip, the four feature lines, the pip meter, "See
Advent Praise Pro", and the two Restore buttons. **Restore is still one tap away:** the
paywall has "Restore purchases" in its footer, and for a Pro user it shows the thank-you
card (`ProActiveCard`). `RestoreSource.more` is now unused but left in place for the
analytics schema.

## Verification
- `xcodebuild build` (Debug, iPhone 17 Pro, iOS 27.1), foreground, one simulator:
  succeeded, **no warnings**.
- Screenshots in `build/shots/procard/`: `more-free-{light,dark}` (3 of 5 plays left),
  `more-pro-{light,dark}`, and `more-free-axl-light` (Accessibility XL: the text wraps,
  the tile is capped, nothing is cut off).
- Build output (`build/DD`) deleted afterwards; the simulator is shut down.
- Not exercised by a tap in the simulator: the card's action is the same closure the
  old button called.

## For Malcolm
- At Accessibility XL, More's existing "Church mode" row breaks the word ("Churc / h")
  because of its detail text. That row isn't part of this change, but it's worth fixing.

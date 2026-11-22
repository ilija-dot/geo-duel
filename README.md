# Tile Sprint

A daily speed puzzle for phones. Tap the numbers 1, 2, 3… in order on a shuffled grid,
five rounds a day. Everyone gets the **same boards each day**, so you can compare times with friends.

Built with **Godot 4.7** (GDScript). Portrait, mobile renderer.

## How to run it
1. Open Godot → **Import** → pick this folder's `project.godot`.
2. Press **F5** (or the ▶ button) to play.

## How it works
| Feature | Where |
|---|---|
| Today's puzzle number + seeded boards (same for everyone) | `scripts/daily.gd` |
| Saving coins, gems, themes, streaks, friends (local JSON only) | `scripts/save_data.gd` |
| Ratings (green/yellow/red), share message, friend codes | `scripts/scoring.gd` |
| Shop themes (cosmetic only) | `scripts/theme_catalog.gd` |
| Colors / button style | `scripts/ui.gd` |
| Screens (menu, game, results, friends, shop) | `scripts/screens/` |

**Friends without a server:** after the daily, tap *Copy result to share* and paste it in a group chat.
Friends paste your message into their *Friends* screen to see who was fastest today.

**Money:** coins come from the daily (+ streak bonus). Gems come free every 7-day streak and,
later, from real-money packs. Both only buy color themes, so paying never makes anyone faster.

## Tests
```
godot --headless --path . res://tests/test_runner.tscn
```
`tests/screenshots.tscn` saves a picture of each screen (set the `SHOT_DIR` env var to a folder).

## Next steps
- **Play it on your phone:** Project → Install Android Build Template, install Android SDK + JDK 17,
  then Project → Export → Android.
- **Real gem purchases:** add the Godot Google Play Billing plugin, and call `Save.add_gems()`
  only after Google confirms payment (see `_get_gems()` in `shop_screen.gd`).
  All purchases must go through Google Play / Apple billing. Don't add paid loot boxes.
- **Ideas:** sound + vibration on taps, more cosmetics (tap effects, tile shapes), a native
  "Share" button instead of copy-to-clipboard.
- **Known gap:** quitting the daily halfway lets you see the boards and try again. Consider
  counting a started daily as played.

## Privacy
The game collects no personal data: no accounts, no ads, no analytics, nothing sent online.
Nicknames stay on the phone unless the player shares a result. Keep it that way, or check the
COPPA / GDPR rules before adding ads, analytics or online features.

# Geo Duel / Гео Дуел

A mobile geography quiz for 13–15 year olds. Challenge a friend with their player ID; you both
answer the same 10 questions from the 8th-grade geography textbook
(„Географија за VIII одделение“, ARS Studio). Each question has 8 tiles. Several are correct,
and **the rarer the correct answer you pick, the more points you get** (10 / 25 / 50 / 100);
wrong answers and running out of time (20 s) score 0. English and Macedonian.

Also: **Easy / Medium / Hard** difficulty, an **avatar builder**, a **global leaderboard** (weekly, last week's champions, all time), **player-made levels** shared by code (with reporting and a word filter), and **Help (F1)** with the rules and a tutorial.

Built with **Godot 4.7** (GDScript) and **Supabase** (online duels).

## Run it
1. Open Godot → **Import** → this folder's `project.godot` → press **F5**.
2. Without Supabase settings the game runs in **practice mode** (solo, offline).

## Turn on online duels (Supabase, free)
1. Create a free project at supabase.com.
2. **Authentication → Sign In / Providers → allow anonymous sign-ins** (players get an account
   automatically, with no email).
3. **SQL Editor → New query**: paste and run, in this order: `supabase/schema.sql`, `supabase/002_avatars_leaderboard.sql`, `supabase/003_difficulty_levels.sql`, `supabase/004_accounts.sql`, `supabase/005_delete_account.sql`, `supabase/006_wallet.sql`, `supabase/seed_questions.sql`. Then **Authentication → Sign In / Providers → Email → turn off "Confirm email"** (needed for email accounts without your own email server).
4. **Project Settings → API**: copy the Project URL and the `anon public` key into
   `scripts/supabase_config.gd`. (Never use the `service_role` key in the app.)

How it works: every player gets a 6-character ID (e.g. `K7M2QX`). Starting a duel asks the server
for 10 questions that **neither player has had before**. Each player plays their turn when they
like; the server scores the answers from the answer key, so scores can't be faked.

## Questions
- `data/questions.json`: 500 questions, grouped by the book's lessons (Africa, North/South America,
  Australia & Oceania, polar regions).
- To change questions, edit the JSON, then run
  `godot --headless --path . -s tools/build_questions.gd`. It checks every question and regenerates
  `supabase/seed_questions.sql`. Re-run that SQL in Supabase afterwards.

## Code map
| What | Where |
|---|---|
| Quiz (tiles, timer, reveal) | `scripts/screens/quiz_screen.gd` |
| Duels list / challenge a friend | `scripts/screens/duels_screen.gd`, `challenge_screen.gd` |
| Online calls (Supabase REST) | `scripts/net.gd` |
| Database tables, rules, functions | `supabase/schema.sql` |
| Scoring, tile order | `scripts/question_bank.gd` |
| All UI text (MK/EN) | `scripts/lang.gd` |
| Saved progress, coins, gems | `scripts/save_data.gd` |
| Shop themes (cosmetic only) | `scripts/theme_catalog.gd` |

## Tests
```
godot --headless --path . res://tests/test_runner.tscn
```

## Publish the web version (GitHub Pages)
```
GODOT="path/to/godot_console.exe" bash tools/publish_web.sh
```
Builds the web export and pushes it to the `gh-pages` branch.

## Money
Coins, gems and purchases are stored on the player's account (server), so they follow them to every device; the server pays rewards and checks prices. Coins come from playing; gems from duel wins (and later real-money packs via Google Play / Apple
billing; see `_get_gems()` in `shop_screen.gd`). Both only buy color themes, so paying never gives
an advantage, and there are no loot boxes.

## Privacy
See [PRIVACY.md](PRIVACY.md) (also in the game under Account → Privacy). Players can delete their account and data in the game.

Players use a nickname and a random ID; no email, real name, ads or analytics. The server stores
only the ID, nickname and duel answers. Check COPPA / GDPR rules before adding ads, analytics or chat.

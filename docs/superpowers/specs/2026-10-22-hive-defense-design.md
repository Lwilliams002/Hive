# Hive Defense — Design Document

Date: 2026-10-22
Status: draft, builder-checked, awaiting owner approval
Working title: **Hive** (final name TBD; owner picks before App Store submission)

## 1. Intent

A free iOS game that earns money through ads. The player is a beehive at the center of the screen defending against waves of mobs. The hive shoots on its own; the player's job is choosing upgrades and, over many sessions, growing the hive into something visibly impressive. The visible growth of the hive is the retention hook; ads are placed where the player *wants* them (double coins, revive, premium upgrade) rather than where they interrupt.

**Why this concept:** base-defense auto-shooters with run-based upgrade cards are a proven, highly retentive loop. The hive theme is not used in this genre on the App Store, so it stands out in screenshots and search.

## 2. Goals

- Sessions of 1–3 minutes that feel complete (one level) but pull toward "one more".
- Difficulty that **respects the player's time**: levels are genuinely hard to clear; wins are earned, not handed out. Players who keep playing get stronger through permanent upgrades and beat levels that stopped them before.
- A hive that looks **mature and striking**, never childish. Think moody, glowing, geometric; not cartoon bees with faces.
- Ad revenue through four placements (section 6), all tuned so they feel like opportunities.
- Shippable to the App Store from this codebase.

## 3. Non-goals (for v1)

- Android or any cross-platform build.
- Multiplayer, leaderboards, social features, accounts.
- In-app purchases (may come later; architecture should not block it, but v1 ships ads only).
- Narrative cutscenes or dialogue. "Story" in v1 means a numbered level progression with a sense of escalation, not written plot.
- Custom hand-drawn art. All visuals are procedurally drawn with SpriteKit shapes, gradients, glow, and particles.
- Sound design beyond a small set of simple effects and one ambient loop. (Builder may stub sound entirely in the first milestone.)

## 4. Anti-goals (what would make this a failure even if it works)

- **A childish-looking hive.** No googly eyes, no primary-color cartoon palette, no bouncy Comic-Sans energy.
- **Pushy ads.** No forced interstitial on every level, no ad on app open, no unskippable video in the first session.
- **Easy levels.** If a new player breezes through the first ten levels, difficulty is wrong.
- **Pay-to-win feel.** Watching an ad accelerates; it never grants something unreachable by play.

## 5. The Game

### 5.1 Core loop (one level)

1. Hive sits at screen center. Mobs spawn at the screen edges and move toward it.
2. Hive auto-targets and fires at the nearest mob (default). Upgrades change targeting, fire rate, projectile count, damage, area, etc.
3. Mobs that reach the hive deal contact damage and die. Hive has HP.
4. Killing mobs drops **nectar** (XP). Filling the nectar bar pauses the game and shows **three upgrade cards**; player taps one. Cards are run-scoped (lost when the run ends).
5. A level is a fixed set of waves ending in a **boss wave**. Clear the boss, level complete. Hive HP reaches zero, run over.
6. Level complete screen: coins earned, option to double via rewarded ad, continue to next level or return home.

**A run is one level.** Upgrade cards reset at the start of every level, so every level is tuned from a cold start against the player's permanent tiers only. "Continue" on the level-complete screen starts a fresh run of the next level. Revive is once per level. (My call: this keeps sessions 1–3 minutes, keeps per-level JSON tuning honest, and means level select never has to reconcile an in-progress chain.)

### 5.2 Modes

- **Story mode:** numbered levels (1, 2, 3, …). Each level has a hand-tuned wave script (enemy mix, counts, spawn timing, boss). Progress is saved; player can replay any cleared level. Target: 30 levels at launch, with the data format making it cheap to add more.
- **Endless mode:** unlocked after clearing story level 10. Waves scale indefinitely; a boss every 5 waves. Tracks personal best wave. Coins per wave scale with wave number.

### 5.3 Difficulty philosophy

- A fresh player **should lose** somewhere around level 3–5 on the first attempt. That loss is the moment they discover permanent upgrades.
- Each story level is tuned so that a player with roughly the "expected" permanent upgrade level for that point can clear it with good card choices, and a player one tier behind usually cannot.
- Boss waves are the gate. Bosses have a clear tell and a weakness (e.g., the Bear is slow but tanks damage; the Hornet Queen spawns escorts; Wasp Swarm bosses punish single-target builds).
- Difficulty is data-driven (JSON/plist per level), so tuning never requires code changes.

### 5.4 Progression

**Run progression (upgrade cards, lost on run end):**
Examples, builder may extend: +fire rate, +damage, +projectile count, piercing stingers, propolis armor (hive HP), honey slow field (slows mobs near hive), guard bees (orbiting melee), pollen cloud (area damage), royal jelly (heal). Each card has rarity: common, rare, epic. Epic cards appear more as the run goes on.

**Permanent progression (home screen, bought with coins):**
A tree of hive upgrades across roughly five tracks: Comb (HP), Stinger (damage), Swarm (fire rate / projectile count), Nectar (coin & XP gain), Queen (starting cards, revive chance). Each track has ~10 tiers. **Each tier change is reflected visually on the hive** (see 5.5). Costs scale so the mid-game requires replaying cleared levels or endless mode, which is where ad placements earn.

**Unlock progression:** some epic cards and permanent tiers unlock only after reaching a story level. The premium ad card (section 6) can let the player *use a locked card for the current run only*; it never permanently unlocks a card and never grants a permanent tier. (My call: keeps the ad an accelerator, not a purchase, and keeps the unlock model simple.)

### 5.5 Visual direction

- **Palette:** deep near-black background with a subtle dark honeycomb texture; hive in warm amber, gold, and burnt orange with soft glow; mobs in cool contrasting tones (slate, violet, sickly green) so threats read instantly. Accent white for projectiles and hit flashes.
- **Hive:** a cluster of hexagonal comb cells. Level 1 is a small irregular lump of a few dim hexes. Each permanent tier adds cells, symmetry, glow intensity, and eventually structural features (outer wax wall, honey channels that pulse, a crowned queen chamber at the top tiers). The hive at max tier should look like a glowing geometric city.
- **Mobs:** simple silhouettes: wasps (small, fast, dart), hornets (medium, tanky), beetles (slow, armored, shielded front), bears (boss, huge, slow). Drawn with shape nodes, no faces.
- **Feel:** screen shake on boss hits, hit-flash on mobs, particle burst on kills, nectar drops that drift to the hive. Everything is slightly glowy on dark. Reference feel: moody minimal mobile games, not candy-colored casual.
- **UI:** thin, modern, high-contrast type (SF Pro / SF Rounded is fine). Minimal chrome. No wooden buttons, no cartoon frames.

### 5.6 Screens

1. **Home:** the hive, large, at current visual tier. Buttons: Play (continue story), Endless (locked until level 10), Upgrades, Settings. Coin balance visible.
2. **Upgrades:** five tracks, each a column of tiers with cost and effect. Hive preview updates live when hovering/tapping a tier.
3. **Level select:** vertical list of story levels with cleared/current/locked state.
4. **Game:** full-screen play. Top: hive HP bar, wave counter, coin count. Nectar bar along the bottom. Pause button.
5. **Upgrade card pick:** overlay, three cards, optional fourth premium slot (section 6).
6. **Level complete / Game over:** results, coins, double-coins ad button, revive ad button (game over only, once per run), continue / retry / home.
7. **Settings:** sound, haptics, restore (future IAP), privacy/ATT, credits.

## 6. Monetization (Google AdMob)

| Placement | Type | Trigger | Rule |
|---|---|---|---|
| Double coins | Rewarded video | Level complete screen | Always offered; never forced |
| Revive | Rewarded video | Hive HP hits zero | Once per run; hive returns at 50% HP |
| Premium upgrade card | Rewarded video | Upgrade card pick | A fourth card slot, shown on ~1 in 3 picks, offering a card the player hasn't unlocked yet or an epic version of a common card. Watch to take it **for this run only**. |
| Interstitial | Interstitial | Between levels | Only after a level ends, never more than once every 3 levels, never in the first 3 levels of a fresh install, never within 90s of a rewarded ad |

- Use AdMob test ad unit IDs in debug builds; real IDs are injected from a config file not committed to git.
- App Tracking Transparency prompt is shown once, after the first level is complete, not on launch.
- Ad loading is preloaded in the background so the button is ready when the screen appears; if an ad fails to load, the button is hidden, never shown broken.
- A **banner** is explicitly *not* used in v1 (it fights the visual direction).
- **Audience and regions (my call):** the app is **not child-directed**; AdMob is tagged accordingly and the App Store age rating is 12+. The app is distributed worldwide, so the Google **User Messaging Platform (UMP)** consent flow is included. It is shown together with the ATT prompt after the first level is complete, before any ad is requested; until then no ads load. This satisfies EEA/UK requirements without an ad prompt on launch.

## 7. Technical decisions (owner has delegated these to Claude; listed as my calls)

- **Language/engine:** Swift 5.x, SpriteKit, UIKit host (SwiftUI for menus is acceptable if the builder prefers; game scene is SpriteKit).
- **Minimum iOS:** 16.
- **Ads:** Google Mobile Ads SDK via Swift Package Manager.
- **Persistence:** local only, `UserDefaults` or a small JSON save file in Application Support. No backend.
- **Level data:** JSON files in the bundle, one per story level, plus an endless scaling config.
- **Architecture:** scenes (Home, Game, Upgrades, …), a `GameState` model for save data, a `WaveDirector` that reads level JSON and spawns, an `UpgradeCatalog` for cards, a `HiveRenderer` that builds the hive node tree from the permanent tier state, an `AdManager` wrapping AdMob with the rules in section 6.
- **Testing:** unit tests for the pure logic (wave scripting, upgrade math, coin economy, ad frequency rules). Rendering is verified visually in the simulator.
- **Project location:** `/Users/lezdev/Desktop/Williams/ad-game/`, git-initialized, Xcode project generated with XcodeGen or created directly (builder's choice).

## 8. Milestones (suggested, builder may refine)

1. **Playable core:** hive, one mob type, auto-fire, HP, nectar bar, three-card pick with ~6 cards, one hand-written level, game over / retry. Visible in simulator.
2. **Progression:** coins, home screen with hive at tier, upgrades screen with the five tracks, hive visuals changing per tier, save/load.
3. **Content:** all mob types, bosses, 30 story levels in JSON, endless mode.
4. **Ads:** AdMob integrated with all four placements and the frequency rules, test IDs.
5. **Polish & ship:** particles, shake, sound, app icon, App Store screenshots, privacy manifest, real ad IDs from config.

## 9. Left to the builder

- Exact numbers for HP, damage, costs, wave counts (tune to the difficulty philosophy in 5.3).
- Final list and names of upgrade cards beyond the examples.
- Exact hive geometry per tier, as long as it follows 5.5.
- Sound effects choice.
- Whether menus are UIKit, SwiftUI, or SpriteKit.

## 10. Open items for the owner (not blocking the plan)

- Final app name and bundle identifier.
- Apple Developer account availability for device testing and submission.
- AdMob account and real ad unit IDs (needed only for milestone 5).
- A hosted privacy policy URL (required by the App Store for an ad-supported app; needed at submission).

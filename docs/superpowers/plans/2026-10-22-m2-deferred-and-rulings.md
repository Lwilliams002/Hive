# Milestone 2 — deferred items, rulings, and seams for M3/M4 (carried from the SDD ledger)

## Execution
Task 1: fix round 1/5 (2 addressed, 0 open — zero-tier Equatable normalization; description test cases; commits 2ae2e2f..8075ce0)
Task 1: minor (deferred): cost(forTier:) unguarded outside 1...10 (doc comment)
Task 1: complete (commits 98af344..8075ce0, review clean after 1 round)
Task 2: minor (deferred): version 0/negative passes; corrupt test doesn't assert backup name or collision branch; round-trip doesn't assert recordedRunIDs persistence; encode errors wrapped as .io
Task 2: complete (commits 8075ce0..56dd089, review clean)
Task 3: minor (deferred): testCardPoolUsedForPicks weak (pool ⊂ milestone1); damage==13 brittle
Task 3: complete (commits 56dd089..44b606e, review clean)
Task 4: minor (deferred): HomeScene PLAY unguarded during fade (double start); end-overlay buttons over the hive (lower stack / raise dim alpha — T6/T7 polish); Button.contains ignores scale/rotation; cleared/CONTINUE + auto-pause under UIScene unobserved (check in T7/T8); HomeScene re-adds stored play node
Task 4: complete (commits 44b606e..980d8b9, review clean)
Task 5: Ruling: walls are flat-top at 6.8r/7.6r (plan's pointy-top 4.2r/5.4r would cut through ring-2 cells and be hidden by ring 3) and honey channels render above cells (plan's z 0 under opaque cells would be invisible) — plan geometry errors; screenshots confirm the intended look — cost if wrong: none.
Task 5: minor (deferred): queen chamber overlaps ring-1 cells (plan 1.6r; acceptable "raised" look); crown modest; tier-1 asymmetry is intentional per spec 5.5
Task 5: complete (commits 980d8b9..c1090fa, review clean, 1 ruling; controller grep: no HiveNode references remain)
Task 6: Ruling: HIVE title at h/2−68 and LEVEL label at 80·scale+24 below the hive accepted (Dynamic Island / large-hive clearance) — cosmetic.
Task 6: minor (deferred): NumberFormatter rebuilt per didMove; level label over the glow halo at high tiers
Task 6: complete (commits c1090fa..2ba5175, review clean)
Task 7: Ruling: dimmed (unaffordable) BUY buttons still accept the tap and trigger the coin shake (feedback matters; brief's isEnabled + shake contradicted); rows move up ~58 pt and bottom-anchor so 667-pt phones don't clip — cost if wrong: cosmetic.
Task 7: fix round 1/5 (4 addressed, 0 open — refusal shake reachable, shake drift, rows anchored, cost formatting; commits 96e04de..5b27597)
Task 7: minor (deferred): tier label hard-codes 5 (expose tiersToNextLook from PermanentUpgrades); frame hit-test assumes rows container at origin
Task 7: complete (commits 2ba5175..5b27597, review clean after 1 round, 1 ruling)
Task 8: minor (deferred): scrolled rows not clipped (no crop node; add in M3 with 30 levels); scrolling untested (one level); greedy policy duplicated in test; CONTINUE verified by code only
Task 8: complete (commits 5b27597..6ecf99d, review clean; midgame probe 20/20)

## Final review (opus) — Needs fixes: 6 Important
Ruling: in-game hive scaled so the comb radius matches Hive.radius+4 (do not change Hive.radius; balance/probes unchanged) — cost if wrong: small visual mismatch.
Ruling: AppFlow.playableLevel = min(currentLevel, maxAvailable) used by Home label and PLAY; "ALL LEVELS CLEARED" shown when highestClearedLevel >= maxAvailable — cost: none.
Ruling: starting cards drawn from a pool excluding heal-only effects (royal_jelly, propolis_armor); 1.5 s "STARTING CARDS" banner at run start — cost: Queen slightly stronger than planned.
Ruling: PauseOverlay gains HOME and RETRY; HOME records the run as a loss (pending coins paid) before leaving — spec silent; reasonable-player expectation — cost: a quit pays partial coins, which is intended.
Ruling: Upgrades layout fitted top-down for small phones (rows anchored, label 16 pt above, hive scaled to fit); verify on an SE/8-class simulator if available, else by computed numbers.
Ruling: GameState decodes with decodeIfPresent defaults, rejects version < 1, v1 fixture test added — forward compatibility before M3 adds fields.
FIX NOW minors: tiersPerLook on PermanentUpgrades; HUD run counter shown as "+N ◆"; Home hive scale curve monotonic; BUY debounce 0.2 s; keep EndOverlay during transition; auto-pause simulator check; recordedRunIDs in round-trip test.
Deferred-minor triage accepted as reported. Seams for M3/M4 recorded in the final report; carry to the M3 plan.
Final fix wave: 6ecf99d..66266a2, 72 tests, probes unchanged. Deferred (M5): Home overflows on 667-pt phones (ENDLESS off-screen); in-game hive at tier 9+ drawn at ~0.44 scale (detail small).

## Seams the final review named for milestones 3 and 4
- Card pool per level + unlock-gated cards: AppFlow.startLevel hard-codes UpgradeCatalog.milestone1; needs pool(unlockedAt:) and a separate starting-eligible pool.
- Unlock-gated permanent tiers: GameState.purchase/canAfford need isUnlocked(track, tier, highestClearedLevel) + LOCKED button state.
- Endless: RunResult.mode (.story(levelId)/.endless), CoinRules.endless(wave:), GameState.bestEndlessWave, Home ENDLESS enabled at highestClearedLevel >= 10, WaveDirector generator protocol.
- Revive (M4): recording currently happens on the gameOver tick keyed by runID; needs an 'ended, awaiting decision' phase, World.revive() (50% HP, same runID), record only on finalization, RunResult.revived flag.
- Double coins (M4): idempotent GameState.awardBonus(runID:coins:) with its own recorded list; multiplier source explicit.
- Premium card (M4): optional 4th locked-pool draw applied for the run only; CardPickOverlay fits 4.
- Interstitial rules (M4): levelsCompletedCount, lastInterstitialLevelCount, lastRewardedAt in GameState.
- Boss content (M3): fix 'bear kill opens a pick before cleared' and 'two thresholds, one pick' first.
- Economy (M3): payouts must scale with level (e.g. level 20 ≈ 600/clear); write an expected-totalTiers-per-level curve and probe each level at expected and expected−1; endless coins-per-wave; check Nectar doesn't dominate early.
- Small phones (M5): Home overflows at 667 pt; in-game hive at tier 9+ is ~0.44 scale.

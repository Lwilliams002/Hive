# Milestone 3 — rulings, deferred items, and M4 seams (carried from the SDD ledger)

## Execution
Task 1: Ruling: escorts spawn at distance max(parentDistance, 140) from the origin along the parent's angle (±15° jitter), never inside contact range — my "radius + 8 toward the hive" put them in contact on spawn — cost if wrong: escorts slightly easier. Ruling: pendingPicks counter in World so two thresholds in one tick yield two picks (nectar.add(0) alone could not) — accepted. Test recipes adjusted by implementer (bear+hornet; fire rate 5) — accepted.
Task 1: minor (deferred): fix (a) regression (later wave still opens pick) unpinned; NaN passes validation; boss escortTimer counts down on its spawn tick; app target won't compile until Task 5 (MobNode exhaustive switch) — Ruling: Tasks 2–4 are core-only; Task 4's "build to confirm bundling" is replaced by a file-count check, Task 5 confirms the build.
Task 1: complete (commits bc57334..c479e37, review clean, 2 rulings)
Ruling for Task 2: splash damage = max(0, d·fraction − armor) (no min-1 for splash; min-1 stays for direct hits and bee stings); precondition escort.every > 0.
Task 2: Ruling: splash fraction stacking capped at 1.0 (min(1, a+b)) — apply in the final fix wave — cost: none.
Task 2: minor (deferred, FIX AT FINAL): splash cap; zero-damage splash still flashes/emits .mobHit; cooldown one-tick drift (drop); untested bee-kill nectar/pick, splash on kill shot, armor on stings
Task 2: complete (commits c479e37..6ff69ad, review clean)
Task 3: Ruling: testEndlessNeverClears runs 240 s (plan's 120 s cannot reach 10 waves under the generator's issue timing); generator timing unchanged — cost: a slower test.
Task 3: minor (deferred): WaveDirector rebuilds the endless wave definition each tick (cache on wave start); RunResult.endless has levelId/totalWaves 0 — T6/T7 must branch on mode; game-over test timing-sensitive
Task 3: complete (commits 6ff69ad..47c106b, review clean, 1 ruling)
Task 4: BLOCKED on tuning (25/29 levels miss; early bosses immune to the difficulty knob; T−4 too close at high T; 300 s cap hit at L25/30). Rulings:
 (1) generator boss wave scales: hpScale = D·(0.4 + 0.06·(L−1)); escort wasps round(D·(4 + L/3)); escort hornets (L≥6) round(D·L/5); non-boss waves unchanged — cost: early bosses weaker than the mob table suggests; the table stays the "full strength" reference.
 (2) behind loadout = T − max(4, T/4) (integer division) — "one tier band behind" scales with progress.
 (3) bounds: atExpected ≥ 10/20 for all L ≥ 2 (L2–3 also ≤ 18); behind ≤ 7/20 for L ≥ 4.
 (4) curve-probe cap 420 s; generator inter-wave delay 2.5 for L < 10, 2.0 for L ≥ 10.
 (5) D steps 0.05 allowed; up to 10 iterations per level; overrides thereafter, flagged.
Cost if wrong overall: curve retuned again in M5 with real playtests.
Task 4: BLOCKED round 2 (late levels time-bound: fixed intervals mean D lengthens waves instead of densifying; hive never damaged at L16+). Rulings:
 (6) non-boss waves spread each group over a fixed 24 s window: interval = max(0.15, 24 / count) per group (all groups start at wave start); boss-wave escorts likewise over 24 s.
 (7) normal-mob hpScale per wave = max(1, D·(0.6 + 0.06·(L−1))); boss hpScale stays D·(0.4 + 0.06·(L−1)).
 (8) D steps of 0.025 allowed; up to 8 flagged overrides total.
Cost if wrong: late levels become "swarm" fights rather than endurance; retune in M5 with playtests.
Task 4: DONE after 2 blocked rounds; 1 override (L9 behind ≤ 8); D range 0.75–1.25; full probe 271 s.
Task 4: review Approved on code; cliff levels (L11,13,14,23,25,26,30: behind dies in wave 1). Rulings round 3:
 (9) non-boss wave budget ramp (0.6 + 0.1·i) instead of (0.75 + 0.08·i);
 (10) behind band = T − max(4, min(6, T/4));
 (11) soft guards for L ≥ 4: atExpected ≤ 19/20 and behind average end wave ≥ 2.0;
 (12) escort hornets use integer L/5 (confirmed).
Cost: another tuning round (~15 min); curve still approximate until playtests.
Task 4: fix round 1/5 (cliff guards + ramp + band; 7 overrides each ±1–2 clears; L12 passes the avg-end-wave guard by 0.05; commits bfa1582..8666606)
Task 4: parked — four levels at 20/20 at expected due to swarm-4/queen-3 loadout breakpoints — Ruling: accept; "behind usually cannot" holds everywhere; retune with real playtests in M5 — cost: some levels feel easy at exactly the expected loadout.
Task 4: minor (deferred): L12 avg-end-wave margin 0.05; curve probes at dt 1/30 are approximations; HIVE_PROBE_LEVELS with a missing level skips the whole test
Task 4: complete (commits 47c106b..8666606, review clean after 1 fix round, 12 rulings, 1 parked)
PAUSED by owner during Task 5 (implementer stopped mid-task; working tree may hold partial Task 5 edits). Resume: inspect git status, then re-dispatch Task 5 (fresh implementer, opus, same brief + report path).
RESUMED by owner; Task 5 implementer resumed on its partial edits.
Task 5: minor (deferred): flashing beetle stroke stays base color; slow-field rotation invisible; beetles first appear at level 6 (generator share) — fine
Task 5: complete (commits 8666606..6011310, review clean)
Task 6: fix round 1/5 (stale previousBest on RETRY; addressed; commits 2b81793..4976f5e; controller verified startRun runs first and HUD/overlay read the refreshed value)
Task 6: minor (deferred): previousBest doc comment stale; "Survived 0 waves" copy
Task 6: complete (commits 6011310..4976f5e, review clean after 1 round)
Task 7: Ruling: story card pool = pool(unlockedThrough: L − 1) (plan said highestClearedLevel) so real play matches the tuned probes; level 1 keeps milestone1; endless uses highestClearedLevel — cost: replaying early levels never offers late epics.
Task 7: minor (deferred): shrink-to-fit tag allowance hard-coded 80; drag starting outside list still scrolls; epics not observed in real play (pool verified in code)
Task 7: complete (commits 4976f5e..acd30d4, review clean, 1 ruling)
Task 8: complete (no fixes; 106 tests incl. full probe; endless 60 fps through wave 18 at ≤87 nodes; ≥40-mob stress not reproduced; best-wave persistence verified in T6)

## Final review (opus) — Needs fixes: 3 Important
Ruling: endless coins per wave 12 + 6k (was 10 + 3k) — endless beats story replays per minute from L10 on (est. 139/min @w10, 190 @w20, 238 @w30 vs story 104/165/220) — cost: endless may outpace the curve; retune in M5.
Ruling: pause→RETRY records the run like HOME via one recordIfInProgress() — cost: none.
Ruling: splash cap min(1, …); zero-damage splash neither flashes nor emits .mobHit.
Ruling: endless copy counts cleared waves ("NEW BEST · N WAVES", HUD "BEST N", "Survived N waves" / "No waves cleared"); BEST shown during boss waves too.
Ruling: boss banner pauses while any overlay is up; locked-tier tap does nothing (no shake); Honey Field fill alpha 0.03; remove slow-field rotation and projectile glowWidth; setHitFlash only on change.
Ruling: DEBUG HIVE_STRESS=N hook (spawns N wasps at wave start) + one baseline measurement before M4.
Ruling: fix (a) regression pin test added; previousBest comment fixed.
Deferred to M4: World split (first step), escort hpScale (M5), monotonic early difficulty (M5), small phones (M5), slate contrast (M5).
Final fix wave: acd30d4..13d3b1a, 109 tests; stress 60→176 nodes 60fps, 120→290 nodes 60fps (simulator).

## M4 seams named by the final review
1. Split World first (refactor-only, guarded by probes): registerKill, openPickUnlessClearing(thresholds:), World+Mechanics.swift (escorts, bees, splash). Add missing tests first: bee-kill nectar/pick, splash on kill shot, armor on stings.
2. Revive: recording is now one GameScene.recordIfInProgress() plus the end-overlay path; add a 'downed' state and record only on finalization; World.revive() = 50% HP, same runID, once per run; also clear/knock back non-boss mobs within ~150 pt and set boss attackCooldown ~1.5 s, or a revive dies again at once; endless revive continues the run.
3. Double coins: idempotent GameState.awardBonus(runID:coins:) with its own recorded list; bonus = result.coinsEarned.
4. Premium card: locked pool = UpgradeCatalog.all.filter { unlockLevel > poolLevel } with poolLevel as AppFlow uses (story id−1, endless highestClearedLevel; level 1 = all − milestone1); roll 1-in-3 and draw on a separate SeededRNG stream (seed XOR constant) so probes stay identical; apply via choose(_:) (add a test that it accepts out-of-pool cards); from poolLevel ≥ 15 the locked pool is empty — define 'epic versions of common cards' or hide the slot; keep epics out of the starting pool.
5. Interstitials: an endless run end counts as a level end; never on pause-RETRY; GameState fields via decodeIfPresent; AppFlow.runEnded is the single hook (also for ATT/UMP after the first level).
6. Card overlay with 4 rows: check fit at 667 pt.

## M5 items
- Perf pass before particles: SKSpriteNode textures, cache endless wave definition; stress baseline (simulator) 60 extra wasps → 176 nodes @60 fps, 120 → 290 nodes @60 fps; measure on a real device.
- Retune with playtests: monotonic early difficulty (fresh player most likely loses L1/L2, spec says L3–5), escort hpScale = normal-wave scale, L12 guard margin, endless vs curve pacing.
- Small phones (Home overflow at 667 pt), slate wasp contrast in crowded late waves, beetle stroke flash, end-overlay hive show-through.

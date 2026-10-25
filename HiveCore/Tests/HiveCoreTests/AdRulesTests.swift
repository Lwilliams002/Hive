import XCTest
import Foundation
@testable import HiveCore

/// M4 Task 5: the 3/3/90 interstitial frequency rule and the consent predicate (R14, R21), clock injected as `now`.
final class AdRulesTests: XCTestCase {
    private func story(level: Int, cleared: Bool, coins: Int = 20) -> RunResult {
        RunResult(runID: UUID(), levelId: level, cleared: cleared, wavesCleared: 2, totalWaves: 5, coinsEarned: coins)
    }

    func testNoInterstitialInFirstThreeRunEnds() {
        var s = GameState()
        for n in 0...3 {
            s.levelsEnded = n
            XCTAssertFalse(AdRules.mayShowInterstitial(s, now: 1000), "levelsEnded \(n)")
        }
        s.levelsEnded = 4
        XCTAssertTrue(AdRules.mayShowInterstitial(s, now: 1000))
    }

    func testInterstitialAtMostOnceEveryThreeRunEnds() {
        var s = GameState()
        s.levelsEnded = 4
        XCTAssertTrue(AdRules.mayShowInterstitial(s, now: 1000))
        AdRules.noteInterstitialShown(&s)
        XCTAssertEqual(s.lastInterstitialAtLevelsEnded, 4)
        s.levelsEnded = 5
        XCTAssertFalse(AdRules.mayShowInterstitial(s, now: 1000))
        s.levelsEnded = 6
        XCTAssertFalse(AdRules.mayShowInterstitial(s, now: 1000))
        s.levelsEnded = 7
        XCTAssertTrue(AdRules.mayShowInterstitial(s, now: 1000))
    }

    func testInterstitialBlockedWithin90sOfRewarded() {
        var s = GameState()
        s.levelsEnded = 10
        XCTAssertTrue(AdRules.mayShowInterstitial(s, now: 1000))
        AdRules.noteRewardedShown(&s, now: 1000)
        XCTAssertEqual(s.lastRewardedAdAt, 1000)
        XCTAssertFalse(AdRules.mayShowInterstitial(s, now: 1089.9))
        XCTAssertTrue(AdRules.mayShowInterstitial(s, now: 1090))
    }

    func testClockSetBackCountsAsInsideCooldown() {
        var s = GameState()
        s.levelsEnded = 10
        AdRules.noteRewardedShown(&s, now: 1000)
        XCTAssertFalse(AdRules.mayShowInterstitial(s, now: 500))
        XCTAssertFalse(AdRules.mayShowInterstitial(s, now: 10))
        XCTAssertTrue(AdRules.mayShowInterstitial(s, now: 1090))
    }

    func testShouldPromptConsentAfterFirstStoryRunEnd() {
        var s = GameState()
        let loss = story(level: 1, cleared: false)
        XCTAssertFalse(AdRules.shouldPromptConsent(s, after: loss))
        XCTAssertTrue(s.record(loss))
        XCTAssertTrue(AdRules.shouldPromptConsent(s, after: loss))
        s.consentPrompted = true
        XCTAssertFalse(AdRules.shouldPromptConsent(s, after: loss))

        var e = GameState()
        let endless = RunResult.endless(runID: UUID(), wavesCleared: 4, coinsEarned: 30)
        XCTAssertTrue(e.record(endless))
        XCTAssertEqual(e.levelsEnded, 1)
        XCTAssertFalse(AdRules.shouldPromptConsent(e, after: endless))
        let clear = story(level: 1, cleared: true)
        XCTAssertTrue(e.record(clear))
        XCTAssertTrue(AdRules.shouldPromptConsent(e, after: clear))
    }

    func testNoteHelpersWriteOnlyTheirField() {
        var s = GameState()
        s.coins = 321
        s.highestClearedLevel = 5
        s.levelsEnded = 9
        s.recordedRunIDs = [UUID()]
        s.bonusAwardedRunIDs = [UUID()]
        s.bestEndlessWave = 3

        var expected = s
        AdRules.noteInterstitialShown(&s)
        expected.lastInterstitialAtLevelsEnded = 9
        XCTAssertEqual(s, expected)

        expected = s
        AdRules.noteRewardedShown(&s, now: 1234.5)
        expected.lastRewardedAdAt = 1234.5
        XCTAssertEqual(s, expected)
        XCTAssertEqual(s.lastInterstitialAtLevelsEnded, 9)
        XCTAssertEqual(s.levelsEnded, 9)
        XCTAssertFalse(s.consentPrompted)
    }
}

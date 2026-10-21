import Foundation
import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

struct UAPPVoteBurstTests {
    @Test func symbolFollowsTheVote() {
        #expect(UAPPVoteBurst.symbol(isSelected: true) == "hand.thumbsup.fill")
        #expect(UAPPVoteBurst.symbol(isSelected: false) == "hand.thumbsdown.fill")
    }

    @Test func burstOnlyFiresAfterARecentTap() {
        let now = Date(timeIntervalSince1970: 1000)
        #expect(UAPPVoteBurst.shouldFire(armedAt: now.addingTimeInterval(-1), now: now, reduceMotion: false))
        #expect(!UAPPVoteBurst.shouldFire(armedAt: nil, now: now, reduceMotion: false))
        #expect(!UAPPVoteBurst.shouldFire(armedAt: now.addingTimeInterval(-11), now: now, reduceMotion: false))
        #expect(!UAPPVoteBurst.shouldFire(armedAt: now.addingTimeInterval(5), now: now, reduceMotion: false))
        #expect(!UAPPVoteBurst.shouldFire(armedAt: now.addingTimeInterval(-1), now: now, reduceMotion: true))
    }

    @Test func particlesStartHiddenAndLeaveOneAfterTheOther() {
        let resting = UAPPVoteBurst.particle(index: 0, progress: 0)
        #expect(resting.opacity == 0)
        #expect(resting.scale == 0)
        #expect(resting.offset.height == 0)

        let first = UAPPVoteBurst.particle(index: 0, progress: 1)
        let second = UAPPVoteBurst.particle(index: 1, progress: 1)
        #expect(first.opacity == 1)
        #expect(first.scale == 1)
        #expect(first.offset.height == -UAPPVoteBurst.rise)
        #expect(second.opacity == 0)
        #expect(first.offset.width == -second.offset.width)
    }

    @Test func particlesFadeAtTheEndOfTheRise() {
        let fading = UAPPVoteBurst.particle(index: 0, progress: 3.5)
        #expect(fading.opacity == 0.5)

        for index in 0 ..< UAPPVoteBurst.count {
            let finished = UAPPVoteBurst.particle(index: index, progress: UAPPVoteBurst.finalProgress)
            #expect(finished.opacity == 0)
            #expect(finished.offset.height == -UAPPVoteBurst.lifetime * UAPPVoteBurst.rise)
        }
    }

    @Test func removedVoteFallsInsteadOfRising() {
        let rising = UAPPVoteBurst.particle(index: 0, progress: 2)
        let falling = UAPPVoteBurst.particle(index: 0, progress: 2, rises: false)
        #expect(falling.offset.height == -rising.offset.height)
        #expect(falling.offset.height > 0)
        #expect(falling.opacity == rising.opacity)
    }

    @MainActor
    @Test func modifierRendersOverAButton() async {
        await render(Button("Votar") {}.uappVoteBurst(isSelected: true, tint: .orange))
        await render(Button("Votar") {}.uappVoteBurst(isSelected: false))
    }
}

import Foundation

/// Detects a double tap of one modifier key with no other keys or modifiers involved.
public struct DoubleTapDetector: Sendable {
    public enum Input: Sendable {
        case modifiers(targetDown: Bool, othersDown: Bool, time: TimeInterval)
        case keyDown(time: TimeInterval)
    }

    private let maxTapDuration: TimeInterval
    private let maxInterval: TimeInterval
    private var targetIsDown = false
    private var pressTime: TimeInterval = 0
    private var pressIsClean = false
    private var firstTapReleaseTime: TimeInterval?

    public init(maxTapDuration: TimeInterval = 0.3, maxInterval: TimeInterval = 0.4) {
        self.maxTapDuration = maxTapDuration
        self.maxInterval = maxInterval
    }

    public mutating func handle(_ input: Input) -> Bool {
        switch input {
        case .keyDown:
            reset()
            return false
        case let .modifiers(targetDown, othersDown, time):
            return handleModifiers(targetDown: targetDown, othersDown: othersDown, time: time)
        }
    }

    private mutating func handleModifiers(targetDown: Bool, othersDown: Bool, time: TimeInterval) -> Bool {
        if othersDown {
            reset()
            targetIsDown = targetDown
            return false
        }
        if targetDown == targetIsDown {
            return false
        }
        targetIsDown = targetDown
        if targetDown {
            pressTime = time
            pressIsClean = true
            if let first = firstTapReleaseTime, time - first > maxInterval {
                firstTapReleaseTime = nil
            }
            return false
        }
        guard pressIsClean, time - pressTime <= maxTapDuration else {
            reset()
            return false
        }
        pressIsClean = false
        if firstTapReleaseTime != nil {
            reset()
            return true
        }
        firstTapReleaseTime = time
        return false
    }

    private mutating func reset() {
        targetIsDown = false
        pressIsClean = false
        firstTapReleaseTime = nil
    }
}

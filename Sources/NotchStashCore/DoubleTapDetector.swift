import Foundation

/// Detects a double tap of the control key with no other keys or modifiers involved.
public struct DoubleTapDetector: Sendable {
    public enum Input: Sendable {
        case modifiers(controlDown: Bool, othersDown: Bool, time: TimeInterval)
        case keyDown(time: TimeInterval)
    }

    private let maxTapDuration: TimeInterval
    private let maxInterval: TimeInterval
    private var controlIsDown = false
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
        case let .modifiers(controlDown, othersDown, time):
            return handleModifiers(controlDown: controlDown, othersDown: othersDown, time: time)
        }
    }

    private mutating func handleModifiers(controlDown: Bool, othersDown: Bool, time: TimeInterval) -> Bool {
        if othersDown {
            reset()
            controlIsDown = controlDown
            return false
        }
        if controlDown == controlIsDown {
            return false
        }
        controlIsDown = controlDown
        if controlDown {
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
        controlIsDown = false
        pressIsClean = false
        firstTapReleaseTime = nil
    }
}

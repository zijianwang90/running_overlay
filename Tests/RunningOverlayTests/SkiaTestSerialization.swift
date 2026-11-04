import Foundation
import Testing

/// Serializes suites that create Skia raster/Metal contexts or Metal video
/// exports for tests.
///
/// Swift Testing runs test functions in parallel across suites; `@Suite(.serialized)`
/// only orders the tests inside one suite. Several Skia suites therefore create
/// contexts and render concurrently, and the full suite has crashed in Skia's
/// raster blur while three suites rendered at once. This trait installs one
/// process-wide gate so those suites take turns without serializing the rest of
/// the test target.
///
/// The trait deliberately keeps the default `isRecursive` value: overriding it
/// to `true` on a `TestScoping` suite trait traps in Swift Testing's
/// `Runner.Plan._recursivelyApplyTraits` while constructing the plan.
extension SuiteTrait where Self == SerializedSkiaRenderTrait {
    static var skiaSerialized: Self { SerializedSkiaRenderTrait() }
}

struct SerializedSkiaRenderTrait: SuiteTrait, TestScoping {
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        await SkiaTestGate.shared.acquire()
        defer { SkiaTestGate.shared.release() }
        try await function()
    }
}

/// Continuation-based gate: waiting tests suspend instead of blocking a
/// cooperative thread, so the holder can always resume.
private final class SkiaTestGate: @unchecked Sendable {
    static let shared = SkiaTestGate()

    private let lock = NSLock()
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        await withCheckedContinuation { continuation in
            let acquiredImmediately = lock.withLock { () -> Bool in
                if isBusy {
                    waiters.append(continuation)
                    return false
                }
                isBusy = true
                return true
            }
            if acquiredImmediately {
                continuation.resume()
            }
        }
    }

    func release() {
        let next = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            if waiters.isEmpty {
                isBusy = false
                return nil
            }
            return waiters.removeFirst()
        }
        next?.resume()
    }
}

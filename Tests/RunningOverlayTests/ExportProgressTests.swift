import Testing
@testable import RunningOverlay

struct ExportProgressTests {
    @Test func exportProgressUpdatesSegmentAndOverallProgress() {
        var state = ExportProgressState(
            title: "Export",
            items: [
                ExportProgressItem(index: 0, name: "a.mov", progress: 0, status: .queued),
                ExportProgressItem(index: 1, name: "b.mov", progress: 0, status: .queued)
            ]
        )

        state.update(OverlayExportProgress(segmentIndex: 0, segmentCount: 2, segmentName: "a.mov", segmentProgress: 0.5))
        #expect(state.items[0].status == .exporting)
        #expect(state.items[0].progress == 0.5)
        #expect(state.overallProgress == 0.25)

        state.update(OverlayExportProgress(segmentIndex: 1, segmentCount: 2, segmentName: "b.mov", segmentProgress: 0.25))
        #expect(state.items[0].status == .completed)
        #expect(state.items[0].progress == 1)
        #expect(state.items[1].status == .exporting)
        #expect(state.overallProgress == 0.625)
    }

    @Test func exportProgressCompletionAndFailureStates() {
        var state = ExportProgressState(
            title: "Export",
            items: [
                ExportProgressItem(index: 0, name: "a.mov", progress: 0.4, status: .exporting),
                ExportProgressItem(index: 1, name: "b.mov", progress: 0, status: .queued)
            ]
        )

        state.markFailed(message: "failed")
        #expect(state.failureMessage == "failed")
        #expect(state.items[0].status == .failed)

        state.markCompleted()
        #expect(state.completedCount == 2)
        #expect(state.overallProgress == 1)
    }

    @Test func exportProgressCanMarkQueuedItemsCancelled() {
        var state = ExportProgressState(
            title: "Export",
            items: [
                ExportProgressItem(index: 0, name: "a.mov", progress: 0.4, status: .exporting),
                ExportProgressItem(index: 1, name: "b.mov", progress: 0, status: .queued)
            ]
        )

        state.markCancelled()

        #expect(state.failureMessage == "Cancelled")
        #expect(state.items[0].status == .cancelled)
        #expect(state.items[1].status == .cancelled)
    }
}

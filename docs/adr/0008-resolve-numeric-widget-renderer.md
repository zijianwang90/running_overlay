# ADR 0008: One Numeric Fuse For Managed Metric Widgets

Date: 2026-09-29

## Status

Implemented for development validation; focused human review required before merge.

## Context

The Workflow panel needs to add, remove, and arrange Heart Rate, Pace, Distance,
and Elapsed Time without asking users to wire Fusion nodes. An initial graph
with one Numeric Fuse per metric and Merge nodes created and positioned the
components, but requesting the merged image repeatedly terminated Resolve 21.
Each Numeric node rendered alone. Changes to the Fuse's shared data cache did
not make the Merge graph stable in this host version.

## Decision

The managed Numeric overlay uses one `CT_SourceTool` Fuse with four independent
metric control groups. Heart Rate retains the original controls; Pace, Distance,
and Elapsed Time have their own enabled, position, size, label, font, and color
inputs. The Workflow panel stores an ordered, unique metric selection and one
of three layout presets. Applying a changed selection enables its metric groups
and sets preset positions. A routine synchronization updates only data paths
and origin; it leaves enabled, position, style, and animation inputs alone.

The composition transaction connects that Fuse directly to MediaOut. It can
remove Merge nodes and extra Numeric nodes owned by the unsuccessful development
graph. Unrelated Fusion nodes are not deleted.

## Consequences

Resolve rendered all four metrics in a single transparent 1080p frame, and a
remove/reorder/resync check retained an animated alpha control and edited size
and color. Per-metric controls remain available in Fusion. Visual order follows
the panel's preset positions; drawing order is fixed by metric if widgets are
later moved to overlap manually.

This limits the managed Numeric renderer to its four current metric types.
Future widget families can use their own renderer/OFX design after host render
behavior is verified. A preexisting single-widget composition whose Metric was
manually changed away from Heart Rate needs a reviewed migration path before
general release; the panel's legacy configuration has no record of that choice.

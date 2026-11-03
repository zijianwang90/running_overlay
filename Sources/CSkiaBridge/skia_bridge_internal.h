#ifndef SKIA_BRIDGE_INTERNAL_H
#define SKIA_BRIDGE_INTERNAL_H

#include "include/core/SkPixmap.h"
#include "include/core/SkRefCnt.h"
#include "include/core/SkSurface.h"
#include "include/gpu/ganesh/GrDirectContext.h"

#include <cstddef>
#include <cstdint>
#include <vector>

/// Shared state for the raster and Metal-backed bridge contexts. `grContext`
/// is null for the raster context.
struct SkiaBridgeContext {
    sk_sp<SkSurface> surface;
    SkPixmap pixmap;
    sk_sp<GrDirectContext> grContext;
    std::vector<uint8_t> readback;
};

/// Implemented in `skia_gpu.mm`.
const uint8_t *skb_read_pixels_impl(SkiaBridgeContext *ctx, size_t *rowBytes);
void skb_flush_impl(SkiaBridgeContext *ctx, bool sync);

#endif

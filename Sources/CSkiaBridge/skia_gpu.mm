#include "skia_bridge.h"
#include "skia_bridge_internal.h"

#include "include/core/SkColorSpace.h"
#include "include/core/SkColorType.h"
#include "include/core/SkImageInfo.h"
#include "include/gpu/ganesh/GrBackendSurface.h"
#include "include/gpu/ganesh/GrTypes.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#include "include/gpu/ganesh/mtl/GrMtlBackendContext.h"
#include "include/gpu/ganesh/mtl/GrMtlBackendSurface.h"
#include "include/gpu/ganesh/mtl/GrMtlDirectContext.h"

#import <Metal/Metal.h>

namespace {

sk_sp<GrDirectContext> makeMetalContext(
    const void *mtlDevice, const void *mtlQueue) {
    GrMtlBackendContext backendContext;
    backendContext.fDevice.retain((GrMTLHandle)mtlDevice);
    backendContext.fQueue.retain((GrMTLHandle)mtlQueue);
    return GrDirectContexts::MakeMetal(backendContext);
}

}  // namespace

SkiaBridgeContext *skb_create_gpu_context(
    int width, int height, const void *mtlDevice, const void *mtlQueue) {
    if (!mtlDevice || !mtlQueue || width <= 0 || height <= 0) {
        return nullptr;
    }
    auto grContext = makeMetalContext(mtlDevice, mtlQueue);
    if (!grContext) {
        return nullptr;
    }
    auto *ctx = new SkiaBridgeContext();
    ctx->grContext = std::move(grContext);
    return ctx;
}

SkiaBridgeContext *skb_create_gpu(
    int width, int height, const void *mtlDevice, const void *mtlQueue) {
    auto *ctx = skb_create_gpu_context(width, height, mtlDevice, mtlQueue);
    if (!ctx) {
        return nullptr;
    }

    auto info = SkImageInfo::Make(
        width, height, kBGRA_8888_SkColorType, kPremul_SkAlphaType);
    auto surface = SkSurfaces::RenderTarget(
        ctx->grContext.get(),
        skgpu::Budgeted::kNo,
        info,
        0,
        kTopLeft_GrSurfaceOrigin,
        nullptr);
    if (!surface) {
        delete ctx;
        return nullptr;
    }
    ctx->surface = std::move(surface);
    return ctx;
}

int skb_wrap_texture(
    SkiaBridgeContext *ctx, int width, int height, const void *mtlTexture) {
    if (!ctx || !ctx->grContext || !mtlTexture || width <= 0 || height <= 0) {
        return 0;
    }

    GrMtlTextureInfo textureInfo;
    textureInfo.fTexture.retain((GrMTLHandle)mtlTexture);
    auto backendRenderTarget =
        GrBackendRenderTargets::MakeMtl(width, height, textureInfo);
    if (!backendRenderTarget.isValid()) {
        return 0;
    }

    auto surface = SkSurfaces::WrapBackendRenderTarget(
        ctx->grContext.get(),
        backendRenderTarget,
        kTopLeft_GrSurfaceOrigin,
        kBGRA_8888_SkColorType,
        nullptr,
        nullptr);
    if (!surface) {
        return 0;
    }
    ctx->surface = std::move(surface);
    return 1;
}

void skb_flush_impl(SkiaBridgeContext *ctx, bool sync) {
    if (!ctx->grContext) {
        return;
    }
    ctx->grContext->flushAndSubmit(sync ? GrSyncCpu::kYes : GrSyncCpu::kNo);
}

const uint8_t *skb_read_pixels_impl(SkiaBridgeContext *ctx, size_t *rowBytes) {
    if (!ctx->grContext) {
        *rowBytes = 0;
        return nullptr;
    }
    ctx->grContext->flushAndSubmit(GrSyncCpu::kYes);

    auto info = SkImageInfo::Make(
        ctx->surface->width(),
        ctx->surface->height(),
        kBGRA_8888_SkColorType,
        kPremul_SkAlphaType);
    const size_t rowBytesValue = info.minRowBytes();
    ctx->readback.resize(rowBytesValue * (size_t)info.height());
    if (!ctx->surface->readPixels(
            info, ctx->readback.data(), rowBytesValue, 0, 0)) {
        *rowBytes = 0;
        return nullptr;
    }
    *rowBytes = rowBytesValue;
    return ctx->readback.data();
}

void skb_flush(SkiaBridgeContext *ctx, int sync) {
    skb_flush_impl(ctx, sync != 0);
}

const uint8_t *skb_read_pixels(SkiaBridgeContext *ctx, size_t *rowBytes) {
    return skb_read_pixels_impl(ctx, rowBytes);
}

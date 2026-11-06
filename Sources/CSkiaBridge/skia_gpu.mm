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

#if defined(SKB_ENABLE_GRAPHITE)
#include "include/gpu/graphite/ContextOptions.h"
#include "include/gpu/graphite/Image.h"
#include "include/gpu/graphite/ImageProvider.h"
#include <list>
#include <unordered_map>
#include "include/gpu/graphite/Recording.h"
#include "include/gpu/graphite/Surface.h"
#include "include/gpu/graphite/mtl/MtlBackendContext.h"
#include "include/gpu/graphite/mtl/MtlGraphiteTypes.h"
#endif
#include <cstring>
#import <Metal/Metal.h>

namespace {

#if defined(SKB_ENABLE_GRAPHITE)
// Graphite requires explicit raster-image uploads. Each recorder has its own
// bounded LRU so cached uploads cannot leak across contexts/command queues.
class BridgeGraphiteImageProvider final : public skgpu::graphite::ImageProvider {
public:
    explicit BridgeGraphiteImageProvider(bool *failed) : failed_(failed) {}

    sk_sp<SkImage> findOrCreate(skgpu::graphite::Recorder *recorder,
                               const SkImage *image, SkImage::RequiredProperties props) override {
        const uint64_t key = (uint64_t(image->uniqueID()) << 1) | uint64_t(props.fMipmapped);
        auto found = images_.find(key);
        if (found != images_.end()) {
            order_.splice(order_.end(), order_, found->second.order);
            return found->second.image;
        }
        auto uploaded = SkImages::TextureFromImage(recorder, image, props);
        if (!uploaded) { *failed_ = true; return nullptr; }
        const size_t estimate = size_t(image->width()) * size_t(image->height()) * 4
                              * (props.fMipmapped ? 2 : 1);
        if (estimate <= kMaxBytes) {
            while (!order_.empty() && (images_.size() >= 128 || bytes_ + estimate > kMaxBytes)) {
                auto old = images_.find(order_.front());
                bytes_ -= old->second.bytes;
                images_.erase(old);
                order_.pop_front();
            }
            order_.push_back(key);
            images_.emplace(key, Entry{uploaded, estimate, std::prev(order_.end())});
            bytes_ += estimate;
        }
        return uploaded;
    }
private:
    struct Entry {
        sk_sp<SkImage> image;
        size_t bytes;
        std::list<uint64_t>::iterator order;
    };
    static constexpr size_t kMaxBytes = 64 * 1024 * 1024;
    bool *failed_;
    size_t bytes_ = 0;
    std::list<uint64_t> order_;
    std::unordered_map<uint64_t, Entry> images_;
};
#endif

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

SkiaBridgeContext *skb_create_graphite_gpu_context(
    int width, int height, const void *mtlDevice, const void *mtlQueue) {
#if defined(SKB_ENABLE_GRAPHITE)
    if (!mtlDevice || !mtlQueue || width <= 0 || height <= 0) return nullptr;
    skgpu::graphite::MtlBackendContext backend;
    backend.fDevice.retain((CFTypeRef)mtlDevice);
    backend.fQueue.retain((CFTypeRef)mtlQueue);
    auto graphite = skgpu::graphite::ContextFactory::MakeMetal(backend, {});
    if (!graphite) return nullptr;
    auto *ctx = new SkiaBridgeContext();
    ctx->graphiteContext = std::move(graphite);
    skgpu::graphite::RecorderOptions options;
    options.fImageProvider = sk_make_sp<BridgeGraphiteImageProvider>(&ctx->gpuFailed);
    ctx->graphiteRecorder = ctx->graphiteContext->makeRecorder(options);
    if (!ctx->graphiteRecorder) { delete ctx; return nullptr; }
    return ctx;
#else
    return nullptr;
#endif
}

SkiaBridgeContext *skb_create_graphite_gpu(
    int width, int height, const void *mtlDevice, const void *mtlQueue) {
#if defined(SKB_ENABLE_GRAPHITE)
    auto *ctx = skb_create_graphite_gpu_context(width, height, mtlDevice, mtlQueue);
    if (!ctx) return nullptr;
    ctx->surface = SkSurfaces::RenderTarget(ctx->graphiteRecorder.get(),
        SkImageInfo::Make(width, height, kBGRA_8888_SkColorType, kPremul_SkAlphaType));
    if (!ctx->surface) { delete ctx; return nullptr; }
    return ctx;
#else
    return nullptr;
#endif
}

int skb_graphite_available(void) {
#if defined(SKB_ENABLE_GRAPHITE)
    return 1;
#else
    return 0;
#endif
}

int skb_gpu_succeeded(SkiaBridgeContext *ctx) {
    return ctx && !ctx->gpuFailed;
}

int skb_wrap_texture(
    SkiaBridgeContext *ctx, int width, int height, const void *mtlTexture) {
    if (!ctx || ctx->gpuFailed || !mtlTexture || width <= 0 || height <= 0) return 0;
#if defined(SKB_ENABLE_GRAPHITE)
    if (ctx->graphiteContext) {
        auto backend = skgpu::graphite::BackendTextures::MakeMetal(
            SkISize::Make(width, height), (CFTypeRef)mtlTexture);
        auto surface = SkSurfaces::WrapBackendTexture(
            ctx->graphiteRecorder.get(), backend, nullptr, nullptr);
        if (!surface) return 0;
        ctx->surface = std::move(surface);
        return 1;
    }
#endif
    if (!ctx->grContext) return 0;

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

void skb_release_gpu_surface(SkiaBridgeContext *ctx) {
    if (!ctx) return;
    bool isGPU = bool(ctx->grContext);
#if defined(SKB_ENABLE_GRAPHITE)
    isGPU = isGPU || bool(ctx->graphiteContext);
#endif
    if (isGPU) ctx->surface.reset();
}

void skb_flush_impl(SkiaBridgeContext *ctx, bool sync) {
#if defined(SKB_ENABLE_GRAPHITE)
    if (ctx->graphiteContext) {
        auto recording = ctx->graphiteRecorder->snap();
        if (recording) {
            skgpu::graphite::InsertRecordingInfo info;
            info.fRecording = recording.get();
            if (ctx->graphiteContext->insertRecording(info) != skgpu::graphite::InsertStatus::kSuccess) {
                ctx->gpuFailed = true;
            }
        }
        if (!ctx->graphiteContext->submit(skgpu::graphite::SubmitInfo(
                sync ? skgpu::graphite::SyncToCpu::kYes : skgpu::graphite::SyncToCpu::kNo))) {
            ctx->gpuFailed = true;
        }
        return;
    }
#endif
    if (!ctx->grContext) {
        return;
    }
    ctx->grContext->flushAndSubmit(sync ? GrSyncCpu::kYes : GrSyncCpu::kNo);
}

const uint8_t *skb_read_pixels_impl(SkiaBridgeContext *ctx, size_t *rowBytes) {
    *rowBytes = 0;
    if (ctx->gpuFailed || !ctx->surface) return nullptr;
#if defined(SKB_ENABLE_GRAPHITE)
    if (ctx->graphiteContext) {
        skb_flush_impl(ctx, false);
        struct ReadbackState { std::unique_ptr<const SkImage::AsyncReadResult> pixels; };
        auto result = std::make_shared<ReadbackState>();
        // The callback owns its reference, including when submission fails and
        // completion is deferred until context teardown.
        auto *callbackState = new std::shared_ptr<ReadbackState>(result);
        const auto info = SkImageInfo::Make(ctx->surface->width(), ctx->surface->height(),
                                           kBGRA_8888_SkColorType, kPremul_SkAlphaType);
        ctx->graphiteContext->asyncRescaleAndReadPixels(
            ctx->surface.get(), info, SkIRect::MakeWH(info.width(), info.height()),
            SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
            [](void *opaque, std::unique_ptr<const SkImage::AsyncReadResult> pixels) {
                std::unique_ptr<std::shared_ptr<ReadbackState>> state(
                    static_cast<std::shared_ptr<ReadbackState> *>(opaque));
                (*state)->pixels = std::move(pixels);
            }, callbackState);
        if (!ctx->graphiteContext->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes))
                || !result->pixels || ctx->gpuFailed) return nullptr;
        const size_t stride = info.minRowBytes();
        ctx->readback.resize(stride * info.height());
        for (int y = 0; y < info.height(); ++y) {
            std::memcpy(ctx->readback.data() + y * stride,
                static_cast<const uint8_t *>(result->pixels->data(0)) + y * result->pixels->rowBytes(0), stride);
        }
        *rowBytes = stride;
        return ctx->readback.data();
    }
#endif
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

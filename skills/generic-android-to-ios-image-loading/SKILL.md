---
name: generic-android-to-ios-image-loading
description: Guides migration of Android image loading libraries (Coil, Glide) with Compose/View integration, caching, transformations, and placeholder/error states to iOS equivalents (Kingfisher, Nuke, AsyncImage, SDWebImage) with SwiftUI integration, caching strategies, and image processing pipelines
type: generic
---

# generic-android-to-ios-image-loading

## Context

Android's image loading ecosystem revolves around Coil (Kotlin-first, Compose-native) and Glide (mature, View-based with Compose support). Both handle disk/memory caching, transformations, placeholder and error states, and lifecycle-aware loading out of the box. On iOS, the landscape splits between Kingfisher (most popular Swift library), Nuke (performance-focused with async/await), SDWebImage (Objective-C heritage, very mature), and SwiftUI's built-in `AsyncImage`. This skill maps Android image loading patterns to idiomatic iOS equivalents, preserving caching behavior, transformation pipelines, and error handling.

## Android Best Practices (Source Patterns)

### Coil in Jetpack Compose (Preferred)

```kotlin
// Basic image loading
@Composable
fun ProfileImage(imageUrl: String) {
    AsyncImage(
        model = imageUrl,
        contentDescription = "Profile",
        contentScale = ContentScale.Crop,
        modifier = Modifier
            .size(64.dp)
            .clip(CircleShape)
    )
}

// With placeholder, error, and crossfade
@Composable
fun ProductImage(imageUrl: String?) {
    AsyncImage(
        model = ImageRequest.Builder(LocalContext.current)
            .data(imageUrl)
            .crossfade(true)
            .memoryCachePolicy(CachePolicy.ENABLED)
            .diskCachePolicy(CachePolicy.ENABLED)
            .build(),
        contentDescription = "Product",
        placeholder = painterResource(R.drawable.placeholder),
        error = painterResource(R.drawable.error_image),
        contentScale = ContentScale.Fit,
        modifier = Modifier.fillMaxWidth()
    )
}

// SubcomposeAsyncImage for custom loading/error composables
@Composable
fun HeroImage(imageUrl: String) {
    SubcomposeAsyncImage(
        model = imageUrl,
        contentDescription = "Hero"
    ) {
        when (painter.state) {
            is AsyncImagePainter.State.Loading -> {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            }
            is AsyncImagePainter.State.Error -> {
                Icon(Icons.Default.BrokenImage, contentDescription = "Error")
            }
            else -> {
                SubcomposeAsyncImageContent(
                    contentScale = ContentScale.Crop
                )
            }
        }
    }
}
```

### Coil Transformations and Custom Configuration

```kotlin
// Custom transformations
AsyncImage(
    model = ImageRequest.Builder(LocalContext.current)
        .data(imageUrl)
        .transformations(
            CircleCropTransformation(),
            RoundedCornersTransformation(16f),
            BlurTransformation(LocalContext.current, radius = 10f)
        )
        .size(Size.ORIGINAL)
        .build(),
    contentDescription = null
)

// Global Coil configuration
class MyApplication : Application(), ImageLoaderFactory {
    override fun newImageLoader(): ImageLoader {
        return ImageLoader.Builder(this)
            .memoryCachePolicy(CachePolicy.ENABLED)
            .memoryCache {
                MemoryCache.Builder(this)
                    .maxSizePercent(0.25)
                    .build()
            }
            .diskCache {
                DiskCache.Builder()
                    .directory(cacheDir.resolve("image_cache"))
                    .maxSizeBytes(250L * 1024 * 1024) // 250 MB
                    .build()
            }
            .crossfade(true)
            .respectCacheHeaders(true)
            .build()
    }
}
```

### Glide (View-Based and Compose)

```kotlin
// Glide in Views
Glide.with(context)
    .load(imageUrl)
    .placeholder(R.drawable.placeholder)
    .error(R.drawable.error_image)
    .centerCrop()
    .circleCrop()
    .transform(RoundedCorners(16))
    .diskCacheStrategy(DiskCacheStrategy.ALL)
    .into(imageView)

// Glide in Compose (via integration library)
@Composable
fun GlideImage(imageUrl: String) {
    GlideImage(
        model = imageUrl,
        contentDescription = "Image",
        modifier = Modifier.size(100.dp)
    ) {
        it.placeholder(R.drawable.placeholder)
            .error(R.drawable.error_image)
            .centerCrop()
    }
}

// Preloading
Glide.with(context)
    .load(imageUrl)
    .preload()
```

### Key Android Patterns to Recognize

- `AsyncImage` / `SubcomposeAsyncImage` — Coil's Compose-native components
- `ImageRequest.Builder` — configuring cache policies, transformations, sizing
- `ImageLoader` / `ImageLoaderFactory` — global cache configuration
- `DiskCacheStrategy` — controls disk caching (ALL, AUTOMATIC, DATA, RESOURCE, NONE)
- `CachePolicy` — memory and disk cache enabling/disabling
- `crossfade(true)` — animated transitions on load
- `Glide.with(lifecycleOwner)` — lifecycle-aware image loading
- `.preload()` — prefetching images before display

## iOS Best Practices (Target Patterns)

### Kingfisher (Most Popular — Recommended Default)

```swift
import Kingfisher
import SwiftUI

// Basic SwiftUI usage
struct ProfileImage: View {
    let imageURL: URL?

    var body: some View {
        KFImage(imageURL)
            .resizable()
            .placeholder {
                ProgressView()
            }
            .onFailure { error in
                print("Failed: \(error.localizedDescription)")
            }
            .fade(duration: 0.3)
            .scaledToFill()
            .frame(width: 64, height: 64)
            .clipShape(Circle())
    }
}

// With error image and processing
struct ProductImage: View {
    let imageURL: URL?

    var body: some View {
        KFImage(imageURL)
            .resizable()
            .placeholder {
                Image("placeholder")
                    .resizable()
                    .scaledToFit()
            }
            .onFailureImage(KFCrossPlatformImage(named: "error_image"))
            .fade(duration: 0.25)
            .cacheMemoryOnly(false)
            .memoryCacheExpiration(.days(7))
            .diskCacheExpiration(.days(30))
            .scaledToFit()
    }
}

// Custom loading states (SubcomposeAsyncImage equivalent)
struct HeroImage: View {
    let imageURL: URL?

    var body: some View {
        KFImage(imageURL)
            .onProgress { receivedSize, totalSize in
                // Progress tracking
            }
            .placeholder {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onFailure { _ in }
            .onFailureImage(KFCrossPlatformImage(systemName: "photo"))
            .resizable()
            .scaledToFill()
    }
}
```

### Kingfisher Transformations and Configuration

```swift
// Image processing pipeline
struct RoundedImage: View {
    let imageURL: URL?

    var body: some View {
        KFImage(imageURL)
            .setProcessor(
                DownsamplingImageProcessor(size: CGSize(width: 200, height: 200))
                |> RoundCornerImageProcessor(cornerRadius: 16)
            )
            .resizable()
            .scaledToFill()
            .frame(width: 200, height: 200)
    }
}

// Blur transformation
KFImage(imageURL)
    .setProcessor(BlurImageProcessor(blurRadius: 10))

// Circle crop
KFImage(imageURL)
    .setProcessor(
        DownsamplingImageProcessor(size: CGSize(width: 64, height: 64))
        |> CroppingImageProcessor(size: CGSize(width: 64, height: 64))
        |> RoundCornerImageProcessor(cornerRadius: 32)
    )

// Global cache configuration (typically in AppDelegate/App init)
func configureKingfisherCache() {
    let cache = ImageCache.default
    cache.memoryStorage.config.totalCostLimit = 300 * 1024 * 1024 // 300 MB memory
    cache.memoryStorage.config.countLimit = 150
    cache.diskStorage.config.sizeLimit = 250 * 1024 * 1024 // 250 MB disk
    cache.diskStorage.config.expiration = .days(30)
    cache.memoryStorage.config.expiration = .days(7)

    // Clean expired cache on app launch
    cache.cleanExpiredDiskCache()
}

// Prefetching (equivalent to Glide preload)
let prefetcher = ImagePrefetcher(urls: imageURLs) {
    skippedResources, failedResources, completedResources in
    print("Prefetch done: \(completedResources.count) completed")
}
prefetcher.start()
```

### Nuke (Performance-Focused, Modern Swift)

```swift
import NukeUI
import Nuke

// SwiftUI integration with LazyImage
struct ProfileImageNuke: View {
    let imageURL: URL?

    var body: some View {
        LazyImage(url: imageURL) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFill()
            } else if state.error != nil {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .processors([
            .resize(size: CGSize(width: 64, height: 64), contentMode: .aspectFill),
            .circle
        ])
        .priority(.high)
        .frame(width: 64, height: 64)
        .clipShape(Circle())
    }
}

// Global pipeline configuration
func configureNuke() {
    let pipeline = ImagePipeline {
        $0.dataCache = try? DataCache(name: "com.app.images")
        $0.dataCachePolicy = .automatic
        $0.imageCache = ImageCache.shared
        // Progressive JPEG decoding
        $0.isProgressiveDecodingEnabled = true
        // Decompression on background queue
        $0.isDecompressionEnabled = true
    }
    ImagePipeline.shared = pipeline

    // Memory cache limits
    ImageCache.shared.costLimit = 300 * 1024 * 1024
    ImageCache.shared.countLimit = 100
}

// Prefetching with Nuke
let prefetcher = ImagePrefetcher()
prefetcher.startPrefetching(with: urls)
// Cancel when scrolled away
prefetcher.stopPrefetching(with: urls)
```

### AsyncImage (SwiftUI Native — Simple Use Cases Only)

```swift
// Basic usage — no caching beyond URLSession defaults
struct SimpleImage: View {
    let imageURL: URL?

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeIn(duration: 0.3)))
            case .failure:
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

### SDWebImage (Objective-C Heritage, Feature-Rich)

```swift
import SDWebImageSwiftUI

struct SDImage: View {
    let imageURL: URL?

    var body: some View {
        WebImage(url: imageURL) { image in
            image.resizable()
        } placeholder: {
            ProgressView()
        }
        .onFailure { error in
            print("Error: \(error.localizedDescription)")
        }
        .transition(.fade(duration: 0.3))
        .scaledToFill()
        .frame(width: 100, height: 100)
        .clipShape(Circle())
    }
}
```

## Migration Mapping Table

| Android (Coil/Glide) | Kingfisher | Nuke | AsyncImage (Native) |
|---|---|---|---|
| `AsyncImage` (Coil) | `KFImage(url)` | `LazyImage(url:)` | `AsyncImage(url:)` |
| `SubcomposeAsyncImage` | `KFImage` + `.placeholder { }` | `LazyImage { state in }` | `AsyncImage { phase in }` |
| `placeholder()` | `.placeholder { View }` | State-based in closure | `.empty` phase |
| `error()` | `.onFailureImage()` | `state.error` check | `.failure` phase |
| `crossfade(true)` | `.fade(duration:)` | `.transition(.fadeIn(...))` | `.transition(.opacity)` |
| `CircleCropTransformation` | `RoundCornerImageProcessor` | `.circle` processor | `.clipShape(Circle())` |
| `RoundedCornersTransformation` | `RoundCornerImageProcessor(cornerRadius:)` | `.resize + .roundedCorners` | `.clipShape(RoundedRectangle(...))` |
| `BlurTransformation` | `BlurImageProcessor` | `.gaussianBlur(...)` | No built-in |
| `DiskCacheStrategy.ALL` | `.diskCacheExpiration()` | `dataCachePolicy: .automatic` | URLSession cache only |
| `MemoryCache` config | `ImageCache.default.memoryStorage` | `ImageCache.shared.costLimit` | None configurable |
| `DiskCache` config | `ImageCache.default.diskStorage` | `DataCache(name:)` | None configurable |
| `.preload()` | `ImagePrefetcher(urls:)` | `ImagePrefetcher` | Not available |
| `ImageRequest.Builder.size()` | `DownsamplingImageProcessor` | `.resize(size:)` | Not available |
| `CachePolicy.DISABLED` | `.forceRefresh()` | `ImageRequest(url:, options: [.reloadIgnoringCachedData])` | Not available |
| `memoryCachePolicy` | `.cacheMemoryOnly()` | `imageCachePolicy` | Not configurable |
| `ImageLoaderFactory` | `ImageCache.default` config | `ImagePipeline` config | N/A |

## Common Pitfalls

1. **Using AsyncImage for production apps** — SwiftUI's native `AsyncImage` has no configurable disk/memory caching beyond `URLSession` defaults, no transformation pipeline, no prefetching, and no fine-grained cache control. Use it only for prototypes or trivial use cases. For production, use Kingfisher or Nuke.

2. **Not downsampling large images** — Both Android and iOS load full-resolution images into memory by default. On Android, Coil/Glide auto-resize to the view size. On iOS, you must explicitly use `DownsamplingImageProcessor` (Kingfisher) or `.resize(size:)` (Nuke) to avoid excessive memory usage, especially in lists.

3. **Missing cache configuration** — Android's Coil/Glide have sensible defaults. On iOS, Kingfisher and Nuke also have good defaults, but if your app loads many images (e.g., social feed), you should configure `totalCostLimit`, `countLimit`, disk size limits, and expiration policies explicitly.

4. **Forgetting prefetching in scrollable lists** — On Android, Coil and Glide handle list prefetching somewhat automatically with RecyclerView integration. On iOS, especially in `LazyVStack`/`LazyVGrid`, you need to manually use `ImagePrefetcher` to pre-warm images for upcoming cells.

5. **Not cancelling in-flight requests** — Coil/Glide cancel requests when the View is recycled. On iOS, `KFImage` and `LazyImage` handle cancellation automatically when the SwiftUI view is removed. However, if you use the imperative API (e.g., `KingfisherManager.shared.retrieveImage`), you must cancel manually.

6. **Cache key mismatches with transformations** — On Android, Coil includes transformations in the cache key automatically. On iOS, Kingfisher uses the processor identifier as part of the cache key. If you use custom processors, ensure they have unique `identifier` strings or you will get incorrect cached results.

7. **Memory warnings** — On Android, Coil/Glide respond to `onTrimMemory`. On iOS, Kingfisher and Nuke listen for `UIApplication.didReceiveMemoryWarningNotification` and clear memory caches automatically. If using a custom cache, subscribe to this notification yourself.

## Migration Checklist

- [ ] Audit all `AsyncImage` (Coil), `GlideImage`, and `Glide.with()` usages in the Android codebase
- [ ] Choose primary iOS image loading library (Kingfisher recommended for most projects)
- [ ] Add the library dependency via SPM (Kingfisher, NukeUI, or SDWebImageSwiftUI)
- [ ] Migrate basic image loading calls to `KFImage`/`LazyImage`
- [ ] Convert placeholder/error drawable references to SwiftUI placeholder views or asset images
- [ ] Map all `ImageRequest.Builder` transformations to equivalent processors
- [ ] Configure global cache settings (memory limit, disk limit, expiration) in app startup
- [ ] Replace `preload()` calls with `ImagePrefetcher` in list/collection contexts
- [ ] Verify downsampling is applied for images displayed at sizes smaller than their source resolution
- [ ] Test memory usage under heavy scrolling with Instruments (Allocations, Leaks)
- [ ] Verify cache clearing on memory warnings works correctly
- [ ] Test offline behavior to ensure disk cache serves previously loaded images

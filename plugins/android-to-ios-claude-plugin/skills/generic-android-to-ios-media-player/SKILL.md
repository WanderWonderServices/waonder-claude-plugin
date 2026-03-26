---
name: generic-android-to-ios-media-player
description: Guides migration of Android Media3/ExoPlayer (PlayerView, MediaItem, adaptive streaming, DRM, media sessions, background playback) to iOS AVFoundation/AVKit (AVPlayer, AVPlayerViewController, AVAsset, HLS, FairPlay DRM, MPNowPlayingInfoCenter, background audio) with player setup, streaming, DRM integration, picture-in-picture, and media controls
type: generic
---

# generic-android-to-ios-media-player

## Context

Android's Media3 library (successor to ExoPlayer) provides a comprehensive media playback framework supporting adaptive streaming (HLS, DASH, SmoothStreaming), DRM (Widevine), media session integration, and background playback. On iOS, AVFoundation and AVKit provide equivalent functionality through AVPlayer and AVPlayerViewController, with native HLS support, FairPlay DRM, MPNowPlayingInfoCenter for lock screen controls, and background audio modes. This skill maps Media3/ExoPlayer patterns to their iOS equivalents, covering the full media playback lifecycle.

## Android Best Practices (Source Patterns)

### Basic Player Setup with Media3

```kotlin
class VideoPlayerActivity : ComponentActivity() {

    private lateinit var player: ExoPlayer
    private lateinit var playerView: PlayerView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_video_player)
        playerView = findViewById(R.id.player_view)

        player = ExoPlayer.Builder(this)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                    .setUsage(C.USAGE_MEDIA)
                    .build(),
                /* handleAudioFocus = */ true
            )
            .setHandleAudioBecomingNoisy(true)
            .build()

        playerView.player = player

        val mediaItem = MediaItem.Builder()
            .setUri("https://example.com/video.m3u8")
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle("Sample Video")
                    .setArtist("Author")
                    .setArtworkUri(Uri.parse("https://example.com/thumb.jpg"))
                    .build()
            )
            .build()

        player.setMediaItem(mediaItem)
        player.prepare()
        player.playWhenReady = true
    }

    override fun onStop() {
        super.onStop()
        player.release()
    }
}
```

### Compose Player Integration

```kotlin
@Composable
fun VideoPlayer(
    uri: String,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val player = remember {
        ExoPlayer.Builder(context).build().apply {
            setMediaItem(MediaItem.fromUri(uri))
            prepare()
            playWhenReady = true
        }
    }

    DisposableEffect(Unit) {
        onDispose { player.release() }
    }

    AndroidView(
        factory = { ctx ->
            PlayerView(ctx).apply {
                this.player = player
                useController = true
                controllerAutoShow = true
            }
        },
        modifier = modifier
    )
}
```

### Playlist and Queue Management

```kotlin
fun setupPlaylist(player: ExoPlayer, items: List<VideoItem>) {
    val mediaItems = items.map { item ->
        MediaItem.Builder()
            .setUri(item.url)
            .setMediaId(item.id)
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(item.title)
                    .setArtist(item.artist)
                    .build()
            )
            .build()
    }

    player.setMediaItems(mediaItems)
    player.prepare()

    // Seek to specific item
    player.seekTo(/* mediaItemIndex = */ 2, /* positionMs = */ 0L)

    // Shuffle and repeat
    player.shuffleModeEnabled = true
    player.repeatMode = Player.REPEAT_MODE_ALL
}
```

### Player Listener and State Management

```kotlin
class PlayerViewModel(private val player: ExoPlayer) : ViewModel() {

    private val _playerState = MutableStateFlow(PlayerUiState())
    val playerState: StateFlow<PlayerUiState> = _playerState.asStateFlow()

    init {
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                _playerState.update {
                    it.copy(
                        isBuffering = playbackState == Player.STATE_BUFFERING,
                        isEnded = playbackState == Player.STATE_ENDED,
                        isReady = playbackState == Player.STATE_READY
                    )
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                _playerState.update { it.copy(isPlaying = isPlaying) }
            }

            override fun onPlayerError(error: PlaybackException) {
                _playerState.update {
                    it.copy(error = error.message, errorCode = error.errorCode)
                }
            }

            override fun onMediaMetadataChanged(metadata: MediaMetadata) {
                _playerState.update {
                    it.copy(title = metadata.title?.toString(), artist = metadata.artist?.toString())
                }
            }

            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int
            ) {
                updateProgress()
            }
        })

        // Periodic progress updates
        viewModelScope.launch {
            while (true) {
                delay(500)
                updateProgress()
            }
        }
    }

    private fun updateProgress() {
        _playerState.update {
            it.copy(
                currentPosition = player.currentPosition,
                duration = player.duration.takeIf { d -> d != C.TIME_UNSET } ?: 0L,
                bufferedPercentage = player.bufferedPercentage
            )
        }
    }
}

data class PlayerUiState(
    val isPlaying: Boolean = false,
    val isBuffering: Boolean = false,
    val isEnded: Boolean = false,
    val isReady: Boolean = false,
    val currentPosition: Long = 0L,
    val duration: Long = 0L,
    val bufferedPercentage: Int = 0,
    val title: String? = null,
    val artist: String? = null,
    val error: String? = null,
    val errorCode: Int? = null
)
```

### Adaptive Streaming with DRM (Widevine)

```kotlin
fun createDrmMediaItem(url: String, licenseUrl: String): MediaItem {
    return MediaItem.Builder()
        .setUri(url)
        .setDrmConfiguration(
            MediaItem.DrmConfiguration.Builder(C.WIDEVINE_UUID)
                .setLicenseUri(licenseUrl)
                .setLicenseRequestHeaders(
                    mapOf("Authorization" to "Bearer $token")
                )
                .setMultiSession(false)
                .build()
        )
        .build()
}

fun createPlayerWithDrm(context: Context): ExoPlayer {
    val drmSessionManagerProvider = DefaultDrmSessionManagerProvider().apply {
        setDrmHttpDataSourceFactory(
            DefaultHttpDataSource.Factory()
                .setDefaultRequestProperties(mapOf("User-Agent" to "MyApp/1.0"))
        )
    }

    return ExoPlayer.Builder(context)
        .setMediaSourceFactory(
            DefaultMediaSourceFactory(context)
                .setDrmSessionManagerProvider(drmSessionManagerProvider)
        )
        .build()
}
```

### Media Session and Background Playback

```kotlin
class PlaybackService : MediaSessionService() {

    private var mediaSession: MediaSession? = null
    private lateinit var player: ExoPlayer

    override fun onCreate() {
        super.onCreate()

        player = ExoPlayer.Builder(this)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .setUsage(C.USAGE_MEDIA)
                    .build(),
                true
            )
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()

        mediaSession = MediaSession.Builder(this, player)
            .setCallback(object : MediaSession.Callback {
                override fun onAddMediaItems(
                    session: MediaSession,
                    controller: MediaSession.ControllerInfo,
                    mediaItems: MutableList<MediaItem>
                ): ListenableFuture<MutableList<MediaItem>> {
                    val resolved = mediaItems.map { item ->
                        item.buildUpon()
                            .setUri(resolveMediaUri(item.mediaId))
                            .build()
                    }.toMutableList()
                    return Futures.immediateFuture(resolved)
                }
            })
            .build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }

    override fun onDestroy() {
        mediaSession?.run {
            player.release()
            release()
        }
        super.onDestroy()
    }
}

// AndroidManifest.xml
// <service
//     android:name=".PlaybackService"
//     android:foregroundServiceType="mediaPlayback"
//     android:exported="true">
//     <intent-filter>
//         <action android:name="androidx.media3.session.MediaSessionService" />
//     </intent-filter>
// </service>
```

### Picture-in-Picture

```kotlin
class PipVideoActivity : ComponentActivity() {

    private lateinit var player: ExoPlayer

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (player.isPlaying) {
            enterPictureInPictureMode(
                PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(16, 9))
                    .setAutoEnterEnabled(true)
                    .setSeamlessResizeEnabled(true)
                    .build()
            )
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPipMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPipMode, newConfig)
        playerView.useController = !isInPipMode
    }
}
```

## iOS Equivalent Patterns

### Basic AVPlayer Setup

```swift
import AVFoundation
import AVKit

class VideoPlayerViewController: UIViewController {
    private var player: AVPlayer!
    private var playerViewController: AVPlayerViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure audio session
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .moviePlayback,
            options: [.allowAirPlay]
        )
        try? AVAudioSession.sharedInstance().setActive(true)

        let url = URL(string: "https://example.com/video.m3u8")!
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        player = AVPlayer(playerItem: playerItem)
        player.allowsExternalPlayback = true

        playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.allowsPictureInPicturePlayback = true

        addChild(playerViewController)
        view.addSubview(playerViewController.view)
        playerViewController.view.frame = view.bounds
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerViewController.didMove(toParent: self)

        player.play()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        player.pause()
    }

    deinit {
        player.replaceCurrentItem(with: nil)
    }
}
```

### SwiftUI Video Player

```swift
import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .onAppear {
                setupAudioSession()
                let item = AVPlayerItem(url: url)
                player = AVPlayer(playerItem: item)
                player?.play()
            }
            .onDisappear {
                player?.pause()
                player?.replaceCurrentItem(with: nil)
            }
    }

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

// Custom player with overlay controls
struct CustomVideoPlayer: View {
    let url: URL
    @StateObject private var viewModel: PlayerViewModel

    init(url: URL) {
        self.url = url
        _viewModel = StateObject(wrappedValue: PlayerViewModel(url: url))
    }

    var body: some View {
        ZStack {
            VideoPlayer(player: viewModel.player)

            if viewModel.isBuffering {
                ProgressView()
                    .scaleEffect(2)
                    .tint(.white)
            }

            VStack {
                Spacer()
                PlayerControlsView(viewModel: viewModel)
                    .padding()
            }
        }
    }
}
```

### Playlist and Queue Management

```swift
class QueuePlayerManager: ObservableObject {
    let player: AVQueuePlayer
    @Published var currentIndex: Int = 0
    @Published var items: [AVPlayerItem] = []

    init(urls: [URL]) {
        let playerItems = urls.map { AVPlayerItem(url: $0) }
        self.items = playerItems
        self.player = AVQueuePlayer(items: playerItems)
    }

    func skipToItem(at index: Int) {
        guard index >= 0, index < items.count else { return }

        // AVQueuePlayer doesn't support random access natively.
        // Rebuild the queue from the target index.
        player.removeAllItems()
        for i in index..<items.count {
            let newItem = AVPlayerItem(url: (items[i].asset as! AVURLAsset).url)
            items[i] = newItem
            player.insert(newItem, after: nil)
        }
        currentIndex = index
        player.play()
    }

    func setupAdvanceObserver() {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let finishedItem = notification.object as? AVPlayerItem,
                  let index = self.items.firstIndex(of: finishedItem) else { return }
            self.currentIndex = index + 1
        }
    }
}
```

### Player State Observation

```swift
@Observable
class PlayerViewModel {
    let player: AVPlayer
    var isPlaying = false
    var isBuffering = false
    var currentTime: Double = 0
    var duration: Double = 0
    var bufferedTime: Double = 0
    var title: String?
    var error: String?

    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var bufferObservation: NSKeyValueObservation?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        self.player = AVPlayer(playerItem: item)
        setupObservers()
    }

    private func setupObservers() {
        // Periodic time observer (replaces ExoPlayer position polling)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            self.duration = self.player.currentItem?.duration.seconds ?? 0
            if self.duration.isNaN { self.duration = 0 }
        }

        // Playback status (replaces onPlaybackStateChanged)
        statusObservation = player.currentItem?.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self?.isBuffering = false
                case .failed:
                    self?.error = item.error?.localizedDescription
                default:
                    break
                }
            }
        }

        // Rate observation (replaces onIsPlayingChanged)
        rateObservation = player.observe(\.rate) { [weak self] player, _ in
            Task { @MainActor in
                self?.isPlaying = player.rate > 0
            }
        }

        // Buffer observation (replaces onBufferingChanged)
        bufferObservation = player.currentItem?.observe(\.isPlaybackLikelyToKeepUp) { [weak self] item, _ in
            Task { @MainActor in
                self?.isBuffering = !item.isPlaybackLikelyToKeepUp
            }
        }

        // End of playback (replaces STATE_ENDED)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
        }
    }

    func seek(to percentage: Double) {
        let targetTime = CMTime(seconds: duration * percentage, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func togglePlayback() {
        if isPlaying { player.pause() } else { player.play() }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        statusObservation?.invalidate()
        rateObservation?.invalidate()
        bufferObservation?.invalidate()
    }
}
```

### FairPlay DRM (Replaces Widevine)

```swift
class FairPlayHandler: NSObject, AVAssetResourceLoaderDelegate {
    private let licenseServerURL: URL
    private let authToken: String

    init(licenseServerURL: URL, authToken: String) {
        self.licenseServerURL = licenseServerURL
        self.authToken = authToken
    }

    func createDrmPlayerItem(url: URL) -> AVPlayerItem {
        // FairPlay uses a custom URL scheme (skd://)
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(self, queue: DispatchQueue(label: "fairplay"))
        return AVPlayerItem(asset: asset)
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let url = loadingRequest.request.url,
              url.scheme == "skd" else { return false }

        Task {
            do {
                // Step 1: Get the content identifier
                let contentId = url.host ?? ""
                let contentIdData = contentId.data(using: .utf8)!

                // Step 2: Request the application certificate from your server
                let certData = try await fetchApplicationCertificate()

                // Step 3: Create the SPC (Server Playback Context)
                let spcData = try await AVContentKeySession
                    .pendingExpiredSessionReports(
                        withAppIdentifier: certData,
                        storageDirectoryAt: FileManager.default.temporaryDirectory
                    )

                // Alternative: create SPC via streaming content key request
                let spc = try loadingRequest.streamingContentKeyRequestData(
                    forApp: certData,
                    contentIdentifier: contentIdData,
                    options: nil
                )

                // Step 4: Send SPC to license server, get CKC
                var request = URLRequest(url: licenseServerURL)
                request.httpMethod = "POST"
                request.httpBody = spc
                request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

                let (ckcData, _) = try await URLSession.shared.data(for: request)

                // Step 5: Provide the CKC to the loading request
                loadingRequest.dataRequest?.respond(with: ckcData)
                loadingRequest.finishLoading()
            } catch {
                loadingRequest.finishLoading(with: error)
            }
        }

        return true
    }

    private func fetchApplicationCertificate() async throws -> Data {
        let certURL = licenseServerURL.appendingPathComponent("certificate")
        let (data, _) = try await URLSession.shared.data(from: certURL)
        return data
    }
}

// Modern approach using AVContentKeySession (iOS 11.2+)
class ContentKeyManager: NSObject, AVContentKeySessionDelegate {
    private let keySession: AVContentKeySession
    private let licenseServerURL: URL

    init(licenseServerURL: URL) {
        self.licenseServerURL = licenseServerURL
        self.keySession = AVContentKeySession(keySystem: .fairPlayStreaming)
        super.init()
        keySession.setDelegate(self, queue: DispatchQueue(label: "content-key"))
    }

    func attachTo(asset: AVURLAsset) {
        keySession.addContentKeyRecipient(asset)
    }

    func contentKeySession(
        _ session: AVContentKeySession,
        didProvide keyRequest: AVContentKeyRequest
    ) {
        handleKeyRequest(keyRequest)
    }

    private func handleKeyRequest(_ keyRequest: AVContentKeyRequest) {
        Task {
            do {
                let certData = try await fetchApplicationCertificate()
                let contentId = keyRequest.identifier as! String
                let contentIdData = contentId.data(using: .utf8)!

                let spcData = try await keyRequest.makeStreamingContentKeyRequestData(
                    forApp: certData,
                    contentIdentifier: contentIdData
                )

                var request = URLRequest(url: licenseServerURL)
                request.httpMethod = "POST"
                request.httpBody = spcData

                let (ckcData, _) = try await URLSession.shared.data(for: request)

                let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
                keyRequest.processContentKeyResponse(keyResponse)
            } catch {
                keyRequest.processContentKeyResponseError(error)
            }
        }
    }
}
```

### Background Audio Playback

```swift
// 1. Enable background audio in Info.plist:
// <key>UIBackgroundModes</key>
// <array>
//     <string>audio</string>
// </array>

// 2. Configure audio session
class AudioPlayerService {
    static let shared = AudioPlayerService()
    private var player: AVPlayer?

    func configure() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playback,
            mode: .default,
            options: []
        )
        try? session.setActive(true)
    }

    func play(url: URL) {
        configure()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.play()
        setupNowPlaying()
        setupRemoteCommands()
    }

    // Now Playing Info (replaces MediaSession metadata)
    private func setupNowPlaying() {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: "Sample Track",
            MPMediaItemPropertyArtist: "Artist Name",
            MPMediaItemPropertyPlaybackDuration: player?.currentItem?.duration.seconds ?? 0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime().seconds ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: player?.rate ?? 0
        ]

        // Artwork
        if let image = UIImage(named: "album_art") {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // Remote commands (replaces MediaSession.Callback)
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipToNext()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipToPrevious()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let time = CMTime(seconds: event.positionTime, preferredTimescale: 600)
            self?.player?.seek(to: time)
            return .success
        }
    }

    // Audio interruption handling (replaces handleAudioBecomingNoisy)
    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            switch type {
            case .began:
                self?.player?.pause()
            case .ended:
                if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self?.player?.play()
                    }
                }
            @unknown default:
                break
            }
        }

        // Route change (audio becoming noisy - e.g., headphones unplugged)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                  reason == .oldDeviceUnavailable else { return }
            self?.player?.pause()
        }
    }

    private func skipToNext() { /* implement queue advance */ }
    private func skipToPrevious() { /* implement queue rewind */ }
}
```

### Picture-in-Picture

```swift
import AVKit

class PiPVideoViewController: UIViewController, AVPictureInPictureControllerDelegate {
    private var player: AVPlayer!
    private var playerLayer: AVPlayerLayer!
    private var pipController: AVPictureInPictureController?

    override func viewDidLoad() {
        super.viewDidLoad()

        player = AVPlayer(url: URL(string: "https://example.com/video.m3u8")!)

        playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)

        // Setup PiP
        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipController = AVPictureInPictureController(playerLayer: playerLayer)
            pipController?.delegate = self
            pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        }

        player.play()
    }

    func pictureInPictureControllerWillStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        // Hide custom controls
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        // Show custom controls
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // Restore UI when returning from PiP
        completionHandler(true)
    }
}

// SwiftUI PiP with AVPlayerViewController
struct PiPVideoPlayer: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
```

### Subtitles and Track Selection

```swift
func selectSubtitleTrack(player: AVPlayer, languageCode: String) {
    guard let item = player.currentItem,
          let group = item.asset.mediaSelectionGroup(
              forMediaCharacteristic: .legible
          ) else { return }

    let locale = Locale(identifier: languageCode)
    let options = AVMediaSelectionGroup.mediaSelectionOptions(
        from: group.options,
        with: locale
    )

    if let option = options.first {
        item.select(option, in: group)
    } else {
        // Disable subtitles
        item.select(nil, in: group)
    }
}

func selectAudioTrack(player: AVPlayer, languageCode: String) {
    guard let item = player.currentItem,
          let group = item.asset.mediaSelectionGroup(
              forMediaCharacteristic: .audible
          ) else { return }

    let locale = Locale(identifier: languageCode)
    let options = AVMediaSelectionGroup.mediaSelectionOptions(
        from: group.options,
        with: locale
    )

    if let option = options.first {
        item.select(option, in: group)
    }
}
```

## Concept Mapping Table

| Android (Media3/ExoPlayer) | iOS (AVFoundation/AVKit) | Notes |
|---|---|---|
| `ExoPlayer` | `AVPlayer` | Core player object |
| `PlayerView` | `AVPlayerViewController` | Built-in player UI |
| `ExoPlayer.Builder(context).build()` | `AVPlayer(playerItem:)` | Player construction |
| `MediaItem.fromUri(uri)` | `AVPlayerItem(url:)` | Media item creation |
| `player.setMediaItem(item)` | `player.replaceCurrentItem(with:)` | Set single item |
| `player.setMediaItems(items)` | `AVQueuePlayer(items:)` | Playlist/queue |
| `player.prepare()` | Automatic on play | No explicit prepare needed |
| `player.playWhenReady = true` | `player.play()` | Start playback |
| `player.seekTo(positionMs)` | `player.seek(to: CMTime)` | Seek; use CMTime on iOS |
| `Player.Listener.onPlaybackStateChanged` | KVO on `playerItem.status` | Observe via NSKeyValueObservation |
| `Player.Listener.onIsPlayingChanged` | KVO on `player.rate` | rate > 0 means playing |
| `Player.STATE_BUFFERING` | `!item.isPlaybackLikelyToKeepUp` | Buffering state |
| `Player.STATE_ENDED` | `.AVPlayerItemDidPlayToEndTime` notification | End of playback |
| `Player.Listener.onPlayerError` | KVO on `item.status == .failed` | Check `item.error` |
| `MediaMetadata` | `MPNowPlayingInfoCenter.nowPlayingInfo` | Lock screen metadata |
| `MediaSession` | `MPRemoteCommandCenter` | Media control commands |
| `MediaSessionService` | Background audio mode + `MPRemoteCommandCenter` | No service abstraction on iOS |
| `AudioAttributes` | `AVAudioSession.setCategory(_:mode:)` | Audio session config |
| `handleAudioBecomingNoisy` | `AVAudioSession.routeChangeNotification` | Headphone unplug |
| `C.WAKE_MODE_NETWORK` | Background audio entitlement | Keeps network alive during bg playback |
| DRM: Widevine (`C.WIDEVINE_UUID`) | DRM: FairPlay Streaming | Different DRM systems |
| `DrmConfiguration.Builder(widevineUuid)` | `AVContentKeySession(keySystem: .fairPlayStreaming)` | DRM session setup |
| `DrmConfiguration.setLicenseUri(url)` | Custom `AVContentKeySessionDelegate` | License server request |
| HLS / DASH / SmoothStreaming | HLS only | iOS supports HLS natively; no DASH/SS |
| `PictureInPictureParams.Builder()` | `AVPictureInPictureController` | PiP setup |
| `enterPictureInPictureMode()` | `pipController.startPictureInPicture()` | Or automatic with `canStartAutomatically` |
| `player.shuffleModeEnabled` | Manual queue shuffle | AVQueuePlayer has no built-in shuffle |
| `player.repeatMode` | `actionAtItemEnd = .none` + re-seek | Manual repeat implementation |
| `player.setPlaybackSpeed(speed)` | `player.rate = speed` | Playback speed |

## Common Pitfalls

1. **No DASH/SmoothStreaming on iOS** -- iOS only supports HLS natively. If your Android app uses DASH, you must transcode/repackage content as HLS for iOS or use a third-party player SDK.

2. **Audio session must be configured** -- Unlike Android where `AudioAttributes` are set on the player, iOS requires configuring `AVAudioSession` separately before playback. Forgetting this causes silent playback when the phone is in silent mode or the app is backgrounded.

3. **CMTime vs milliseconds** -- Android uses milliseconds (`Long`) for positions and durations. iOS uses `CMTime` which stores a value/timescale pair. Always check `duration.isValid` and `!duration.seconds.isNaN` before using.

4. **No built-in shuffle/repeat** -- `AVQueuePlayer` does not support shuffle mode or repeat mode natively. You must implement these by manually managing the queue order and re-inserting items.

5. **FairPlay vs Widevine** -- iOS uses FairPlay DRM exclusively. You cannot use Widevine on iOS. Your DRM license server must support FairPlay key delivery. The integration flow (SPC/CKC exchange) differs significantly from Widevine.

6. **Background playback requires both entitlement and audio session** -- Enable the "Audio, AirPlay, and Picture in Picture" background mode in Xcode capabilities AND set the audio session category to `.playback`. Missing either causes background audio to stop.

7. **KVO vs Listener pattern** -- ExoPlayer uses a listener interface. AVPlayer uses KVO (Key-Value Observing). Always store `NSKeyValueObservation` references and invalidate them on cleanup to prevent memory leaks and crashes.

8. **Now Playing info must be updated continuously** -- `MPNowPlayingInfoCenter.nowPlayingInfo` must be updated whenever position, rate, or metadata changes. Stale data causes incorrect lock screen progress.

9. **PiP requires AVPlayerLayer or AVPlayerViewController** -- PiP only works with `AVPlayerLayer` or `AVPlayerViewController`. Custom rendering surfaces (e.g., `AVSampleBufferDisplayLayer`) require additional setup.

10. **Player item is single-use** -- An `AVPlayerItem` can only be associated with one `AVPlayer` at a time and should not be reused after playback ends. Create a new `AVPlayerItem` for replays.

## Migration Checklist

- [ ] Replace `ExoPlayer.Builder` with `AVPlayer(playerItem:)` initialization
- [ ] Replace `PlayerView` with `AVPlayerViewController` (or SwiftUI `VideoPlayer`)
- [ ] Configure `AVAudioSession` with appropriate category and mode (replaces `AudioAttributes`)
- [ ] Replace `MediaItem.Builder` with `AVPlayerItem(url:)` / `AVURLAsset`
- [ ] Convert `Player.Listener` callbacks to KVO observations and NotificationCenter observers
- [ ] Replace position polling with `addPeriodicTimeObserver(forInterval:queue:)`
- [ ] Replace `MediaSession` with `MPRemoteCommandCenter` for play/pause/skip commands
- [ ] Replace `MediaMetadata` with `MPNowPlayingInfoCenter.default().nowPlayingInfo`
- [ ] Replace `MediaSessionService` with background audio mode entitlement
- [ ] Replace Widevine DRM with FairPlay Streaming via `AVContentKeySession`
- [ ] Implement audio interruption handling via `AVAudioSession.interruptionNotification`
- [ ] Implement route change handling (audio becoming noisy) via `AVAudioSession.routeChangeNotification`
- [ ] Replace `enterPictureInPictureMode()` with `AVPictureInPictureController`
- [ ] Implement manual shuffle/repeat logic for `AVQueuePlayer` (no built-in support)
- [ ] Replace DASH/SmoothStreaming content with HLS
- [ ] Add subtitle/audio track selection via `AVMediaSelectionGroup`
- [ ] Enable "Audio, AirPlay, and Picture in Picture" in Xcode background modes
- [ ] Verify `CMTime` handling (check `.isValid`, `.isNumeric` before using `.seconds`)

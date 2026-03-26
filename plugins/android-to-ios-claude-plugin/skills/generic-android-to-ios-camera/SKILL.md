---
name: generic-android-to-ios-camera
description: Guides migration of Android CameraX (CameraProvider, Preview, ImageCapture, ImageAnalysis, VideoCapture use cases) to iOS AVFoundation Camera (AVCaptureSession, AVCaptureDevice, AVCapturePhotoOutput, AVCaptureVideoDataOutput) with camera setup, preview rendering, photo capture, video recording, barcode scanning, face detection, and permissions
type: generic
---

# generic-android-to-ios-camera

## Context

Android's CameraX library abstracts the complexity of Camera2 into high-level use cases: Preview, ImageCapture, ImageAnalysis, and VideoCapture. It handles device-specific quirks, lifecycle binding, and rotation automatically. On iOS, AVFoundation provides the camera API through `AVCaptureSession` with input/output objects. While more verbose than CameraX, AVFoundation offers fine-grained control over capture pipelines. This skill provides a systematic migration path from CameraX patterns to their iOS equivalents, covering the full camera lifecycle from permissions through capture to analysis.

## Android Best Practices (Source Patterns)

### CameraX Setup with Preview and Capture

```kotlin
class CameraFragment : Fragment() {

    private lateinit var cameraProvider: ProcessCameraProvider
    private lateinit var imageCapture: ImageCapture
    private lateinit var preview: Preview
    private lateinit var previewView: PreviewView

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        previewView = view.findViewById(R.id.preview_view)
        startCamera()
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(requireContext())
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()

            preview = Preview.Builder()
                .setTargetAspectRatio(AspectRatio.RATIO_16_9)
                .build()
                .also { it.surfaceProvider = previewView.surfaceProvider }

            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                .setTargetRotation(requireView().display.rotation)
                .setFlashMode(ImageCapture.FLASH_MODE_AUTO)
                .build()

            val cameraSelector = CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_BACK)
                .build()

            try {
                cameraProvider.unbindAll()
                val camera = cameraProvider.bindToLifecycle(
                    viewLifecycleOwner,
                    cameraSelector,
                    preview,
                    imageCapture
                )

                // Access camera controls
                val cameraControl = camera.cameraControl
                val cameraInfo = camera.cameraInfo

                // Tap to focus
                previewView.setOnTouchListener { _, event ->
                    val factory = previewView.meteringPointFactory
                    val point = factory.createPoint(event.x, event.y)
                    val action = FocusMeteringAction.Builder(point).build()
                    cameraControl.startFocusAndMetering(action)
                    true
                }
            } catch (e: Exception) {
                Log.e("Camera", "Binding failed", e)
            }
        }, ContextCompat.getMainExecutor(requireContext()))
    }
}
```

### Compose Camera Preview

```kotlin
@Composable
fun CameraPreview(
    modifier: Modifier = Modifier,
    onImageCaptured: (Uri) -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val previewView = remember { PreviewView(context) }
    val imageCapture = remember {
        ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
            .build()
    }

    LaunchedEffect(Unit) {
        val cameraProvider = ProcessCameraProvider.getInstance(context).await()
        val preview = Preview.Builder().build().also {
            it.surfaceProvider = previewView.surfaceProvider
        }

        cameraProvider.unbindAll()
        cameraProvider.bindToLifecycle(
            lifecycleOwner,
            CameraSelector.DEFAULT_BACK_CAMERA,
            preview,
            imageCapture
        )
    }

    AndroidView(factory = { previewView }, modifier = modifier)
}
```

### Photo Capture

```kotlin
fun capturePhoto(
    imageCapture: ImageCapture,
    context: Context,
    onCaptured: (Uri) -> Unit,
    onError: (Exception) -> Unit
) {
    val photoFile = File(
        context.cacheDir,
        "photo_${System.currentTimeMillis()}.jpg"
    )
    val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile)
        .setMetadata(
            ImageCapture.Metadata().apply {
                isReversedHorizontal = false // Mirror for front camera
            }
        )
        .build()

    imageCapture.takePicture(
        outputOptions,
        ContextCompat.getMainExecutor(context),
        object : ImageCapture.OnImageSavedCallback {
            override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                onCaptured(Uri.fromFile(photoFile))
            }

            override fun onError(exception: ImageCaptureException) {
                onError(exception)
            }
        }
    )
}

// In-memory capture (without saving to file)
fun captureToMemory(
    imageCapture: ImageCapture,
    context: Context,
    onCaptured: (ImageProxy) -> Unit
) {
    imageCapture.takePicture(
        ContextCompat.getMainExecutor(context),
        object : ImageCapture.OnImageCapturedCallback() {
            override fun onCaptureSuccess(image: ImageProxy) {
                // Process the image
                val buffer = image.planes[0].buffer
                val bytes = ByteArray(buffer.remaining())
                buffer.get(bytes)
                onCaptured(image)
                image.close() // Must close when done
            }

            override fun onError(exception: ImageCaptureException) {
                Log.e("Camera", "Capture failed", exception)
            }
        }
    )
}
```

### Video Recording

```kotlin
class VideoRecordingFragment : Fragment() {

    private lateinit var videoCapture: VideoCapture<Recorder>
    private var activeRecording: Recording? = null

    private fun setupVideoCapture() {
        val recorder = Recorder.Builder()
            .setQualitySelector(
                QualitySelector.from(
                    Quality.FHD,
                    FallbackStrategy.higherQualityOrLowerThan(Quality.FHD)
                )
            )
            .build()

        videoCapture = VideoCapture.withOutput(recorder)

        // Bind to lifecycle with preview
        cameraProvider.bindToLifecycle(
            viewLifecycleOwner,
            CameraSelector.DEFAULT_BACK_CAMERA,
            preview,
            videoCapture
        )
    }

    @SuppressLint("MissingPermission")
    fun startRecording() {
        val outputFile = File(requireContext().cacheDir, "video_${System.currentTimeMillis()}.mp4")
        val outputOptions = FileOutputOptions.Builder(outputFile).build()

        activeRecording = videoCapture.output
            .prepareRecording(requireContext(), outputOptions)
            .withAudioEnabled()
            .start(ContextCompat.getMainExecutor(requireContext())) { event ->
                when (event) {
                    is VideoRecordEvent.Start -> {
                        // Recording started
                    }
                    is VideoRecordEvent.Status -> {
                        val stats = event.recordingStats
                        val durationMs = stats.recordedDurationNanos / 1_000_000
                        val sizeBytes = stats.numBytesRecorded
                    }
                    is VideoRecordEvent.Finalize -> {
                        if (event.hasError()) {
                            Log.e("Video", "Error: ${event.error}")
                        } else {
                            val uri = event.outputResults.outputUri
                            // Video saved successfully
                        }
                    }
                }
            }
    }

    fun stopRecording() {
        activeRecording?.stop()
        activeRecording = null
    }
}
```

### Image Analysis (Frame Processing)

```kotlin
private fun setupImageAnalysis() {
    val imageAnalyzer = ImageAnalysis.Builder()
        .setTargetResolution(Size(1280, 720))
        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
        .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888)
        .build()
        .also {
            it.setAnalyzer(cameraExecutor) { imageProxy ->
                processImage(imageProxy)
                imageProxy.close() // Must close when done
            }
        }

    cameraProvider.bindToLifecycle(
        viewLifecycleOwner,
        CameraSelector.DEFAULT_BACK_CAMERA,
        preview,
        imageAnalyzer
    )
}

private fun processImage(imageProxy: ImageProxy) {
    val rotationDegrees = imageProxy.imageInfo.rotationDegrees
    val buffer = imageProxy.planes[0].buffer
    // Process frame data...
}
```

### Barcode Scanning with ML Kit

```kotlin
private fun setupBarcodeScanner() {
    val scanner = BarcodeScanning.getClient(
        BarcodeScannerOptions.Builder()
            .setBarcodeFormats(
                Barcode.FORMAT_QR_CODE,
                Barcode.FORMAT_EAN_13,
                Barcode.FORMAT_CODE_128
            )
            .build()
    )

    val imageAnalyzer = ImageAnalysis.Builder()
        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
        .build()
        .also {
            it.setAnalyzer(cameraExecutor) { imageProxy ->
                val mediaImage = imageProxy.image ?: run {
                    imageProxy.close()
                    return@setAnalyzer
                }
                val inputImage = InputImage.fromMediaImage(
                    mediaImage,
                    imageProxy.imageInfo.rotationDegrees
                )

                scanner.process(inputImage)
                    .addOnSuccessListener { barcodes ->
                        for (barcode in barcodes) {
                            val value = barcode.rawValue
                            val format = barcode.format
                            val bounds = barcode.boundingBox
                            // Handle barcode
                        }
                    }
                    .addOnCompleteListener {
                        imageProxy.close()
                    }
            }
        }
}
```

### Camera Permissions

```kotlin
class CameraPermissionHandler(private val activity: ComponentActivity) {

    private val permissionLauncher = activity.registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val cameraGranted = permissions[Manifest.permission.CAMERA] == true
        val audioGranted = permissions[Manifest.permission.RECORD_AUDIO] == true
        if (cameraGranted) {
            onPermissionGranted()
        } else {
            onPermissionDenied()
        }
    }

    fun requestCameraPermission() {
        when {
            ContextCompat.checkSelfPermission(
                activity, Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_GRANTED -> {
                onPermissionGranted()
            }
            activity.shouldShowRequestPermissionRationale(Manifest.permission.CAMERA) -> {
                showRationale()
            }
            else -> {
                permissionLauncher.launch(
                    arrayOf(
                        Manifest.permission.CAMERA,
                        Manifest.permission.RECORD_AUDIO
                    )
                )
            }
        }
    }
}
```

### Zoom, Flash, and Camera Switch

```kotlin
fun setupCameraControls(camera: Camera) {
    val cameraControl = camera.cameraControl
    val cameraInfo = camera.cameraInfo

    // Zoom
    cameraControl.setLinearZoom(0.5f) // 0f to 1f
    // Or pinch-to-zoom
    val scaleGestureDetector = ScaleGestureDetector(context,
        object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                val currentZoom = cameraInfo.zoomState.value?.zoomRatio ?: 1f
                val delta = detector.scaleFactor
                cameraControl.setZoomRatio(currentZoom * delta)
                return true
            }
        }
    )

    // Flash
    cameraControl.enableTorch(true)  // Torch mode
    // imageCapture.flashMode = ImageCapture.FLASH_MODE_ON  // Flash on capture

    // Switch camera
    fun switchCamera() {
        currentLensFacing = if (currentLensFacing == CameraSelector.LENS_FACING_BACK) {
            CameraSelector.LENS_FACING_FRONT
        } else {
            CameraSelector.LENS_FACING_BACK
        }
        bindCamera() // Rebind with new selector
    }
}
```

## iOS Equivalent Patterns

### AVCaptureSession Setup with Preview

```swift
import AVFoundation

class CameraManager: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session")

    @Published var isSessionRunning = false
    @Published var currentPosition: AVCaptureDevice.Position = .back

    func configure() {
        sessionQueue.async { [self] in
            captureSession.beginConfiguration()
            captureSession.sessionPreset = .photo // Equivalent to RATIO_16_9

            // Add video input
            guard let videoDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ),
            let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
            else { return }

            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                videoDeviceInput = videoInput
            }

            // Add photo output
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                photoOutput.isHighResolutionCaptureEnabled = true
                photoOutput.maxPhotoQualityPrioritization = .quality
            }

            captureSession.commitConfiguration()
            captureSession.startRunning()

            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
}
```

### Camera Preview in SwiftUI

```swift
import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

// Usage in SwiftUI
struct CameraScreen: View {
    @StateObject private var camera = CameraManager()

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.captureSession)
                .ignoresSafeArea()

            VStack {
                Spacer()
                HStack(spacing: 40) {
                    Button("Switch") { camera.switchCamera() }
                    Button("Capture") { camera.capturePhoto() }
                    Button("Flash") { camera.toggleFlash() }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { camera.configure() }
        .onDisappear { camera.stop() }
    }
}
```

### Photo Capture

```swift
extension CameraManager: AVCapturePhotoCaptureDelegate {

    func capturePhoto() {
        sessionQueue.async { [self] in
            let settings = AVCapturePhotoSettings()

            // Flash mode (equivalent to ImageCapture.FLASH_MODE_AUTO)
            if photoOutput.supportedFlashModes.contains(.auto) {
                settings.flashMode = .auto
            }

            // High resolution
            settings.isHighResolutionPhotoEnabled = true

            // Photo quality prioritization (equivalent to CAPTURE_MODE_MAXIMIZE_QUALITY)
            settings.photoQualityPrioritization = .quality

            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // Delegate callback - photo captured
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            print("Photo capture error: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else { return }

        // Save to file (equivalent to OutputFileOptions)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("photo_\(Date().timeIntervalSince1970).jpg")
        try? imageData.write(to: tempURL)

        // Or get UIImage directly (equivalent to in-memory capture)
        let image = UIImage(data: imageData)

        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }

    // Mirror front camera (equivalent to Metadata.isReversedHorizontal)
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        // Front camera mirroring is handled automatically by AVFoundation
        // when using AVCapturePhotoOutput
    }
}

// Save to photo library
import Photos

func saveToPhotoLibrary(imageData: Data) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized else { return }

        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: nil)
        } completionHandler: { success, error in
            if success {
                print("Photo saved to library")
            }
        }
    }
}
```

### Video Recording

```swift
class VideoRecordingManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "video.session")

    @Published var isRecording = false
    @Published var recordedURL: URL?
    @Published var recordingDuration: TimeInterval = 0

    func configure() {
        sessionQueue.async { [self] in
            captureSession.beginConfiguration()
            captureSession.sessionPreset = .high

            // Video input
            guard let videoDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back
            ),
            let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
            else { return }

            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }

            // Audio input (equivalent to .withAudioEnabled())
            guard let audioDevice = AVCaptureDevice.default(for: .audio),
                  let audioInput = try? AVCaptureDeviceInput(device: audioDevice)
            else { return }

            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }

            // Movie output
            if captureSession.canAddOutput(movieOutput) {
                captureSession.addOutput(movieOutput)

                // Set video stabilization
                if let connection = movieOutput.connection(with: .video),
                   connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }

            captureSession.commitConfiguration()
            captureSession.startRunning()
        }
    }

    func startRecording() {
        guard !isRecording else { return }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("video_\(Date().timeIntervalSince1970).mov")

        sessionQueue.async { [self] in
            movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            DispatchQueue.main.async { self.isRecording = true }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        movieOutput.stopRecording()
    }

    // Delegate callback
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isRecording = false
            if let error {
                print("Recording error: \(error.localizedDescription)")
            } else {
                self.recordedURL = outputFileURL
            }
        }
    }

    // Recording progress (equivalent to VideoRecordEvent.Status)
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        DispatchQueue.main.async {
            self.recordingDuration = self.movieOutput.recordedDuration.seconds
        }
    }
}
```

### Frame-by-Frame Analysis (Image Analysis Equivalent)

```swift
class FrameAnalyzer: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let analysisQueue = DispatchQueue(label: "frame.analysis")

    @Published var analysisResult: String = ""

    func configure() {
        captureSession.beginConfiguration()

        guard let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ),
        let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
        else { return }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        // Video data output (equivalent to ImageAnalysis)
        videoDataOutput.setSampleBufferDelegate(self, queue: analysisQueue)

        // STRATEGY_KEEP_ONLY_LATEST equivalent
        videoDataOutput.alwaysDiscardsLateVideoFrames = true

        // Pixel format (equivalent to OUTPUT_IMAGE_FORMAT_YUV_420_888)
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]

        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)

            // Set resolution (equivalent to setTargetResolution)
            if let connection = videoDataOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
            }
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    // Frame callback (equivalent to ImageAnalysis.Analyzer)
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Get rotation (equivalent to imageProxy.imageInfo.rotationDegrees)
        let rotation = connection.videoOrientation

        // Process frame
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // ... process ciImage

        DispatchQueue.main.async {
            self.analysisResult = "Processed frame"
        }
    }

    // Dropped frame callback
    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Frame was dropped due to processing backpressure
    }
}
```

### Barcode Scanning with Vision Framework

```swift
import Vision

class BarcodeScannerManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let analysisQueue = DispatchQueue(label: "barcode.analysis")

    @Published var detectedBarcodes: [DetectedBarcode] = []

    struct DetectedBarcode: Identifiable {
        let id = UUID()
        let value: String
        let symbology: VNBarcodeSymbology
        let bounds: CGRect
    }

    func configure() {
        captureSession.beginConfiguration()

        guard let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ),
        let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
        else { return }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        videoDataOutput.setSampleBufferDelegate(self, queue: analysisQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Vision barcode detection request (replaces ML Kit BarcodeScanning)
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let results = request.results as? [VNBarcodeObservation] else { return }

            let barcodes = results.compactMap { observation -> DetectedBarcode? in
                guard let payload = observation.payloadStringValue else { return nil }
                return DetectedBarcode(
                    value: payload,
                    symbology: observation.symbology,
                    bounds: observation.boundingBox
                )
            }

            DispatchQueue.main.async {
                self?.detectedBarcodes = barcodes
            }
        }

        // Specify barcode formats (equivalent to setBarcodeFormats)
        request.symbologies = [.qr, .ean13, .code128]

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}

// iOS 16+ DataScannerViewController (simpler alternative)
import VisionKit

struct DataScannerView: UIViewControllerRepresentable {
    let onBarcode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.qr, .ean13, .code128])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onBarcode: onBarcode) }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcode: (String) -> Void
        init(onBarcode: @escaping (String) -> Void) { self.onBarcode = onBarcode }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .barcode(let barcode) = item {
                onBarcode(barcode.payloadStringValue ?? "")
            }
        }
    }
}
```

### Face Detection

```swift
import Vision

class FaceDetectionManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var detectedFaces: [VNFaceObservation] = []

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation] else { return }

            DispatchQueue.main.async {
                self?.detectedFaces = results
            }
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .right, // Match camera orientation
            options: [:]
        )
        try? handler.perform([request])
    }
}
```

### Camera Permissions

```swift
import AVFoundation

class CameraPermissionManager: ObservableObject {
    @Published var cameraAuthorized = false
    @Published var microphoneAuthorized = false

    func checkAndRequestPermissions() async {
        // Camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await MainActor.run { cameraAuthorized = true }
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run { cameraAuthorized = granted }
        case .denied, .restricted:
            await MainActor.run { cameraAuthorized = false }
            // Direct user to Settings
        @unknown default:
            break
        }

        // Microphone permission (for video recording)
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            await MainActor.run { microphoneAuthorized = true }
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            await MainActor.run { microphoneAuthorized = granted }
        case .denied, .restricted:
            await MainActor.run { microphoneAuthorized = false }
        @unknown default:
            break
        }
    }

    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

// Info.plist keys required:
// NSCameraUsageDescription - "This app needs camera access to capture photos"
// NSMicrophoneUsageDescription - "This app needs microphone access to record video"
// NSPhotoLibraryAddUsageDescription - "This app needs photo library access to save photos"

// SwiftUI usage
struct CameraPermissionView: View {
    @StateObject private var permissions = CameraPermissionManager()

    var body: some View {
        Group {
            if permissions.cameraAuthorized {
                CameraScreen()
            } else {
                VStack {
                    Text("Camera access is required")
                    Button("Open Settings") {
                        permissions.openSettings()
                    }
                }
            }
        }
        .task {
            await permissions.checkAndRequestPermissions()
        }
    }
}
```

### Zoom, Flash, and Camera Switch

```swift
extension CameraManager {

    // Zoom (equivalent to setLinearZoom / setZoomRatio)
    func setZoom(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
                device.videoZoomFactor = max(1.0, min(factor, maxZoom))
                device.unlockForConfiguration()
            } catch {
                print("Zoom error: \(error)")
            }
        }
    }

    // Pinch-to-zoom gesture handler
    func handlePinchZoom(_ scale: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        let newZoom = device.videoZoomFactor * scale
        setZoom(newZoom)
    }

    // Flash / Torch (equivalent to enableTorch)
    func toggleFlash() {
        guard let device = videoDeviceInput?.device,
              device.hasTorch else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.torchMode = device.torchMode == .on ? .off : .on
                device.unlockForConfiguration()
            } catch {
                print("Torch error: \(error)")
            }
        }
    }

    // Camera switch (equivalent to switching CameraSelector)
    func switchCamera() {
        sessionQueue.async { [self] in
            let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

            guard let newDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: newPosition
            ),
            let newInput = try? AVCaptureDeviceInput(device: newDevice)
            else { return }

            captureSession.beginConfiguration()

            if let currentInput = videoDeviceInput {
                captureSession.removeInput(currentInput)
            }

            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                videoDeviceInput = newInput
            }

            captureSession.commitConfiguration()

            DispatchQueue.main.async {
                self.currentPosition = newPosition
            }
        }
    }

    // Tap to focus (equivalent to FocusMeteringAction)
    func focus(at point: CGPoint, in previewLayer: AVCaptureVideoPreviewLayer) {
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)

        guard let device = videoDeviceInput?.device else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .autoExpose
                }

                device.unlockForConfiguration()
            } catch {
                print("Focus error: \(error)")
            }
        }
    }
}
```

## Concept Mapping Table

| Android (CameraX) | iOS (AVFoundation) | Notes |
|---|---|---|
| `ProcessCameraProvider` | `AVCaptureSession` | Session manages the capture pipeline |
| `CameraSelector` | `AVCaptureDevice.default(for:position:)` | Device selection |
| `LENS_FACING_BACK` / `LENS_FACING_FRONT` | `.back` / `.front` (`AVCaptureDevice.Position`) | Camera position |
| `Preview` use case | `AVCaptureVideoPreviewLayer` | Preview rendering |
| `PreviewView` | Custom `UIView` with `AVCaptureVideoPreviewLayer` | Wrapped in `UIViewRepresentable` for SwiftUI |
| `ImageCapture` use case | `AVCapturePhotoOutput` | Photo capture |
| `ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY` | `.photoQualityPrioritization = .quality` | Quality setting |
| `ImageCapture.FLASH_MODE_AUTO` | `settings.flashMode = .auto` | Per-capture setting |
| `imageCapture.takePicture()` | `photoOutput.capturePhoto(with:delegate:)` | Trigger capture |
| `OnImageSavedCallback` | `AVCapturePhotoCaptureDelegate` | Capture result delegate |
| `ImageProxy` | `AVCapturePhoto` | Captured photo data |
| `VideoCapture` use case | `AVCaptureMovieFileOutput` | Video recording |
| `Recorder.Builder().setQualitySelector(...)` | `captureSession.sessionPreset = .high` | Quality preset |
| `recording.start()` / `recording.stop()` | `movieOutput.startRecording()` / `.stopRecording()` | Record control |
| `VideoRecordEvent.Status` | `AVCaptureFileOutputRecordingDelegate` | Recording progress |
| `ImageAnalysis` use case | `AVCaptureVideoDataOutput` | Frame-by-frame processing |
| `STRATEGY_KEEP_ONLY_LATEST` | `alwaysDiscardsLateVideoFrames = true` | Drop old frames |
| `setTargetResolution(Size)` | `captureSession.sessionPreset` | Resolution control |
| `ImageAnalysis.Analyzer` | `AVCaptureVideoDataOutputSampleBufferDelegate` | Frame callback |
| `imageProxy.close()` | Automatic (no explicit close needed) | Buffer management |
| `bindToLifecycle(owner, ...)` | Manual `startRunning()` / `stopRunning()` | No lifecycle binding; manage manually |
| `cameraProvider.unbindAll()` | `captureSession.removeInput/removeOutput` | Manual cleanup |
| `FocusMeteringAction` | `device.focusPointOfInterest` + `lockForConfiguration` | Must lock device |
| `cameraControl.setLinearZoom(f)` | `device.videoZoomFactor` | Must lock device |
| `cameraControl.enableTorch(true)` | `device.torchMode = .on` | Must lock device |
| ML Kit `BarcodeScanning` | Vision `VNDetectBarcodesRequest` or `DataScannerViewController` | Apple Vision framework |
| ML Kit `FaceDetection` | Vision `VNDetectFaceLandmarksRequest` | Apple Vision framework |
| `Manifest.permission.CAMERA` | `AVCaptureDevice.requestAccess(for: .video)` | Runtime permission |
| `Manifest.permission.RECORD_AUDIO` | `AVCaptureDevice.requestAccess(for: .audio)` | Runtime permission |
| `shouldShowRequestPermissionRationale` | Check `.denied` status, direct to Settings | No rationale API on iOS |

## Common Pitfalls

1. **No lifecycle binding** -- CameraX automatically binds to the Android lifecycle. On iOS, you must manually call `captureSession.startRunning()` in `onAppear`/`viewDidAppear` and `stopRunning()` in `onDisappear`/`viewDidDisappear`. Failing to stop the session wastes battery and keeps the camera indicator active.

2. **Device locking** -- iOS requires `device.lockForConfiguration()` before changing zoom, focus, torch, or exposure. Forgetting this causes runtime exceptions. Always pair with `unlockForConfiguration()` in a do-catch block.

3. **Session configuration atomicity** -- Always wrap session changes in `beginConfiguration()` / `commitConfiguration()`. Making changes outside this block can cause session interruptions or crashes.

4. **Thread safety** -- `AVCaptureSession` operations must run on a serial background queue (not the main queue). The `captureOutput` delegate callback also runs on its delegate queue. Dispatch UI updates to the main queue explicitly.

5. **Coordinate space conversion** -- Tap-to-focus requires converting from view coordinates to camera device coordinates using `previewLayer.captureDevicePointConverted(fromLayerPoint:)`. The device coordinate space is [0,1] x [0,1] with origin at top-left in landscape.

6. **Photo output must be added before starting session** -- Unlike CameraX where use cases can be bound/unbound dynamically, adding outputs to a running `AVCaptureSession` requires `beginConfiguration()` / `commitConfiguration()` and may briefly interrupt the preview.

7. **No simultaneous photo + video data output** -- On some devices, `AVCapturePhotoOutput` and `AVCaptureVideoDataOutput` cannot be added to the same session simultaneously. Check `canAddOutput` before adding. CameraX handles this transparently.

8. **Orientation handling** -- CameraX handles rotation via `setTargetRotation`. On iOS, set `connection.videoOrientation` on the output connection. The default orientation is `.landscapeRight` (matching the sensor orientation), not `.portrait`.

9. **Info.plist usage descriptions are mandatory** -- iOS requires `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` in Info.plist. Without these, the app crashes on first permission request. Android uses `<uses-permission>` in the manifest.

10. **Front camera mirroring** -- CameraX requires manual `isReversedHorizontal` metadata. `AVCapturePhotoOutput` automatically mirrors front camera photos. `AVCaptureVideoDataOutput` does NOT mirror by default; set `connection.isVideoMirrored = true` for front camera video frames.

11. **Barcode scanning differences** -- ML Kit BarcodeScanning provides barcode bounds in image coordinates. Vision framework's `VNBarcodeObservation.boundingBox` uses normalized coordinates [0,1] with origin at bottom-left. Convert using `VNImagePointForNormalizedPoint` for overlay rendering.

12. **Memory pressure** -- High-resolution frame processing can cause memory pressure. Set `alwaysDiscardsLateVideoFrames = true` and process frames efficiently. Unlike CameraX's `ImageProxy.close()`, AVFoundation sample buffers are auto-released, but holding references prevents buffer recycling and stalls the pipeline.

## Migration Checklist

- [ ] Replace `ProcessCameraProvider` with `AVCaptureSession` setup on a background serial queue
- [ ] Replace `PreviewView` with custom `UIView` using `AVCaptureVideoPreviewLayer`, wrapped in `UIViewRepresentable`
- [ ] Replace `CameraSelector` with `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position:)`
- [ ] Replace `ImageCapture` use case with `AVCapturePhotoOutput`
- [ ] Implement `AVCapturePhotoCaptureDelegate` for capture callbacks (replaces `OnImageSavedCallback`)
- [ ] Replace `VideoCapture<Recorder>` with `AVCaptureMovieFileOutput` and `AVCaptureFileOutputRecordingDelegate`
- [ ] Add audio input (`AVCaptureDeviceInput` for `.audio`) for video recording with audio
- [ ] Replace `ImageAnalysis` with `AVCaptureVideoDataOutput` and `AVCaptureVideoDataOutputSampleBufferDelegate`
- [ ] Set `alwaysDiscardsLateVideoFrames = true` (equivalent to `STRATEGY_KEEP_ONLY_LATEST`)
- [ ] Replace ML Kit barcode scanning with Vision `VNDetectBarcodesRequest` or `DataScannerViewController` (iOS 16+)
- [ ] Replace ML Kit face detection with Vision `VNDetectFaceLandmarksRequest`
- [ ] Implement manual lifecycle management: `startRunning()` / `stopRunning()` in appropriate view lifecycle
- [ ] Use `lockForConfiguration()` / `unlockForConfiguration()` for zoom, focus, torch, and exposure changes
- [ ] Wrap all session modifications in `beginConfiguration()` / `commitConfiguration()`
- [ ] Add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to Info.plist
- [ ] Replace Android permission flow with `AVCaptureDevice.requestAccess(for:)` and Settings deep link for denied state
- [ ] Handle `connection.videoOrientation` for proper output rotation
- [ ] Handle front camera mirroring on `AVCaptureVideoDataOutput` connections
- [ ] Convert barcode bounding box coordinates from Vision normalized space to view coordinates

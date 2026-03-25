---
name: generic-android-to-ios-opengl
description: Guides migration of Android OpenGL ES 3.x rendering (GLSurfaceView, EGLContext, GLSL shaders, textures, framebuffers, compute shaders) to iOS Metal (MTKView, MTLDevice, MTLCommandQueue, MSL shaders, Metal 3) with rendering pipeline mapping, shader translation, texture handling, and performance optimization
type: generic
---

# generic-android-to-ios-opengl

## Context

Android uses OpenGL ES 3.0/3.1/3.2 as its primary GPU graphics API, with GLSurfaceView providing the rendering surface and EGL managing the context. On iOS, OpenGL ES has been deprecated since iOS 12 and is unavailable on Apple Silicon. Metal is Apple's sole GPU API, offering lower overhead, better CPU/GPU parallelism, and tighter hardware integration. This skill provides a systematic migration path from OpenGL ES rendering to Metal, covering the entire pipeline from context creation through shader translation to frame presentation.

## Android Best Practices (Source Patterns)

### GLSurfaceView Setup and Renderer

```kotlin
class GameView(context: Context) : GLSurfaceView(context) {
    private val renderer: GameRenderer

    init {
        setEGLContextClientVersion(3)
        setEGLConfigChooser(8, 8, 8, 8, 24, 8) // RGBA8, depth24, stencil8
        renderer = GameRenderer(context)
        setRenderer(renderer)
        renderMode = RENDERMODE_CONTINUOUSLY
    }
}

class GameRenderer(private val context: Context) : GLSurfaceView.Renderer {

    private var program: Int = 0
    private var vao: Int = 0
    private var vbo: Int = 0
    private var textureId: Int = 0

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES30.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
        GLES30.glEnable(GLES30.GL_DEPTH_TEST)
        GLES30.glEnable(GLES30.GL_BLEND)
        GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE_MINUS_SRC_ALPHA)
        setupShaders()
        setupGeometry()
        loadTextures()
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES30.glViewport(0, 0, width, height)
        updateProjectionMatrix(width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT or GLES30.GL_DEPTH_BUFFER_BIT)
        GLES30.glUseProgram(program)
        GLES30.glBindVertexArray(vao)
        GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textureId)
        GLES30.glDrawElements(GLES30.GL_TRIANGLES, indexCount, GLES30.GL_UNSIGNED_SHORT, 0)
        GLES30.glBindVertexArray(0)
    }
}
```

### Shader Compilation and Linking

```kotlin
private fun setupShaders() {
    val vertexShader = loadShader(GLES30.GL_VERTEX_SHADER, vertexShaderSource)
    val fragmentShader = loadShader(GLES30.GL_FRAGMENT_SHADER, fragmentShaderSource)

    program = GLES30.glCreateProgram().also {
        GLES30.glAttachShader(it, vertexShader)
        GLES30.glAttachShader(it, fragmentShader)
        GLES30.glLinkProgram(it)

        val linkStatus = IntArray(1)
        GLES30.glGetProgramiv(it, GLES30.GL_LINK_STATUS, linkStatus, 0)
        if (linkStatus[0] == 0) {
            val log = GLES30.glGetProgramInfoLog(it)
            GLES30.glDeleteProgram(it)
            throw RuntimeException("Program link failed: $log")
        }
    }
}

private fun loadShader(type: Int, source: String): Int {
    return GLES30.glCreateShader(type).also { shader ->
        GLES30.glShaderSource(shader, source)
        GLES30.glCompileShader(shader)
        val compiled = IntArray(1)
        GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            val log = GLES30.glGetShaderInfoLog(shader)
            GLES30.glDeleteShader(shader)
            throw RuntimeException("Shader compile failed: $log")
        }
    }
}

// GLSL ES 3.0 Vertex Shader
private val vertexShaderSource = """
    #version 300 es
    layout(location = 0) in vec3 aPosition;
    layout(location = 1) in vec2 aTexCoord;
    layout(location = 2) in vec3 aNormal;

    uniform mat4 uModelViewProjection;
    uniform mat4 uModelView;
    uniform mat3 uNormalMatrix;

    out vec2 vTexCoord;
    out vec3 vNormal;
    out vec3 vFragPos;

    void main() {
        gl_Position = uModelViewProjection * vec4(aPosition, 1.0);
        vTexCoord = aTexCoord;
        vNormal = uNormalMatrix * aNormal;
        vFragPos = vec3(uModelView * vec4(aPosition, 1.0));
    }
""".trimIndent()

// GLSL ES 3.0 Fragment Shader
private val fragmentShaderSource = """
    #version 300 es
    precision mediump float;

    in vec2 vTexCoord;
    in vec3 vNormal;
    in vec3 vFragPos;

    uniform sampler2D uTexture;
    uniform vec3 uLightPos;
    uniform vec3 uLightColor;

    out vec4 fragColor;

    void main() {
        vec3 norm = normalize(vNormal);
        vec3 lightDir = normalize(uLightPos - vFragPos);
        float diff = max(dot(norm, lightDir), 0.0);
        vec3 diffuse = diff * uLightColor;
        vec3 ambient = 0.1 * uLightColor;
        vec4 texColor = texture(uTexture, vTexCoord);
        fragColor = vec4((ambient + diffuse) * texColor.rgb, texColor.a);
    }
""".trimIndent()
```

### Texture Loading

```kotlin
private fun loadTextures() {
    val texIds = IntArray(1)
    GLES30.glGenTextures(1, texIds, 0)
    textureId = texIds[0]

    GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textureId)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR_MIPMAP_LINEAR)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_REPEAT)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_REPEAT)

    val bitmap = BitmapFactory.decodeResource(context.resources, R.drawable.texture_diffuse)
    GLUtils.texImage2D(GLES30.GL_TEXTURE_2D, 0, bitmap, 0)
    GLES30.glGenerateMipmap(GLES30.GL_TEXTURE_2D)
    bitmap.recycle()
}
```

### Framebuffer Objects (Off-Screen Rendering)

```kotlin
class OffscreenRenderer(private val width: Int, private val height: Int) {

    private var fbo: Int = 0
    private var colorTexture: Int = 0
    private var depthRenderbuffer: Int = 0

    fun setup() {
        val fbos = IntArray(1)
        GLES30.glGenFramebuffers(1, fbos, 0)
        fbo = fbos[0]

        val texIds = IntArray(1)
        GLES30.glGenTextures(1, texIds, 0)
        colorTexture = texIds[0]

        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, colorTexture)
        GLES30.glTexImage2D(
            GLES30.GL_TEXTURE_2D, 0, GLES30.GL_RGBA,
            width, height, 0, GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, null
        )
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)

        val rbos = IntArray(1)
        GLES30.glGenRenderbuffers(1, rbos, 0)
        depthRenderbuffer = rbos[0]
        GLES30.glBindRenderbuffer(GLES30.GL_RENDERBUFFER, depthRenderbuffer)
        GLES30.glRenderbufferStorage(GLES30.GL_RENDERBUFFER, GLES30.GL_DEPTH24_STENCIL8, width, height)

        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, fbo)
        GLES30.glFramebufferTexture2D(
            GLES30.GL_FRAMEBUFFER, GLES30.GL_COLOR_ATTACHMENT0,
            GLES30.GL_TEXTURE_2D, colorTexture, 0
        )
        GLES30.glFramebufferRenderbuffer(
            GLES30.GL_FRAMEBUFFER, GLES30.GL_DEPTH_STENCIL_ATTACHMENT,
            GLES30.GL_RENDERBUFFER, depthRenderbuffer
        )

        val status = GLES30.glCheckFramebufferStatus(GLES30.GL_FRAMEBUFFER)
        if (status != GLES30.GL_FRAMEBUFFER_COMPLETE) {
            throw RuntimeException("Framebuffer incomplete: $status")
        }
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
    }

    fun beginRender() {
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, fbo)
        GLES30.glViewport(0, 0, width, height)
    }

    fun endRender() {
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
    }
}
```

### Compute Shaders (OpenGL ES 3.1+)

```kotlin
private fun setupComputeShader() {
    val computeSource = """
        #version 310 es
        layout(local_size_x = 16, local_size_y = 16) in;
        layout(rgba8, binding = 0) uniform readonly highp image2D inputImage;
        layout(rgba8, binding = 1) uniform writeonly highp image2D outputImage;

        void main() {
            ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
            vec4 color = imageLoad(inputImage, pos);
            float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
            imageStore(outputImage, pos, vec4(gray, gray, gray, color.a));
        }
    """.trimIndent()

    val computeShader = loadShader(GLES31.GL_COMPUTE_SHADER, computeSource)
    computeProgram = GLES31.glCreateProgram()
    GLES31.glAttachShader(computeProgram, computeShader)
    GLES31.glLinkProgram(computeProgram)
}

private fun runComputeShader(inputTex: Int, outputTex: Int, width: Int, height: Int) {
    GLES31.glUseProgram(computeProgram)
    GLES31.glBindImageTexture(0, inputTex, 0, false, 0, GLES31.GL_READ_ONLY, GLES31.GL_RGBA8)
    GLES31.glBindImageTexture(1, outputTex, 0, false, 0, GLES31.GL_WRITE_ONLY, GLES31.GL_RGBA8)
    GLES31.glDispatchCompute(
        (width + 15) / 16,
        (height + 15) / 16,
        1
    )
    GLES31.glMemoryBarrier(GLES31.GL_SHADER_IMAGE_ACCESS_BARRIER_BIT)
}
```

## iOS Equivalent Patterns

### MTKView Setup and Delegate

```swift
import MetalKit

class GameMetalView: MTKView {
    private var renderer: GameRenderer!

    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    init(frame: CGRect) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        super.init(frame: frame, device: device)
        commonInit()
    }

    private func commonInit() {
        colorPixelFormat = .bgra8Unorm_srgb
        depthStencilPixelFormat = .depth32Float_stencil8
        sampleCount = 1
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        preferredFramesPerSecond = 60

        renderer = GameRenderer(device: device!, view: self)
        delegate = renderer
    }
}

class GameRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    private var texture: MTLTexture!

    init(device: MTLDevice, view: MTKView) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        buildPipeline(view: view)
        buildDepthStencil()
        buildGeometry()
        loadTextures()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateProjectionMatrix(width: Float(size.width), height: Float(size.height))
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
```

### Render Pipeline and MSL Shaders

```swift
private func buildPipeline(view: MTKView) {
    let library = device.makeDefaultLibrary()!
    let vertexFunction = library.makeFunction(name: "vertexShader")!
    let fragmentFunction = library.makeFunction(name: "fragmentShader")!

    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = vertexFunction
    descriptor.fragmentFunction = fragmentFunction
    descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
    descriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    descriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat

    // Blending (equivalent to glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA))
    descriptor.colorAttachments[0].isBlendingEnabled = true
    descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
    descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

    let vertexDescriptor = MTLVertexDescriptor()
    // position
    vertexDescriptor.attributes[0].format = .float3
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.attributes[0].bufferIndex = 0
    // texCoord
    vertexDescriptor.attributes[1].format = .float2
    vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
    vertexDescriptor.attributes[1].bufferIndex = 0
    // normal
    vertexDescriptor.attributes[2].format = .float3
    vertexDescriptor.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD2<Float>>.stride
    vertexDescriptor.attributes[2].bufferIndex = 0

    vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
    descriptor.vertexDescriptor = vertexDescriptor

    pipelineState = try! device.makeRenderPipelineState(descriptor: descriptor)
}

private func buildDepthStencil() {
    let descriptor = MTLDepthStencilDescriptor()
    descriptor.depthCompareFunction = .less
    descriptor.isDepthWriteEnabled = true
    depthStencilState = device.makeDepthStencilState(descriptor: descriptor)
}
```

```metal
// Shaders.metal - MSL equivalent of the GLSL shaders above
#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float3 normal   [[attribute(2)]];
};

struct Uniforms {
    float4x4 modelViewProjection;
    float4x4 modelView;
    float3x3 normalMatrix;
    float3 lightPos;
    float3 lightColor;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float3 normal;
    float3 fragPos;
};

vertex VertexOut vertexShader(
    Vertex in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    out.position = uniforms.modelViewProjection * float4(in.position, 1.0);
    out.texCoord = in.texCoord;
    out.normal = uniforms.normalMatrix * in.normal;
    out.fragPos = float3(uniforms.modelView * float4(in.position, 1.0));
    return out;
}

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]],
    texture2d<float> colorTexture [[texture(0)]],
    sampler texSampler [[sampler(0)]]
) {
    float3 norm = normalize(in.normal);
    float3 lightDir = normalize(uniforms.lightPos - in.fragPos);
    float diff = max(dot(norm, lightDir), 0.0);
    float3 diffuse = diff * uniforms.lightColor;
    float3 ambient = 0.1 * uniforms.lightColor;
    float4 texColor = colorTexture.sample(texSampler, in.texCoord);
    return float4((ambient + diffuse) * texColor.rgb, texColor.a);
}
```

### Texture Loading with MetalKit

```swift
private func loadTextures() {
    let textureLoader = MTKTextureLoader(device: device)

    let options: [MTKTextureLoader.Option: Any] = [
        .textureUsage: MTLTextureUsage.shaderRead.rawValue,
        .textureStorageMode: MTLStorageMode.private.rawValue,
        .generateMipmaps: true,
        .SRGB: true
    ]

    // From asset catalog
    texture = try! textureLoader.newTexture(
        name: "texture_diffuse",
        scaleFactor: 1.0,
        bundle: nil,
        options: options
    )

    // From URL/Data
    let url = Bundle.main.url(forResource: "texture_diffuse", withExtension: "png")!
    texture = try! textureLoader.newTexture(URL: url, options: options)

    // Manual texture creation (equivalent to glTexImage2D with nil data)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: 1024,
        height: 1024,
        mipmapped: true
    )
    descriptor.usage = [.shaderRead, .renderTarget]
    descriptor.storageMode = .private
    let manualTexture = device.makeTexture(descriptor: descriptor)!

    // Sampler state (equivalent to glTexParameteri calls)
    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.minFilter = .linear
    samplerDescriptor.magFilter = .linear
    samplerDescriptor.mipFilter = .linear
    samplerDescriptor.sAddressMode = .repeat
    samplerDescriptor.tAddressMode = .repeat
    samplerDescriptor.maxAnisotropy = 8
    let samplerState = device.makeSamplerState(descriptor: samplerDescriptor)!
}
```

### Off-Screen Rendering (Render to Texture)

```swift
class OffscreenRenderer {
    private let device: MTLDevice
    private let colorTexture: MTLTexture
    private let depthTexture: MTLTexture
    private let renderPassDescriptor: MTLRenderPassDescriptor

    init(device: MTLDevice, width: Int, height: Int) {
        self.device = device

        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: width,
            height: height,
            mipmapped: false
        )
        colorDesc.usage = [.renderTarget, .shaderRead]
        colorDesc.storageMode = .private
        colorTexture = device.makeTexture(descriptor: colorDesc)!

        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float_stencil8,
            width: width,
            height: height,
            mipmapped: false
        )
        depthDesc.usage = .renderTarget
        depthDesc.storageMode = .private
        depthTexture = device.makeTexture(descriptor: depthDesc)!

        renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = colorTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .dontCare
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        renderPassDescriptor.stencilAttachment.texture = depthTexture
    }

    func encode(into commandBuffer: MTLCommandBuffer, renderBlock: (MTLRenderCommandEncoder) -> Void) {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderBlock(encoder)
        encoder.endEncoding()
    }

    var resultTexture: MTLTexture { colorTexture }
}
```

### Compute Shaders in Metal

```swift
class ComputeProcessor {
    private let device: MTLDevice
    private let computePipeline: MTLComputePipelineState
    private let commandQueue: MTLCommandQueue

    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        let library = device.makeDefaultLibrary()!
        let function = library.makeFunction(name: "grayscaleKernel")!
        self.computePipeline = try! device.makeComputePipelineState(function: function)
    }

    func process(input: MTLTexture, output: MTLTexture) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.setComputePipelineState(computePipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)

        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (input.width + 15) / 16,
            height: (input.height + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
```

```metal
// ComputeShaders.metal
#include <metal_stdlib>
using namespace metal;

kernel void grayscaleKernel(
    texture2d<float, access::read> inputImage [[texture(0)]],
    texture2d<float, access::write> outputImage [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputImage.get_width() || gid.y >= inputImage.get_height()) return;
    float4 color = inputImage.read(gid);
    float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
    outputImage.write(float4(gray, gray, gray, color.a), gid);
}
```

### SwiftUI Integration

```swift
import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    let renderer: GameRenderer

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.depthStencilPixelFormat = .depth32Float_stencil8
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.delegate = renderer
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}

// Usage in SwiftUI
struct GameScreen: View {
    @StateObject private var renderer = GameRenderer(
        device: MTLCreateSystemDefaultDevice()!,
        view: nil
    )

    var body: some View {
        MetalView(renderer: renderer)
            .ignoresSafeArea()
    }
}
```

## Concept Mapping Table

| Android (OpenGL ES) | iOS (Metal) | Notes |
|---|---|---|
| `GLSurfaceView` | `MTKView` | Metal view with built-in display link |
| `EGLContext` | `MTLDevice` + `MTLCommandQueue` | Device represents GPU, queue schedules work |
| `GLSurfaceView.Renderer` | `MTKViewDelegate` | `draw(in:)` replaces `onDrawFrame` |
| `RENDERMODE_CONTINUOUSLY` | `isPaused = false` (default) | `enableSetNeedsDisplay` for manual |
| `RENDERMODE_WHEN_DIRTY` | `isPaused = true; enableSetNeedsDisplay = true` | Call `setNeedsDisplay()` to trigger |
| `glCreateProgram` / `glLinkProgram` | `MTLRenderPipelineState` | Pipeline state is immutable, create upfront |
| GLSL ES shaders | MSL (.metal files) | Compiled at build time into metallib |
| `glCreateShader` / `glCompileShader` | `MTLLibrary.makeFunction(name:)` | No runtime compilation by default |
| `glUniform*` | `setVertexBuffer` / `setFragmentBuffer` | Pass structs via buffers |
| `glGenTextures` / `glTexImage2D` | `MTLTextureDescriptor` + `device.makeTexture` | Or use `MTKTextureLoader` |
| `glTexParameteri` (filtering/wrapping) | `MTLSamplerDescriptor` + `makeSamplerState` | Sampler is a separate object |
| `glGenFramebuffers` / FBO | Render to `MTLTexture` via `MTLRenderPassDescriptor` | No explicit FBO object |
| `glGenBuffers` / `glBufferData` | `device.makeBuffer(bytes:length:options:)` | Returns `MTLBuffer` |
| `glVertexAttribPointer` / VAO | `MTLVertexDescriptor` in pipeline descriptor | Defined at pipeline creation |
| `glDrawElements` | `drawIndexedPrimitives` | On `MTLRenderCommandEncoder` |
| `glViewport` | `setViewport` on encoder | Per-encoder setting |
| `glEnable(GL_DEPTH_TEST)` | `MTLDepthStencilState` | Set on encoder, not global |
| `glClear` | `loadAction = .clear` on render pass | Clearing is per-attachment |
| `glDispatchCompute` (ES 3.1) | `dispatchThreadgroups` | On `MTLComputeCommandEncoder` |
| `glMemoryBarrier` | Automatic within command buffer | Metal handles barriers for you |
| `glReadPixels` | Blit encoder or `getBytes` on shared texture | Use `MTLBlitCommandEncoder` |

## GLSL to MSL Shader Translation Reference

| GLSL ES | MSL | Notes |
|---|---|---|
| `in vec3 aPosition` | `float3 position [[attribute(0)]]` | Attribute index must match vertex descriptor |
| `out vec2 vTexCoord` | Return struct member | No separate out qualifier |
| `uniform mat4 uMVP` | `constant Uniforms &u [[buffer(N)]]` | Passed as buffer argument |
| `uniform sampler2D tex` | `texture2d<float> tex [[texture(0)]]` | Texture and sampler are separate |
| `texture(tex, coord)` | `tex.sample(sampler, coord)` | Explicit sampler object required |
| `gl_Position` | `out.position` with `[[position]]` | Return struct attribute |
| `gl_FragCoord` | `float4 pos [[position]]` | In fragment input struct |
| `gl_GlobalInvocationID` | `uint2 gid [[thread_position_in_grid]]` | Compute shader thread ID |
| `precision mediump float` | Not needed | Metal uses explicit types |
| `imageLoad` / `imageStore` | `texture.read(gid)` / `texture.write(val, gid)` | Access qualifier on texture param |
| `#version 300 es` | `#include <metal_stdlib>` | No version directive in MSL |
| `vec2/vec3/vec4` | `float2/float3/float4` | SIMD types |
| `mat4` | `float4x4` | Column-major like GLSL |
| `mix(a, b, t)` | `mix(a, b, t)` | Same function name |
| `clamp(x, 0.0, 1.0)` | `clamp(x, 0.0, 1.0)` or `saturate(x)` | `saturate` is Metal-specific |

## Common Pitfalls

1. **Coordinate system differences** -- Metal uses a [0, 1] NDC depth range (like Vulkan), while OpenGL uses [-1, 1]. Adjust projection matrices accordingly or use `MTLDepthClipMode.zero_to_one`.

2. **Texture coordinate origin** -- Metal's texture origin is top-left (y=0 at top), matching UIKit. OpenGL's origin is bottom-left. Flip the v-coordinate in shaders or when loading textures.

3. **Immutable pipeline state** -- Metal `MTLRenderPipelineState` is immutable once created. You cannot change blend mode, vertex format, or shader on the fly. Pre-create pipeline state variants for each configuration you need.

4. **No global state** -- Metal has no `glEnable`/`glDisable` equivalent. Depth testing, blending, stencil ops are all baked into pipeline or depth-stencil state objects. Set state on the encoder, not globally.

5. **Triple buffering** -- Metal best practice uses triple-buffered uniform data to avoid CPU-GPU synchronization stalls. Use a semaphore with value 3 and cycle through buffer offsets.

6. **Metal shaders compile at build time** -- GLSL shaders are compiled at runtime from string sources. Metal shaders are compiled into a metallib at build time by Xcode. Runtime shader compilation is possible via `MTLDevice.makeLibrary(source:options:)` but is discouraged for production.

7. **Resource storage modes** -- Metal requires you to choose storage modes (`.shared`, `.private`, `.managed`). Textures used only by GPU should be `.private` for best performance. Use `.shared` only when CPU needs access.

8. **Command buffer lifecycle** -- A command buffer can only be committed once. Do not reuse command buffers. Create a new one each frame from the command queue.

9. **Thread safety** -- `MTLDevice` and `MTLCommandQueue` are thread-safe. Command buffers, encoders, and most other objects are not. Encode from a single thread or synchronize access.

10. **Forgetting endEncoding** -- Every `makeRenderCommandEncoder` / `makeComputeCommandEncoder` call must have a matching `endEncoding()` before committing the command buffer or creating another encoder.

## Migration Checklist

- [ ] Replace `GLSurfaceView` with `MTKView` and `GLSurfaceView.Renderer` with `MTKViewDelegate`
- [ ] Create `MTLDevice` and `MTLCommandQueue` (replaces EGL context setup)
- [ ] Translate GLSL ES vertex/fragment shaders to MSL in `.metal` files
- [ ] Adjust NDC depth range from [-1, 1] to [0, 1] in projection matrices
- [ ] Flip texture v-coordinates if textures appear upside down
- [ ] Build `MTLRenderPipelineState` for each unique shader/blend/format combination
- [ ] Build `MTLDepthStencilState` for depth/stencil configurations
- [ ] Define `MTLVertexDescriptor` matching your vertex data layout
- [ ] Replace `glUniform*` calls with uniform buffer structs passed via `setVertexBuffer`/`setFragmentBuffer`
- [ ] Replace `glGenTextures` / `glTexImage2D` with `MTKTextureLoader` or `MTLTextureDescriptor`
- [ ] Create `MTLSamplerState` objects for texture sampling parameters
- [ ] Replace FBO setup with render-to-texture using `MTLRenderPassDescriptor`
- [ ] Convert compute shaders from GLSL ES 3.1 to MSL kernel functions
- [ ] Implement triple buffering with semaphore for uniform data
- [ ] Wrap `MTKView` in `UIViewRepresentable` for SwiftUI integration
- [ ] Profile with Metal System Trace in Instruments (replaces GPU profiling via `adb shell dumpsys gfxinfo`)
- [ ] Test on actual hardware (Metal is not available in iOS Simulator on Intel Macs)

---
name: generic-android-to-ios-canvas
description: Guides migration of Android Canvas drawing (Compose DrawScope, android.graphics.Canvas, Paint, Path, drawArc/drawRect/drawPath) to iOS equivalents (SwiftUI Canvas/GraphicsContext, Core Graphics CGContext, UIBezierPath, CAShapeLayer) with drawing primitives mapping, custom shapes, animations, gradients, clipping, and hit testing
type: generic
---

# generic-android-to-ios-canvas

## Context

Android provides two canvas drawing approaches: the legacy `android.graphics.Canvas` API and the modern Jetpack Compose `DrawScope`. Both use imperative draw commands with `Paint` objects for styling and `Path` for custom shapes. On iOS, the equivalents are SwiftUI's `Canvas` view with `GraphicsContext`, Core Graphics' `CGContext` for lower-level drawing, `UIBezierPath` for paths, and `CAShapeLayer` for layer-based shape rendering. This skill maps Android canvas drawing patterns to their idiomatic iOS counterparts, covering primitives, paths, gradients, clipping, transforms, and animated drawing.

## Android Best Practices (Source Patterns)

### Compose DrawScope Basics

```kotlin
@Composable
fun CustomChart(data: List<Float>, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.fillMaxSize()) {
        val barWidth = size.width / data.size
        val maxValue = data.max()

        data.forEachIndexed { index, value ->
            val barHeight = (value / maxValue) * size.height
            drawRect(
                color = Color.Blue,
                topLeft = Offset(index * barWidth, size.height - barHeight),
                size = Size(barWidth - 4f, barHeight),
                style = Fill
            )
        }

        // Draw baseline
        drawLine(
            color = Color.Gray,
            start = Offset(0f, size.height),
            end = Offset(size.width, size.height),
            strokeWidth = 2f,
            cap = StrokeCap.Round
        )
    }
}
```

### DrawScope Shapes and Styling

```kotlin
@Composable
fun ShapesDemo(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(300.dp)) {
        // Filled circle
        drawCircle(
            color = Color.Red,
            radius = 50f,
            center = Offset(100f, 100f)
        )

        // Stroked circle
        drawCircle(
            color = Color.Blue,
            radius = 50f,
            center = Offset(250f, 100f),
            style = Stroke(width = 4f, cap = StrokeCap.Round)
        )

        // Rounded rectangle
        drawRoundRect(
            color = Color.Green,
            topLeft = Offset(50f, 200f),
            size = Size(200f, 100f),
            cornerRadius = CornerRadius(16f, 16f)
        )

        // Arc
        drawArc(
            color = Color.Magenta,
            startAngle = 0f,
            sweepAngle = 270f,
            useCenter = true,
            topLeft = Offset(300f, 200f),
            size = Size(150f, 150f)
        )

        // Oval
        drawOval(
            color = Color.Cyan,
            topLeft = Offset(50f, 400f),
            size = Size(200f, 100f)
        )
    }
}
```

### Custom Paths

```kotlin
@Composable
fun StarShape(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(200.dp)) {
        val path = Path().apply {
            val cx = size.width / 2
            val cy = size.height / 2
            val outerRadius = size.minDimension / 2
            val innerRadius = outerRadius * 0.4f
            val points = 5

            for (i in 0 until points * 2) {
                val radius = if (i % 2 == 0) outerRadius else innerRadius
                val angle = Math.toRadians((i * 360.0 / (points * 2)) - 90.0)
                val x = cx + radius * cos(angle).toFloat()
                val y = cy + radius * sin(angle).toFloat()
                if (i == 0) moveTo(x, y) else lineTo(x, y)
            }
            close()
        }

        drawPath(
            path = path,
            color = Color.Yellow,
            style = Fill
        )
        drawPath(
            path = path,
            color = Color.Black,
            style = Stroke(width = 2f, join = StrokeJoin.Round)
        )
    }
}
```

### Gradients

```kotlin
@Composable
fun GradientDemo(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.fillMaxSize()) {
        // Linear gradient
        drawRect(
            brush = Brush.linearGradient(
                colors = listOf(Color.Red, Color.Yellow, Color.Green),
                start = Offset.Zero,
                end = Offset(size.width, size.height)
            ),
            size = Size(size.width, size.height / 3)
        )

        // Radial gradient
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(Color.White, Color.Blue),
                center = center,
                radius = 150f
            ),
            radius = 150f,
            center = Offset(center.x, size.height * 2 / 3)
        )

        // Sweep gradient
        drawCircle(
            brush = Brush.sweepGradient(
                colors = listOf(Color.Red, Color.Green, Color.Blue, Color.Red),
                center = Offset(center.x, size.height / 2)
            ),
            radius = 100f,
            center = Offset(center.x, size.height / 2)
        )
    }
}
```

### Clipping and Transforms

```kotlin
@Composable
fun ClippingDemo(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(300.dp)) {
        // Clip to circle and draw image
        clipPath(Path().apply {
            addOval(Rect(Offset(50f, 50f), 100f))
        }) {
            drawRect(color = Color.Red, size = size)
            drawCircle(color = Color.White, radius = 30f, center = Offset(100f, 100f))
        }

        // Rotation transform
        withTransform({
            rotate(degrees = 45f, pivot = Offset(250f, 250f))
            translate(left = 200f, top = 200f)
        }) {
            drawRect(
                color = Color.Blue,
                topLeft = Offset.Zero,
                size = Size(100f, 100f)
            )
        }

        // Scale transform
        withTransform({
            scale(scaleX = 1.5f, scaleY = 1.5f, pivot = center)
        }) {
            drawCircle(color = Color.Green.copy(alpha = 0.5f), radius = 40f, center = center)
        }
    }
}
```

### Animated Canvas Drawing

```kotlin
@Composable
fun AnimatedCircle(modifier: Modifier = Modifier) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val animatedRadius by infiniteTransition.animateFloat(
        initialValue = 50f,
        targetValue = 100f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = EaseInOutCubic),
            repeatMode = RepeatMode.Reverse
        ),
        label = "radius"
    )
    val animatedAlpha by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 0.3f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = EaseInOutCubic),
            repeatMode = RepeatMode.Reverse
        ),
        label = "alpha"
    )

    Canvas(modifier = modifier.fillMaxSize()) {
        drawCircle(
            color = Color.Blue.copy(alpha = animatedAlpha),
            radius = animatedRadius,
            center = center
        )
    }
}
```

### android.graphics.Canvas (Legacy View System)

```kotlin
class CustomCanvasView(context: Context, attrs: AttributeSet?) : View(context, attrs) {

    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.BLUE
        style = Paint.Style.FILL
    }

    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.RED
        style = Paint.Style.STROKE
        strokeWidth = 4f
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }

    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.BLACK
        textSize = 48f
        textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
    }

    private val path = android.graphics.Path()

    override fun onDraw(canvas: android.graphics.Canvas) {
        super.onDraw(canvas)

        canvas.drawRect(50f, 50f, 250f, 150f, fillPaint)
        canvas.drawCircle(width / 2f, height / 2f, 80f, strokePaint)
        canvas.drawText("Hello", width / 2f, height - 100f, textPaint)

        path.reset()
        path.moveTo(100f, 300f)
        path.quadTo(200f, 200f, 300f, 300f)
        canvas.drawPath(path, strokePaint)
    }
}
```

## iOS Equivalent Patterns

### SwiftUI Canvas Basics

```swift
struct CustomChart: View {
    let data: [CGFloat]

    var body: some View {
        Canvas { context, size in
            let barWidth = size.width / CGFloat(data.count)
            let maxValue = data.max() ?? 1

            for (index, value) in data.enumerated() {
                let barHeight = (value / maxValue) * size.height
                let rect = CGRect(
                    x: CGFloat(index) * barWidth,
                    y: size.height - barHeight,
                    width: barWidth - 4,
                    height: barHeight
                )
                context.fill(Path(rect), with: .color(.blue))
            }

            // Draw baseline
            var baselinePath = Path()
            baselinePath.move(to: CGPoint(x: 0, y: size.height))
            baselinePath.addLine(to: CGPoint(x: size.width, y: size.height))
            context.stroke(baselinePath, with: .color(.gray), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}
```

### SwiftUI Canvas Shapes and Styling

```swift
struct ShapesDemo: View {
    var body: some View {
        Canvas { context, size in
            // Filled circle
            let filledCircle = Path(ellipseIn: CGRect(x: 50, y: 50, width: 100, height: 100))
            context.fill(filledCircle, with: .color(.red))

            // Stroked circle
            let strokedCircle = Path(ellipseIn: CGRect(x: 200, y: 50, width: 100, height: 100))
            context.stroke(strokedCircle, with: .color(.blue), style: StrokeStyle(lineWidth: 4, lineCap: .round))

            // Rounded rectangle
            let roundedRect = Path(roundedRect: CGRect(x: 50, y: 200, width: 200, height: 100), cornerRadius: 16)
            context.fill(roundedRect, with: .color(.green))

            // Arc
            var arcPath = Path()
            arcPath.addArc(
                center: CGPoint(x: 375, y: 275),
                radius: 75,
                startAngle: .degrees(0),
                endAngle: .degrees(270),
                clockwise: false
            )
            arcPath.addLine(to: CGPoint(x: 375, y: 275))
            arcPath.closeSubpath()
            context.fill(arcPath, with: .color(.purple))

            // Oval
            let oval = Path(ellipseIn: CGRect(x: 50, y: 400, width: 200, height: 100))
            context.fill(oval, with: .color(.cyan))
        }
        .frame(width: 300, height: 550)
    }
}
```

### Custom Paths

```swift
struct StarShape: View {
    var body: some View {
        Canvas { context, size in
            let path = starPath(in: size)
            context.fill(path, with: .color(.yellow))
            context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
        .frame(width: 200, height: 200)
    }

    private func starPath(in size: CGSize) -> Path {
        var path = Path()
        let cx = size.width / 2
        let cy = size.height / 2
        let outerRadius = min(size.width, size.height) / 2
        let innerRadius = outerRadius * 0.4
        let points = 5

        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = Angle.degrees(Double(i) * 360.0 / Double(points * 2) - 90)
            let x = cx + radius * CGFloat(cos(angle.radians))
            let y = cy + radius * CGFloat(sin(angle.radians))
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

// Reusable SwiftUI Shape (alternative approach)
struct Star: Shape {
    let points: Int
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRatio

        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = Angle.degrees(Double(i) * 360.0 / Double(points * 2) - 90)
            let point = CGPoint(
                x: cx + radius * CGFloat(cos(angle.radians)),
                y: cy + radius * CGFloat(sin(angle.radians))
            )
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
```

### Gradients

```swift
struct GradientDemo: View {
    var body: some View {
        Canvas { context, size in
            // Linear gradient
            let linearGradient = Gradient(colors: [.red, .yellow, .green])
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height / 3)
            context.fill(
                Path(rect),
                with: .linearGradient(
                    linearGradient,
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height / 3)
                )
            )

            // Radial gradient
            let radialCenter = CGPoint(x: size.width / 2, y: size.height * 2 / 3)
            let radialGradient = Gradient(colors: [.white, .blue])
            let radialCircle = Path(ellipseIn: CGRect(
                x: radialCenter.x - 150, y: radialCenter.y - 150,
                width: 300, height: 300
            ))
            context.fill(
                radialCircle,
                with: .radialGradient(
                    radialGradient,
                    center: radialCenter,
                    startRadius: 0,
                    endRadius: 150
                )
            )

            // Conic (sweep) gradient
            let conicCenter = CGPoint(x: size.width / 2, y: size.height / 2)
            let conicGradient = Gradient(colors: [.red, .green, .blue, .red])
            let conicCircle = Path(ellipseIn: CGRect(
                x: conicCenter.x - 100, y: conicCenter.y - 100,
                width: 200, height: 200
            ))
            context.fill(
                conicCircle,
                with: .conicGradient(
                    conicGradient,
                    center: conicCenter
                )
            )
        }
    }
}
```

### Clipping and Transforms

```swift
struct ClippingDemo: View {
    var body: some View {
        Canvas { context, size in
            // Clip to circle and draw
            var clippedContext = context
            let clipCircle = Path(ellipseIn: CGRect(x: 50, y: 50, width: 200, height: 200))
            clippedContext.clip(to: clipCircle)
            clippedContext.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.red))
            clippedContext.fill(
                Path(ellipseIn: CGRect(x: 120, y: 120, width: 60, height: 60)),
                with: .color(.white)
            )

            // Rotation transform
            var rotatedContext = context
            rotatedContext.translateBy(x: 250, y: 250)
            rotatedContext.rotate(by: .degrees(45))
            rotatedContext.fill(
                Path(CGRect(x: -50, y: -50, width: 100, height: 100)),
                with: .color(.blue)
            )

            // Scale transform
            var scaledContext = context
            scaledContext.translateBy(x: size.width / 2, y: size.height / 2)
            scaledContext.scaleBy(x: 1.5, y: 1.5)
            scaledContext.fill(
                Path(ellipseIn: CGRect(x: -40, y: -40, width: 80, height: 80)),
                with: .color(.green.opacity(0.5))
            )
        }
        .frame(width: 300, height: 500)
    }
}
```

### Animated Canvas Drawing

```swift
struct AnimatedCircle: View {
    @State private var animationProgress: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let radius = 50 + 50 * animationProgress
            let alpha = 1.0 - 0.7 * animationProgress

            let circle = Path(ellipseIn: CGRect(
                x: size.width / 2 - radius,
                y: size.height / 2 - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.fill(circle, with: .color(.blue.opacity(alpha)))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animationProgress = 1.0
            }
        }
    }
}

// TimelineView for frame-by-frame canvas animation
struct FrameAnimatedCanvas: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let phase = CGFloat(sin(time * 2)) * 0.5 + 0.5

                let radius = 50 + 50 * phase
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                let circle = Path(ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2
                ))
                context.fill(circle, with: .color(.blue.opacity(1 - 0.7 * phase)))
            }
        }
    }
}
```

### Core Graphics (CGContext) for Custom UIView Drawing

```swift
class CustomCanvasUIView: UIView {
    private let fillColor = UIColor.blue
    private let strokeColor = UIColor.red

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Filled rectangle
        context.setFillColor(fillColor.cgColor)
        context.fill(CGRect(x: 50, y: 50, width: 200, height: 100))

        // Stroked circle
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(4)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokeEllipseInRect(CGRect(
            x: bounds.midX - 80, y: bounds.midY - 80,
            width: 160, height: 160
        ))

        // Text
        let text = "Hello" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 48),
            .foregroundColor: UIColor.black
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(
            at: CGPoint(x: bounds.midX - textSize.width / 2, y: bounds.height - 148),
            withAttributes: attributes
        )

        // Quadratic curve path
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 100, y: 300))
        path.addQuadCurve(to: CGPoint(x: 300, y: 300), controlPoint: CGPoint(x: 200, y: 200))
        strokeColor.setStroke()
        path.lineWidth = 4
        path.stroke()
    }
}
```

### CAShapeLayer for Animated Paths

```swift
class AnimatedShapeView: UIView {
    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        shapeLayer.strokeColor = UIColor.blue.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 4
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        layer.addSublayer(shapeLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        shapeLayer.path = createPath().cgPath
    }

    private func createPath() -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 20, y: bounds.midY))
        path.addCurve(
            to: CGPoint(x: bounds.width - 20, y: bounds.midY),
            controlPoint1: CGPoint(x: bounds.width * 0.3, y: 20),
            controlPoint2: CGPoint(x: bounds.width * 0.7, y: bounds.height - 20)
        )
        return path
    }

    func animateStroke() {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 2.0
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shapeLayer.add(animation, forKey: "strokeAnimation")
    }
}
```

### Drawing Text on Canvas

```swift
struct TextOnCanvas: View {
    var body: some View {
        Canvas { context, size in
            // Resolved text for high performance
            let text = Text("Score: 100")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.black)
            let resolvedText = context.resolve(text)
            let textSize = resolvedText.measure(in: size)

            context.draw(
                resolvedText,
                at: CGPoint(x: size.width / 2, y: size.height / 2),
                anchor: .center
            )
        }
    }
}
```

### Hit Testing on Canvas

```swift
struct InteractiveCanvas: View {
    @State private var circles: [CircleData] = [
        CircleData(center: CGPoint(x: 100, y: 100), radius: 40, color: .red),
        CircleData(center: CGPoint(x: 200, y: 200), radius: 60, color: .blue),
    ]
    @State private var selectedIndex: Int?

    var body: some View {
        Canvas { context, size in
            for (index, circle) in circles.enumerated() {
                let path = Path(ellipseIn: CGRect(
                    x: circle.center.x - circle.radius,
                    y: circle.center.y - circle.radius,
                    width: circle.radius * 2,
                    height: circle.radius * 2
                ))
                context.fill(path, with: .color(circle.color))
                if index == selectedIndex {
                    context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 3))
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    let point = value.location
                    selectedIndex = circles.lastIndex { circle in
                        let dx = point.x - circle.center.x
                        let dy = point.y - circle.center.y
                        return sqrt(dx * dx + dy * dy) <= circle.radius
                    }
                }
        )
    }
}

struct CircleData {
    var center: CGPoint
    var radius: CGFloat
    var color: Color
}
```

## Concept Mapping Table

| Android (Canvas/DrawScope) | iOS (SwiftUI Canvas/Core Graphics) | Notes |
|---|---|---|
| `Canvas` composable | `Canvas { context, size in }` view | SwiftUI Canvas is a View |
| `DrawScope` | `GraphicsContext` | Context passed into Canvas closure |
| `drawRect(color, topLeft, size)` | `context.fill(Path(rect), with: .color(...))` | Build Path from CGRect |
| `drawCircle(color, radius, center)` | `context.fill(Path(ellipseIn:), with:)` | Use ellipse in bounding rect |
| `drawLine(color, start, end, strokeWidth)` | `context.stroke(path, with:, style:)` | Build Path with move/addLine |
| `drawArc(color, startAngle, sweepAngle)` | `path.addArc(center:radius:startAngle:endAngle:clockwise:)` | Angles in `Angle` type |
| `drawOval(color, topLeft, size)` | `Path(ellipseIn: CGRect(...))` | Same as circle but with non-square rect |
| `drawRoundRect(cornerRadius)` | `Path(roundedRect:cornerRadius:)` | SwiftUI Path initializer |
| `drawPath(path, color)` | `context.fill(path, with:)` or `context.stroke(path, with:)` | Fill or stroke separately |
| `drawImage(image, topLeft)` | `context.draw(Image(...), in: rect)` | SwiftUI Image or resolved image |
| `drawText(textMeasurer, text)` | `context.draw(context.resolve(Text(...)), at:)` | Resolve text first for performance |
| `Path()` / `android.graphics.Path` | `Path()` (SwiftUI) / `UIBezierPath` | SwiftUI Path is a struct |
| `path.moveTo(x, y)` | `path.move(to: CGPoint(x:y:))` | Same concept |
| `path.lineTo(x, y)` | `path.addLine(to: CGPoint(x:y:))` | Same concept |
| `path.quadTo(cx, cy, x, y)` | `path.addQuadCurve(to:control:)` | Single control point |
| `path.cubicTo(c1x,c1y,c2x,c2y,x,y)` | `path.addCurve(to:control1:control2:)` | Two control points |
| `path.close()` | `path.closeSubpath()` | Close current subpath |
| `path.addOval(rect)` | `path.addEllipse(in: rect)` | Same concept |
| `Paint(style = Fill)` | `context.fill(...)` | Fill is a method, not paint style |
| `Paint(style = Stroke)` | `context.stroke(..., style: StrokeStyle(...))` | Stroke config in StrokeStyle |
| `Brush.linearGradient(colors, start, end)` | `.linearGradient(gradient, startPoint:, endPoint:)` | Gradient shading |
| `Brush.radialGradient(colors, center, radius)` | `.radialGradient(gradient, center:, startRadius:, endRadius:)` | Radial shading |
| `Brush.sweepGradient(colors, center)` | `.conicGradient(gradient, center:)` | Conic/sweep gradient |
| `clipPath(path) { ... }` | `context.clip(to: path)` | Mutates context copy |
| `withTransform { rotate(...) }` | `context.rotate(by: angle)` | Mutates context copy |
| `withTransform { translate(...) }` | `context.translateBy(x:y:)` | Mutates context copy |
| `withTransform { scale(...) }` | `context.scaleBy(x:y:)` | Mutates context copy |
| `Offset(x, y)` | `CGPoint(x:y:)` | Point type |
| `Size(w, h)` | `CGSize(width:height:)` | Size type |
| `Color.Blue` | `.blue` / `Color.blue` | SwiftUI Color |
| `StrokeCap.Round` | `.round` (in StrokeStyle lineCap) | Line cap style |
| `StrokeJoin.Round` | `.round` (in StrokeStyle lineJoin) | Line join style |
| `View.onDraw(canvas)` | `UIView.draw(_ rect:)` with `UIGraphicsGetCurrentContext()` | Legacy/UIKit approach |
| N/A (use `Animatable`) | `CAShapeLayer` + `CABasicAnimation` | Layer-based path animation |

## Common Pitfalls

1. **Coordinate system** -- Both Android Canvas and iOS Canvas use top-left origin with y-increasing-downward. Core Graphics (`CGContext`) in some cases uses bottom-left origin. When using `UIGraphicsGetCurrentContext()` inside `UIView.draw(_:)`, the coordinate system is already flipped to match UIKit conventions.

2. **Arc angle direction** -- Android's `drawArc` uses clockwise sweep angles (positive = clockwise). SwiftUI's `Path.addArc` `clockwise` parameter is inverted relative to visual expectation because of the flipped y-axis: pass `clockwise: false` for visually clockwise arcs.

3. **Context is a value type** -- SwiftUI's `GraphicsContext` is a struct. Calling `var clipped = context; clipped.clip(to: path)` creates an independent copy. The original context is unaffected. This replaces Android's `canvas.save()` / `canvas.restore()` pattern.

4. **No Paint object** -- iOS does not have Android's `Paint` equivalent. Fill color, stroke width, blend mode, and opacity are set per-draw-call or via context properties (`context.opacity`, `context.blendMode`).

5. **Performance with Canvas** -- SwiftUI Canvas redraws entirely when state changes. For complex drawings, use `context.drawLayer` to cache portions of the drawing. For heavy real-time animation, prefer `TimelineView` wrapping `Canvas` over animating `@State` values.

6. **Text measurement** -- Android Compose provides `TextMeasurer` for measuring text before drawing. In SwiftUI Canvas, use `context.resolve(Text(...))` then `.measure(in: size)` to get text dimensions.

7. **Missing drawPoints** -- iOS SwiftUI Canvas has no direct `drawPoints` equivalent. Draw individual small circles or build a path with short line segments.

8. **Shadow and blur** -- Android uses `Paint.setShadowLayer()`. In SwiftUI Canvas, use `context.addFilter(.shadow(...))` before drawing. In Core Graphics, use `context.setShadow(offset:blur:color:)`.

9. **Hit testing** -- SwiftUI Canvas has no built-in hit testing. Manually compute geometry intersection on gesture callbacks. For complex shapes, use `path.contains(point)`.

10. **Retina scaling** -- SwiftUI Canvas automatically handles display scale. When using Core Graphics directly, multiply dimensions by `UIScreen.main.scale` for pixel-perfect rendering, or use `UIGraphicsBeginImageContextWithOptions` with the correct scale.

## Migration Checklist

- [ ] Replace Compose `Canvas` with SwiftUI `Canvas { context, size in }` view
- [ ] Map `DrawScope` draw calls to `GraphicsContext` fill/stroke methods
- [ ] Convert `Path` construction from Kotlin to Swift `Path` API
- [ ] Replace `Brush.linearGradient` / `radialGradient` / `sweepGradient` with SwiftUI `.linearGradient` / `.radialGradient` / `.conicGradient` shading
- [ ] Replace `clipPath { }` blocks with `var copy = context; copy.clip(to:)` pattern
- [ ] Replace `withTransform { }` blocks with context mutation methods (translate, rotate, scale)
- [ ] Convert animated draw parameters from `animateFloat` / `infiniteTransition` to SwiftUI `withAnimation` or `TimelineView`
- [ ] Replace `android.graphics.Canvas` custom View drawing with `UIView.draw(_:)` + `CGContext` or SwiftUI Canvas
- [ ] Convert `Paint` styling to per-call fill/stroke parameters and `StrokeStyle`
- [ ] Add hit testing via `DragGesture` or `onTapGesture` with manual geometry checks using `path.contains(_:)`
- [ ] Replace `drawText` with `context.resolve(Text(...))` and `context.draw(resolvedText, at:)`
- [ ] For path stroke animations, use `CAShapeLayer` with `CABasicAnimation` on `strokeEnd`
- [ ] Test that arc directions render correctly (swap `clockwise` boolean if needed)
- [ ] Verify gradient positioning matches Android output visually

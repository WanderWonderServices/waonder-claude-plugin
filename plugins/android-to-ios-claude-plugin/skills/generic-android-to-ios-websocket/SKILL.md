---
name: generic-android-to-ios-websocket
description: Guides migration of Android WebSocket implementations (OkHttp WebSocket, Ktor WebSocket, Scarlet) with Flow-based message streams and lifecycle-aware connections to iOS equivalents (URLSessionWebSocketTask, Starscream) with async/await integration, reconnection strategies, and Combine/AsyncStream-based message handling
type: generic
---

# generic-android-to-ios-websocket

## Context

Android WebSocket implementations commonly use OkHttp's built-in WebSocket client, Ktor's multiplatform WebSocket support, or Scarlet (a type-safe, lifecycle-aware WebSocket library by Tinder). These integrate with Kotlin coroutines and Flow for reactive message streams. On iOS, the native `URLSessionWebSocketTask` (iOS 13+) provides basic WebSocket support, while Starscream offers richer features. This skill maps Android WebSocket patterns to idiomatic iOS equivalents, preserving connection lifecycle management, reconnection strategies, and message serialization.

## Android Best Practices (Source Patterns)

### OkHttp WebSocket

```kotlin
class ChatWebSocketClient(
    private val okHttpClient: OkHttpClient,
    private val json: Json
) {
    private val _messages = MutableSharedFlow<ChatMessage>(
        replay = 0,
        extraBufferCapacity = 64,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val messages: SharedFlow<ChatMessage> = _messages.asSharedFlow()

    private val _connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    private var webSocket: WebSocket? = null

    fun connect(url: String) {
        val request = Request.Builder().url(url).build()

        webSocket = okHttpClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                _connectionState.value = ConnectionState.Connected
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                val message = json.decodeFromString<ChatMessage>(text)
                _messages.tryEmit(message)
            }

            override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                // Handle binary messages
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
                _connectionState.value = ConnectionState.Disconnecting
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                _connectionState.value = ConnectionState.Disconnected
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                _connectionState.value = ConnectionState.Error(t)
                scheduleReconnect()
            }
        })
    }

    fun send(message: ChatMessage) {
        val text = json.encodeToString(message)
        webSocket?.send(text)
    }

    fun disconnect() {
        webSocket?.close(1000, "Client disconnect")
        webSocket = null
    }
}

sealed interface ConnectionState {
    data object Disconnected : ConnectionState
    data object Connecting : ConnectionState
    data object Connected : ConnectionState
    data object Disconnecting : ConnectionState
    data class Error(val throwable: Throwable) : ConnectionState
}
```

### OkHttp WebSocket with Reconnection

```kotlin
class ReconnectingWebSocket(
    private val okHttpClient: OkHttpClient,
    private val scope: CoroutineScope
) {
    private var reconnectAttempt = 0
    private val maxReconnectAttempts = 10
    private var reconnectJob: Job? = null

    private fun scheduleReconnect() {
        if (reconnectAttempt >= maxReconnectAttempts) return

        reconnectJob = scope.launch {
            val delayMs = minOf(
                1000L * (1 shl reconnectAttempt), // Exponential backoff
                30_000L // Max 30 seconds
            )
            delay(delayMs)
            reconnectAttempt++
            connect(currentUrl)
        }
    }

    fun resetReconnectCounter() {
        reconnectAttempt = 0
        reconnectJob?.cancel()
    }
}
```

### Ktor WebSocket Client

```kotlin
class KtorWebSocketClient(
    private val httpClient: HttpClient // configured with WebSockets plugin
) {
    suspend fun connectAndCollect(url: String, onMessage: suspend (ChatMessage) -> Unit) {
        httpClient.webSocket(url) {
            // Send a message
            send(Frame.Text(Json.encodeToString(ChatMessage("hello"))))

            // Collect incoming messages
            for (frame in incoming) {
                when (frame) {
                    is Frame.Text -> {
                        val message = Json.decodeFromString<ChatMessage>(frame.readText())
                        onMessage(message)
                    }
                    is Frame.Binary -> { /* handle binary */ }
                    else -> {}
                }
            }
        }
    }
}

// Ktor HttpClient configuration
val httpClient = HttpClient(OkHttp) {
    install(WebSockets) {
        pingInterval = 15_000
        maxFrameSize = Long.MAX_VALUE
    }
}
```

### Scarlet (Type-Safe, Lifecycle-Aware)

```kotlin
// Service interface (Retrofit-like)
interface ChatService {
    @Receive
    fun observeMessages(): Flow<ChatMessage>

    @Receive
    fun observeConnectionState(): Flow<WebSocket.Event>

    @Send
    fun sendMessage(message: ChatMessage)
}

// Scarlet configuration
val scarlet = Scarlet.Builder()
    .webSocketFactory(okHttpClient.newWebSocketFactory(url))
    .addMessageAdapterFactory(MoshiMessageAdapter.Factory())
    .addStreamAdapterFactory(FlowStreamAdapter.Factory())
    .lifecycle(AndroidLifecycle.ofApplicationForeground(application))
    .backoffStrategy(ExponentialBackoffStrategy(1000, 30000))
    .build()

val chatService = scarlet.create<ChatService>()

// Usage in ViewModel
viewModelScope.launch {
    chatService.observeMessages().collect { message ->
        _uiState.update { it.copy(messages = it.messages + message) }
    }
}
```

### Lifecycle-Aware Connection in ViewModel

```kotlin
class ChatViewModel(
    private val webSocketClient: ChatWebSocketClient
) : ViewModel() {

    init {
        viewModelScope.launch {
            webSocketClient.messages.collect { message ->
                _uiState.update { state ->
                    state.copy(messages = state.messages + message)
                }
            }
        }

        viewModelScope.launch {
            webSocketClient.connectionState.collect { state ->
                _uiState.update { it.copy(connectionState = state) }
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        webSocketClient.disconnect()
    }
}
```

### Key Android Patterns to Recognize

- `WebSocketListener` callbacks — `onOpen`, `onMessage`, `onClosing`, `onClosed`, `onFailure`
- `SharedFlow` / `StateFlow` for reactive message streams
- `viewModelScope` for lifecycle-scoped collection
- Scarlet's annotation-based service interface (`@Receive`, `@Send`)
- `ExponentialBackoffStrategy` for reconnection
- `AndroidLifecycle.ofApplicationForeground` — auto-connect/disconnect with app lifecycle
- `ByteString` — OkHttp's binary message type

## iOS Best Practices (Target Patterns)

### URLSessionWebSocketTask (Native, iOS 13+)

```swift
import Foundation

actor WebSocketClient {
    private var webSocket: URLSessionWebSocketTask?
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private let messageContinuation: AsyncStream<ChatMessage>.Continuation
    let messages: AsyncStream<ChatMessage>

    private let stateContinuation: AsyncStream<ConnectionState>.Continuation
    let connectionState: AsyncStream<ConnectionState>

    init(session: URLSession = .shared) {
        self.session = session

        var msgCont: AsyncStream<ChatMessage>.Continuation!
        self.messages = AsyncStream { msgCont = $0 }
        self.messageContinuation = msgCont

        var stateCont: AsyncStream<ConnectionState>.Continuation!
        self.connectionState = AsyncStream { stateCont = $0 }
        self.stateContinuation = stateCont
    }

    func connect(url: URL) {
        disconnect()
        let ws = session.webSocketTask(with: url)
        self.webSocket = ws
        ws.resume()
        stateContinuation.yield(.connected)
        listenForMessages()
    }

    private func listenForMessages() {
        guard let ws = webSocket else { return }

        Task { [weak self] in
            do {
                let message = try await ws.receive()
                guard let self else { return }
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let chatMessage = try? self.decoder.decode(ChatMessage.self, from: data) {
                        self.messageContinuation.yield(chatMessage)
                    }
                case .data(let data):
                    if let chatMessage = try? self.decoder.decode(ChatMessage.self, from: data) {
                        self.messageContinuation.yield(chatMessage)
                    }
                @unknown default:
                    break
                }
                // Continue listening recursively
                await self.listenForMessages()
            } catch {
                guard let self else { return }
                self.stateContinuation.yield(.error(error))
                await self.scheduleReconnect()
            }
        }
    }

    func send(_ message: ChatMessage) async throws {
        let data = try encoder.encode(message)
        let text = String(data: data, encoding: .utf8) ?? ""
        try await webSocket?.send(.string(text))
    }

    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        stateContinuation.yield(.disconnected)
    }

    deinit {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        messageContinuation.finish()
        stateContinuation.finish()
    }
}

enum ConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error(Error)
}
```

### URLSessionWebSocketTask with Reconnection

```swift
actor ReconnectingWebSocket {
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 10
    private var reconnectTask: Task<Void, Never>?
    private var currentURL: URL?

    func scheduleReconnect() async {
        guard reconnectAttempt < maxReconnectAttempts else { return }

        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            let delay = min(
                pow(2.0, Double(self.reconnectAttempt)) * 1.0, // Exponential backoff
                30.0 // Max 30 seconds
            )
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self.incrementAttempt()
            if let url = await self.currentURL {
                await self.connect(url: url)
            }
        }
    }

    private func incrementAttempt() {
        reconnectAttempt += 1
    }

    func resetReconnectCounter() {
        reconnectAttempt = 0
        reconnectTask?.cancel()
    }
}
```

### Starscream (Third-Party, Feature-Rich)

```swift
import Starscream

final class StarscreamWebSocket: Sendable {
    private let socket: WebSocket
    private let messageContinuation: AsyncStream<ChatMessage>.Continuation
    let messages: AsyncStream<ChatMessage>
    private let decoder = JSONDecoder()

    init(url: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        var msgCont: AsyncStream<ChatMessage>.Continuation!
        self.messages = AsyncStream { msgCont = $0 }
        self.messageContinuation = msgCont

        self.socket = WebSocket(request: request)
        setupHandlers()
    }

    private func setupHandlers() {
        socket.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .connected(let headers):
                print("Connected: \(headers)")

            case .disconnected(let reason, let code):
                print("Disconnected: \(reason) (\(code))")

            case .text(let text):
                if let data = text.data(using: .utf8),
                   let message = try? self.decoder.decode(ChatMessage.self, from: data) {
                    self.messageContinuation.yield(message)
                }

            case .binary(let data):
                if let message = try? self.decoder.decode(ChatMessage.self, from: data) {
                    self.messageContinuation.yield(message)
                }

            case .ping, .pong, .viabilityChanged, .reconnectSuggested:
                break

            case .peerClosed:
                self.messageContinuation.finish()

            case .cancelled:
                self.messageContinuation.finish()

            case .error(let error):
                print("Error: \(String(describing: error))")
            }
        }
    }

    func connect() {
        socket.connect()
    }

    func send(_ message: ChatMessage) throws {
        let data = try JSONEncoder().encode(message)
        let text = String(data: data, encoding: .utf8) ?? ""
        socket.write(string: text)
    }

    func disconnect() {
        socket.disconnect()
        messageContinuation.finish()
    }
}
```

### Lifecycle-Aware Connection in ViewModel

```swift
@Observable
final class ChatViewModel {
    private let webSocketClient: WebSocketClient
    private var messageTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?

    var messages: [ChatMessage] = []
    var connectionState: ConnectionState = .disconnected

    init(webSocketClient: WebSocketClient) {
        self.webSocketClient = webSocketClient
    }

    func startListening() {
        messageTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await message in await webSocketClient.messages {
                self.messages.append(message)
            }
        }

        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await state in await webSocketClient.connectionState {
                self.connectionState = state
            }
        }
    }

    func send(_ message: ChatMessage) {
        Task {
            try? await webSocketClient.send(message)
        }
    }

    deinit {
        messageTask?.cancel()
        stateTask?.cancel()
        Task { [webSocketClient] in
            await webSocketClient.disconnect()
        }
    }
}

// SwiftUI View with lifecycle binding
struct ChatView: View {
    @State private var viewModel: ChatViewModel

    var body: some View {
        MessageList(messages: viewModel.messages)
            .task {
                // Auto-cancelled when view disappears
                await viewModel.webSocketClient.connect(url: chatURL)
                viewModel.startListening()
            }
            .onDisappear {
                Task { await viewModel.webSocketClient.disconnect() }
            }
    }
}
```

### Combine-Based Alternative (iOS 15-16)

```swift
import Combine

final class WebSocketCombineClient: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var connectionState: ConnectionState = .disconnected

    private var webSocket: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()

    private let messageSubject = PassthroughSubject<ChatMessage, Never>()

    init() {
        messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.messages.append(message)
            }
            .store(in: &cancellables)
    }

    // ... connect/listen/send methods using messageSubject.send()
}
```

## Migration Mapping Table

| Android | iOS (Native) | iOS (Starscream) |
|---|---|---|
| `OkHttpClient.newWebSocket()` | `URLSession.webSocketTask(with:)` | `WebSocket(request:)` |
| `WebSocketListener.onOpen` | Immediate after `.resume()` | `.connected` event |
| `WebSocketListener.onMessage(text)` | `ws.receive()` -> `.string` | `.text` event |
| `WebSocketListener.onMessage(bytes)` | `ws.receive()` -> `.data` | `.binary` event |
| `WebSocketListener.onClosing` | N/A (handle in receive error) | `.disconnected` event |
| `WebSocketListener.onClosed` | Catch after `.cancel()` | `.disconnected` event |
| `WebSocketListener.onFailure` | Catch error in `receive()` | `.error` event |
| `webSocket.send(text)` | `ws.send(.string(text))` | `socket.write(string:)` |
| `webSocket.send(ByteString)` | `ws.send(.data(data))` | `socket.write(data:)` |
| `webSocket.close(code, reason)` | `ws.cancel(with:reason:)` | `socket.disconnect()` |
| `SharedFlow<Message>` | `AsyncStream<Message>` | `AsyncStream<Message>` |
| `StateFlow<ConnectionState>` | `AsyncStream<ConnectionState>` | Callback-based |
| `viewModelScope.launch { flow.collect }` | `Task { for await in stream }` | `Task { for await in stream }` |
| Scarlet `@Receive` | Manual stream setup | Manual stream setup |
| Scarlet `@Send` | `send()` method | `write()` method |
| `ExponentialBackoffStrategy` | Manual exponential backoff | Manual exponential backoff |
| `AndroidLifecycle.ofApplicationForeground` | `.task { }` view modifier | `scenePhase` observation |
| Ktor `WebSockets` plugin | N/A (use native or Starscream) | N/A |
| `Frame.Text` / `Frame.Binary` | `.string` / `.data` | `.text` / `.binary` |

## Common Pitfalls

1. **URLSessionWebSocketTask receive is one-shot** — Unlike Android's `WebSocketListener` which continuously fires callbacks, iOS's `URLSessionWebSocketTask.receive()` returns a single message. You must call it again recursively/in a loop to keep receiving. Forgetting this results in receiving only the first message.

2. **No built-in reconnection** — Neither `URLSessionWebSocketTask` nor Starscream provides automatic reconnection out of the box. Android's Scarlet has `ExponentialBackoffStrategy` built in. On iOS, you must implement exponential backoff reconnection manually.

3. **Actor isolation and sendability** — WebSocket clients often need to be accessed from multiple contexts (UI thread for state, background for receiving). Use Swift `actor` to ensure thread safety, or mark classes with `@MainActor` if all state mutations happen on the main thread.

4. **AsyncStream continuation lifecycle** — If you create an `AsyncStream` with a continuation, you must call `continuation.finish()` when the WebSocket closes or the stream consumer will hang indefinitely waiting for more values.

5. **Missing ping/pong handling** — OkHttp handles WebSocket ping/pong automatically. `URLSessionWebSocketTask` also handles pings automatically, but if you need to send custom pings, use `ws.sendPing(pongReceiveHandler:)`. Starscream exposes ping/pong events that you can observe.

6. **Background execution** — On Android, a foreground Service can keep a WebSocket alive in the background. On iOS, background execution is severely limited. WebSocket connections are suspended when the app enters the background. Use Background App Refresh, push notifications, or PushKit for real-time updates when backgrounded.

7. **Memory leaks with closure captures** — Android's `WebSocketListener` is an anonymous class that can leak the outer class. On iOS, closures in `socket.onEvent` and `Task` blocks can similarly create retain cycles. Always use `[weak self]` in closures that capture `self`.

8. **Scarlet has no direct iOS equivalent** — Scarlet's declarative, annotation-based approach (defining a service interface like Retrofit) has no iOS counterpart. On iOS, you must manually build the WebSocket client with connection management, serialization, and stream exposure.

## Migration Checklist

- [ ] Identify all WebSocket connection points in the Android codebase
- [ ] Determine if the app uses OkHttp WebSocket, Ktor WebSocket, or Scarlet
- [ ] Choose iOS approach: `URLSessionWebSocketTask` (native, no dependencies) or Starscream (richer API)
- [ ] Implement the WebSocket client class using `actor` for thread safety
- [ ] Set up `AsyncStream`-based message and connection state streams
- [ ] Implement recursive `receive()` loop for `URLSessionWebSocketTask`
- [ ] Implement exponential backoff reconnection logic
- [ ] Map Scarlet `@Receive`/`@Send` annotations to manual stream/send methods
- [ ] Convert `Flow.collect` in ViewModels to `for await in` Task blocks
- [ ] Add `deinit` cleanup: cancel tasks, close WebSocket, finish continuations
- [ ] Bind connection lifecycle to SwiftUI view using `.task { }` modifier
- [ ] Handle app backgrounding — WebSocket will be suspended; plan for reconnection on `scenePhase` changes
- [ ] Implement message serialization using `Codable` (replacing Moshi/Gson/kotlinx.serialization)
- [ ] Test reconnection behavior under network interruption conditions
- [ ] Test memory leaks with Instruments (Leaks tool) during connect/disconnect cycles

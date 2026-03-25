---
name: generic-android-to-ios-paging
description: Guides migration of Android Paging 3 (PagingSource, RemoteMediator, PagingData, LazyPagingItems in Compose, LoadState) to iOS equivalents (custom pagination with onAppear-triggered loading, AsyncSequence-based data loading, infinite scroll in List/LazyVStack) with cursor/offset pagination, caching, and error/loading states
type: generic
---

# generic-android-to-ios-paging

## Context

Android's Paging 3 library provides a sophisticated framework for loading data incrementally with built-in support for local caching, remote fetching, load state tracking, and Compose integration via `LazyPagingItems`. iOS has no first-party equivalent library. Pagination on iOS is implemented through custom solutions combining SwiftUI's `List`/`LazyVStack` with `onAppear`-triggered loading, `AsyncSequence` for streaming pages, and manual state management. This skill provides patterns to replicate Paging 3's capabilities on iOS while remaining idiomatic to SwiftUI and Swift concurrency.

## Android Best Practices (Source Patterns)

### PagingSource (Network Only)

```kotlin
class ArticlePagingSource(
    private val api: ArticleApi,
    private val query: String
) : PagingSource<Int, Article>() {

    override suspend fun load(params: LoadParams<Int>): LoadResult<Int, Article> {
        val page = params.key ?: 1
        return try {
            val response = api.searchArticles(
                query = query,
                page = page,
                pageSize = params.loadSize
            )
            LoadResult.Page(
                data = response.articles,
                prevKey = if (page == 1) null else page - 1,
                nextKey = if (response.articles.isEmpty()) null else page + 1
            )
        } catch (e: Exception) {
            LoadResult.Error(e)
        }
    }

    override fun getRefreshKey(state: PagingState<Int, Article>): Int? {
        return state.anchorPosition?.let { anchor ->
            state.closestPageToPosition(anchor)?.prevKey?.plus(1)
                ?: state.closestPageToPosition(anchor)?.nextKey?.minus(1)
        }
    }
}
```

### Cursor-Based PagingSource

```kotlin
class CursorPagingSource(
    private val api: FeedApi
) : PagingSource<String, FeedItem>() {

    override suspend fun load(params: LoadParams<String>): LoadResult<String, FeedItem> {
        return try {
            val response = api.getFeed(
                cursor = params.key,
                limit = params.loadSize
            )
            LoadResult.Page(
                data = response.items,
                prevKey = null,
                nextKey = response.nextCursor
            )
        } catch (e: Exception) {
            LoadResult.Error(e)
        }
    }

    override fun getRefreshKey(state: PagingState<String, FeedItem>): String? = null
}
```

### RemoteMediator (Offline-First with Room)

```kotlin
@OptIn(ExperimentalPagingApi::class)
class ArticleRemoteMediator(
    private val api: ArticleApi,
    private val database: AppDatabase,
    private val query: String
) : RemoteMediator<Int, ArticleEntity>() {

    override suspend fun load(
        loadType: LoadType,
        state: PagingState<Int, ArticleEntity>
    ): MediatorResult {
        val page = when (loadType) {
            LoadType.REFRESH -> 1
            LoadType.PREPEND -> return MediatorResult.Success(endOfPaginationReached = true)
            LoadType.APPEND -> {
                val remoteKey = database.remoteKeyDao().getKeyForQuery(query)
                remoteKey?.nextPage ?: return MediatorResult.Success(endOfPaginationReached = true)
            }
        }

        return try {
            val response = api.searchArticles(query, page, state.config.pageSize)

            database.withTransaction {
                if (loadType == LoadType.REFRESH) {
                    database.articleDao().clearByQuery(query)
                    database.remoteKeyDao().deleteByQuery(query)
                }
                database.remoteKeyDao().insert(
                    RemoteKey(query, if (response.articles.isEmpty()) null else page + 1)
                )
                database.articleDao().insertAll(response.articles.map { it.toEntity() })
            }

            MediatorResult.Success(endOfPaginationReached = response.articles.isEmpty())
        } catch (e: Exception) {
            MediatorResult.Error(e)
        }
    }
}
```

### ViewModel with Pager

```kotlin
@HiltViewModel
class ArticleListViewModel @Inject constructor(
    private val api: ArticleApi,
    private val database: AppDatabase
) : ViewModel() {

    private val _query = MutableStateFlow("")

    val articles: Flow<PagingData<Article>> = _query
        .debounce(300)
        .flatMapLatest { query ->
            Pager(
                config = PagingConfig(
                    pageSize = 20,
                    prefetchDistance = 5,
                    enablePlaceholders = false,
                    initialLoadSize = 40
                ),
                remoteMediator = ArticleRemoteMediator(api, database, query),
                pagingSourceFactory = { database.articleDao().pagingSource(query) }
            ).flow
        }
        .cachedIn(viewModelScope)

    fun onQueryChanged(query: String) {
        _query.value = query
    }
}
```

### Compose UI with LazyPagingItems

```kotlin
@Composable
fun ArticleListScreen(viewModel: ArticleListViewModel = hiltViewModel()) {
    val articles = viewModel.articles.collectAsLazyPagingItems()

    LazyColumn {
        items(
            count = articles.itemCount,
            key = articles.itemKey { it.id }
        ) { index ->
            articles[index]?.let { article ->
                ArticleCard(article = article)
            }
        }

        // Loading states
        when (articles.loadState.append) {
            is LoadState.Loading -> {
                item { LoadingIndicator() }
            }
            is LoadState.Error -> {
                item {
                    RetryButton(
                        onRetry = { articles.retry() }
                    )
                }
            }
            else -> {}
        }

        when (articles.loadState.refresh) {
            is LoadState.Loading -> {
                item { FullScreenLoading() }
            }
            is LoadState.Error -> {
                item {
                    FullScreenError(
                        onRetry = { articles.refresh() }
                    )
                }
            }
            else -> {}
        }
    }
}
```

## iOS Equivalent Patterns

### Core Pagination Infrastructure

```swift
// Generic page result
struct PageResult<Item: Sendable> {
    let items: [Item]
    let nextKey: PaginationKey?
    let isLastPage: Bool
}

enum PaginationKey: Sendable {
    case offset(Int)
    case cursor(String)
    case page(Int)
}

// Load state equivalent
enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)

    static func == (lhs: LoadState, rhs: LoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
```

### Paginator (PagingSource Equivalent)

```swift
@Observable
class Paginator<Item: Identifiable & Sendable> {
    private(set) var items: [Item] = []
    private(set) var refreshState: LoadState = .idle
    private(set) var appendState: LoadState = .idle

    private var nextKey: PaginationKey?
    private var hasReachedEnd = false
    private let pageSize: Int
    private let prefetchDistance: Int
    private let loadPage: (PaginationKey?, Int) async throws -> PageResult<Item>

    init(
        pageSize: Int = 20,
        prefetchDistance: Int = 5,
        loadPage: @escaping (PaginationKey?, Int) async throws -> PageResult<Item>
    ) {
        self.pageSize = pageSize
        self.prefetchDistance = prefetchDistance
        self.loadPage = loadPage
    }

    func refresh() async {
        refreshState = .loading
        appendState = .idle
        hasReachedEnd = false
        nextKey = nil

        do {
            let result = try await loadPage(nil, pageSize)
            items = result.items
            nextKey = result.nextKey
            hasReachedEnd = result.isLastPage
            refreshState = .loaded
        } catch {
            refreshState = .error(error.localizedDescription)
        }
    }

    func loadNextPageIfNeeded(currentItem: Item) async {
        guard !hasReachedEnd, appendState != .loading else { return }

        // Check if we're within prefetch distance of the end
        guard let index = items.firstIndex(where: { $0.id == currentItem.id }),
              index >= items.count - prefetchDistance else {
            return
        }

        await loadNextPage()
    }

    func loadNextPage() async {
        guard !hasReachedEnd, appendState != .loading else { return }

        appendState = .loading
        do {
            let result = try await loadPage(nextKey, pageSize)
            items.append(contentsOf: result.items)
            nextKey = result.nextKey
            hasReachedEnd = result.isLastPage
            appendState = .loaded
        } catch {
            appendState = .error(error.localizedDescription)
        }
    }

    func retry() async {
        if case .error = refreshState {
            await refresh()
        } else if case .error = appendState {
            await loadNextPage()
        }
    }
}
```

### Offset-Based Pagination

```swift
@Observable
class ArticleListViewModel {
    let paginator: Paginator<Article>

    private let api: ArticleAPI
    private var query: String = ""

    init(api: ArticleAPI) {
        self.api = api

        self.paginator = Paginator(
            pageSize: 20,
            prefetchDistance: 5
        ) { [api] nextKey, pageSize in
            let page: Int
            switch nextKey {
            case .page(let p): page = p
            case nil: page = 1
            default: page = 1
            }

            let response = try await api.searchArticles(
                query: "",
                page: page,
                pageSize: pageSize
            )

            return PageResult(
                items: response.articles,
                nextKey: response.articles.isEmpty ? nil : .page(page + 1),
                isLastPage: response.articles.isEmpty
            )
        }
    }

    func onQueryChanged(_ newQuery: String) {
        query = newQuery
        Task { await paginator.refresh() }
    }
}
```

### Cursor-Based Pagination

```swift
@Observable
class FeedViewModel {
    let paginator: Paginator<FeedItem>

    init(api: FeedAPI) {
        self.paginator = Paginator(
            pageSize: 20,
            prefetchDistance: 5
        ) { nextKey, limit in
            let cursor: String?
            switch nextKey {
            case .cursor(let c): cursor = c
            case nil: cursor = nil
            default: cursor = nil
            }

            let response = try await api.getFeed(cursor: cursor, limit: limit)

            return PageResult(
                items: response.items,
                nextKey: response.nextCursor.map { .cursor($0) },
                isLastPage: response.nextCursor == nil
            )
        }
    }
}
```

### SwiftUI List with Pagination (LazyPagingItems Equivalent)

```swift
struct ArticleListView: View {
    @State private var viewModel: ArticleListViewModel

    init(api: ArticleAPI) {
        _viewModel = State(initialValue: ArticleListViewModel(api: api))
    }

    var body: some View {
        Group {
            switch viewModel.paginator.refreshState {
            case .idle:
                Color.clear.onAppear {
                    Task { await viewModel.paginator.refresh() }
                }
            case .loading where viewModel.paginator.items.isEmpty:
                ProgressView("Loading articles...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let message) where viewModel.paginator.items.isEmpty:
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.paginator.retry() }
                    }
                }
            default:
                articleList
            }
        }
        .refreshable {
            await viewModel.paginator.refresh()
        }
    }

    private var articleList: some View {
        List {
            ForEach(viewModel.paginator.items) { article in
                ArticleRow(article: article)
                    .onAppear {
                        Task {
                            await viewModel.paginator.loadNextPageIfNeeded(
                                currentItem: article
                            )
                        }
                    }
            }

            // Append loading / error footer
            switch viewModel.paginator.appendState {
            case .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            case .error(let message):
                VStack(spacing: 8) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await viewModel.paginator.loadNextPage() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
            default:
                EmptyView()
            }
        }
        .listStyle(.plain)
    }
}
```

### Offline-First with SwiftData (RemoteMediator Equivalent)

```swift
import SwiftData

@Model
class CachedArticle {
    @Attribute(.unique) var id: String
    var title: String
    var content: String
    var query: String
    var pageIndex: Int
    var cachedAt: Date

    init(id: String, title: String, content: String, query: String, pageIndex: Int) {
        self.id = id
        self.title = title
        self.content = content
        self.query = query
        self.pageIndex = pageIndex
        self.cachedAt = Date()
    }
}

@Model
class PaginationRemoteKey {
    @Attribute(.unique) var query: String
    var nextPage: Int?

    init(query: String, nextPage: Int?) {
        self.query = query
        self.nextPage = nextPage
    }
}

@Observable
class OfflineFirstPaginator {
    private(set) var articles: [CachedArticle] = []
    private(set) var refreshState: LoadState = .idle
    private(set) var appendState: LoadState = .idle

    private let modelContext: ModelContext
    private let api: ArticleAPI
    private var query: String = ""
    private var hasReachedEnd = false

    init(modelContext: ModelContext, api: ArticleAPI) {
        self.modelContext = modelContext
        self.api = api
    }

    func refresh(query: String) async {
        self.query = query
        refreshState = .loading
        hasReachedEnd = false

        // Load from cache first
        loadFromCache()

        // Then fetch from network
        do {
            let response = try await api.searchArticles(query: query, page: 1, pageSize: 20)

            // Clear old cache for this query
            try modelContext.delete(
                model: CachedArticle.self,
                where: #Predicate { $0.query == query }
            )
            try modelContext.delete(
                model: PaginationRemoteKey.self,
                where: #Predicate { $0.query == query }
            )

            // Insert new data
            for (index, article) in response.articles.enumerated() {
                let cached = CachedArticle(
                    id: article.id,
                    title: article.title,
                    content: article.content,
                    query: query,
                    pageIndex: index
                )
                modelContext.insert(cached)
            }

            let nextPage = response.articles.isEmpty ? nil : 2
            let key = PaginationRemoteKey(query: query, nextPage: nextPage)
            modelContext.insert(key)

            try modelContext.save()
            hasReachedEnd = response.articles.isEmpty
            loadFromCache()
            refreshState = .loaded
        } catch {
            // Cache is already displayed, just update state
            refreshState = articles.isEmpty ? .error(error.localizedDescription) : .loaded
        }
    }

    func loadNextPage() async {
        guard !hasReachedEnd, appendState != .loading else { return }
        appendState = .loading

        // Get next page from remote key
        let descriptor = FetchDescriptor<PaginationRemoteKey>(
            predicate: #Predicate { $0.query == query }
        )
        guard let remoteKey = try? modelContext.fetch(descriptor).first,
              let nextPage = remoteKey.nextPage else {
            hasReachedEnd = true
            appendState = .loaded
            return
        }

        do {
            let response = try await api.searchArticles(
                query: query, page: nextPage, pageSize: 20
            )

            let currentCount = articles.count
            for (index, article) in response.articles.enumerated() {
                let cached = CachedArticle(
                    id: article.id,
                    title: article.title,
                    content: article.content,
                    query: query,
                    pageIndex: currentCount + index
                )
                modelContext.insert(cached)
            }

            remoteKey.nextPage = response.articles.isEmpty ? nil : nextPage + 1
            try modelContext.save()

            hasReachedEnd = response.articles.isEmpty
            loadFromCache()
            appendState = .loaded
        } catch {
            appendState = .error(error.localizedDescription)
        }
    }

    private func loadFromCache() {
        var descriptor = FetchDescriptor<CachedArticle>(
            predicate: #Predicate { $0.query == query },
            sortBy: [SortDescriptor(\.pageIndex)]
        )
        articles = (try? modelContext.fetch(descriptor)) ?? []
    }
}
```

### Debounced Search with Pagination

```swift
@Observable
class SearchViewModel {
    var searchText: String = "" {
        didSet { debouncedSearch() }
    }

    let paginator: Paginator<Article>
    private var searchTask: Task<Void, Never>?

    init(api: ArticleAPI) {
        self.paginator = Paginator(pageSize: 20) { nextKey, pageSize in
            // loadPage closure captures current query at call time
            let page: Int = switch nextKey {
            case .page(let p): p
            case nil: 1
            default: 1
            }
            let response = try await api.searchArticles(
                query: "", page: page, pageSize: pageSize
            )
            return PageResult(
                items: response.articles,
                nextKey: response.articles.isEmpty ? nil : .page(page + 1),
                isLastPage: response.articles.isEmpty
            )
        }
    }

    private func debouncedSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await paginator.refresh()
        }
    }
}
```

## Concept Mapping

| Android Paging 3 | iOS Equivalent |
|------------------|----------------|
| `PagingSource` | Custom `Paginator` class with `loadPage` closure |
| `PagingConfig` | `pageSize` and `prefetchDistance` parameters |
| `RemoteMediator` | Custom offline-first paginator with SwiftData/Core Data |
| `PagingData` | `@Observable` class with `items` array |
| `LazyPagingItems` | `ForEach` + `onAppear` trigger |
| `LoadState.Loading` | Custom `LoadState.loading` enum |
| `LoadState.Error` | Custom `LoadState.error(String)` enum |
| `items.loadState.refresh` | `refreshState` property |
| `items.loadState.append` | `appendState` property |
| `items.retry()` | `paginator.retry()` method |
| `items.refresh()` | `paginator.refresh()` method |
| `.cachedIn(viewModelScope)` | Items stored in `@Observable` viewModel (automatic with SwiftUI) |
| `enablePlaceholders` | No direct equivalent; use shimmer/skeleton views |

## Common Pitfalls

1. **Not using onAppear for prefetch** - Without onAppear-triggered loading, the user hits the end of the list before new data loads. Always trigger loading when items near the end appear.

2. **Loading duplicate pages** - Without a guard against concurrent loads (`appendState != .loading`), rapid scrolling can trigger the same page multiple times. Always check state before initiating a load.

3. **Not cancelling previous search** - When query text changes rapidly, cancel the previous search task to avoid out-of-order results and wasted network calls.

4. **Forgetting pull-to-refresh** - SwiftUI's `.refreshable` modifier provides native pull-to-refresh. Always wire it to `paginator.refresh()` to reset and reload from page 1.

5. **Using ScrollView instead of List for large datasets** - `ScrollView` with `LazyVStack` does not recycle views as aggressively as `List`. For very large paginated lists, prefer `List` for better memory performance.

6. **Not handling empty state** - After a successful refresh with zero results, display an empty state view rather than a loading indicator or blank screen.

7. **Losing pagination state on view recreation** - If the paginator is created inside a view's init, SwiftUI may recreate it on recomposition. Use `@State` or keep it in a parent-owned view model.

8. **Not persisting intermediate pages for offline** - Unlike RemoteMediator which writes each page to Room, custom iOS solutions often skip caching. For offline-first, persist each page to SwiftData as it arrives.

## Migration Checklist

- [ ] Create a generic `Paginator<Item>` class with `refresh()`, `loadNextPage()`, and `retry()` methods
- [ ] Define `LoadState` enum matching Paging 3's states (idle, loading, loaded, error)
- [ ] Implement page-based or cursor-based loading in the `loadPage` closure
- [ ] Add prefetch distance logic using `onAppear` on list items near the end
- [ ] Guard against concurrent loads and duplicate page fetches
- [ ] Implement pull-to-refresh with `.refreshable` modifier wired to `paginator.refresh()`
- [ ] Handle all UI states: initial loading, empty results, append loading, append error, refresh error
- [ ] Add retry functionality for both refresh and append errors
- [ ] For offline-first: implement SwiftData caching with remote key tracking (RemoteMediator equivalent)
- [ ] Add search debouncing with `Task` cancellation for query-driven pagination
- [ ] Use `@State` or dependency injection to preserve paginator across view updates
- [ ] Test scroll performance with large datasets; prefer `List` over `ScrollView + LazyVStack`
- [ ] Add skeleton/shimmer placeholders for initial load if the Android version used `enablePlaceholders`
- [ ] Verify memory usage under rapid scrolling with Instruments (Allocations)

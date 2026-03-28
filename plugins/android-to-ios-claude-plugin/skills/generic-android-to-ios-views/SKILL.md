---
name: generic-android-to-ios-views
description: Use when migrating Android XML-based Views (ViewBinding, DataBinding, ConstraintLayout, RecyclerView) to iOS UIKit equivalents (Storyboards, XIBs, programmatic layout, Auto Layout, UICollectionView, UITableView)
type: generic
---

# generic-android-to-ios-views

## Context

Android's traditional UI system is built on XML layout files inflated into `View` hierarchies at runtime. Developers use ViewBinding or DataBinding to safely reference views, ConstraintLayout for flexible positioning, and RecyclerView for efficient scrolling lists. On iOS, the UIKit equivalent uses Storyboards, XIBs, or programmatic view construction with Auto Layout constraints, and UICollectionView or UITableView for scrolling lists.

This skill provides a comprehensive reference for migrating Android XML-based View code to iOS UIKit code. It covers layout systems, view references, list rendering, and lifecycle patterns. Use this skill when converting an existing Android screen or component to its UIKit equivalent.

## Concept Mapping

| Android | iOS UIKit |
|---------|-----------|
| `View` | `UIView` |
| XML layout file | Storyboard / XIB / programmatic `UIView` subclass |
| `ViewBinding` | `@IBOutlet` or programmatic property references |
| `DataBinding` | Combine-based bindings or manual KVO |
| `ConstraintLayout` | Auto Layout (`NSLayoutConstraint`) |
| `LinearLayout` (vertical) | `UIStackView` with `.vertical` axis |
| `LinearLayout` (horizontal) | `UIStackView` with `.horizontal` axis |
| `FrameLayout` | Plain `UIView` with subview constraints |
| `RecyclerView` + `Adapter` | `UICollectionView` + `UICollectionViewDataSource` / Diffable Data Source |
| `RecyclerView` + `Adapter` (simple list) | `UITableView` + `UITableViewDataSource` / Diffable Data Source |
| `RecyclerView.ViewHolder` | `UICollectionViewCell` / `UITableViewCell` |
| `RecyclerView.LayoutManager` | `UICollectionViewLayout` / `UICollectionViewCompositionalLayout` |
| `ListAdapter` / `DiffUtil` | `UICollectionViewDiffableDataSource` / `NSDiffableDataSourceSnapshot` |
| `Fragment` | `UIViewController` |
| `Activity` | `UIViewController` (root) or `UINavigationController` |
| `ViewGroup.LayoutParams` | Auto Layout constraints |
| `View.GONE` / `View.VISIBLE` | `isHidden = true/false` + stack view automatic removal |
| `android:padding` | `layoutMargins` or `directionalLayoutMargins` |
| `android:layout_margin` | Constraint constants or `UIStackView` spacing |
| `View.OnClickListener` | `addTarget(_:action:for:)` or `UIAction` |
| `RecyclerView.ItemDecoration` | `UICollectionViewDelegateFlowLayout` or custom layout attributes |

## Android Best Practices (Kotlin, 2024-2025)

- Use ViewBinding over `findViewById` -- it is null-safe and type-safe.
- Prefer ConstraintLayout as the root container to flatten view hierarchies.
- Use `ListAdapter` with `DiffUtil.ItemCallback` for RecyclerView to get efficient item-level animations.
- Use `ConcatAdapter` to compose multiple adapters for heterogeneous lists.
- Avoid nested `LinearLayout`s -- use ConstraintLayout chains or `Flow` instead.
- Use `ViewBinding` delegate patterns in Fragments to avoid memory leaks (nullify binding in `onDestroyView`).

```kotlin
// Android: ViewBinding in Fragment
class ProfileFragment : Fragment(R.layout.fragment_profile) {
    private var _binding: FragmentProfileBinding? = null
    private val binding get() = _binding!!

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        _binding = FragmentProfileBinding.bind(view)

        binding.nameTextView.text = "John Doe"
        binding.avatarImageView.load("https://example.com/avatar.png")
        binding.editButton.setOnClickListener { navigateToEdit() }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
```

```kotlin
// Android: RecyclerView with ListAdapter
class UserAdapter : ListAdapter<User, UserAdapter.ViewHolder>(UserDiffCallback()) {

    class ViewHolder(private val binding: ItemUserBinding) : RecyclerView.ViewHolder(binding.root) {
        fun bind(user: User) {
            binding.nameText.text = user.name
            binding.emailText.text = user.email
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemUserBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(getItem(position))
    }
}

class UserDiffCallback : DiffUtil.ItemCallback<User>() {
    override fun areItemsTheSame(oldItem: User, newItem: User) = oldItem.id == newItem.id
    override fun areContentsTheSame(oldItem: User, newItem: User) = oldItem == newItem
}
```

## iOS Best Practices (Swift, UIKit, 2024-2025)

- Prefer programmatic Auto Layout over Storyboards for complex or reusable views -- it is easier to review in code.
- Use `UICollectionViewCompositionalLayout` (iOS 13+) for modern list and grid layouts.
- Use `UICollectionViewDiffableDataSource` with `NSDiffableDataSourceSnapshot` for automatic diffing and animations.
- Use `UICollectionView` with list configuration instead of `UITableView` for new code (iOS 14+).
- Activate constraints in batches using `NSLayoutConstraint.activate([...])` rather than one-by-one.
- Set `translatesAutoresizingMaskIntoConstraints = false` on every programmatically created view before adding constraints.
- Use `UIStackView` to replace simple `LinearLayout` equivalents -- it handles visibility toggling automatically.
- Use `UIAction` closures (iOS 14+) instead of target-action for button handling.

```swift
// iOS: Programmatic UIViewController equivalent to ProfileFragment
class ProfileViewController: UIViewController {
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var editButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Edit", for: .normal)
        button.addAction(UIAction { [weak self] _ in
            self?.navigateToEdit()
        }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let stack = UIStackView(arrangedSubviews: [avatarImageView, nameLabel, editButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageView.heightAnchor.constraint(equalToConstant: 100),
        ])

        nameLabel.text = "John Doe"
        // Load avatar via URLSession or an image loading library
    }

    private func navigateToEdit() {
        let editVC = EditProfileViewController()
        navigationController?.pushViewController(editVC, animated: true)
    }
}
```

```swift
// iOS: UICollectionView with DiffableDataSource equivalent to RecyclerView + ListAdapter
class UserListViewController: UIViewController {
    enum Section { case main }

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, User>!

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
    }

    private func configureCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)
    }

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, User> { cell, indexPath, user in
            var content = cell.defaultContentConfiguration()
            content.text = user.name
            content.secondaryText = user.email
            cell.contentConfiguration = content
        }

        dataSource = UICollectionViewDiffableDataSource<Section, User>(collectionView: collectionView) {
            collectionView, indexPath, user in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: user)
        }
    }

    func applySnapshot(users: [User], animating: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, User>()
        snapshot.appendSections([.main])
        snapshot.appendItems(users)
        dataSource.apply(snapshot, animatingDifferences: animating)
    }
}
```

## Common Pitfalls and Gotchas

1. **Forgetting `translatesAutoresizingMaskIntoConstraints = false`** -- This is the single most common UIKit bug. Every programmatically created view must have this set to `false` before adding Auto Layout constraints, or the autoresizing mask will conflict.

2. **RecyclerView cell reuse vs. UICollectionView cell reuse** -- Both platforms reuse cells, but iOS requires calling `prepareForReuse()` to reset state. Failing to reset toggles, images, or text in reused cells causes visual glitches.

3. **ConstraintLayout guidelines vs. Auto Layout guides** -- ConstraintLayout `Guideline` maps to `UILayoutGuide` on iOS, not to invisible views. Using invisible views wastes memory.

4. **Fragment lifecycle vs. UIViewController lifecycle** -- `onViewCreated` maps roughly to `viewDidLoad`, but `onDestroyView` has no direct equivalent. Use `deinit` or `viewDidDisappear` with appropriate cleanup. Be especially careful with observation/subscription cleanup.

5. **DataBinding two-way bindings** -- iOS has no built-in two-way data binding. Use Combine's `assign(to:)` for one-way and manual `@objc` target-action or `UITextFieldDelegate` for reverse flow.

6. **RecyclerView `notifyItemChanged` vs. Diffable snapshots** -- Do not manually call `reloadItems` on a diffable data source to force a UI refresh. Instead, create a new snapshot or use `reconfigureItems` (iOS 15+) which reuses existing cells.

7. **View.GONE behavior** -- Android's `GONE` removes the view from layout calculations. iOS `isHidden` does the same only inside a `UIStackView`. In plain Auto Layout, hiding a view does not collapse its space -- you must deactivate constraints or use stack views.

8. **Thread safety** -- Both platforms require UI updates on the main thread. Android's `View.post {}` maps to `DispatchQueue.main.async {}` or `@MainActor` on iOS.

9. **XML `match_parent` / `wrap_content`** -- There is no direct equivalent in Auto Layout. `match_parent` maps to pinning edges to the superview. `wrap_content` is the default intrinsic content size behavior, but you may need to set content hugging and compression resistance priorities.

10. **RecyclerView `ItemDecoration`** -- iOS has no direct equivalent. Use section-level insets in `UICollectionViewCompositionalLayout`, custom `UICollectionViewLayoutAttributes`, or supplementary views for separators and spacing.

## Migration Checklist

1. **Inventory all XML layouts** -- List every XML layout file used by the Android feature. Note root layout types, nested structures, and included layouts.
2. **Map each XML layout to an iOS approach** -- Decide per screen: programmatic UIView, XIB, or Storyboard. Prefer programmatic for reusable components and XIBs for one-off cells.
3. **Convert ViewBinding references to properties** -- Replace each `binding.someView` with a corresponding `UIView` property (lazy var or let) in the UIViewController or UIView subclass.
4. **Translate ConstraintLayout to Auto Layout** -- Convert each constraint: `app:layout_constraintTop_toBottomOf` becomes `topAnchor.constraint(equalTo: otherView.bottomAnchor)`. Convert chains to stack views.
5. **Replace LinearLayout with UIStackView** -- Map `orientation="vertical"` to `.vertical` axis, `orientation="horizontal"` to `.horizontal`. Map `layout_weight` to stack view distribution (`.fillProportionally` or custom constraints).
6. **Migrate RecyclerView to UICollectionView** -- Use `UICollectionViewCompositionalLayout` with list configuration. Port `DiffUtil.ItemCallback` identity checks to `Hashable` conformance on your model.
7. **Port Adapter to DiffableDataSource** -- Replace `onCreateViewHolder`/`onBindViewHolder` with `CellRegistration` closures.
8. **Convert click listeners** -- Replace `setOnClickListener` with `UIAction` closures or target-action patterns.
9. **Handle visibility toggling** -- Replace `View.GONE`/`View.VISIBLE` with `isHidden` inside stack views, or constraint activation/deactivation outside stack views.
10. **Port view animations** -- Replace Android `ViewPropertyAnimator` or `TransitionManager` with `UIView.animate(withDuration:)` or `UIViewPropertyAnimator`.
11. **Test on multiple screen sizes** -- Verify Auto Layout adapts correctly to iPhone SE through iPhone Pro Max and iPad if applicable.
12. **Verify accessibility** -- Migrate `contentDescription` to `accessibilityLabel`. Ensure VoiceOver support matches TalkBack behavior.

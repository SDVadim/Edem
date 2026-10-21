import UIKit

/// Каталог машин на UIKit: UICollectionView с compositional layout и diffable data source.
final class CarsCollectionViewController: UIViewController {
    enum Section: Int, CaseIterable {
        case filters
        case cars
    }

    enum Item: Hashable {
        case filter(CatalogFilter, isSelected: Bool)
        case car(Car)
    }

    var onSelectFilter: ((CatalogFilter) -> Void)?
    var onSelectCar: ((Car) -> Void)?
    var onRefresh: (() async -> Void)?

    private let imageLoader: ImageLoading
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private let refreshControl = UIRefreshControl()

    init(imageLoader: ImageLoading) {
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureCollectionView()
        configureDataSource()
    }

    func apply(cars: [Car], filters: [CatalogFilter], selectedFilter: CatalogFilter) {
        loadViewIfNeeded()
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(Section.allCases)
        snapshot.appendItems(filters.map { .filter($0, isSelected: $0 == selectedFilter) }, toSection: .filters)
        snapshot.appendItems(cars.map(Item.car), toSection: .cars)
        dataSource.apply(snapshot, animatingDifferences: view.window != nil)
    }

    // MARK: - Setup

    private func configureCollectionView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        collectionView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureDataSource() {
        let filterRegistration = UICollectionView.CellRegistration<FilterChipCell, (CatalogFilter, Bool)> { cell, _, item in
            cell.configure(title: item.0.title, isSelected: item.1)
        }
        let carRegistration = UICollectionView.CellRegistration<CarCell, Car> { [imageLoader] cell, _, car in
            cell.configure(with: car, imageLoader: imageLoader)
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case let .filter(filter, isSelected):
                return collectionView.dequeueConfiguredReusableCell(
                    using: filterRegistration, for: indexPath, item: (filter, isSelected)
                )
            case .car(let car):
                return collectionView.dequeueConfiguredReusableCell(using: carRegistration, for: indexPath, item: car)
            }
        }
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, environment in
            switch Section(rawValue: sectionIndex) ?? .cars {
            case .filters:
                let size = NSCollectionLayoutSize(widthDimension: .estimated(90), heightDimension: .absolute(36))
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .continuous
                section.interGroupSpacing = 8
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                return section

            case .cars:
                let columns = environment.container.effectiveContentSize.width > 600 ? 3 : 2
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
                    heightDimension: .estimated(250)
                ))
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(250)),
                    repeatingSubitem: item,
                    count: columns
                )
                group.interItemSpacing = .fixed(12)
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 16
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 24, trailing: 16)
                return section
            }
        }
    }

    @objc private func handleRefresh() {
        Task { [weak self] in
            await self?.onRefresh?()
            self?.refreshControl.endRefreshing()
        }
    }
}

extension CarsCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .filter(let filter, _):
            onSelectFilter?(filter)
        case .car(let car):
            onSelectCar?(car)
        }
    }
}

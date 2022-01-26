import UIKit

private enum ProductSection: Hashable {
    case main
}

private enum RequestInformation {
    static let pageNumber = 1
    static let itemsPerPage = 30
}

private enum Design {
    static let indicatorWidth: CGFloat = 50
    static let indicatorHeight: CGFloat = 50
    static let interItemSpacing: CGFloat = 15
    static let interGroupSpacing: CGFloat = 10
    static let columnCount = 2
    static let sectionEdgeInsets: NSDirectionalEdgeInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
    static let gridCellBorderWidth: CGFloat = 1
    static let gridCellCornerRadius: CGFloat = 10
}

class MainViewController: UIViewController {
    private var productListCollectionView: UICollectionView!
    private var productGridCollectionView: UICollectionView!
    private var layoutSegmentedControl: CustomSegmentedControl!
    private var listDataSource: UICollectionViewDiffableDataSource<ProductSection, ProductDetail>?
    private var gridDataSource: UICollectionViewDiffableDataSource<ProductSection, ProductDetail>?
    private var productData: [ProductDetail] = []
    private let api = APIService()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        indicator.hidesWhenStopped = true
        indicator.frame = CGRect(origin: .zero, size: CGSize(width: Design.indicatorWidth, height: Design.indicatorHeight))
        indicator.center = view.center
        indicator.style = .large
        indicator.color = .black
        return indicator
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(fetchProductData), name: .updateProductData, object: nil)
        configUI()
        fetchProductData()
        productListCollectionView.delegate = self
        productGridCollectionView.delegate = self
    }

    @objc private func fetchProductData() {
        activityIndicator.startAnimating()
                
        api.retrieveProductList(pageNo: RequestInformation.pageNumber, itemsPerPage: RequestInformation.itemsPerPage) { result in
            switch result {
            case .success(let data):
                self.productData = data.pages                
                DispatchQueue.main.async {
                    self.configProductCollectionViewDataSource()
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    private func showProductDetail(from id: Int) {
        api.retrieveProductDetail(productId: id) { result in
            switch result {
            case .success(let productDetail):
                DispatchQueue.main.async {
                    let productDetailController = ProductDetailViewController(productDetail: productDetail)
                    self.navigationController?.pushViewController(productDetailController, animated: true)
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    private func configProductCollectionViewDataSource() {
        if listDataSource == nil && gridDataSource == nil {
            configListDataSource()
            configGridDataSource()
        }
        configSnapShot(with: listDataSource)
        configSnapShot(with: gridDataSource)
        activityIndicator.stopAnimating()
    }
    
    @objc private func switchCollectionViewLayout() {
        if layoutSegmentedControl.selectedSegmentIndex == 0 {
            productListCollectionView.isHidden = false
            productGridCollectionView.isHidden = true
            return
        }
        productListCollectionView.isHidden = true
        productGridCollectionView.isHidden = false
    }

    private func configUI() {
        configSegmentedControl()
        setupListAndGridCollectionView()
        configNavigationBar()
        view.backgroundColor = .white
        view.addSubview(activityIndicator)
    }
    
    private func configSegmentedControl() {
        layoutSegmentedControl = CustomSegmentedControl(items: ["LIST", "GRID"])
        layoutSegmentedControl.addTarget(self, action: #selector(switchCollectionViewLayout), for: .valueChanged)
    }

    private func setupListAndGridCollectionView() {
        configListCollectionView()
        configGridCollectionView()
        productGridCollectionView.isHidden = true
    }

    private func configNavigationBar() {
        self.navigationItem.titleView = layoutSegmentedControl
        self.navigationItem.backButtonTitle = ""
        let plusImage = UIImage(systemName: "plus")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: plusImage, style: .plain, target: self, action: #selector(presentProductRegisterView))
    }
    
    @objc private func presentProductRegisterView() {
        let destination = UINavigationController(rootViewController: ProductRegisterViewController()) 
        destination.modalPresentationStyle = .fullScreen
        self.present(destination, animated: true, completion: nil)
    }
    
    private func configCollectionViewLayout(_ collectionView: UICollectionView) {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
                
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
    }
}

// MARK: - Custom List CollectionView

private extension MainViewController {
    func createListLayout() -> UICollectionViewLayout {
        let configuration = UICollectionLayoutListConfiguration(appearance: .plain)
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }
    
    func configListCollectionView() {
        productListCollectionView = UICollectionView(frame: .zero, collectionViewLayout: createListLayout())
        view.addSubview(productListCollectionView)
        configCollectionViewLayout(productListCollectionView)
    }
    
    func configListDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<ProductListLayoutCell, ProductDetail> { cell, _, product in
            cell.updateWithProduct(from: product)
            cell.accessories = [.disclosureIndicator()]
        }
        
        listDataSource = UICollectionViewDiffableDataSource<ProductSection, ProductDetail>(collectionView: productListCollectionView) { (collectionView, indexPath, product) -> UICollectionViewCell? in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: product)
        }
    }
}

// MARK: - Custom Grid CollectionView

private extension MainViewController {
    func createItemLayout() -> NSCollectionLayoutItem {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        
        return NSCollectionLayoutItem(layoutSize: itemSize)
    }
    
    func createGroupLayout(with item: NSCollectionLayoutItem) -> NSCollectionLayoutGroup {
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(self.view.frame.height * 0.35))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: Design.columnCount)
        group.interItemSpacing = .fixed(Design.interItemSpacing)
        
        return group
    }
    
    func createSectionLayout(with group: NSCollectionLayoutGroup) -> NSCollectionLayoutSection {
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = CGFloat(Design.interGroupSpacing)
        section.contentInsets = Design.sectionEdgeInsets
        
        return section
    }
    
    func createGridLayout() -> UICollectionViewLayout {
        let item = createItemLayout()
        let group = createGroupLayout(with: item)
        let section = createSectionLayout(with: group)
        let layout = UICollectionViewCompositionalLayout(section: section)
        
        return layout
    }
    
    func configGridCollectionView() {
        productGridCollectionView = UICollectionView(frame: .zero, collectionViewLayout: createGridLayout())
        view.addSubview(productGridCollectionView)
        configCollectionViewLayout(productGridCollectionView)
    }
    
    func configGridDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<ProductGridLayoutCell, ProductDetail> { (cell, _, product) in
            cell.configUI(with: product)
            cell.layer.borderColor = UIColor.lightGray.cgColor
            cell.layer.borderWidth = Design.gridCellBorderWidth
            cell.layer.masksToBounds = true
            cell.layer.cornerRadius = Design.gridCellCornerRadius
        }
        
        gridDataSource = UICollectionViewDiffableDataSource<ProductSection, ProductDetail>(collectionView: productGridCollectionView) { (collectionView, indexPath, product) -> UICollectionViewCell? in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: product)
        }
    }
    
    func configSnapShot(with dataSource: UICollectionViewDiffableDataSource<ProductSection, ProductDetail>?) {
        var snapshot = NSDiffableDataSourceSnapshot<ProductSection, ProductDetail>()
        snapshot.appendSections([.main])
        snapshot.appendItems(productData)
        dataSource?.apply(snapshot)
    }
}

extension MainViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedProductID = productData[indexPath.item].id
        showProductDetail(from: selectedProductID)
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}
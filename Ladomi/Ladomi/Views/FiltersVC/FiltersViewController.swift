import UIKit

class FiltersViewController: UIViewController {
    
    // MARK: - Public Properties
    
    var selectedFilter: FilterType = .all
    var onFilterSelected: ((FilterType) -> Void)?
    
    // MARK: - Private properties
    
    private lazy var titleLabel: UILabel = {
       let label = UILabel()
        let text = NSLocalizedString("filterButton", comment: "заголовок")
        label.text = text
        label.font = .ladomiBold(32)
        label.textColor = .ypBlack
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.82
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        return tableView
    }()
    
    // MARK: - Overrides methods

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ypWhite
        setupUI()
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    // MARK: - Private methods
    
    private func setupUI() {
        [titleLabel, tableView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 27),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func configureCornerRadius(for cell: UITableViewCell, indexPath: IndexPath, tableView: UITableView) {
        let cornerRadius:CGFloat = 16
        let numberOfRows = tableView.numberOfRows(inSection: indexPath.section)
        
        if numberOfRows == 1 {
            cell.layer.cornerRadius = cornerRadius
            cell.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else {
            switch indexPath.row {
            case 0:
                cell.layer.cornerRadius = cornerRadius
                cell.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            case numberOfRows - 1:
                cell.layer.cornerRadius = cornerRadius
                cell.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            default:
                cell.layer.cornerRadius = 0
                cell.layer.maskedCorners = []
            }
        }
        
        cell.layer.masksToBounds = true
    }

}

// MARK: - Extension: UITableViewDelegate

extension FiltersViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
           return 75
       }
}

// MARK: - Extension: UITableViewDataSource

extension FiltersViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        FilterType.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        let filter = FilterType.allCases[indexPath.row]
        cell.textLabel?.text = filter.title
        cell.textLabel?.font = .ladomiMedium(18)
        cell.textLabel?.textColor = .ypBlack
        cell.backgroundColor = .ypGray
        configureCornerRadius(for: cell, indexPath: indexPath, tableView: tableView)
        cell.accessoryType = filter == selectedFilter ? .checkmark : .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selected = FilterType.allCases[indexPath.row]
        onFilterSelected?(selected)
        dismiss(animated: true)
    }
    
    
}

import Foundation
import UIKit

protocol CategorySelectionDelegate: AnyObject {
    func didSelectCategory(_ category: RitmoCategory)
}

final class CategoryViewController: UIViewController {
    
    // MARK: - Public Properties
    
    private var viewModel = CategoryViewModel()
    var selectedCategory: RitmoCategory?
    weak var delegate: CategorySelectionDelegate?
    
    // MARK: - Private Properties
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        let labelText = NSLocalizedString("categoryTable.title", comment: "ячейка таблицы")
        label.text = labelText
        label.textColor = .ypBlack
        label.font = .ritmoBold(32)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.82
        return label
    }()
    
    private lazy var doneButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.ypWhite, for: .normal)
        let buttonText = NSLocalizedString("addCategoryButton", comment: "Кнопка добавления категории")
        button.setTitle(buttonText, for: .normal)
        button.titleLabel?.font = .ritmoBold(17)
        button.addTarget(self, action: #selector(addCategoryButtonTap), for: .touchUpInside)
        button.backgroundColor = .ypBlack
        button.setTitleColor(.ypWhite, for: .normal)
        button.layer.cornerRadius = 16
        return button
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        return tableView
    }()
    
    private lazy var placeholderImage: UIImageView = {
        let placeholderImageView = UIImageView()
        placeholderImageView.image = UIImage(named: "placeholder")
        return placeholderImageView
    }()
    
    private lazy var placeholderLabel: UILabel = {
        let placeholderLabel = UILabel()
        placeholderLabel.textAlignment = .center
        placeholderLabel.numberOfLines = 0
        let placeholderText = NSLocalizedString("categoryCreateVC.title", comment: "Заглушка если нет категорий созданных")
        placeholderLabel.text = placeholderText
        placeholderLabel.font = .ritmoMedium(12)
        return placeholderLabel
    }()
    
    // MARK: - Overrides Methods
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        showPlaceholder()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ypWhite
        setupUI()
        
        viewModel.reloadData = { [weak self] in
            self?.tableView.reloadData()
            self?.showPlaceholder()
        }
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    // MARK: - Private Methods
    
    private func showPlaceholder(){
        if viewModel.isEmpty() {
            placeholderImage.isHidden = false
            placeholderLabel.isHidden = false
        } else {
            placeholderImage.isHidden = true
            placeholderLabel.isHidden = true
        }
    }
    
    private func setupUI(){
        
        [titleLabel, doneButton, tableView, placeholderImage, placeholderLabel].forEach{
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 27),
            doneButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            doneButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            doneButton.heightAnchor.constraint(equalToConstant: 60),
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -10),
            placeholderImage.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 358),
            placeholderImage.heightAnchor.constraint(equalToConstant: 80),
            placeholderImage.widthAnchor.constraint(equalToConstant: 80),
            placeholderImage.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: placeholderImage.bottomAnchor, constant: 8),
            placeholderLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    @objc private func addCategoryButtonTap(){
        let newVc = AddCategoryViewController()
        newVc.delegate = self
        present(newVc, animated: true)
    }
    
    private func editCategory(at index: Int) {
        guard let category = viewModel.category(at: index) else { return }
        
        let editVC = AddCategoryViewController()
        editVC.categoryToEdit = category
        editVC.categoryUpdated = { [weak self] updatedCategory in
            guard let self = self else { return }
            
            self.viewModel.editCategory(at: IndexPath(row: index, section: 0), newTitle: updatedCategory.title)
            self.tableView.reloadData()
        }
        present(editVC, animated: true)
    }
    
    
    private func deleteCategory(_ category: RitmoCategory) {
        let alertText = NSLocalizedString("alert", comment: "текст алерта при удалении категории")
        let deleteText = NSLocalizedString("delete", comment: "кнопка удалить")
        
        let alert = UIAlertController(title: alertText, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title:deleteText, style: .destructive, handler: { _ in
            
            self.viewModel.deleteCategory(category)
        }))
        let cancelText = NSLocalizedString("cancel", comment: "кнопка отмены")
        alert.addAction(UIAlertAction(title: cancelText, style: .cancel))
        self.present(alert, animated: true)
        
        tableView.reloadData()
    }
}

extension CategoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        guard viewModel.category(at: indexPath.row) != nil else { return nil }
        
        let editText = NSLocalizedString("edit", comment: "кнопка редактирования")
        let editAction = UIAction(title: editText) { _ in
            self.editCategory(at: indexPath.row)
        }
        
        let deleteText = NSLocalizedString("delete", comment: "кнопка удалить")
        let deleteAction = UIAction(title: deleteText, attributes: .destructive) { _ in
            self.viewModel.deleteCategory(at: indexPath.row)
        }
        
        let menu = UIMenu(title: "", children: [editAction, deleteAction])
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in menu }
    }
    
}

extension CategoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfCategories()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        cell.backgroundColor = .ypGray
        cell.textLabel?.font = .ritmoMedium(18)
        cell.textLabel?.textColor = .ypBlack
        cell.selectionStyle = .none
        configureCornerRadius(for: cell, indexPath: indexPath, tableView: tableView)
        let category = viewModel.category(at: indexPath.row)
        cell.textLabel?.text = category?.title
        return cell
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        75
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let selectedCategory = viewModel.selectCategory(at: indexPath.row) {
            delegate?.didSelectCategory(selectedCategory)
            dismiss(animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let isLastCell = indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1
        
        if isLastCell {
            cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: tableView.bounds.width)
        }
    }
}

extension CategoryViewController: AddCategoryViewControllerDelegate{
    func didAddCategory(_ category: RitmoCategory) {
        viewModel.addCategory(category)
    }
}




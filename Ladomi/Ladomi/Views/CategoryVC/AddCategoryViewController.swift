import UIKit

protocol AddCategoryViewControllerDelegate: AnyObject {
    func didAddCategory(_ category: DayItemCategory)
}

class AddCategoryViewController: UIViewController {
    
    weak var delegate: AddCategoryViewControllerDelegate?
    var categoryToEdit: DayItemCategory?
    var categoryUpdated: ((DayItemCategory) -> Void)?
    
    private lazy var categoryNameTF: UITextField = {
        let textField = UITextField()
        textField.backgroundColor = .ypGray
        textField.layer.masksToBounds = true
        textField.layer.cornerRadius = 16
        let textFieldText = NSLocalizedString("textFieldCategories", comment: "строка в текст филде")
        textField.font = .ladomiMedium(17)
        textField.textColor = .ypBlack
        textField.attributedPlaceholder = NSAttributedString(
            string: textFieldText,
            attributes: [
                .foregroundColor: UIColor.ypLightGray,
                .font: UIFont.ladomiRegular(17)
            ]
        )
        let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: textField.frame.height))
        textField.leftView = leftPaddingView
        let clearButton = UIButton(type: .custom)
        clearButton.setImage(.xmark, for: .normal)
        clearButton.frame = CGRect(x: 0, y: 0, width: 17, height: 17)
        clearButton.addTarget(self, action: #selector(clearButtonDidTap), for: .touchUpInside)
        
        let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: clearButton.frame.width + 12, height: clearButton.frame.height))
        rightPaddingView.addSubview(clearButton)
        textField.rightView = rightPaddingView
        textField.rightViewMode = .whileEditing
        textField.leftViewMode = .always
        textField.delegate = self
        return textField
    }()
    
    private lazy var categoryLabel: UILabel = {
        let label = UILabel()
        let labelText = NSLocalizedString("newCategory", comment: "")
        label.text =  labelText
        label.font = .ladomiBold(32)
        label.textColor = .ypBlack
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.82
        return label
    }()
    
    private lazy var doneButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.ypWhite, for: .normal)
        let buttonText = NSLocalizedString("done", comment: "")
        button.setTitle(buttonText, for: .normal)
        button.titleLabel?.font = .ladomiBold(17)
        button.addTarget(self, action: #selector(doneButtonTap), for: .touchUpInside)
        button.backgroundColor = .ypBlack
        button.setTitleColor(.ypWhite, for: .normal)
        button.layer.cornerRadius = 16
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .ypWhite
        setupUI()
        
        if let category = categoryToEdit {
            categoryNameTF.text = category.title
        }
        doneButtonIsAvailable()
    }
    
    @objc private func doneButtonTap() {
        guard let title = categoryNameTF.text?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return }
        
        let updatedCategory = DayItemCategory(
            title: title,
            dayItems: categoryToEdit?.dayItems ?? []
        )
        
        if categoryToEdit != nil {
            categoryUpdated?(updatedCategory)
        } else {
            delegate?.didAddCategory(updatedCategory)
        }
        
        dismiss(animated: true)
    }
    
    @objc private func clearButtonDidTap(){
        categoryNameTF.text = ""
        
    }
    
    private func doneButtonIsAvailable() {
        let trimmedText = categoryNameTF.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isNotEmpty = !trimmedText.isEmpty
        doneButton.isEnabled = isNotEmpty
        doneButton.backgroundColor = isNotEmpty ? .ypBlack : .ypLightGray
    }
    
    private func setupUI(){
        [categoryNameTF, categoryLabel, doneButton].forEach{
            $0.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            
            categoryLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            categoryLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 27),
            
            categoryNameTF.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            categoryNameTF.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            categoryNameTF.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 38),
            categoryNameTF.heightAnchor.constraint(equalToConstant: 75),
            
            doneButton.heightAnchor.constraint(equalToConstant: 60),
            doneButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }
    
    
    
}

extension AddCategoryViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        doneButtonIsAvailable()
        return true
    }
}

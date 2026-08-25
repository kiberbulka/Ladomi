import Foundation
import UIKit

protocol NewHabitOrEventViewControllerDelegate: AnyObject {
    func didCreateDayItemOrEvent(dayItem: DayItem)
}

final class NewHabitOrEventViewController: UIViewController, CategorySelectionDelegate {
    private enum DayItemSettingsRow: Equatable {
        case category
        case schedule
        case eventDate
        case reminder
    }

    // MARK: - Public Properties

    var isHabit: Bool = true
    var isStopList: Bool = false
    var isEditingDayItem: Bool = false
    var dayItemToEdit: DayItem?
    var dayItemCategoryToEdit: DayItemCategory?
    var categoryCellIndexPath: IndexPath?
    var dayItem: DayItem?
    var completedDays: Int = 0
    var selectedEventDate: Date?

    weak var delegate: NewHabitOrEventViewControllerDelegate?

    // MARK: - Private Properties

    private var selectedDays: [Weekday] = []
    private var selectedEmoji: String?
    private var selectedColor: UIColor?
    private let dayItemStore = DayItemStore()
    private let dayItemRecordStore = DayItemRecordStore()
    private var selectedCategory: DayItemCategory?
    private var selectedReminderTime: Date?
    private var tableViewHeightConstraint: NSLayoutConstraint!
    private var characterLimitHeightConstraint: NSLayoutConstraint!
    private var typeSegmentHeightConstraint: NSLayoutConstraint!
    private let settingsRowHeight: CGFloat = 75

    private var selectedEmojiIndexPath: IndexPath?
    private var selectedColorIndexPath: IndexPath?

    private let emojis = ["💧", "🏃", "🧘", "😴", "📚", "💻",
                          "🧠", "📵", "🧹", "💰", "🎯", "🔥",
                          "🥗", "💊", "🚶", "✍️", "☕️", "✅",
                          "🌿", "🪴", "🍎", "🍋", "🥛", "🏋️",
                          "🚴", "🏊", "🧩", "🎨", "🎧", "📝",
                          "🕯️", "🌙", "☀️", "⏰", "🗓️", "🛏️"]

    private let stopListEmojis = ["🚭", "🍷", "🍺", "🍔", "🍟", "🍬",
                                  "🍫", "🥤", "📱", "🎰", "🛒", "💸",
                                  "😡", "🌙", "☕️", "🛋️", "🧂", "🍕"]

    private let colors: [UIColor] = [
        UIColor(red: 0.20, green: 0.47, blue: 1.00, alpha: 1),
        UIColor(red: 0.22, green: 0.68, blue: 0.96, alpha: 1),
        UIColor(red: 0.00, green: 0.72, blue: 0.84, alpha: 1),
        UIColor(red: 0.00, green: 0.59, blue: 0.54, alpha: 1),
        UIColor(red: 0.40, green: 0.83, blue: 0.64, alpha: 1),
        UIColor(red: 0.18, green: 0.70, blue: 0.38, alpha: 1),
        UIColor(red: 0.68, green: 0.84, blue: 0.20, alpha: 1),
        UIColor(red: 1.00, green: 0.84, blue: 0.24, alpha: 1),
        UIColor(red: 1.00, green: 0.92, blue: 0.36, alpha: 1),
        UIColor(red: 1.00, green: 0.69, blue: 0.13, alpha: 1),
        UIColor(red: 1.00, green: 0.52, blue: 0.14, alpha: 1),
        UIColor(red: 1.00, green: 0.38, blue: 0.25, alpha: 1),
        UIColor(red: 0.94, green: 0.27, blue: 0.24, alpha: 1),
        UIColor(red: 0.88, green: 0.12, blue: 0.31, alpha: 1),
        UIColor(red: 1.00, green: 0.37, blue: 0.51, alpha: 1),
        UIColor(red: 0.93, green: 0.38, blue: 0.70, alpha: 1),
        UIColor(red: 0.83, green: 0.25, blue: 0.81, alpha: 1),
        UIColor(red: 0.61, green: 0.32, blue: 0.86, alpha: 1),
        UIColor(red: 0.49, green: 0.34, blue: 0.95, alpha: 1),
        UIColor(red: 0.31, green: 0.36, blue: 0.90, alpha: 1),
        UIColor(red: 0.12, green: 0.23, blue: 0.54, alpha: 1),
        UIColor(red: 0.10, green: 0.45, blue: 0.73, alpha: 1),
        UIColor(red: 0.11, green: 0.13, blue: 0.18, alpha: 1),
        UIColor(red: 0.40, green: 0.45, blue: 0.55, alpha: 1),
        UIColor(red: 0.55, green: 0.56, blue: 0.58, alpha: 1),
        UIColor(red: 0.67, green: 0.56, blue: 0.41, alpha: 1),
        UIColor(red: 0.55, green: 0.33, blue: 0.20, alpha: 1),
        UIColor(red: 0.77, green: 0.62, blue: 0.38, alpha: 1),
        UIColor(red: 1.00, green: 0.70, blue: 0.50, alpha: 1),
        UIColor(red: 1.00, green: 0.78, blue: 0.36, alpha: 1),
        UIColor(red: 0.75, green: 0.61, blue: 0.96, alpha: 1),
        UIColor(red: 0.56, green: 0.63, blue: 0.95, alpha: 1),
        UIColor(red: 0.28, green: 0.82, blue: 0.82, alpha: 1),
        UIColor(red: 0.24, green: 0.64, blue: 0.86, alpha: 1),
        UIColor(red: 0.96, green: 0.49, blue: 0.18, alpha: 1),
        UIColor(red: 0.98, green: 0.20, blue: 0.42, alpha: 1)
    ]

    private var settingsRows: [DayItemSettingsRow] {
        if isStopList {
            return []
        }

        return isHabit ? [.category, .schedule, .reminder] : [.category, .eventDate, .reminder]
    }

    private var activeEmojis: [String] {
        isStopList ? stopListEmojis : emojis
    }

    private var tableViewHeight: CGFloat {
        CGFloat(settingsRows.count) * settingsRowHeight
    }

    private lazy var reminderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .appPreferred
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private lazy var eventDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .appPreferred
        formatter.setLocalizedDateFormatFromTemplate("EEE, d MMM")
        return formatter
    }()

    private lazy var countDaysLabel: UILabel = {
       let label = UILabel()
        label.font = .ladomiBold(28)
        label.textColor = .ypBlack
        label.isHidden = true
        label.textAlignment = .center
        return label
    }()

    private lazy var newHabitLabel: UILabel = {
        let label = UILabel()
        let labelText = NSLocalizedString("newHabit", comment: "Заголовок экрана создания привычки или события")
        label.text = labelText
        label.font = .ladomiBold(32)
        label.textColor = .ypBlack
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.78
        return label
    }()

    private lazy var nameTitleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("nameField.title", comment: "Name field title")
        label.font = .ladomiBold(18)
        label.textColor = .ypLightGray
        return label
    }()

    private lazy var dayItemNameTF: UITextField = {
        let textField = UITextField()
        textField.backgroundColor = .ypWhite
        textField.layer.masksToBounds = true
        textField.layer.cornerRadius = 18
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.ypGray.cgColor
        textField.font = .ladomiMedium(17)
        textField.textColor = .ypBlack
        let textFieldText = NSLocalizedString("textFieldDayItem", comment: "Текст в текст филде")
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
        textField.addTarget(self, action: #selector(dayItemNameDidChange), for: .editingChanged)
        return textField
    }()

    private lazy var typeSegmentView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            makeTypeChip(
                title: NSLocalizedString("habit", comment: ""),
                systemImageName: "checkmark.circle.fill",
                isSelected: isHabit,
                selectsHabit: true
            ),
            makeTypeChip(
                title: NSLocalizedString("irregularEvent", comment: ""),
                systemImageName: "calendar",
                isSelected: !isHabit,
                selectsHabit: false
            )
        ])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        stackView.backgroundColor = .ypGray
        stackView.layer.cornerRadius = 20
        stackView.layer.masksToBounds = true
        return stackView
    }()

    private lazy var previewCardView: UIView = {
        let view = UIView()
        view.backgroundColor = selectedColor ?? colors[0]
        view.layer.cornerRadius = 22
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var previewTopCircleView: UIView = makePreviewCircle(diameter: 126)
    private lazy var previewBottomCircleView: UIView = makePreviewCircle(diameter: 76)

    private lazy var previewEmojiLabel: UILabel = {
        let label = UILabel()
        label.text = selectedEmoji ?? activeEmojis[0]
        label.font = .ladomiMedium(34)
        label.textAlignment = .center
        label.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        label.layer.cornerRadius = 22
        label.layer.masksToBounds = true
        return label
    }()

    private lazy var previewTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiBold(22)
        label.textColor = .ypWhite
        label.textAlignment = .left
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.72
        return label
    }()

    private lazy var previewSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiMedium(16)
        label.textColor = UIColor.white.withAlphaComponent(0.86)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.72
        return label
    }()

    private lazy var previewTextStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [previewTitleLabel, previewSubtitleLabel])
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 4
        return stackView
    }()

    private lazy var topStackView: UIStackView = {
        let topStackView = UIStackView(arrangedSubviews: [
            newHabitLabel,
            countDaysLabel,
            typeSegmentView,
            nameTitleLabel,
            dayItemNameTF
        ])
        topStackView.axis = .vertical
        topStackView.alignment = .fill
        topStackView.distribution = .fill
        topStackView.translatesAutoresizingMaskIntoConstraints = false
        topStackView.setCustomSpacing(16, after: newHabitLabel)
        topStackView.setCustomSpacing(16, after: countDaysLabel)
        topStackView.setCustomSpacing(24, after: typeSegmentView)
        topStackView.setCustomSpacing(10, after: nameTitleLabel)
        return topStackView
    }()


    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        let buttonText = NSLocalizedString("cancel", comment: "Кнопка отмены")
        button.setTitle(buttonText, for: .normal)
        button.titleLabel?.font = .ladomiBold(17)
        button.setTitleColor(.ypRed, for: .normal)
        button.layer.borderColor = UIColor.ypRed.cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 22
        button.addTarget(self, action: #selector(cancelButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var characterLimitLabel: UILabel = {
        let label = UILabel()
        label.textColor = .ypRed
        let labelText = NSLocalizedString("limit.title", comment: "Предупреждение об ограничении по символам")
        label.text = labelText
        label.font = .ladomiMedium(15)
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    private lazy var createButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .ypLightGray
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 22
        let buttonText = NSLocalizedString("createButton", comment: "Кнопка создания")
        button.setTitle(buttonText, for: .normal)
        button.addTarget(self, action: #selector(createButtonDidTap), for: .touchUpInside)
        button.titleLabel?.textColor = .ypWhite
        button.setTitleColor(.ypWhite, for: .normal)
        button.isEnabled = false
        button.titleLabel?.font = .ladomiBold(17)
        return button
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.bounces = false
        tableView.isScrollEnabled = false
        tableView.estimatedRowHeight = settingsRowHeight
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor.ypGray
        return tableView
    }()

    private lazy var emojiCollection : UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.cellIdentifier)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.allowsSelection = true
        collectionView.allowsMultipleSelection = false
        collectionView.isScrollEnabled = true
        collectionView.alwaysBounceHorizontal = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.tag = 1
        return collectionView
    }()

    private lazy var colorCollection : UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(ColorCell.self, forCellWithReuseIdentifier: ColorCell.cellIdentifier)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.allowsSelection = true
        collectionView.allowsMultipleSelection = false
        collectionView.isScrollEnabled = true
        collectionView.alwaysBounceHorizontal = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.tag = 2
        return collectionView
    }()

    private lazy var emojiLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiBold(24)
        label.textColor = .ypLightGray
        label.text = NSLocalizedString("emojiCollectionView.title", comment: "Emoji picker title")
        return label
    }()

    private lazy var colorLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiBold(24)
        label.textColor = .ypLightGray
        let labelText = NSLocalizedString("colorCollectionView.title", comment: "Заголовок выбора цвета")
        label.text = labelText
        return label
    }()

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private lazy var contentView: UIView = {
        let contentView = UIView()
        return contentView
    }()


    // MARK: - Overrides Methods

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTableViewHeight()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        prepareInitialEventDate()
        setupUI()
        tableView.delegate = self
        tableView.dataSource = self
        dayItemNameTF.delegate = self
        habitOrEventLabel()
        editDayItem()
        setupEmojiAndColorForEditDayItem()
        updateTableViewHeight()
    }

    // MARK: - Public Methods

    func didSelectCategory(_ category: DayItemCategory) {
        selectedCategory = category
        tableView.reloadData()
        updateTableViewHeight()
        updatePreviewCard()
    }

    // MARK: - UI

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // TableView height constraint
        tableViewHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: tableViewHeight)
        tableViewHeightConstraint.isActive = true
        characterLimitHeightConstraint = characterLimitLabel.heightAnchor.constraint(equalToConstant: 0)
        typeSegmentHeightConstraint = typeSegmentView.heightAnchor.constraint(equalToConstant: isStopList ? 0 : 56)
        typeSegmentHeightConstraint.isActive = true
        setupPreviewCard()

        // UI Elements
        [topStackView, cancelButton, createButton, tableView, characterLimitLabel, previewCardView,
         emojiLabel, emojiCollection, colorLabel, colorCollection].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            // Scroll and content view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Stack with label + count + textfield
            topStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            topStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            topStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            dayItemNameTF.heightAnchor.constraint(equalToConstant: 64),
            previewCardView.heightAnchor.constraint(equalToConstant: 104),

            // Character limit label
            characterLimitHeightConstraint,
            characterLimitLabel.widthAnchor.constraint(equalToConstant: 286),
            characterLimitLabel.topAnchor.constraint(equalTo: dayItemNameTF.bottomAnchor, constant: 4),
            characterLimitLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // Table view
            tableView.topAnchor.constraint(equalTo: characterLimitLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // Emoji section
            emojiLabel.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 32),
            emojiLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            emojiCollection.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 12),
            emojiCollection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            emojiCollection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            emojiCollection.heightAnchor.constraint(equalToConstant: 186),

            // Color section
            colorLabel.topAnchor.constraint(equalTo: emojiCollection.bottomAnchor, constant: 24),
            colorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            colorCollection.topAnchor.constraint(equalTo: colorLabel.bottomAnchor, constant: 12),
            colorCollection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            colorCollection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            colorCollection.heightAnchor.constraint(equalToConstant: 186),

            // Preview card
            previewCardView.topAnchor.constraint(equalTo: colorCollection.bottomAnchor, constant: 24),
            previewCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            previewCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // Buttons
            createButton.heightAnchor.constraint(equalToConstant: 60),
            createButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            createButton.topAnchor.constraint(equalTo: previewCardView.bottomAnchor, constant: 16),

            cancelButton.heightAnchor.constraint(equalToConstant: 60),
            cancelButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cancelButton.topAnchor.constraint(equalTo: previewCardView.bottomAnchor, constant: 16),

            // Bottom padding
            createButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            dayItemNameTF.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -40)

        ])

        if traitCollection.userInterfaceIdiom == .pad {
            NSLayoutConstraint.activate([
                cancelButton.trailingAnchor.constraint(equalTo: createButton.leadingAnchor, constant: -8),
                cancelButton.widthAnchor.constraint(equalTo: createButton.widthAnchor)
            ])
        } else {
            let phoneButtonWidth = UIScreen.main.bounds.width / 2 - 30
            NSLayoutConstraint.activate([
                createButton.widthAnchor.constraint(equalToConstant: phoneButtonWidth),
                cancelButton.widthAnchor.constraint(equalToConstant: phoneButtonWidth)
            ])
        }
        updatePreviewCard()
    }


    // MARK: - Private Methods

    private func setupPreviewCard() {
        [
            previewTopCircleView,
            previewBottomCircleView,
            previewEmojiLabel,
            previewTextStackView
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            previewCardView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            previewTopCircleView.widthAnchor.constraint(equalToConstant: 126),
            previewTopCircleView.heightAnchor.constraint(equalToConstant: 126),
            previewTopCircleView.topAnchor.constraint(equalTo: previewCardView.topAnchor, constant: -56),
            previewTopCircleView.trailingAnchor.constraint(equalTo: previewCardView.trailingAnchor, constant: 34),

            previewBottomCircleView.widthAnchor.constraint(equalToConstant: 76),
            previewBottomCircleView.heightAnchor.constraint(equalToConstant: 76),
            previewBottomCircleView.bottomAnchor.constraint(equalTo: previewCardView.bottomAnchor, constant: 36),
            previewBottomCircleView.trailingAnchor.constraint(equalTo: previewCardView.trailingAnchor, constant: -112),

            previewEmojiLabel.leadingAnchor.constraint(equalTo: previewCardView.leadingAnchor, constant: 18),
            previewEmojiLabel.centerYAnchor.constraint(equalTo: previewCardView.centerYAnchor),
            previewEmojiLabel.widthAnchor.constraint(equalToConstant: 64),
            previewEmojiLabel.heightAnchor.constraint(equalToConstant: 64),

            previewTextStackView.leadingAnchor.constraint(equalTo: previewEmojiLabel.trailingAnchor, constant: 16),
            previewTextStackView.trailingAnchor.constraint(equalTo: previewCardView.trailingAnchor, constant: -18),
            previewTextStackView.centerYAnchor.constraint(equalTo: previewCardView.centerYAnchor)
        ])
    }

    private func makeTypeChip(title: String, systemImageName: String, isSelected: Bool, selectsHabit: Bool) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: systemImageName), for: .normal)
        button.setTitleColor(isSelected ? .ypWhite : .ypLightGray, for: .normal)
        button.tintColor = isSelected ? .ypWhite : .ypLightGray
        button.backgroundColor = isSelected ? .ypBlack : .clear
        button.layer.cornerRadius = 20
        button.layer.masksToBounds = true
        button.titleLabel?.font = .ladomiBold(17)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.72
        button.titleLabel?.lineBreakMode = .byClipping
        button.contentHorizontalAlignment = .center
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        button.tag = selectsHabit ? 0 : 1
        button.isEnabled = !isEditingDayItem
        button.addTarget(self, action: #selector(typeSegmentDidTap(_:)), for: .touchUpInside)
        return button
    }

    private func updateTypeSegmentView() {
        typeSegmentView.isHidden = isStopList
        typeSegmentHeightConstraint?.constant = isStopList ? 0 : 56
        guard !isStopList else {
            return
        }

        typeSegmentView.arrangedSubviews.forEach {
            typeSegmentView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        typeSegmentView.addArrangedSubview(
            makeTypeChip(
                title: NSLocalizedString("habit", comment: ""),
                systemImageName: "checkmark.circle.fill",
                isSelected: isHabit,
                selectsHabit: true
            )
        )
        typeSegmentView.addArrangedSubview(
            makeTypeChip(
                title: NSLocalizedString("irregularEvent", comment: ""),
                systemImageName: "calendar",
                isSelected: !isHabit,
                selectsHabit: false
            )
        )
    }

    private func makePreviewCircle(diameter: CGFloat) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        view.layer.cornerRadius = diameter / 2
        return view
    }

    private func updatePreviewCard() {
        let fallbackTitle: String
        if isStopList {
            fallbackTitle = NSLocalizedString("newStopListItem", comment: "Stop-list item preview fallback")
        } else if isHabit {
            fallbackTitle = NSLocalizedString("newHabit", comment: "Habit preview fallback")
        } else {
            fallbackTitle = NSLocalizedString("newIrregularEvent", comment: "Event preview fallback")
        }
        let title = (dayItemNameTF.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let color = selectedColor ?? colors[0]

        previewCardView.backgroundColor = color
        previewEmojiLabel.text = selectedEmoji ?? activeEmojis[0]
        previewTitleLabel.text = title.isEmpty ? fallbackTitle : title
        previewSubtitleLabel.text = previewSubtitle()
    }

    private func previewSubtitle() -> String {
        if isStopList {
            return NSLocalizedString("stopList.preview.subtitle", comment: "Stop-list preview subtitle")
        }

        if isHabit {
            let schedule = scheduleSubtitle().isEmpty
                ? NSLocalizedString("scheduleTable.title", comment: "")
                : scheduleSubtitle()
            return "\(schedule) · \(reminderSubtitle())"
        } else {
            return "\(eventDateSubtitle()) · \(reminderSubtitle())"
        }
    }

    @objc private func dayItemNameDidChange() {
        updatePreviewCard()
        createButtonIsAvailable()
    }

    @objc private func typeSegmentDidTap(_ sender: UIButton) {
        guard !isEditingDayItem, !isStopList else { return }

        let shouldSelectHabit = sender.tag == 0
        guard isHabit != shouldSelectHabit else { return }

        isHabit = shouldSelectHabit
        if !isHabit {
            selectedEventDate = normalizedEventDate(selectedEventDate)
        }

        habitOrEventLabel()
        createButtonIsAvailable()
    }

    private func setupEmojiAndColorForEditDayItem(){
        if let habit = dayItemToEdit {
                if let emojiIndex = activeEmojis.firstIndex(of: habit.emoji) {
                    selectedEmojiIndexPath = IndexPath(item: emojiIndex, section: 0)
                }

                if let colorIndex = colors.firstIndex(of: habit.color) {
                    selectedColorIndexPath = IndexPath(item: colorIndex, section: 0)
                }

                emojiCollection.reloadData()
                colorCollection.reloadData()

                DispatchQueue.main.async {
                    if let emojiIndex = self.selectedEmojiIndexPath,
                       let emojiCell = self.emojiCollection.cellForItem(at: emojiIndex) as? EmojiCell {
                        emojiCell.updateSelection(isSelected: true)
                    }
                    if let colorIndex = self.selectedColorIndexPath,
                       let colorCell = self.colorCollection.cellForItem(at: colorIndex) as? ColorCell {
                        colorCell.updateFrameColor(color: self.colors[colorIndex.item], isHidden: false)
                    }
                }
            }
    }


    @objc private func createButtonDidTap() {
        print("createButtonDidTap вызван")

        let newDayItem = makeDayItem()

        let category = selectedCategory
        guard isStopList || category != nil else {
            return
        }

        if isEditingDayItem, let originalDayItem = dayItemToEdit {
            dayItemStore.updateDayItem(original: originalDayItem, with: newDayItem, category: category)
        } else {
            dayItemStore.addDayItem(dayItem: newDayItem, category: category)
        }
        ReminderNotificationService.shared.scheduleReminder(
            for: newDayItem,
            completedRecords: dayItemRecordStore.fetch()
        )
        createButtonIsAvailable()

        NotificationCenter.default.post(name: Notification.Name("DidCreateDayItem"), object: nil)

        if isEditingDayItem{
            presentingViewController?.dismiss(animated: true)
        } else if presentingViewController is CreateDayItemViewController {
            presentingViewController?.presentingViewController?.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }


    private func makeDayItem() -> DayItem {
        let name = dayItemNameTF.text ?? ""
        let id = isEditingDayItem ? dayItemToEdit?.id ?? UUID() : UUID()
        let today = Date()
        var schedule: [Weekday] = []

        if isStopList {
            schedule = Weekday.allCases
        } else if isHabit {
            schedule = selectedDays
        } else {
            let eventDate = eventDate(for: today) ?? today
            if let selectedDayOfWeek = weekday(for: eventDate) {
                schedule.append(selectedDayOfWeek)
            }
        }

        return DayItem(
            id: id,
            name: name,
            color: selectedColor ?? UIColor(white: 1, alpha: 1),
            emoji: selectedEmoji ?? "",
            schedule: schedule,
            isHabit: isStopList ? false : isHabit,
            reminderTime: isStopList ? nil : selectedReminderTime,
            eventDate: eventDate(for: today),
            createdDate: dayItemToEdit?.createdDate ?? today,
            archivedDate: dayItemToEdit?.archivedDate,
            isArchived: dayItemToEdit?.isArchived ?? false,
            isStopList: isStopList
        )
    }

    private func eventDate(for fallbackDate: Date) -> Date? {
        guard !isHabit, !isStopList else {
            return nil
        }

        return selectedEventDate ?? dayItemToEdit?.eventDate ?? fallbackDate
    }

    private func prepareInitialEventDate() {
        guard !isHabit, !isStopList else { return }

        selectedEventDate = normalizedEventDate(selectedEventDate ?? dayItemToEdit?.eventDate)
    }

    private func normalizedEventDate(_ date: Date?) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let candidate = calendar.startOfDay(for: date ?? today)

        guard candidate >= today, isDateInCurrentWeek(candidate) else {
            return today
        }

        return candidate
    }

    private func isDateInCurrentWeek(_ date: Date) -> Bool {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return true
        }

        return weekInterval.contains(calendar.startOfDay(for: date))
    }

    private func currentWeekDates() -> [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let today = calendar.startOfDay(for: Date())
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return [today]
        }

        var dates: [Date] = []
        var date = max(today, calendar.startOfDay(for: weekInterval.start))
        while date < weekInterval.end {
            dates.append(date)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = nextDate
        }

        return dates
    }

    private func weekday(for date: Date) -> Weekday? {
        let weekday = Calendar.current.component(.weekday, from: date)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        return Weekday.allCases.first { $0.numberValue == adjustedWeekday }
    }

    private func createButtonIsAvailable() {
        let isText = dayItemNameTF.hasText
        let selectedSchedule = !selectedDays.isEmpty
        let category = selectedCategory != nil
        let selectedEmoji = selectedEmoji != nil
        let selectedColor = selectedColor != nil
        if isEditingDayItem {
            isHabit = dayItemToEdit?.isHabit ?? false
            isStopList = dayItemToEdit?.isStopList ?? false
        }

        print("isText: \(isText), selectedSchedule: \(selectedSchedule), category: \(category), emoji: \(selectedEmoji), color: \(selectedColor), isHabit: \(isHabit)")

        let buttonIsAvailable: Bool
        if isStopList {
            buttonIsAvailable = isText && selectedColor && selectedEmoji
        } else if isHabit {
            buttonIsAvailable = isText && selectedSchedule && category && selectedEmoji && selectedColor
        } else {
            buttonIsAvailable = isText && category && selectedColor && selectedEmoji
        }
        createButton.isEnabled = buttonIsAvailable
        createButton.backgroundColor = buttonIsAvailable ? .ypBlack : .ypLightGray
    }

    private func updateTableViewHeight() {
        tableViewHeightConstraint.constant = tableViewHeight
    }

    @objc private func cancelButtonDidTap(){
        dismiss(animated: true)
    }

    @objc private func clearButtonDidTap(){
        dayItemNameTF.text = ""
        characterLimitLabel.isHidden = true
        characterLimitHeightConstraint.constant = 0
        updatePreviewCard()
        createButtonIsAvailable()
    }

    private func habitOrEventLabel(){
        if isStopList {
            let text = NSLocalizedString("newStopListItem", comment: "Заголовок экрана создания пункта стоп-листа")
            newHabitLabel.text = text
        } else if isHabit {
            let text = NSLocalizedString("newHabit", comment: "Заголовок экрана создания ритма")
            newHabitLabel.text = text
        } else {
            let text = NSLocalizedString("newIrregularEvent", comment: "Заголовок экрана создания события")
            newHabitLabel.text = text
        }
        tableView.reloadData()
        updateTableViewHeight()
        updateTypeSegmentView()
        updatePreviewCard()
    }

    private func scheduleSubtitle()->String{
        guard !selectedDays.isEmpty else {
            return ""
        }

        if selectedDays.count == 7 {
            let text = NSLocalizedString("everyDay", comment: "Каждый день")
            return text
        } else {
            let shortNames = selectedDays
                .sorted {
                    guard let firstIndex = Weekday.allCases.firstIndex(of: $0),
                          let secondIndex = Weekday.allCases.firstIndex(of: $1) else { return false }
                    return firstIndex < secondIndex
                }
                .map { $0.shortName }
            return shortNames.joined(separator: ", ")
        }
    }

    private func reminderSubtitle() -> String {
        guard let selectedReminderTime = selectedReminderTime else {
            return NSLocalizedString("reminder.off", comment: "Reminder is off")
        }

        return reminderDateFormatter.string(from: selectedReminderTime)
    }

    private func eventDateSubtitle() -> String {
        eventDateFormatter.string(from: normalizedEventDate(selectedEventDate))
    }

    private func presentEventDatePicker() {
        let title = NSLocalizedString("eventSchedulePicker.title", comment: "Current week day picker title")
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

        currentWeekDates().forEach { date in
            let action = UIAlertAction(title: eventDateFormatter.string(from: date), style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.selectedEventDate = date
                self.tableView.reloadData()
                self.updatePreviewCard()
            }
            alertController.addAction(action)
        }

        let cancelTitle = NSLocalizedString("cancel", comment: "Cancel button")
        alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
        alertController.popoverPresentationController?.sourceView = view
        alertController.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX,
            y: view.bounds.midY,
            width: 1,
            height: 1
        )

        present(alertController, animated: true)
    }

    private func configureReminderCell(_ cell: UITableViewCell) {
        let cellText = NSLocalizedString("reminderTable.title", comment: "Reminder cell title")
        cell.textLabel?.text = cellText
        cell.detailTextLabel?.text = reminderSubtitle()
        cell.accessoryType = .none

        let reminderSwitch = UISwitch()
        reminderSwitch.isOn = selectedReminderTime != nil
        reminderSwitch.onTintColor = .ypBlue
        reminderSwitch.addTarget(self, action: #selector(reminderSwitchDidChange(_:)), for: .valueChanged)

        guard let selectedReminderTime = selectedReminderTime else {
            cell.accessoryView = reminderSwitch
            return
        }

        let timePicker = UIDatePicker()
        timePicker.datePickerMode = .time
        timePicker.preferredDatePickerStyle = .compact
        timePicker.date = selectedReminderTime
        timePicker.addTarget(self, action: #selector(reminderTimeDidChange(_:)), for: .valueChanged)

        let stackView = UIStackView(arrangedSubviews: [timePicker, reminderSwitch])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.frame = CGRect(x: 0, y: 0, width: 190, height: 44)
        cell.accessoryView = stackView
    }

    private func configureSettingsIcon(for cell: UITableViewCell, row: DayItemSettingsRow) {
        let imageName: String
        let tintColor: UIColor

        switch row {
        case .category:
            imageName = "number"
            tintColor = .ypBlue
        case .schedule, .eventDate:
            imageName = "clock"
            tintColor = .colorSection7
        case .reminder:
            imageName = "bell.fill"
            tintColor = .colorSection3
        }

        let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        cell.imageView?.image = UIImage(systemName: imageName, withConfiguration: configuration)
        cell.imageView?.tintColor = tintColor
    }

    @objc private func reminderSwitchDidChange(_ sender: UISwitch) {
        selectedReminderTime = sender.isOn ? selectedReminderTime ?? Date() : nil
        tableView.reloadData()
        updateTableViewHeight()
        updatePreviewCard()
    }

    @objc private func reminderTimeDidChange(_ sender: UIDatePicker) {
        selectedReminderTime = sender.date
        guard let reminderRow = settingsRows.firstIndex(of: .reminder) else {
            return
        }

        let indexPath = IndexPath(row: reminderRow, section: 0)
        tableView.cellForRow(at: indexPath)?.detailTextLabel?.text = reminderSubtitle()
        updatePreviewCard()
    }

    private func pluralizeDays(_ count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100
        if remainder10 == 1 && remainder100 != 11 {
            let text = NSLocalizedString("dayItem.day", comment: "")
            return "\(count) \(text)"
        } else if remainder10 >= 2 && remainder10 <= 4 && (remainder100 < 10 || remainder100 >= 20) {
            let text = NSLocalizedString("dayItem.2,3,4day", comment: "")
            return "\(count) \(text)"
        } else {
            let text = NSLocalizedString("dayItem.days", comment: "")
            return "\(count) \(text)"
        }
    }

    private func editDayItem() {
        guard isEditingDayItem, let dayItem = dayItemToEdit else {return}

        dayItemNameTF.text = dayItem.name
        selectedColor = dayItem.color
        selectedEmoji = dayItem.emoji
        selectedDays = dayItem.schedule
        selectedCategory = dayItemCategoryToEdit
        selectedReminderTime = dayItem.isStopList ? nil : dayItem.reminderTime
        selectedEventDate = dayItem.isHabit || dayItem.isStopList ? nil : normalizedEventDate(dayItem.eventDate)
        isHabit = dayItem.isHabit
        isStopList = dayItem.isStopList
        updateTypeSegmentView()
        let text = isStopList
            ? NSLocalizedString("editStopListItem", comment: "")
            : NSLocalizedString("editHabit", comment: "")
        newHabitLabel.text = text

        countDaysLabel.isHidden = !dayItem.isHabit

        countDaysLabel.text = pluralizeDays(completedDays)

        if let index = colors.firstIndex(of: dayItem.color) {
                selectedColorIndexPath = IndexPath(item: index, section: 0)
            }

            if let index = activeEmojis.firstIndex(of: dayItem.emoji) {
                selectedEmojiIndexPath = IndexPath(item: index, section: 0)
            }

            tableView.reloadData()
            emojiCollection.reloadData()
            colorCollection.reloadData()
        createButton.setTitle(NSLocalizedString("saveButton", comment: "Save button"), for: .normal)
            createButtonIsAvailable()
            updatePreviewCard()
    }

}

// MARK: - Extension: UITableViewDataSource

extension NewHabitOrEventViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsRows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        configureCornerRadius(for: cell, indexPath: indexPath, tableView: tableView)
        cell.backgroundColor = .ypWhite
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.font = .ladomiBold(19)
        cell.detailTextLabel?.font = .ladomiMedium(15)
        cell.detailTextLabel?.textColor = .ypLightGray
        cell.selectionStyle = .none
        cell.tintColor = .ypLightGray

        switch settingsRows[indexPath.row] {
        case .category:
            let cellText = NSLocalizedString("categoryTable.title", comment: "название ячейки")
            cell.textLabel?.text = cellText
            cell.detailTextLabel?.text = selectedCategory?.title
        case .schedule:
            let cellText = NSLocalizedString("scheduleTable.title", comment: "название ячейки")
            cell.textLabel?.text = cellText
            cell.detailTextLabel?.text = scheduleSubtitle()
        case .eventDate:
            let cellText = NSLocalizedString("eventScheduleTable.title", comment: "Event schedule cell title")
            cell.textLabel?.text = cellText
            cell.detailTextLabel?.text = eventDateSubtitle()
        case .reminder:
            configureReminderCell(cell)
        }

        configureSettingsIcon(for: cell, row: settingsRows[indexPath.row])

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        settingsRowHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch settingsRows[indexPath.row] {
        case .category:
            categoryCellIndexPath = indexPath
            let categoryVC = CategoryViewController()
            categoryVC.delegate = self
            present(categoryVC, animated: true)
        case .schedule:
            let scheduleVC = ScheduleViewController()
            scheduleVC.selectedDays = self.selectedDays
            scheduleVC.delegate = self
            present(scheduleVC, animated: true)
        case .eventDate:
            presentEventDatePicker()
        case .reminder:
            break
        }
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

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let isLastCell = indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1

        if isLastCell {
            cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: tableView.bounds.width)
        }
    }

}

// MARK: - Extension: UITableViewDelegate

extension NewHabitOrEventViewController: UITableViewDelegate {

}

// MARK: - Extension: UITextFieldDelegate

extension NewHabitOrEventViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
        let isLimitVisible = newText.count >= 38
        characterLimitLabel.isHidden = !isLimitVisible
        characterLimitHeightConstraint.constant = isLimitVisible ? 20 : 0

        return newText.count <= 39
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        createButtonIsAvailable()
        return true
    }
}

// MARK: - Extension: ScheduleViewControllerDelegate

extension NewHabitOrEventViewController: ScheduleViewControllerDelegate {
    func didSelectDays(days: [Weekday]) {
        selectedDays = days
        tableView.reloadData()
        updateTableViewHeight()
        updatePreviewCard()
    }
}

// MARK: - Extension: UICollectionViewDelegate + DataSource + FlowLayout

extension NewHabitOrEventViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectionView.tag {
        case 1:
            return activeEmojis.count
        case 2:
            return colors.count
        default:
            return 0
        }
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        switch collectionView.tag {
        case 1:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCell", for: indexPath) as? EmojiCell else {return UICollectionViewCell()}
            cell.configureEmoji(emoji: activeEmojis[indexPath.item])
            cell.updateSelection(isSelected: selectedEmojiIndexPath == indexPath)
            return cell
        case 2:
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ColorCell.cellIdentifier, for: indexPath) as? ColorCell else {
                    return UICollectionViewCell()
                }
                let color = colors[indexPath.item]
                cell.updateColor(color: color)

                if selectedColorIndexPath == indexPath {
                    cell.updateFrameColor(color: color, isHidden: false)
                } else {
                    cell.updateFrameColor(color: color, isHidden: true)
                }
                return cell
        default:
            return UICollectionViewCell()
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        5
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        5
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: 56, height: 56)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch collectionView.tag {
        case 1:
            guard activeEmojis.indices.contains(indexPath.row) else { return }
            let selectedEmoji = activeEmojis[indexPath.row]

            if let previousIndexPath = selectedEmojiIndexPath,
               let previousCell = emojiCollection.cellForItem(at: previousIndexPath) as? EmojiCell {
                previousCell.updateSelection(isSelected: false)
            }
            if let cell = emojiCollection.cellForItem(at: indexPath) as? EmojiCell {
                cell.updateSelection(isSelected: true)
            }
            selectedEmojiIndexPath = indexPath
            self.selectedEmoji = selectedEmoji
            updatePreviewCard()
            createButtonIsAvailable()

        case 2:
            guard colors.indices.contains(indexPath.row) else { return }
            let selectedColor = colors[indexPath.row]

            if let previousIndexPath = selectedColorIndexPath,
               let previousCell = colorCollection.cellForItem(at: previousIndexPath) as? ColorCell {
                previousCell.updateFrameColor(color: .clear, isHidden: true)
            }
            if let cell = colorCollection.cellForItem(at: indexPath) as? ColorCell {
                cell.updateFrameColor(color: colors[indexPath.row], isHidden: false)
            }
            selectedColorIndexPath = indexPath
            self.selectedColor = selectedColor
            updatePreviewCard()
            createButtonIsAvailable()

        default:
            break
        }
    }
}

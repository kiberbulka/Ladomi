import UIKit

class DayViewController: UIViewController {
    private enum DashboardMode {
        case dayItems
        case stopList
    }
    
    // MARK: - Private Properties
    
    private var dayItems: [DayItem] = []
    private var dayItem: DayItem?
    private var categories: [DayItemCategory] = []
    private var visibleCategories: [DayItemCategory] = []
    private var filteredCategories: [DayItemCategory] = []
    private var completedDayItems: [DayItemRecord] = []
    private var pinnedDayItems: [DayItem] = []
    private let pinnedDayItemsKey = "pinnedDayItemsIDs"
    private let postponedDayItemsKey = "postponedDayItemsByDate"
    private var currentDate: Date?
    private let dayItemCategoryStore = DayItemCategoryStore()
    private let dayItemStore = DayItemStore()
    private let dayItemRecordStore = DayItemRecordStore()
    private let hiddenFilterBottomInset: CGFloat = 24
    private var filterChipHeightConstraint: NSLayoutConstraint!
    private var filterChipTopConstraint: NSLayoutConstraint!
    private var collectionViewTopConstraint: NSLayoutConstraint!
    private var addButtonLeadingConstraint: NSLayoutConstraint!
    private var dateButtonTrailingConstraint: NSLayoutConstraint!
    private var titleLeadingConstraint: NSLayoutConstraint!
    private var titleTrailingConstraint: NSLayoutConstraint!
    private var titleBelowAddConstraint: NSLayoutConstraint!
    private var titleWideTopConstraint: NSLayoutConstraint!
    private var controlsLeadingConstraint: NSLayoutConstraint!
    private var controlsTrailingConstraint: NSLayoutConstraint!
    private var modeSegmentWidthConstraint: NSLayoutConstraint!
    private var appliedAdaptiveLayoutMode = -1
    private var dashboardMode: DashboardMode = .dayItems
    var onStopListModeChange: ((Bool) -> Void)?

    private lazy var dateChipFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .appPreferred
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    private lazy var postponeStorageDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private lazy var postponeActionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .appPreferred
        formatter.setLocalizedDateFormatFromTemplate("EEE, d MMM")
        return formatter
    }()
    
    private var selectedFilter: FilterType = .all {
        didSet {
            updateUIForSelectedFilter()
        }
    }
    
    // MARK: - UI Elements

    private lazy var addDayItemButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .ypWhite
        button.tintColor = .ypBlack
        button.layer.cornerRadius = 24
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 16
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.addTarget(self, action: #selector(createDayItemOrHabit), for: .touchUpInside)
        return button
    }()

    private lazy var dateButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .ypWhite
        button.tintColor = .ypBlack
        button.setTitleColor(.ypBlack, for: .normal)
        button.titleLabel?.font = .ladomiBold(17)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.85
        button.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        button.layer.cornerRadius = 22
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.ypGray.cgColor
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(dateButtonDidTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var dayItemLabel: UILabel = {
        let label = UILabel()
        let labelText = NSLocalizedString("dayItems.title", comment: "Заголовок на главном экране ритмов")
        label.text = labelText
        label.font = .ladomiBold(32)
        label.textColor = .ypBlack
        return label
    }()

    private lazy var dayItemSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiMedium(17)
        label.textColor = .ypLightGray
        return label
    }()

    private lazy var modeSegmentControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [
            NSLocalizedString("dashboard.dayItems", comment: "Main dashboard dayItems mode"),
            NSLocalizedString("dashboard.stopList", comment: "Main dashboard stop-list mode")
        ])
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = .ypBlack
        control.backgroundColor = .ypGray
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.ypLightGray,
            .font: UIFont.ladomiBold(15)
        ], for: .normal)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.ypWhite,
            .font: UIFont.ladomiBold(15)
        ], for: .selected)
        control.addTarget(self, action: #selector(modeSegmentDidChange), for: .valueChanged)
        return control
    }()
    
    private lazy var datePicker: UIDatePicker = {
        let datePicker = UIDatePicker()
        datePicker.calendar.firstWeekday = 2
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.addTarget(self, action: #selector(datePickerValueChanged), for: .valueChanged)
        return datePicker
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(DayItemCell.self, forCellWithReuseIdentifier: DayItemCell.dayItemCellIdentifier)
        collectionView.register(SupplementaryView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        return collectionView
    }()

    private lazy var allFilterChip = makeFilterChip(
        title: NSLocalizedString("filter.all", comment: "All filter chip"),
        action: #selector(allFilterChipDidTap)
    )
    private lazy var habitsFilterChip = makeFilterChip(
        title: NSLocalizedString("habitsFilter", comment: ""),
        action: #selector(habitsFilterChipDidTap)
    )
    private lazy var eventsFilterChip = makeFilterChip(
        title: NSLocalizedString("eventsFilter", comment: ""),
        action: #selector(eventsFilterChipDidTap)
    )
    private lazy var completedFilterChip = makeFilterChip(
        title: NSLocalizedString("completedDayItems", comment: ""),
        action: #selector(completedFilterChipDidTap)
    )
    private lazy var notCompletedFilterChip = makeFilterChip(
        title: NSLocalizedString("uncompletedDayItems", comment: ""),
        action: #selector(notCompletedFilterChipDidTap)
    )

    private lazy var filterChipStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            allFilterChip,
            habitsFilterChip,
            eventsFilterChip,
            completedFilterChip,
            notCompletedFilterChip
        ])
        stackView.axis = .horizontal
        stackView.alignment = .leading
        stackView.spacing = 12
        return stackView
    }()

    private lazy var filterChipScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = true
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 4)
        filterChipStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(filterChipStackView)

        NSLayoutConstraint.activate([
            filterChipStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            filterChipStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            filterChipStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            filterChipStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            filterChipStackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        return scrollView
    }()
    
    private lazy var searchStackView: UIStackView = {
        let searchStackview = UIStackView(arrangedSubviews: [searchTextField])
        searchStackview.axis = .horizontal
        searchStackview.distribution = .fill
        searchStackview.spacing = 14
        return searchStackview
    }()

    private lazy var controlsStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [modeSegmentControl, searchStackView])
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 14
        return stackView
    }()
    
    private lazy var searchTextField: UISearchTextField = {
        let searchTextField = UISearchTextField()
        searchTextField.backgroundColor = .ypGray
        searchTextField.textColor = .ypBlack
        searchTextField.tintColor = .ypBlack
        searchTextField.font = .ladomiRegular(17)
        searchTextField.layer.cornerRadius = 22
        searchTextField.layer.masksToBounds = true
        searchTextField.borderStyle = .none
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.ypLightGray,
            .font: UIFont.ladomiRegular(15)
        ]
        let searchTextFieldText = NSLocalizedString("searchBar", comment: "Строка поиска")
        searchTextField.attributedPlaceholder = NSAttributedString(string: searchTextFieldText, attributes: attributes)
        searchTextField.clearButtonMode = .never
        searchTextField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        searchTextField.delegate = self
        return searchTextField
    }()
    
    
    private lazy var placeholderImage: UIImageView = {
        let placeholderImageView = UIImageView()
        placeholderImageView.image = UIImage(named: "placeholder")
        return placeholderImageView
    }()
    
    private lazy var placeholderLabel: UILabel = {
        let placeholderLabel = UILabel()
        let placeholderText = NSLocalizedString("emptyState.title", comment: "Заглушка если ритмов нет")
        placeholderLabel.text = placeholderText
        placeholderLabel.font = .ladomiMedium(12)
        placeholderLabel.textColor = .ypBlack
        placeholderLabel.textAlignment = .center
        placeholderLabel.numberOfLines = 0
        return placeholderLabel
    }()

    private lazy var placeholderStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [placeholderImage, placeholderLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        return stackView
    }()
    
    // MARK: - Overrides Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationAppearance()
        setupUI()
        updateDateButtonTitle()
        showPlaceholder()
        view.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidCreateDayItem), name: Notification.Name("DidCreateDayItem"), object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchRecordsDidChange),
            name: LadomiWatchSyncService.recordsDidChangeNotification,
            object: nil
        )
        dayItemCategoryStore.delegate = self
        AnalyticsService.shared.report(event: "open", screen: "Main")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        reloadData()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        AnalyticsService.shared.report(event: "close", screen: "Main")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAdaptiveLayout()
        updateCollectionViewBottomInset()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.appliedAdaptiveLayoutMode = -1
            self.updateAdaptiveLayout(proposedSize: size)
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.view.layoutIfNeeded()
        })
    }
    
    // MARK: -  Setup UI
    
    private func setupUI() {
        
        [
            addDayItemButton,
            dateButton,
            dayItemLabel,
            dayItemSubtitleLabel,
            controlsStackView,
            filterChipScrollView,
            collectionView,
            placeholderStackView
        ].forEach{
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        addButtonLeadingConstraint = addDayItemButton.leadingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.leadingAnchor,
            constant: 20
        )
        dateButtonTrailingConstraint = dateButton.trailingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.trailingAnchor,
            constant: -20
        )
        titleLeadingConstraint = dayItemLabel.leadingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.leadingAnchor,
            constant: 20
        )
        titleTrailingConstraint = dayItemLabel.trailingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.trailingAnchor,
            constant: -20
        )
        titleBelowAddConstraint = dayItemLabel.topAnchor.constraint(
            equalTo: addDayItemButton.bottomAnchor,
            constant: 12
        )
        titleWideTopConstraint = dayItemLabel.topAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.topAnchor,
            constant: 12
        )
        controlsLeadingConstraint = controlsStackView.leadingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.leadingAnchor,
            constant: 20
        )
        controlsTrailingConstraint = controlsStackView.trailingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.trailingAnchor,
            constant: -20
        )
        modeSegmentWidthConstraint = modeSegmentControl.widthAnchor.constraint(equalToConstant: 260)

        NSLayoutConstraint.activate([
            addDayItemButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            addButtonLeadingConstraint,
            addDayItemButton.heightAnchor.constraint(equalToConstant: 48),
            addDayItemButton.widthAnchor.constraint(equalToConstant: 48),

            dateButton.centerYAnchor.constraint(equalTo: addDayItemButton.centerYAnchor),
            dateButtonTrailingConstraint,
            dateButton.heightAnchor.constraint(equalToConstant: 44),
            dateButton.widthAnchor.constraint(equalToConstant: 112),

            titleLeadingConstraint,
            titleTrailingConstraint,
            titleBelowAddConstraint,

            dayItemSubtitleLabel.topAnchor.constraint(equalTo: dayItemLabel.bottomAnchor, constant: 6),
            dayItemSubtitleLabel.leadingAnchor.constraint(equalTo: dayItemLabel.leadingAnchor),
            dayItemSubtitleLabel.trailingAnchor.constraint(equalTo: dayItemLabel.trailingAnchor),

            controlsStackView.topAnchor.constraint(equalTo: dayItemSubtitleLabel.bottomAnchor, constant: 16),
            controlsLeadingConstraint,
            controlsTrailingConstraint,
            modeSegmentControl.heightAnchor.constraint(equalTo: searchTextField.heightAnchor),

            filterChipScrollView.leadingAnchor.constraint(equalTo: controlsStackView.leadingAnchor),
            filterChipScrollView.trailingAnchor.constraint(equalTo: controlsStackView.trailingAnchor),

            placeholderImage.heightAnchor.constraint(equalToConstant: 80),
            placeholderImage.widthAnchor.constraint(equalToConstant: 80),
            placeholderLabel.widthAnchor.constraint(lessThanOrEqualTo: collectionView.widthAnchor, constant: -40),
            placeholderStackView.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            placeholderStackView.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor)
            
        ])

        filterChipTopConstraint = filterChipScrollView.topAnchor.constraint(equalTo: controlsStackView.bottomAnchor, constant: 14)
        filterChipHeightConstraint = filterChipScrollView.heightAnchor.constraint(equalToConstant: 38)
        collectionViewTopConstraint = collectionView.topAnchor.constraint(equalTo: filterChipScrollView.bottomAnchor, constant: 6)
        NSLayoutConstraint.activate([
            filterChipTopConstraint,
            filterChipHeightConstraint,
            collectionViewTopConstraint
        ])
        updateAdaptiveLayout()
        updateDashboardModeUI()
    }

    private struct CardLayoutMetrics {
        let itemSize: CGSize
        let spacing: CGFloat
        let sectionInsets: UIEdgeInsets
    }

    private func updateAdaptiveLayout(proposedSize: CGSize? = nil) {
        let size = proposedSize ?? view.bounds.size
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let isWidePad = isPad && size.width > size.height
        let layoutMode = isPad ? (isWidePad ? 2 : 1) : 0

        guard layoutMode != appliedAdaptiveLayoutMode else { return }
        appliedAdaptiveLayoutMode = layoutMode

        let horizontalMargin: CGFloat
        switch layoutMode {
        case 1:
            horizontalMargin = 48
        case 2:
            horizontalMargin = 32
        default:
            horizontalMargin = 20
        }

        addButtonLeadingConstraint.constant = horizontalMargin
        dateButtonTrailingConstraint.constant = -horizontalMargin
        titleLeadingConstraint.constant = horizontalMargin
        titleTrailingConstraint.constant = -horizontalMargin
        controlsLeadingConstraint.constant = horizontalMargin
        controlsTrailingConstraint.constant = -horizontalMargin

        addDayItemButton.isHidden = isWidePad
        titleBelowAddConstraint.isActive = !isWidePad
        titleWideTopConstraint.isActive = isWidePad
        modeSegmentWidthConstraint.isActive = isWidePad

        controlsStackView.axis = isWidePad ? .horizontal : .vertical
        controlsStackView.alignment = isWidePad ? .center : .fill
        controlsStackView.spacing = isWidePad ? 16 : 14

        dayItemLabel.font = .ladomiBold(isPad ? 44 : 32)
        dayItemSubtitleLabel.font = .ladomiMedium(isPad ? 18 : 17)
        collectionView.collectionViewLayout.invalidateLayout()
    }

    private func cardLayoutMetrics(in collectionView: UICollectionView) -> CardLayoutMetrics {
        let collectionWidth = collectionView.bounds.width
        let isPad = traitCollection.userInterfaceIdiom == .pad

        guard isPad else {
            let spacing: CGFloat = 14
            let insets = UIEdgeInsets(top: 6, left: 20, bottom: 12, right: 20)
            let width = (collectionWidth - insets.left - insets.right - spacing) / 2
            return CardLayoutMetrics(
                itemSize: CGSize(width: floor(width), height: 156),
                spacing: spacing,
                sectionInsets: insets
            )
        }

        let isWidePad = view.bounds.width > view.bounds.height
        let columnCount: CGFloat = isWidePad ? 4 : 3
        let spacing: CGFloat = 16
        let preferredWidth: CGFloat = isWidePad ? 188 : 212
        let minimumOuterInset: CGFloat = isWidePad ? 32 : 48
        let availableWidth = collectionWidth - (minimumOuterInset * 2) - (spacing * (columnCount - 1))
        let itemWidth = min(preferredWidth, floor(availableWidth / columnCount))
        let gridWidth = (itemWidth * columnCount) + (spacing * (columnCount - 1))
        let centeredInset = max(minimumOuterInset, floor((collectionWidth - gridWidth) / 2))
        let leadingInset = isWidePad ? centeredInset : minimumOuterInset
        let trailingInset = isWidePad
            ? centeredInset
            : max(minimumOuterInset, floor(collectionWidth - leadingInset - gridWidth))
        let itemHeight = max(156, floor(itemWidth * 0.86))

        return CardLayoutMetrics(
            itemSize: CGSize(width: itemWidth, height: itemHeight),
            spacing: spacing,
            sectionInsets: UIEdgeInsets(top: 8, left: leadingInset, bottom: 18, right: trailingInset)
        )
    }
    
    private func setupNavigationItem(){
        let image = UIImage(named: "addDayItem")
        let barButton = UIBarButtonItem(
            image: image,
            style: .plain,
            target: self,
            action: #selector(createDayItemOrHabit)
        )
        barButton.tintColor = .label
        navigationItem.leftBarButtonItem = barButton
        
        let datePickerItem = UIBarButtonItem(customView: datePicker)

        navigationItem.rightBarButtonItem = datePickerItem
    }
    
    private func setupNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .ypWhite
        appearance.shadowColor = .clear
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }

    private func makeFilterChip(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .ladomiBold(16)
        button.titleLabel?.lineBreakMode = .byClipping
        button.layer.cornerRadius = 19
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func updateFilterChips() {
        let chips: [(UIButton, FilterType)] = [
            (allFilterChip, .all),
            (habitsFilterChip, .habits),
            (eventsFilterChip, .events),
            (completedFilterChip, .completed),
            (notCompletedFilterChip, .notCompleted)
        ]

        chips.forEach { button, filter in
            let isSelected = selectedFilter == filter
            button.backgroundColor = isSelected ? .ypBlack : .ypGray
            button.setTitleColor(isSelected ? .ypWhite : UIColor(white: 0.48, alpha: 1), for: .normal)
        }
    }

    private func updateDateButtonTitle() {
        let title = dateChipFormatter.string(from: datePicker.date).replacingOccurrences(of: ".", with: "")
        dateButton.setTitle(title, for: .normal)
    }

    private func updateDayItemSubtitle() {
        let count = visibleCategories.reduce(0) { $0 + $1.dayItems.count }
        switch dashboardMode {
        case .dayItems:
            let format = NSLocalizedString("dashboard.dayItems.subtitle", comment: "Main dashboard dayItems subtitle")
            dayItemSubtitleLabel.text = String(format: format, count, dayItemWord(for: count))
        case .stopList:
            let format = NSLocalizedString("dashboard.stopList.subtitle", comment: "Stop-list dashboard subtitle")
            dayItemSubtitleLabel.text = String(format: format, count, stopItemWord(for: count))
        }
    }

    private func dayItemWord(for count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100

        if remainder10 == 1 && remainder100 != 11 {
            return NSLocalizedString("day.item.one", comment: "One day item")
        } else if remainder10 >= 2 && remainder10 <= 4 && (remainder100 < 10 || remainder100 >= 20) {
            return NSLocalizedString("day.item.few", comment: "Few day items")
        } else {
            return NSLocalizedString("day.item.many", comment: "Many day items")
        }
    }

    private func stopItemWord(for count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100

        if remainder10 == 1 && remainder100 != 11 {
            return NSLocalizedString("stopList.item.one", comment: "One stop-list item")
        } else if remainder10 >= 2 && remainder10 <= 4 && (remainder100 < 10 || remainder100 >= 20) {
            return NSLocalizedString("stopList.item.few", comment: "Few stop-list items")
        } else {
            return NSLocalizedString("stopList.item.many", comment: "Many stop-list items")
        }
    }
    
    private func showPlaceholder() {
        let hasAnyDayItems: Bool
        if dashboardMode == .stopList {
            hasAnyDayItems = dayItems.contains { $0.isStopList }
        } else {
            hasAnyDayItems = categories.contains { category in
                category.dayItems.contains { !$0.isStopList }
            }
        }

        if !hasAnyDayItems {
            placeholderStackView.isHidden = false
            placeholderImage.image = UIImage(named: "placeholder")
            placeholderLabel.text = dashboardMode == .stopList
                ? NSLocalizedString("stopList.empty", comment: "Empty stop-list placeholder")
                : NSLocalizedString("emptyState.title", comment: "Заглушка если ритмов совсем нет")
        } else if visibleCategories.isEmpty {
            placeholderStackView.isHidden = false
            placeholderImage.image = UIImage(named: "placeholder2")
            placeholderLabel.text = NSLocalizedString("emptySearchResult", comment: "Заглушка если выдача нулевая")
        } else {
            placeholderStackView.isHidden = true
        }

        updateCollectionViewBottomInset()
    }

    // MARK: -  Objc Private Properties
    
    @objc private func allFilterChipDidTap() {
        selectedFilter = .all
    }

    @objc private func habitsFilterChipDidTap() {
        selectedFilter = .habits
    }

    @objc private func eventsFilterChipDidTap() {
        selectedFilter = .events
    }

    @objc private func completedFilterChipDidTap() {
        selectedFilter = .completed
    }

    @objc private func notCompletedFilterChipDidTap() {
        selectedFilter = .notCompleted
    }

    @objc private func modeSegmentDidChange() {
        dashboardMode = modeSegmentControl.selectedSegmentIndex == 1 ? .stopList : .dayItems
        updateDashboardModeUI()
        reloadVisibleCategories()
    }

    @objc private func dateButtonDidTap() {
        let alert = UIAlertController(title: nil, message: "\n\n\n\n\n\n\n\n\n\n\n\n\n\n", preferredStyle: .actionSheet)
        let picker = UIDatePicker()
        picker.calendar.firstWeekday = 2
        picker.datePickerMode = .date
        if #available(iOS 14.0, *) {
            picker.preferredDatePickerStyle = .inline
        } else {
            picker.preferredDatePickerStyle = .wheels
        }
        picker.date = datePicker.date
        picker.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 14.0, *) {
            picker.addTarget(self, action: #selector(calendarPickerValueChanged(_:)), for: .valueChanged)
        } else {
            alert.addAction(UIAlertAction(title: NSLocalizedString("done", comment: "Done button"), style: .default) { [weak self] _ in
                self?.datePicker.setDate(picker.date, animated: false)
                self?.datePickerValueChanged()
            })
        }
        alert.view.addSubview(picker)

        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 16),
            picker.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -16),
            picker.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 12),
            picker.heightAnchor.constraint(equalToConstant: 330)
        ])

        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel button"), style: .cancel))
        alert.popoverPresentationController?.sourceView = dateButton
        alert.popoverPresentationController?.sourceRect = dateButton.bounds

        present(alert, animated: true)
    }

    @objc private func calendarPickerValueChanged(_ picker: UIDatePicker) {
        datePicker.setDate(picker.date, animated: false)
        datePickerValueChanged()
        presentedViewController?.dismiss(animated: true)
    }
    
    @objc private func handleDidCreateDayItem() {
        reloadData()
        collectionView.register(SupplementaryView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        collectionView.reloadData()
        showPlaceholder()
    }

    @objc private func handleWatchRecordsDidChange() {
        reloadData()
    }
    
    @objc private func datePickerValueChanged() {
        currentDate = datePicker.date
        updateDateButtonTitle()

        reloadVisibleCategories()
        collectionView.reloadData()
    }
    
    func presentCreateDayItem() {
        createDayItemOrHabit()
    }

    @objc private func createDayItemOrHabit(){
        let createDayItemVC = NewHabitOrEventViewController()
        createDayItemVC.delegate = self
        createDayItemVC.selectedEventDate = datePicker.date
        createDayItemVC.isStopList = dashboardMode == .stopList
        createDayItemVC.isHabit = dashboardMode == .stopList ? false : true
        present(createDayItemVC, animated: true)
        AnalyticsService.shared.report(event: "click", screen: "Main", item: "add_track")
    }
    
    // MARK: - Private Methods Filters
    
    private func dayItemPassesAllFilters(_ dayItem: DayItem, on date: Date, searchText: String) -> Bool {
        let calendar = Calendar.current
        let modeCondition = dashboardMode == .stopList ? dayItem.isStopList : !dayItem.isStopList
        guard modeCondition else {
            return false
        }
        
        let textCondition = searchText.isEmpty || dayItem.name.lowercased().contains(searchText.lowercased())
        
        let dateCondition: Bool
        if dayItem.isStopList {
            dateCondition = calendar.startOfDay(for: date) >= calendar.startOfDay(for: dayItem.createdDate)
        } else if isDayItemPostponedFrom(dayItem, on: date) {
            dateCondition = false
        } else if isDayItemPostponedTo(dayItem, on: date) {
            dateCondition = true
        } else if dayItem.isHabit {
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            dateCondition = dayItem.schedule.contains { $0.numberValue == adjustedWeekday }
        } else {
            if let record = completedDayItems.first(where: { $0.dayItemID == dayItem.id }) {
                dateCondition = calendar.isDate(record.date, inSameDayAs: date)
            } else {
                dateCondition = calendar.isDate(effectiveDateForIncompleteEvent(dayItem), inSameDayAs: date)
            }
        }
        
        let filterCondition: Bool
        if dashboardMode == .stopList {
            filterCondition = true
        } else {
            switch selectedFilter {
            case .habits:
                filterCondition = dayItem.isHabit
            case .events:
                filterCondition = !dayItem.isHabit
            case .completed:
                filterCondition = isDayItemCompleted(dayItem, on: date)
            case .notCompleted:
                filterCondition = !isDayItemCompleted(dayItem, on: date)
            case .all:
                filterCondition = true
            }
        }
        return textCondition && dateCondition && filterCondition
    }
    
    private func reloadVisibleCategories() {
        guard let currentDate = currentDate else { return }

        let searchText = (searchTextField.text ?? "").lowercased()

        let pinnedFilteredDayItems = pinnedDayItems.filter {
            dayItemPassesAllFilters($0, on: currentDate, searchText: searchText)
        }
        visibleCategories = []

        if !pinnedFilteredDayItems.isEmpty {
            visibleCategories.append(
                DayItemCategory(
                    title: NSLocalizedString("pinnedDayItems", comment: "Pinned dayItems section title"),
                    dayItems: pinnedFilteredDayItems
                )
            )
        }

        if dashboardMode == .stopList {
            let stopListDayItems = dayItems.filter { dayItem in
                !pinnedDayItems.contains(where: { $0.id == dayItem.id }) &&
                dayItemPassesAllFilters(dayItem, on: currentDate, searchText: searchText)
            }

            if !stopListDayItems.isEmpty {
                visibleCategories.append(DayItemCategory(title: "", dayItems: stopListDayItems))
            }
        } else {
            let otherCategories = filteredCategories.compactMap { category -> DayItemCategory? in
                let dayItems = category.dayItems.filter { dayItem in
                    !pinnedDayItems.contains(where: { $0.id == dayItem.id }) &&
                    dayItemPassesAllFilters(dayItem, on: currentDate, searchText: searchText)
                }
                return dayItems.isEmpty ? nil : DayItemCategory(title: category.title, dayItems: dayItems)
            }

            visibleCategories.append(contentsOf: otherCategories)
        }

        collectionView.reloadData()
        updateDayItemSubtitle()
        updateFilterChips()
        showPlaceholder()
    }

    
    private func isDayItemActiveOnDate(_ dayItem: DayItem, date: Date) -> Bool {
        let calendar = Calendar.current

        if dayItem.isStopList {
            return calendar.startOfDay(for: date) >= calendar.startOfDay(for: dayItem.createdDate)
        }

        if isDayItemPostponedFrom(dayItem, on: date) {
            return false
        }

        if isDayItemPostponedTo(dayItem, on: date) {
            return true
        }

        if dayItem.isHabit {
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            return dayItem.schedule.contains { $0.numberValue == adjustedWeekday }
        } else {
            if let record = completedDayItems.first(where: { $0.dayItemID == dayItem.id }) {
                return calendar.isDate(record.date, inSameDayAs: date)
            }

            return calendar.isDate(effectiveDateForIncompleteEvent(dayItem), inSameDayAs: date)
        }
    }

    private func effectiveDateForIncompleteEvent(_ dayItem: DayItem) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let eventDate = calendar.startOfDay(for: dayItem.eventDate ?? today)

        return eventDate < today ? today : eventDate
    }

    private func isCurrentDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    // MARK: - Private Methods
    
    private func updateUIForSelectedFilter() {
        updateFilterChips()
        reloadVisibleCategories()
        showPlaceholder()
        
    }

    private func updateDashboardModeUI() {
        let isStopListMode = dashboardMode == .stopList
        onStopListModeChange?(isStopListMode)
        selectedFilter = .all
        dayItemLabel.text = isStopListMode
            ? NSLocalizedString("stopList.title", comment: "Stop-list screen title")
            : NSLocalizedString("dayItems.title", comment: "Main screen title")
        filterChipScrollView.isHidden = isStopListMode
        filterChipScrollView.alpha = isStopListMode ? 0 : 1
        filterChipTopConstraint.constant = isStopListMode ? 6 : 14
        filterChipHeightConstraint.constant = isStopListMode ? 0 : 38
        collectionViewTopConstraint.constant = isStopListMode ? 10 : 6
    }

    private func updateCollectionViewBottomInset() {
        let bottomInset = hiddenFilterBottomInset
        guard collectionView.contentInset.bottom != bottomInset else {
            return
        }

        collectionView.contentInset.bottom = bottomInset
        collectionView.verticalScrollIndicatorInsets.bottom = bottomInset
    }
    
    private func savePinnedDayItems() {
        let pinnedIDs = pinnedDayItems.map { $0.id.uuidString }
        UserDefaults.standard.set(pinnedIDs, forKey: pinnedDayItemsKey)
    }
    
    private func loadPinnedDayItems() {
        guard let pinnedIDs = UserDefaults.standard.array(forKey: pinnedDayItemsKey) as? [String] else {
            pinnedDayItems = []
            return
        }
        
        pinnedDayItems = dayItems.filter { pinnedIDs.contains($0.id.uuidString) }
    }
    
    private func reloadData(){
        dayItems = dayItemStore.fetchDayItems().filter { !$0.isArchived }
        categories = activeCategories(from: dayItemCategoryStore.fetchCategories())
        filteredCategories = categories
        completedDayItems = dayItemRecordStore.fetch()
        refreshReminders()
        loadPinnedDayItems()
        datePickerValueChanged()
        reloadVisibleCategories()
        showPlaceholder()
        LadomiWatchSyncService.shared.publishTodayPlans()
    }

    private func refreshReminders() {
        dayItems.filter { !$0.isStopList }.forEach {
            ReminderNotificationService.shared.scheduleReminder(
                for: $0,
                completedRecords: completedDayItems
            )
        }
        scheduleSoftRemindersForToday()
        updateTodayWidgetSnapshot()
    }

    private func scheduleSoftRemindersForToday() {
        dayItems.filter { !$0.isStopList }.forEach {
            ReminderNotificationService.shared.scheduleSoftReminderIfNeeded(
                for: $0,
                completedRecords: completedDayItems
            )
        }
    }

    private func activeCategories(from categories: [DayItemCategory]) -> [DayItemCategory] {
        categories.compactMap { category in
            let activeDayItems = category.dayItems.filter { !$0.isArchived }
            return activeDayItems.isEmpty ? nil : DayItemCategory(title: category.title, dayItems: activeDayItems)
        }
    }

    private func updateTodayWidgetSnapshot() {
        LadomiWidgetSnapshotService.shared.saveTodaySnapshot(
            dayItems: dayItems,
            completedRecords: completedDayItems
        )
    }
    
    private func isDayItemCompletedToday(id:UUID) -> Bool {
        
        completedDayItems.contains { dayItemRecord in
            let isSameDay = Calendar.current.isDate(dayItemRecord.date, inSameDayAs: datePicker.date)
            return dayItemRecord.dayItemID == id && isSameDay
        }
    }
    
    private func isDayItemCompleted(_ dayItem: DayItem, on date: Date) -> Bool {
        let calendar = Calendar.current
        return completedDayItems.contains {
            $0.dayItemID == dayItem.id && calendar.isDate($0.date, inSameDayAs: date)
        }
    }

    private func stopListCleanDays(for dayItem: DayItem, on date: Date) -> Int {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        let createdDate = calendar.startOfDay(for: dayItem.createdDate)
        let latestSlipDate = completedDayItems
            .filter { $0.dayItemID == dayItem.id && calendar.startOfDay(for: $0.date) <= targetDate }
            .map { calendar.startOfDay(for: $0.date) }
            .max()
        let anchorDate = latestSlipDate ?? createdDate
        let days = calendar.dateComponents([.day], from: anchorDate, to: targetDate).day ?? 0

        return max(0, days)
    }
    
    private func openEditScreen(with dayItem: DayItem) {
        let editVC = NewHabitOrEventViewController()
        editVC.isEditingDayItem = true
        editVC.dayItemToEdit = dayItem
        
        editVC.isHabit = dayItem.isHabit
        editVC.isStopList = dayItem.isStopList
        self.present(editVC, animated: true)
    }
    
    // MARK: - UIContextMenu Methods
    
    private func deleteDayItem(at indexPath: IndexPath) {
        let visualDayItem = visibleCategories[indexPath.section].dayItems[indexPath.item]

        guard let dayItemToDelete = dayItemStore.dayItem(with: visualDayItem.id) else {
            print("Не найден ритм в базе")
            return
        }

        if let pinnedIndex = pinnedDayItems.firstIndex(where: { $0.id == dayItemToDelete.id }) {
            pinnedDayItems.remove(at: pinnedIndex)
            savePinnedDayItems()
        }

        dayItemStore.deleteDayItem(dayItemToDelete)

        dayItems = dayItemStore.fetchDayItems().filter { !$0.isArchived }
        categories = activeCategories(from: dayItemCategoryStore.fetchCategories())
        filteredCategories = categories
        reloadVisibleCategories()
        collectionView.reloadData()
        showPlaceholder()
        LadomiWatchSyncService.shared.publishTodayPlans()
    }

    private func archiveDayItem(_ dayItem: DayItem) {
        dayItemStore.setArchived(true, dayItem: dayItem)

        if let pinnedIndex = pinnedDayItems.firstIndex(where: { $0.id == dayItem.id }) {
            pinnedDayItems.remove(at: pinnedIndex)
            savePinnedDayItems()
        }

        reloadData()
    }

    private func togglePinDayItem(_ dayItem: DayItem) {
        if let index = pinnedDayItems.firstIndex(where: { $0.id == dayItem.id }) {
            pinnedDayItems.remove(at: index)
        } else {
            pinnedDayItems.append(dayItem)
        }
        savePinnedDayItems()
        reloadVisibleCategories()
    }

    private func showPostponeOptions(for dayItem: DayItem) {
        let sourceDate = Calendar.current.startOfDay(for: datePicker.date)
        guard !isDayItemCompleted(dayItem, on: sourceDate) else {
            return
        }

        let alert = UIAlertController(
            title: NSLocalizedString("postpone.title", comment: "Postpone dayItem title"),
            message: nil,
            preferredStyle: .actionSheet
        )

        (1...7).forEach { dayOffset in
            guard let targetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: sourceDate) else {
                return
            }

            let title = postponeActionDateFormatter.string(from: targetDate)
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.postponeDayItem(dayItem, from: sourceDate, to: targetDate)
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel action"), style: .cancel))
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX,
            y: view.bounds.midY,
            width: 1,
            height: 1
        )

        present(alert, animated: true)
    }

    private func postponeDayItem(_ dayItem: DayItem, from sourceDate: Date, to targetDate: Date) {
        var postponements = loadPostponements()
        postponements[postponementKey(for: dayItem.id, date: sourceDate)] = dateKey(for: targetDate)
        UserDefaults.standard.set(postponements, forKey: postponedDayItemsKey)

        if dayItem.isHabit {
            ReminderNotificationService.shared.removeReminder(for: dayItem.id, on: sourceDate)
            ReminderNotificationService.shared.scheduleReminder(
                for: dayItem,
                completedRecords: completedDayItems
            )
        } else {
            ReminderNotificationService.shared.removeReminder(for: dayItem.id)
        }

        reloadVisibleCategories()
        updateTodayWidgetSnapshot()
    }

    private func loadPostponements() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: postponedDayItemsKey) as? [String: String] ?? [:]
    }

    private func isDayItemPostponedFrom(_ dayItem: DayItem, on date: Date) -> Bool {
        loadPostponements()[postponementKey(for: dayItem.id, date: date)] != nil
    }

    private func isDayItemPostponedTo(_ dayItem: DayItem, on date: Date) -> Bool {
        let targetDateKey = dateKey(for: date)
        let dayItemPrefix = "\(dayItem.id.uuidString)_"
        return loadPostponements().contains { key, value in
            key.hasPrefix(dayItemPrefix) && value == targetDateKey
        }
    }

    private func postponementKey(for dayItemID: UUID, date: Date) -> String {
        "\(dayItemID.uuidString)_\(dateKey(for: date))"
    }

    private func dateKey(for date: Date) -> String {
        postponeStorageDateFormatter.string(from: Calendar.current.startOfDay(for: date))
    }
    
    private func showDeleteConfirmation(for dayItem: DayItem, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "",
            message: NSLocalizedString("delete.confirmation", comment: "Delete dayItem confirmation"),
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel action"), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("delete", comment: "Delete action"), style: .destructive) { _ in
            self.deleteDayItem(at: indexPath)
            AnalyticsService.shared.report(event: "click", screen: "Main", item: "delete")
        })
        present(alert, animated: true)
    }
}

// MARK: - Extension: UICollectionViewDelegate

extension DayViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let visualDayItem = visibleCategories[indexPath.section].dayItems[indexPath.item]

        guard let dayItem = dayItemStore.dayItem(with: visualDayItem.id) else {
            return
        }
        guard dayItem.isHabit else {
            return
        }

        let historyVC = DayItemHistoryViewController(dayItem: dayItem, records: completedDayItems)
        present(historyVC, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        let visualDayItem = visibleCategories[indexPath.section].dayItems[indexPath.item]
  
        guard let dayItem = dayItemStore.dayItem(with: visualDayItem.id) else {
            print("Не найден ритм в базе")
            return nil
        }

        let completedDays = completedDayItems.filter { $0.dayItemID == dayItem.id }.count

        let dayItemCategory = dayItemCategoryStore.loadCategories().first(where: { category in
            category.dayItems.contains(where: { $0.id == dayItem.id })
        })

        guard dayItem.isStopList || dayItemCategory != nil else {
            print("Категория ритма не найдена")
            return nil
        }

        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
            let editAction = UIAction(title: NSLocalizedString("edit", comment: "Edit dayItem action")) { [weak self] _ in
                let editVC = NewHabitOrEventViewController()
                editVC.isEditingDayItem = true
                editVC.dayItemToEdit = dayItem
                editVC.completedDays = completedDays
                editVC.isHabit = dayItem.isHabit
                editVC.isStopList = dayItem.isStopList
                editVC.dayItemCategoryToEdit = dayItemCategory

                self?.present(editVC, animated: true)
                AnalyticsService.shared.report(event: "click", screen: "Main", item: "edit")
            }

            let deleteAction = UIAction(title: NSLocalizedString("delete", comment: "Delete dayItem action"), attributes: .destructive) { [weak self] _ in
                self?.showDeleteConfirmation(for: dayItem, at: indexPath)
            }

            let archiveAction = UIAction(title: NSLocalizedString("archiveDayItem", comment: "Archive dayItem action")) { [weak self] _ in
                self?.archiveDayItem(dayItem)
            }

            let isCompletedOnSelectedDate = self.isDayItemCompleted(dayItem, on: self.datePicker.date)
            let postponeAttributes: UIMenuElement.Attributes = isCompletedOnSelectedDate ? .disabled : []
            let postponeAction = UIAction(
                title: NSLocalizedString("postponeDayItem", comment: "Postpone dayItem action"),
                attributes: postponeAttributes
            ) { [weak self] _ in
                self?.showPostponeOptions(for: dayItem)
            }

            let isPinned = self.pinnedDayItems.contains { $0.id == dayItem.id }
            let pinTitle = isPinned
                ? NSLocalizedString("unpinDayItem", comment: "Unpin dayItem action")
                : NSLocalizedString("pinDayItem", comment: "Pin dayItem action")
            let pinAction = UIAction(title: pinTitle) { [weak self] _ in
                self?.togglePinDayItem(dayItem)
            }

            let actions: [UIMenuElement] = dayItem.isStopList
                ? [pinAction, editAction, archiveAction, deleteAction]
                : [pinAction, postponeAction, editAction, archiveAction, deleteAction]
            return UIMenu(title: "", children: actions)
        }
    }

    
    func collectionView(_ collectionView: UICollectionView,
                        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath,
              let cell = collectionView.cellForItem(at: indexPath) as? DayItemCell else {
            return nil
        }
        return UITargetedPreview(view: cell.dayItemCardView)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath,
              let cell = collectionView.cellForItem(at: indexPath) as? DayItemCell else {
            return nil
        }
        return UITargetedPreview(view: cell.dayItemCardView)
    }
    
    
}
// MARK: - Extension: UICollectionViewDataSource

extension DayViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return visibleCategories.isEmpty ? 0: visibleCategories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return visibleCategories[section].dayItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DayItemCell.dayItemCellIdentifier, for: indexPath) as? DayItemCell else {
            return UICollectionViewCell()
        }
        let dayItem = visibleCategories[indexPath.section].dayItems[indexPath.item]
        cell.delegate = self
        let isCompletedToday = isDayItemCompletedToday(id: dayItem.id)
        let displayDays = dayItem.isStopList
            ? stopListCleanDays(for: dayItem, on: datePicker.date)
            : completedDayItems.filter { $0.dayItemID == dayItem.id}.count
        let isPinned = pinnedDayItems.contains { $0.id == dayItem.id }
        cell.configureCell(dayItem: dayItem, isCompletedToday: isCompletedToday, displayDays: displayDays, indexPath: indexPath, isPinned: isPinned)
        return cell
    }
    
    
    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            guard indexPath.section < visibleCategories.count else { return UICollectionReusableView()}
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "header",
                for: indexPath) as! SupplementaryView
            let category = visibleCategories[indexPath.section]

            header.configure(
                text: category.title,
                count: category.dayItems.count,
                horizontalInset: cardLayoutMetrics(in: collectionView).sectionInsets.left
            )
            return header
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        if dashboardMode == .stopList,
           visibleCategories.indices.contains(section),
           visibleCategories[section].title.isEmpty {
            return .zero
        }

        return CGSize(
            width: collectionView.bounds.width,
            height: traitCollection.userInterfaceIdiom == .pad ? 44 : 36
        )
    }
}

// MARK: - Extension: UITextFieldDelegate

extension DayViewController: UITextFieldDelegate{
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchTextField.resignFirstResponder()
        reloadVisibleCategories()
        return true
    }
}

// MARK: - Extension: DayItemCellDelegate

extension DayViewController: DayItemCellDelegate {
    func completeDayItem(id: UUID, at indexPath: IndexPath) {
        guard datePicker.date <= Date() else {
            return
        }
        
        let dayItemRecord = DayItemRecord(dayItemID: id, date: datePicker.date)
        do {
            try dayItemRecordStore.add(dayItemRecord: dayItemRecord)
            completedDayItems.append(dayItemRecord)
            LadomiWatchSyncService.shared.publishTodayPlans()
            if let dayItem = dayItemStore.dayItem(with: id) {
                if dayItem.isStopList {
                    collectionView.reloadItems(at: [indexPath])
                    return
                } else if dayItem.isHabit {
                    ReminderNotificationService.shared.removeReminder(for: id, on: datePicker.date)
                    updateTodayWidgetSnapshot()
                } else {
                    ReminderNotificationService.shared.removeReminder(for: id)
                }
            }
            if selectedFilter == .notCompleted {
                reloadVisibleCategories()
            } else {
                collectionView.reloadItems(at: [indexPath])
            }
        } catch {
            print("Failed to add dayItem record: \(error)")
        }
    }
    
    
    func uncompletedDayItem(id: UUID, at indexPath: IndexPath) {
        completedDayItems.removeAll { dayItemRecord in
            let isSameDay = Calendar.current.isDate(dayItemRecord.date, inSameDayAs: datePicker.date)
            let shouldRemove = dayItemRecord.dayItemID == id && isSameDay

            if shouldRemove {
                do {
                    try dayItemRecordStore.delete(dayItemRecord: dayItemRecord)
                } catch {
                    print("Failed to delete dayItem record: \(error)")
                }
            }
            return shouldRemove
        }

        if let dayItem = dayItemStore.dayItem(with: id) {
            LadomiWatchSyncService.shared.publishTodayPlans()
            if dayItem.isStopList {
                collectionView.reloadItems(at: [indexPath])
            } else if dayItem.isHabit {
                ReminderNotificationService.shared.scheduleReminder(
                    for: dayItem,
                    completedRecords: completedDayItems
                )
                ReminderNotificationService.shared.scheduleSoftReminderIfNeeded(
                    for: dayItem,
                    completedRecords: completedDayItems,
                    date: datePicker.date
                )
                updateTodayWidgetSnapshot()
                if selectedFilter == .completed {
                    reloadVisibleCategories()
                } else {
                    collectionView.reloadItems(at: [indexPath])
                }
            } else {
                ReminderNotificationService.shared.scheduleReminder(
                    for: dayItem,
                    completedRecords: completedDayItems
                )
                reloadVisibleCategories()
            }
        } else {
            collectionView.reloadItems(at: [indexPath])
        }
    }

}

// MARK: - Extension: NewHabitOrEventViewControllerDelegate

extension DayViewController: NewHabitOrEventViewControllerDelegate {
    func didCreateDayItemOrEvent(dayItem: DayItem) {
        dayItems.append(dayItem)
        reloadData()
    }
}

// MARK: - Extension: UICollectionViewDelegateFlowLayout

extension DayViewController: UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        cardLayoutMetrics(in: collectionView).itemSize
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        cardLayoutMetrics(in: collectionView).spacing
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        cardLayoutMetrics(in: collectionView).spacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        cardLayoutMetrics(in: collectionView).sectionInsets
    }
}

// MARK: - Extension: DayItemsStoresDelegates

extension DayViewController: DayItemStoreDelegate, DayItemRecordStoreDelegate, DayItemCategoryStoreDelegate {
    func didUpdate(_ update: DayItemStoreUpdate) {
        collectionView.performBatchUpdates {
            let insertedIndexPath = update.insertedIndexes.map { IndexPath(item: $0, section: $0) }
            let deletedIndexPath = update.deletedIndexes.map { IndexPath(item: $0, section: $0) }
            collectionView.insertItems(at: insertedIndexPath)
            collectionView.deleteItems(at: deletedIndexPath)
        }
    }
    
    func didUpdateRecords(_ update: DayItemCategoryStoreUpdate) {
        collectionView.performBatchUpdates {
            let insertedIndexPath = update.insertedIndexes.map { IndexPath(item: $0, section: $0) }
            let deletedIndexPath = update.deletedIndexes.map { IndexPath(item: $0, section: $0) }
            collectionView.insertItems(at: insertedIndexPath)
            collectionView.deleteItems(at: deletedIndexPath)
        }
    }
    
    func didUpdateCategories(_ update: DayItemCategoryStoreUpdate) {
        categories = dayItemCategoryStore.fetchCategories()
        filteredCategories = categories
        reloadVisibleCategories()
        collectionView.reloadData()
    }
}

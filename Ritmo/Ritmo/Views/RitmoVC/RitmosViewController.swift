//
//  ViewController.swift
//  Ritmo
//
//  Created by User on 20.03.2025.
//

import UIKit

class RitmosViewController: UIViewController {
    
    // MARK: - Private Properties
    
    private var ritmos: [Ritmo] = []
    private var ritmo: Ritmo?
    private var categories: [RitmoCategory] = []
    private var visibleCategories: [RitmoCategory] = []
    private var filteredCategories: [RitmoCategory] = []
    private var completedRitmos: [RitmoRecord] = []
    private var pinnedRitmos: [Ritmo] = []
    private let pinnedRitmosKey = "pinnedRitmosIDs"
    private let postponedRitmosKey = "postponedRitmosByDate"
    private var currentDate: Date?
    private let ritmoCategoryStore = RitmoCategoryStore()
    private let ritmoStore = RitmoStore()
    private let ritmoRecordStore = RitmoRecordStore()
    private let hiddenFilterBottomInset: CGFloat = 24

    private lazy var dateChipFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
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
        formatter.setLocalizedDateFormatFromTemplate("EEE, d MMM")
        return formatter
    }()
    
    private var selectedFilter: FilterType = .all {
        didSet {
            updateUIForSelectedFilter()
        }
    }
    
    // MARK: - UI Elements

    private lazy var addRitmoButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .ypWhite
        button.tintColor = .ypBlack
        button.layer.cornerRadius = 24
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 16
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.addTarget(self, action: #selector(createRitmoOrHabit), for: .touchUpInside)
        return button
    }()

    private lazy var dateButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .ypWhite
        button.tintColor = .ypBlack
        button.setTitleColor(.ypBlack, for: .normal)
        button.titleLabel?.font = .ritmoBold(17)
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
    
    private lazy var ritmoLabel: UILabel = {
        let label = UILabel()
        let labelText = NSLocalizedString("ritmos.title", comment: "Заголовок на главном экране трекеров")
        label.text = labelText
        label.font = .ritmoBold(32)
        label.textColor = .ypBlack
        return label
    }()

    private lazy var ritmoSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoMedium(17)
        label.textColor = .ypLightGray
        return label
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
        collectionView.register(RitmoCell.self, forCellWithReuseIdentifier: RitmoCell.ritmoCellIdentifier)
        collectionView.register(SupplementaryView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        return collectionView
    }()

    private lazy var allFilterChip = makeFilterChip(title: "Все", action: #selector(allFilterChipDidTap))
    private lazy var habitsFilterChip = makeFilterChip(
        title: NSLocalizedString("habitsFilter", comment: ""),
        action: #selector(habitsFilterChipDidTap)
    )
    private lazy var eventsFilterChip = makeFilterChip(
        title: NSLocalizedString("eventsFilter", comment: ""),
        action: #selector(eventsFilterChipDidTap)
    )
    private lazy var notCompletedFilterChip = makeFilterChip(
        title: NSLocalizedString("uncompletedRitmos", comment: ""),
        action: #selector(notCompletedFilterChipDidTap)
    )

    private lazy var filterChipStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            allFilterChip,
            habitsFilterChip,
            eventsFilterChip,
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
    
    private lazy var searchTextField: UISearchTextField = {
        let searchTextField = UISearchTextField()
        searchTextField.backgroundColor = .ypGray
        searchTextField.textColor = .ypBlack
        searchTextField.tintColor = .ypBlack
        searchTextField.font = .ritmoRegular(17)
        searchTextField.layer.cornerRadius = 18
        searchTextField.layer.masksToBounds = true
        searchTextField.borderStyle = .none
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.ypLightGray,
            .font: UIFont.ritmoRegular(15)
        ]
        let searchTextFieldText = NSLocalizedString("searchBar", comment: "Строка поиска")
        searchTextField.attributedPlaceholder = NSAttributedString(string: searchTextFieldText, attributes: attributes)
        searchTextField.clearButtonMode = .never
        searchTextField.heightAnchor.constraint(equalToConstant: 56).isActive = true
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
        let placeholderText = NSLocalizedString("emptyState.title", comment: "Заглушка если трекеров нет")
        placeholderLabel.text = placeholderText
        placeholderLabel.font = .ritmoMedium(12)
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
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidCreateRitmo), name: Notification.Name("DidCreateRitmo"), object: nil)
        ritmoCategoryStore.delegate = self
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
        updateCollectionViewBottomInset()
    }
    
    // MARK: -  Setup UI
    
    private func setupUI() {
        
        [
            addRitmoButton,
            dateButton,
            ritmoLabel,
            ritmoSubtitleLabel,
            searchStackView,
            filterChipScrollView,
            collectionView,
            placeholderStackView
        ].forEach{
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([

            addRitmoButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            addRitmoButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            addRitmoButton.heightAnchor.constraint(equalToConstant: 48),
            addRitmoButton.widthAnchor.constraint(equalToConstant: 48),

            dateButton.centerYAnchor.constraint(equalTo: addRitmoButton.centerYAnchor),
            dateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            dateButton.heightAnchor.constraint(equalToConstant: 44),
            dateButton.widthAnchor.constraint(equalToConstant: 112),
            
            ritmoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            ritmoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            ritmoLabel.topAnchor.constraint(equalTo: addRitmoButton.bottomAnchor, constant: 12),

            ritmoSubtitleLabel.topAnchor.constraint(equalTo: ritmoLabel.bottomAnchor, constant: 6),
            ritmoSubtitleLabel.leadingAnchor.constraint(equalTo: ritmoLabel.leadingAnchor),
            ritmoSubtitleLabel.trailingAnchor.constraint(equalTo: ritmoLabel.trailingAnchor),

            searchStackView.topAnchor.constraint(equalTo: ritmoSubtitleLabel.bottomAnchor, constant: 20),
            searchStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            searchStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),

            filterChipScrollView.topAnchor.constraint(equalTo: searchStackView.bottomAnchor, constant: 14),
            filterChipScrollView.leadingAnchor.constraint(equalTo: searchStackView.leadingAnchor),
            filterChipScrollView.trailingAnchor.constraint(equalTo: searchStackView.trailingAnchor),
            filterChipScrollView.heightAnchor.constraint(equalToConstant: 38),

            placeholderImage.heightAnchor.constraint(equalToConstant: 80),
            placeholderImage.widthAnchor.constraint(equalToConstant: 80),
            placeholderLabel.widthAnchor.constraint(lessThanOrEqualTo: collectionView.widthAnchor, constant: -40),
            placeholderStackView.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            placeholderStackView.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            collectionView.topAnchor.constraint(equalTo: filterChipScrollView.bottomAnchor, constant: 6),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
            
        ])
    }
    
    private func setupNavigationItem(){
        let image = UIImage(named: "addRitmo")
        let barButton = UIBarButtonItem(
            image: image,
            style: .plain,
            target: self,
            action: #selector(createRitmoOrHabit)
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
        button.titleLabel?.font = .ritmoBold(16)
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

    private func updateRitmoSubtitle() {
        let count = visibleCategories.reduce(0) { $0 + $1.ritmos.count }
        ritmoSubtitleLabel.text = "\(count) \(habitWord(for: count)) сегодня"
    }

    private func habitWord(for count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100

        if remainder10 == 1 && remainder100 != 11 {
            return "привычка"
        } else if remainder10 >= 2 && remainder10 <= 4 && (remainder100 < 10 || remainder100 >= 20) {
            return "привычки"
        } else {
            return "привычек"
        }
    }
    
    private func showPlaceholder() {
        let hasAnyRitmos = categories.contains { !$0.ritmos.isEmpty }

        if !hasAnyRitmos {
            placeholderStackView.isHidden = false
            placeholderImage.image = UIImage(named: "placeholder")
            placeholderLabel.text = NSLocalizedString("emptyState.title", comment: "Заглушка если трекеров совсем нет")
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

    @objc private func notCompletedFilterChipDidTap() {
        selectedFilter = .notCompleted
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
    
    @objc private func handleDidCreateRitmo() {
        reloadData()
        collectionView.register(SupplementaryView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        collectionView.reloadData()
        showPlaceholder()
    }
    
    @objc private func datePickerValueChanged() {
        currentDate = datePicker.date
        updateDateButtonTitle()

        reloadVisibleCategories()
        collectionView.reloadData()
    }
    
    @objc private func createRitmoOrHabit(){
        let createRitmoVC = NewHabitOrEventViewController()
        createRitmoVC.delegate = self
        createRitmoVC.selectedEventDate = datePicker.date
        present(createRitmoVC, animated: true)
        AnalyticsService.shared.report(event: "click", screen: "Main", item: "add_track")
    }
    
    // MARK: - Private Methods Filters
    
    private func ritmoPassesAllFilters(_ ritmo: Ritmo, on date: Date, searchText: String) -> Bool {
        let calendar = Calendar.current
        
        let textCondition = searchText.isEmpty || ritmo.name.lowercased().contains(searchText.lowercased())
        
        let dateCondition: Bool
        if isRitmoPostponedFrom(ritmo, on: date) {
            dateCondition = false
        } else if isRitmoPostponedTo(ritmo, on: date) {
            dateCondition = true
        } else if ritmo.isHabit {
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            dateCondition = ritmo.schedule.contains { $0.numberValue == adjustedWeekday }
        } else {
            if let record = completedRitmos.first(where: { $0.ritmoID == ritmo.id }) {
                dateCondition = calendar.isDate(record.date, inSameDayAs: date)
            } else {
                dateCondition = calendar.isDate(effectiveDateForIncompleteEvent(ritmo), inSameDayAs: date)
            }
        }
        
        let filterCondition: Bool
        switch selectedFilter {
        case .habits:
            filterCondition = ritmo.isHabit
        case .events:
            filterCondition = !ritmo.isHabit
        case .notCompleted:
            filterCondition = !isRitmoCompleted(ritmo, on: date)
        case .all:
            filterCondition = true
        }
        return textCondition && dateCondition && filterCondition
    }
    
    private func reloadVisibleCategories() {
        guard let currentDate = currentDate else { return }

        let searchText = (searchTextField.text ?? "").lowercased()

        let pinnedFilteredRitmos = pinnedRitmos.filter {
            ritmoPassesAllFilters($0, on: currentDate, searchText: searchText)
        }
        visibleCategories = []

        if !pinnedFilteredRitmos.isEmpty {
            visibleCategories.append(RitmoCategory(title: "Закрепленные", ritmos: pinnedFilteredRitmos))
        }

        let otherCategories = filteredCategories.compactMap { category -> RitmoCategory? in
            let ritmos = category.ritmos.filter { ritmo in
                !pinnedRitmos.contains(where: { $0.id == ritmo.id }) &&
                ritmoPassesAllFilters(ritmo, on: currentDate, searchText: searchText)
            }
            return ritmos.isEmpty ? nil : RitmoCategory(title: category.title, ritmos: ritmos)
        }

        visibleCategories.append(contentsOf: otherCategories)

        collectionView.reloadData()
        updateRitmoSubtitle()
        updateFilterChips()
        showPlaceholder()
    }

    
    private func isRitmoActiveOnDate(_ ritmo: Ritmo, date: Date) -> Bool {
        let calendar = Calendar.current

        if isRitmoPostponedFrom(ritmo, on: date) {
            return false
        }

        if isRitmoPostponedTo(ritmo, on: date) {
            return true
        }

        if ritmo.isHabit {
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            return ritmo.schedule.contains { $0.numberValue == adjustedWeekday }
        } else {
            if let record = completedRitmos.first(where: { $0.ritmoID == ritmo.id }) {
                return calendar.isDate(record.date, inSameDayAs: date)
            }

            return calendar.isDate(effectiveDateForIncompleteEvent(ritmo), inSameDayAs: date)
        }
    }

    private func effectiveDateForIncompleteEvent(_ ritmo: Ritmo) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let eventDate = calendar.startOfDay(for: ritmo.eventDate ?? today)

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

    private func updateCollectionViewBottomInset() {
        let bottomInset = hiddenFilterBottomInset
        guard collectionView.contentInset.bottom != bottomInset else {
            return
        }

        collectionView.contentInset.bottom = bottomInset
        collectionView.verticalScrollIndicatorInsets.bottom = bottomInset
    }
    
    private func savePinnedRitmos() {
        let pinnedIDs = pinnedRitmos.map { $0.id.uuidString }
        UserDefaults.standard.set(pinnedIDs, forKey: pinnedRitmosKey)
    }
    
    private func loadPinnedRitmos() {
        guard let pinnedIDs = UserDefaults.standard.array(forKey: pinnedRitmosKey) as? [String] else {
            pinnedRitmos = []
            return
        }
        
        pinnedRitmos = ritmos.filter { pinnedIDs.contains($0.id.uuidString) }
    }
    
    private func reloadData(){
        ritmos = ritmoStore.fetchRitmos().filter { !$0.isArchived }
        categories = activeCategories(from: ritmoCategoryStore.fetchCategories())
        filteredCategories = categories
        completedRitmos = ritmoRecordStore.fetch()
        refreshReminders()
        loadPinnedRitmos()
        datePickerValueChanged()
        reloadVisibleCategories()
        showPlaceholder()
    }

    private func refreshReminders() {
        ritmos.forEach {
            ReminderNotificationService.shared.scheduleReminder(
                for: $0,
                completedRecords: completedRitmos
            )
        }
        scheduleSoftRemindersForToday()
        updateTodayWidgetSnapshot()
    }

    private func scheduleSoftRemindersForToday() {
        ritmos.forEach {
            ReminderNotificationService.shared.scheduleSoftReminderIfNeeded(
                for: $0,
                completedRecords: completedRitmos
            )
        }
    }

    private func activeCategories(from categories: [RitmoCategory]) -> [RitmoCategory] {
        categories.compactMap { category in
            let activeRitmos = category.ritmos.filter { !$0.isArchived }
            return activeRitmos.isEmpty ? nil : RitmoCategory(title: category.title, ritmos: activeRitmos)
        }
    }

    private func updateTodayWidgetSnapshot() {
        RitmoWidgetSnapshotService.shared.saveTodaySnapshot(
            ritmos: ritmos,
            completedRecords: completedRitmos
        )
    }
    
    private func isRitmoCompletedToday(id:UUID) -> Bool {
        
        completedRitmos.contains { ritmoRecord in
            let isSameDay = Calendar.current.isDate(ritmoRecord.date, inSameDayAs: datePicker.date)
            return ritmoRecord.ritmoID == id && isSameDay
        }
    }
    
    private func isRitmoCompleted(_ ritmo: Ritmo, on date: Date) -> Bool {
        let calendar = Calendar.current
        return completedRitmos.contains {
            $0.ritmoID == ritmo.id && calendar.isDate($0.date, inSameDayAs: date)
        }
    }
    
    private func openEditScreen(with ritmo: Ritmo) {
        let editVC = NewHabitOrEventViewController()
        editVC.isEditingRitmo = true
        editVC.ritmoToEdit = ritmo
        
        editVC.isHabit = ritmo.isHabit
        self.present(editVC, animated: true)
    }
    
    // MARK: - UIContextMenu Methods
    
    private func deleteRitmo(at indexPath: IndexPath) {
        let visualRitmo = visibleCategories[indexPath.section].ritmos[indexPath.item]

        guard let ritmoToDelete = ritmoStore.ritmo(with: visualRitmo.id) else {
            print("Не найден трекер в базе")
            return
        }

        if let pinnedIndex = pinnedRitmos.firstIndex(where: { $0.id == ritmoToDelete.id }) {
            pinnedRitmos.remove(at: pinnedIndex)
            savePinnedRitmos()
        }

        ritmoStore.deleteRitmo(ritmoToDelete)

        ritmos = ritmoStore.fetchRitmos().filter { !$0.isArchived }
        categories = activeCategories(from: ritmoCategoryStore.fetchCategories())
        filteredCategories = categories
        reloadVisibleCategories()
        collectionView.reloadData()
        showPlaceholder()
    }

    private func archiveRitmo(_ ritmo: Ritmo) {
        ritmoStore.setArchived(true, ritmo: ritmo)

        if let pinnedIndex = pinnedRitmos.firstIndex(where: { $0.id == ritmo.id }) {
            pinnedRitmos.remove(at: pinnedIndex)
            savePinnedRitmos()
        }

        reloadData()
    }

    private func togglePinRitmo(_ ritmo: Ritmo) {
        if let index = pinnedRitmos.firstIndex(where: { $0.id == ritmo.id }) {
            pinnedRitmos.remove(at: index)
        } else {
            pinnedRitmos.append(ritmo)
        }
        savePinnedRitmos()
        reloadVisibleCategories()
    }

    private func showPostponeOptions(for ritmo: Ritmo) {
        let sourceDate = Calendar.current.startOfDay(for: datePicker.date)
        guard !isRitmoCompleted(ritmo, on: sourceDate) else {
            return
        }

        let alert = UIAlertController(
            title: NSLocalizedString("postpone.title", comment: "Postpone ritmo title"),
            message: nil,
            preferredStyle: .actionSheet
        )

        (1...7).forEach { dayOffset in
            guard let targetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: sourceDate) else {
                return
            }

            let title = postponeActionDateFormatter.string(from: targetDate)
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.postponeRitmo(ritmo, from: sourceDate, to: targetDate)
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

    private func postponeRitmo(_ ritmo: Ritmo, from sourceDate: Date, to targetDate: Date) {
        var postponements = loadPostponements()
        postponements[postponementKey(for: ritmo.id, date: sourceDate)] = dateKey(for: targetDate)
        UserDefaults.standard.set(postponements, forKey: postponedRitmosKey)

        if ritmo.isHabit {
            ReminderNotificationService.shared.removeReminder(for: ritmo.id, on: sourceDate)
        } else {
            ReminderNotificationService.shared.removeReminder(for: ritmo.id)
        }

        reloadVisibleCategories()
        updateTodayWidgetSnapshot()
    }

    private func loadPostponements() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: postponedRitmosKey) as? [String: String] ?? [:]
    }

    private func isRitmoPostponedFrom(_ ritmo: Ritmo, on date: Date) -> Bool {
        loadPostponements()[postponementKey(for: ritmo.id, date: date)] != nil
    }

    private func isRitmoPostponedTo(_ ritmo: Ritmo, on date: Date) -> Bool {
        let targetDateKey = dateKey(for: date)
        let ritmoPrefix = "\(ritmo.id.uuidString)_"
        return loadPostponements().contains { key, value in
            key.hasPrefix(ritmoPrefix) && value == targetDateKey
        }
    }

    private func postponementKey(for ritmoID: UUID, date: Date) -> String {
        "\(ritmoID.uuidString)_\(dateKey(for: date))"
    }

    private func dateKey(for date: Date) -> String {
        postponeStorageDateFormatter.string(from: Calendar.current.startOfDay(for: date))
    }
    
    private func showDeleteConfirmation(for ritmo: Ritmo, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "",
            message: NSLocalizedString("delete.confirmation", comment: "Delete ritmo confirmation"),
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel action"), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("delete", comment: "Delete action"), style: .destructive) { _ in
            self.deleteRitmo(at: indexPath)
            AnalyticsService.shared.report(event: "click", screen: "Main", item: "delete")
        })
        present(alert, animated: true)
    }
}

// MARK: - Extension: UICollectionViewDelegate

extension RitmosViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let visualRitmo = visibleCategories[indexPath.section].ritmos[indexPath.item]

        guard let ritmo = ritmoStore.ritmo(with: visualRitmo.id) else {
            return
        }
        guard ritmo.isHabit else {
            return
        }

        let historyVC = RitmoHistoryViewController(ritmo: ritmo, records: completedRitmos)
        present(historyVC, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        let visualRitmo = visibleCategories[indexPath.section].ritmos[indexPath.item]
  
        guard let ritmo = ritmoStore.ritmo(with: visualRitmo.id) else {
            print("Не найден трекер в базе")
            return nil
        }

        let completedDays = completedRitmos.filter { $0.ritmoID == ritmo.id }.count

        guard let ritmoCategory = ritmoCategoryStore.loadCategories().first(where: { category in
            category.ritmos.contains(where: { $0.id == ritmo.id })
        }) else {
            print("Категория трекера не найдена")
            return nil
        }

        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
            let editAction = UIAction(title: NSLocalizedString("edit", comment: "Edit ritmo action")) { [weak self] _ in
                let editVC = NewHabitOrEventViewController()
                editVC.isEditingRitmo = true
                editVC.ritmoToEdit = ritmo
                editVC.completedDays = completedDays
                editVC.isHabit = ritmo.isHabit
                editVC.ritmoCategoryToEdit = ritmoCategory

                self?.present(editVC, animated: true)
                AnalyticsService.shared.report(event: "click", screen: "Main", item: "edit")
            }

            let deleteAction = UIAction(title: NSLocalizedString("delete", comment: "Delete ritmo action"), attributes: .destructive) { [weak self] _ in
                self?.showDeleteConfirmation(for: ritmo, at: indexPath)
            }

            let archiveAction = UIAction(title: NSLocalizedString("archiveRitmo", comment: "Archive ritmo action")) { [weak self] _ in
                self?.archiveRitmo(ritmo)
            }

            let isCompletedOnSelectedDate = self.isRitmoCompleted(ritmo, on: self.datePicker.date)
            let postponeAttributes: UIMenuElement.Attributes = isCompletedOnSelectedDate ? .disabled : []
            let postponeAction = UIAction(
                title: NSLocalizedString("postponeRitmo", comment: "Postpone ritmo action"),
                attributes: postponeAttributes
            ) { [weak self] _ in
                self?.showPostponeOptions(for: ritmo)
            }

            let isPinned = self.pinnedRitmos.contains { $0.id == ritmo.id }
            let pinTitle = isPinned
                ? NSLocalizedString("unpinRitmo", comment: "Unpin ritmo action")
                : NSLocalizedString("pinRitmo", comment: "Pin ritmo action")
            let pinAction = UIAction(title: pinTitle) { [weak self] _ in
                self?.togglePinRitmo(ritmo)
            }

            return UIMenu(title: "", children: [pinAction, postponeAction, editAction, archiveAction, deleteAction])
        }
    }

    
    func collectionView(_ collectionView: UICollectionView,
                        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath,
              let cell = collectionView.cellForItem(at: indexPath) as? RitmoCell else {
            return nil
        }
        return UITargetedPreview(view: cell.ritmoCardView)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath,
              let cell = collectionView.cellForItem(at: indexPath) as? RitmoCell else {
            return nil
        }
        return UITargetedPreview(view: cell.ritmoCardView)
    }
    
    
}
// MARK: - Extension: UICollectionViewDataSource

extension RitmosViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return visibleCategories.isEmpty ? 0: visibleCategories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return visibleCategories[section].ritmos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RitmoCell.ritmoCellIdentifier, for: indexPath) as? RitmoCell else {
            return UICollectionViewCell()
        }
        let ritmo = visibleCategories[indexPath.section].ritmos[indexPath.item]
        cell.delegate = self
        let isCompletedToday = isRitmoCompletedToday(id: ritmo.id)
        let completedDays = completedRitmos.filter { $0.ritmoID == ritmo.id}.count
        let isPinned = pinnedRitmos.contains { $0.id == ritmo.id }
        cell.configureCell(ritmo: ritmo, isCompletedToday: isCompletedToday, completedDays: completedDays, indexPath: indexPath, isPinned: isPinned)
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
            
            header.configure(text: category.title, count: category.ritmos.count)
            return header
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: view.frame.width, height: 36)
    }
}

// MARK: - Extension: UITextFieldDelegate

extension RitmosViewController: UITextFieldDelegate{
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchTextField.resignFirstResponder()
        reloadVisibleCategories()
        return true
    }
}

// MARK: - Extension: RitmoCellDelegate

extension RitmosViewController: RitmoCellDelegate {
    func completeRitmo(id: UUID, at indexPath: IndexPath) {
        guard datePicker.date <= Date() else {
            return
        }
        
        let ritmoRecord = RitmoRecord(ritmoID: id, date: datePicker.date)
        do {
            try ritmoRecordStore.add(ritmoRecord: ritmoRecord)
            completedRitmos.append(ritmoRecord)
            if let ritmo = ritmoStore.ritmo(with: id) {
                if ritmo.isHabit {
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
            print("Failed to add ritmo record: \(error)")
        }
    }
    
    
    func uncompletedRitmo(id: UUID, at indexPath: IndexPath) {
        completedRitmos.removeAll { ritmoRecord in
            let isSameDay = Calendar.current.isDate(ritmoRecord.date, inSameDayAs: datePicker.date)
            let shouldRemove = ritmoRecord.ritmoID == id && isSameDay

            if shouldRemove {
                do {
                    try ritmoRecordStore.delete(ritmoRecord: ritmoRecord)
                } catch {
                    print("Failed to delete ritmo record: \(error)")
                }
            }
            return shouldRemove
        }

        if let ritmo = ritmoStore.ritmo(with: id) {
            if ritmo.isHabit {
                ReminderNotificationService.shared.scheduleReminder(
                    for: ritmo,
                    completedRecords: completedRitmos
                )
                ReminderNotificationService.shared.scheduleSoftReminderIfNeeded(
                    for: ritmo,
                    completedRecords: completedRitmos,
                    date: datePicker.date
                )
                updateTodayWidgetSnapshot()
                collectionView.reloadItems(at: [indexPath])
            } else {
                ReminderNotificationService.shared.scheduleReminder(
                    for: ritmo,
                    completedRecords: completedRitmos
                )
                reloadVisibleCategories()
            }
        } else {
            collectionView.reloadItems(at: [indexPath])
        }
    }

}

// MARK: - Extension: NewHabitOrEventViewControllerDelegate

extension RitmosViewController: NewHabitOrEventViewControllerDelegate {
    func didCreateRitmoOrEvent(ritmo: Ritmo) {
        ritmos.append(ritmo)
        reloadData()
    }
}

// MARK: - Extension: UICollectionViewDelegateFlowLayout

extension RitmosViewController: UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let itemCount: CGFloat = 2
        let space: CGFloat = 14
        let width: CGFloat = (collectionView.bounds.width - space - 40) / itemCount
        let height: CGFloat = 156
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 14
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 14
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 6, left: 20, bottom: 12, right: 20)
    }
}

// MARK: - Extension: RitmosStoresDelegates

extension RitmosViewController: RitmoStoreDelegate, RitmoRecordStoreDelegate, RitmoCategoryStoreDelegate {
    func didUpdate(_ update: RitmoStoreUpdate) {
        collectionView.performBatchUpdates {
            let insertedIndexPath = update.insertedIndexes.map { IndexPath(item: $0, section: $0) }
            let deletedIndexPath = update.deletedIndexes.map { IndexPath(item: $0, section: $0) }
            collectionView.insertItems(at: insertedIndexPath)
            collectionView.deleteItems(at: deletedIndexPath)
        }
    }
    
    func didUpdateRecords(_ update: RitmoCategoryStoreUpdate) {
        collectionView.performBatchUpdates {
            let insertedIndexPath = update.insertedIndexes.map { IndexPath(item: $0, section: $0) }
            let deletedIndexPath = update.deletedIndexes.map { IndexPath(item: $0, section: $0) }
            collectionView.insertItems(at: insertedIndexPath)
            collectionView.deleteItems(at: deletedIndexPath)
        }
    }
    
    func didUpdateCategories(_ update: RitmoCategoryStoreUpdate) {
        categories = ritmoCategoryStore.fetchCategories()
        filteredCategories = categories
        reloadVisibleCategories()
        collectionView.reloadData()
    }
}

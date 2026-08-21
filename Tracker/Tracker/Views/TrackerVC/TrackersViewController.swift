//
//  ViewController.swift
//  Tracker
//
//  Created by User on 20.03.2025.
//

import UIKit

class TrackersViewController: UIViewController {
    
    // MARK: - Private Properties
    
    private var trackers: [Tracker] = []
    private var tracker: Tracker?
    private var categories: [TrackerCategory] = []
    private var visibleCategories: [TrackerCategory] = []
    private var filteredCategories: [TrackerCategory] = []
    private var completedTrackers: [TrackerRecord] = []
    private var pinnedTrackers: [Tracker] = []
    private let pinnedTrackersKey = "pinnedTrackersIDs"
    private let postponedTrackersKey = "postponedTrackersByDate"
    private var currentDate: Date?
    private let trackerCategoryStore = TrackerCategoryStore()
    private let trackerStore = TrackerStore()
    private let trackerRecordStore = TrackerRecordStore()
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

    private lazy var addTrackerButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .ypWhite
        button.tintColor = .ypBlack
        button.layer.cornerRadius = 24
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 16
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.addTarget(self, action: #selector(createTrackerOrHabit), for: .touchUpInside)
        return button
    }()

    private lazy var dateButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .ypWhite
        button.tintColor = .ypBlack
        button.setTitleColor(.ypBlack, for: .normal)
        button.titleLabel?.font = .trackerBold(17)
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
    
    private lazy var trackerLabel: UILabel = {
        let label = UILabel()
        let labelText = NSLocalizedString("trackers.title", comment: "Заголовок на главном экране трекеров")
        label.text = labelText
        label.font = .trackerBold(32)
        label.textColor = .ypBlack
        return label
    }()

    private lazy var trackerSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .trackerMedium(17)
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
        collectionView.register(TrackerCell.self, forCellWithReuseIdentifier: TrackerCell.trackerCellIdentifier)
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
        title: NSLocalizedString("uncompletedTrackers", comment: ""),
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
        searchTextField.font = .trackerRegular(17)
        searchTextField.layer.cornerRadius = 18
        searchTextField.layer.masksToBounds = true
        searchTextField.borderStyle = .none
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.ypLightGray,
            .font: UIFont.trackerRegular(15)
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
        placeholderLabel.font = .trackerMedium(12)
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
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidCreateTracker), name: Notification.Name("DidCreateTracker"), object: nil)
        trackerCategoryStore.delegate = self
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
            addTrackerButton,
            dateButton,
            trackerLabel,
            trackerSubtitleLabel,
            searchStackView,
            filterChipScrollView,
            collectionView,
            placeholderStackView
        ].forEach{
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([

            addTrackerButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            addTrackerButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            addTrackerButton.heightAnchor.constraint(equalToConstant: 48),
            addTrackerButton.widthAnchor.constraint(equalToConstant: 48),

            dateButton.centerYAnchor.constraint(equalTo: addTrackerButton.centerYAnchor),
            dateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            dateButton.heightAnchor.constraint(equalToConstant: 44),
            dateButton.widthAnchor.constraint(equalToConstant: 112),
            
            trackerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            trackerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            trackerLabel.topAnchor.constraint(equalTo: addTrackerButton.bottomAnchor, constant: 12),

            trackerSubtitleLabel.topAnchor.constraint(equalTo: trackerLabel.bottomAnchor, constant: 6),
            trackerSubtitleLabel.leadingAnchor.constraint(equalTo: trackerLabel.leadingAnchor),
            trackerSubtitleLabel.trailingAnchor.constraint(equalTo: trackerLabel.trailingAnchor),

            searchStackView.topAnchor.constraint(equalTo: trackerSubtitleLabel.bottomAnchor, constant: 20),
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
        let image = UIImage(named: "addTracker")
        let barButton = UIBarButtonItem(
            image: image,
            style: .plain,
            target: self,
            action: #selector(createTrackerOrHabit)
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
        button.titleLabel?.font = .trackerBold(16)
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

    private func updateTrackerSubtitle() {
        let count = visibleCategories.reduce(0) { $0 + $1.trackers.count }
        trackerSubtitleLabel.text = "\(count) \(habitWord(for: count)) сегодня"
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
        let hasAnyTrackers = categories.contains { !$0.trackers.isEmpty }

        if !hasAnyTrackers {
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
    
    @objc private func handleDidCreateTracker() {
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
    
    @objc private func createTrackerOrHabit(){
        let createTrackerVC = NewHabitOrEventViewController()
        createTrackerVC.delegate = self
        createTrackerVC.selectedEventDate = datePicker.date
        present(createTrackerVC, animated: true)
        AnalyticsService.shared.report(event: "click", screen: "Main", item: "add_track")
    }
    
    // MARK: - Private Methods Filters
    
    private func trackerPassesAllFilters(_ tracker: Tracker, on date: Date, searchText: String) -> Bool {
        let calendar = Calendar.current
        
        let textCondition = searchText.isEmpty || tracker.name.lowercased().contains(searchText.lowercased())
        
        let dateCondition: Bool
        if isTrackerPostponedFrom(tracker, on: date) {
            dateCondition = false
        } else if isTrackerPostponedTo(tracker, on: date) {
            dateCondition = true
        } else if tracker.isHabit {
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            dateCondition = tracker.schedule.contains { $0.numberValue == adjustedWeekday }
        } else {
            if let record = completedTrackers.first(where: { $0.trackerID == tracker.id }) {
                dateCondition = calendar.isDate(record.date, inSameDayAs: date)
            } else {
                dateCondition = calendar.isDate(effectiveDateForIncompleteEvent(tracker), inSameDayAs: date)
            }
        }
        
        let filterCondition: Bool
        switch selectedFilter {
        case .habits:
            filterCondition = tracker.isHabit
        case .events:
            filterCondition = !tracker.isHabit
        case .notCompleted:
            filterCondition = !isTrackerCompleted(tracker, on: date)
        case .all:
            filterCondition = true
        }
        return textCondition && dateCondition && filterCondition
    }
    
    private func reloadVisibleCategories() {
        guard let currentDate = currentDate else { return }

        let searchText = (searchTextField.text ?? "").lowercased()

        let pinnedFilteredTrackers = pinnedTrackers.filter {
            trackerPassesAllFilters($0, on: currentDate, searchText: searchText)
        }
        visibleCategories = []

        if !pinnedFilteredTrackers.isEmpty {
            visibleCategories.append(TrackerCategory(title: "Закрепленные", trackers: pinnedFilteredTrackers))
        }

        let otherCategories = filteredCategories.compactMap { category -> TrackerCategory? in
            let trackers = category.trackers.filter { tracker in
                !pinnedTrackers.contains(where: { $0.id == tracker.id }) &&
                trackerPassesAllFilters(tracker, on: currentDate, searchText: searchText)
            }
            return trackers.isEmpty ? nil : TrackerCategory(title: category.title, trackers: trackers)
        }

        visibleCategories.append(contentsOf: otherCategories)

        collectionView.reloadData()
        updateTrackerSubtitle()
        updateFilterChips()
        showPlaceholder()
    }

    
    private func isTrackerActiveOnDate(_ tracker: Tracker, date: Date) -> Bool {
        let calendar = Calendar.current

        if isTrackerPostponedFrom(tracker, on: date) {
            return false
        }

        if isTrackerPostponedTo(tracker, on: date) {
            return true
        }

        if tracker.isHabit {
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            return tracker.schedule.contains { $0.numberValue == adjustedWeekday }
        } else {
            if let record = completedTrackers.first(where: { $0.trackerID == tracker.id }) {
                return calendar.isDate(record.date, inSameDayAs: date)
            }

            return calendar.isDate(effectiveDateForIncompleteEvent(tracker), inSameDayAs: date)
        }
    }

    private func effectiveDateForIncompleteEvent(_ tracker: Tracker) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let eventDate = calendar.startOfDay(for: tracker.eventDate ?? today)

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
    
    private func savePinnedTrackers() {
        let pinnedIDs = pinnedTrackers.map { $0.id.uuidString }
        UserDefaults.standard.set(pinnedIDs, forKey: pinnedTrackersKey)
    }
    
    private func loadPinnedTrackers() {
        guard let pinnedIDs = UserDefaults.standard.array(forKey: pinnedTrackersKey) as? [String] else {
            pinnedTrackers = []
            return
        }
        
        pinnedTrackers = trackers.filter { pinnedIDs.contains($0.id.uuidString) }
    }
    
    private func reloadData(){
        trackers = trackerStore.fetchTrackers().filter { !$0.isArchived }
        categories = activeCategories(from: trackerCategoryStore.fetchCategories())
        filteredCategories = categories
        completedTrackers = trackerRecordStore.fetch()
        refreshReminders()
        loadPinnedTrackers()
        datePickerValueChanged()
        reloadVisibleCategories()
        showPlaceholder()
    }

    private func refreshReminders() {
        trackers.forEach {
            ReminderNotificationService.shared.scheduleReminder(
                for: $0,
                completedRecords: completedTrackers
            )
        }
        scheduleSoftRemindersForToday()
        updateTodayWidgetSnapshot()
    }

    private func scheduleSoftRemindersForToday() {
        trackers.forEach {
            ReminderNotificationService.shared.scheduleSoftReminderIfNeeded(
                for: $0,
                completedRecords: completedTrackers
            )
        }
    }

    private func activeCategories(from categories: [TrackerCategory]) -> [TrackerCategory] {
        categories.compactMap { category in
            let activeTrackers = category.trackers.filter { !$0.isArchived }
            return activeTrackers.isEmpty ? nil : TrackerCategory(title: category.title, trackers: activeTrackers)
        }
    }

    private func updateTodayWidgetSnapshot() {
        TrackerWidgetSnapshotService.shared.saveTodaySnapshot(
            trackers: trackers,
            completedRecords: completedTrackers
        )
    }
    
    private func isTrackerCompletedToday(id:UUID) -> Bool {
        
        completedTrackers.contains { trackerRecord in
            let isSameDay = Calendar.current.isDate(trackerRecord.date, inSameDayAs: datePicker.date)
            return trackerRecord.trackerID == id && isSameDay
        }
    }
    
    private func isTrackerCompleted(_ tracker: Tracker, on date: Date) -> Bool {
        let calendar = Calendar.current
        return completedTrackers.contains {
            $0.trackerID == tracker.id && calendar.isDate($0.date, inSameDayAs: date)
        }
    }
    
    private func openEditScreen(with tracker: Tracker) {
        let editVC = NewHabitOrEventViewController()
        editVC.isEditingTracker = true
        editVC.trackerToEdit = tracker
        
        editVC.isHabit = tracker.isHabit
        self.present(editVC, animated: true)
    }
    
    // MARK: - UIContextMenu Methods
    
    private func deleteTracker(at indexPath: IndexPath) {
        let visualTracker = visibleCategories[indexPath.section].trackers[indexPath.item]

        guard let trackerToDelete = trackerStore.tracker(with: visualTracker.id) else {
            print("Не найден трекер в базе")
            return
        }

        if let pinnedIndex = pinnedTrackers.firstIndex(where: { $0.id == trackerToDelete.id }) {
            pinnedTrackers.remove(at: pinnedIndex)
            savePinnedTrackers()
        }

        trackerStore.deleteTracker(trackerToDelete)

        trackers = trackerStore.fetchTrackers().filter { !$0.isArchived }
        categories = activeCategories(from: trackerCategoryStore.fetchCategories())
        filteredCategories = categories
        reloadVisibleCategories()
        collectionView.reloadData()
        showPlaceholder()
    }

    private func archiveTracker(_ tracker: Tracker) {
        trackerStore.setArchived(true, tracker: tracker)

        if let pinnedIndex = pinnedTrackers.firstIndex(where: { $0.id == tracker.id }) {
            pinnedTrackers.remove(at: pinnedIndex)
            savePinnedTrackers()
        }

        reloadData()
    }

    private func togglePinTracker(_ tracker: Tracker) {
        if let index = pinnedTrackers.firstIndex(where: { $0.id == tracker.id }) {
            pinnedTrackers.remove(at: index)
        } else {
            pinnedTrackers.append(tracker)
        }
        savePinnedTrackers()
        reloadVisibleCategories()
    }

    private func showPostponeOptions(for tracker: Tracker) {
        let sourceDate = Calendar.current.startOfDay(for: datePicker.date)
        guard !isTrackerCompleted(tracker, on: sourceDate) else {
            return
        }

        let alert = UIAlertController(
            title: NSLocalizedString("postpone.title", comment: "Postpone tracker title"),
            message: nil,
            preferredStyle: .actionSheet
        )

        (1...7).forEach { dayOffset in
            guard let targetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: sourceDate) else {
                return
            }

            let title = postponeActionDateFormatter.string(from: targetDate)
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.postponeTracker(tracker, from: sourceDate, to: targetDate)
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

    private func postponeTracker(_ tracker: Tracker, from sourceDate: Date, to targetDate: Date) {
        var postponements = loadPostponements()
        postponements[postponementKey(for: tracker.id, date: sourceDate)] = dateKey(for: targetDate)
        UserDefaults.standard.set(postponements, forKey: postponedTrackersKey)

        if tracker.isHabit {
            ReminderNotificationService.shared.removeReminder(for: tracker.id, on: sourceDate)
        } else {
            ReminderNotificationService.shared.removeReminder(for: tracker.id)
        }

        reloadVisibleCategories()
        updateTodayWidgetSnapshot()
    }

    private func loadPostponements() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: postponedTrackersKey) as? [String: String] ?? [:]
    }

    private func isTrackerPostponedFrom(_ tracker: Tracker, on date: Date) -> Bool {
        loadPostponements()[postponementKey(for: tracker.id, date: date)] != nil
    }

    private func isTrackerPostponedTo(_ tracker: Tracker, on date: Date) -> Bool {
        let targetDateKey = dateKey(for: date)
        let trackerPrefix = "\(tracker.id.uuidString)_"
        return loadPostponements().contains { key, value in
            key.hasPrefix(trackerPrefix) && value == targetDateKey
        }
    }

    private func postponementKey(for trackerID: UUID, date: Date) -> String {
        "\(trackerID.uuidString)_\(dateKey(for: date))"
    }

    private func dateKey(for date: Date) -> String {
        postponeStorageDateFormatter.string(from: Calendar.current.startOfDay(for: date))
    }
    
    private func showDeleteConfirmation(for tracker: Tracker, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "",
            message: NSLocalizedString("delete.confirmation", comment: "Delete tracker confirmation"),
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel action"), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("delete", comment: "Delete action"), style: .destructive) { _ in
            self.deleteTracker(at: indexPath)
            AnalyticsService.shared.report(event: "click", screen: "Main", item: "delete")
        })
        present(alert, animated: true)
    }
}

// MARK: - Extension: UICollectionViewDelegate

extension TrackersViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let visualTracker = visibleCategories[indexPath.section].trackers[indexPath.item]

        guard let tracker = trackerStore.tracker(with: visualTracker.id) else {
            return
        }
        guard tracker.isHabit else {
            return
        }

        let historyVC = TrackerHistoryViewController(tracker: tracker, records: completedTrackers)
        present(historyVC, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        let visualTracker = visibleCategories[indexPath.section].trackers[indexPath.item]
  
        guard let tracker = trackerStore.tracker(with: visualTracker.id) else {
            print("Не найден трекер в базе")
            return nil
        }

        let completedDays = completedTrackers.filter { $0.trackerID == tracker.id }.count

        guard let trackerCategory = trackerCategoryStore.loadCategories().first(where: { category in
            category.trackers.contains(where: { $0.id == tracker.id })
        }) else {
            print("Категория трекера не найдена")
            return nil
        }

        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
            let editAction = UIAction(title: NSLocalizedString("edit", comment: "Edit tracker action")) { [weak self] _ in
                let editVC = NewHabitOrEventViewController()
                editVC.isEditingTracker = true
                editVC.trackerToEdit = tracker
                editVC.completedDays = completedDays
                editVC.isHabit = tracker.isHabit
                editVC.trackerCategoryToEdit = trackerCategory

                self?.present(editVC, animated: true)
                AnalyticsService.shared.report(event: "click", screen: "Main", item: "edit")
            }

            let deleteAction = UIAction(title: NSLocalizedString("delete", comment: "Delete tracker action"), attributes: .destructive) { [weak self] _ in
                self?.showDeleteConfirmation(for: tracker, at: indexPath)
            }

            let archiveAction = UIAction(title: NSLocalizedString("archiveTracker", comment: "Archive tracker action")) { [weak self] _ in
                self?.archiveTracker(tracker)
            }

            let isCompletedOnSelectedDate = self.isTrackerCompleted(tracker, on: self.datePicker.date)
            let postponeAttributes: UIMenuElement.Attributes = isCompletedOnSelectedDate ? .disabled : []
            let postponeAction = UIAction(
                title: NSLocalizedString("postponeTracker", comment: "Postpone tracker action"),
                attributes: postponeAttributes
            ) { [weak self] _ in
                self?.showPostponeOptions(for: tracker)
            }

            let isPinned = self.pinnedTrackers.contains { $0.id == tracker.id }
            let pinTitle = isPinned
                ? NSLocalizedString("unpinTracker", comment: "Unpin tracker action")
                : NSLocalizedString("pinTracker", comment: "Pin tracker action")
            let pinAction = UIAction(title: pinTitle) { [weak self] _ in
                self?.togglePinTracker(tracker)
            }

            return UIMenu(title: "", children: [pinAction, postponeAction, editAction, archiveAction, deleteAction])
        }
    }

    
    func collectionView(_ collectionView: UICollectionView,
                        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath,
              let cell = collectionView.cellForItem(at: indexPath) as? TrackerCell else {
            return nil
        }
        return UITargetedPreview(view: cell.trackerCardView)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath,
              let cell = collectionView.cellForItem(at: indexPath) as? TrackerCell else {
            return nil
        }
        return UITargetedPreview(view: cell.trackerCardView)
    }
    
    
}
// MARK: - Extension: UICollectionViewDataSource

extension TrackersViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return visibleCategories.isEmpty ? 0: visibleCategories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return visibleCategories[section].trackers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TrackerCell.trackerCellIdentifier, for: indexPath) as? TrackerCell else {
            return UICollectionViewCell()
        }
        let tracker = visibleCategories[indexPath.section].trackers[indexPath.item]
        cell.delegate = self
        let isCompletedToday = isTrackerCompletedToday(id: tracker.id)
        let completedDays = completedTrackers.filter { $0.trackerID == tracker.id}.count
        let isPinned = pinnedTrackers.contains { $0.id == tracker.id }
        cell.configureCell(tracker: tracker, isCompletedToday: isCompletedToday, completedDays: completedDays, indexPath: indexPath, isPinned: isPinned)
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
            
            header.configure(text: category.title, count: category.trackers.count)
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

extension TrackersViewController: UITextFieldDelegate{
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchTextField.resignFirstResponder()
        reloadVisibleCategories()
        return true
    }
}

// MARK: - Extension: TrackerCellDelegate

extension TrackersViewController: TrackerCellDelegate {
    func completeTracker(id: UUID, at indexPath: IndexPath) {
        guard datePicker.date <= Date() else {
            return
        }
        
        let trackerRecord = TrackerRecord(trackerID: id, date: datePicker.date)
        do {
            try trackerRecordStore.add(trackerRecord: trackerRecord)
            completedTrackers.append(trackerRecord)
            if let tracker = trackerStore.tracker(with: id) {
                if tracker.isHabit {
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
            print("Failed to add tracker record: \(error)")
        }
    }
    
    
    func uncompletedTracker(id: UUID, at indexPath: IndexPath) {
        completedTrackers.removeAll { trackerRecord in
            let isSameDay = Calendar.current.isDate(trackerRecord.date, inSameDayAs: datePicker.date)
            let shouldRemove = trackerRecord.trackerID == id && isSameDay

            if shouldRemove {
                do {
                    try trackerRecordStore.delete(trackerRecord: trackerRecord)
                } catch {
                    print("Failed to delete tracker record: \(error)")
                }
            }
            return shouldRemove
        }

        if let tracker = trackerStore.tracker(with: id) {
            if tracker.isHabit {
                ReminderNotificationService.shared.scheduleReminder(
                    for: tracker,
                    completedRecords: completedTrackers
                )
                ReminderNotificationService.shared.scheduleSoftReminderIfNeeded(
                    for: tracker,
                    completedRecords: completedTrackers,
                    date: datePicker.date
                )
                updateTodayWidgetSnapshot()
                collectionView.reloadItems(at: [indexPath])
            } else {
                ReminderNotificationService.shared.scheduleReminder(
                    for: tracker,
                    completedRecords: completedTrackers
                )
                reloadVisibleCategories()
            }
        } else {
            collectionView.reloadItems(at: [indexPath])
        }
    }

}

// MARK: - Extension: NewHabitOrEventViewControllerDelegate

extension TrackersViewController: NewHabitOrEventViewControllerDelegate {
    func didCreateTrackerOrEvent(tracker: Tracker) {
        trackers.append(tracker)
        reloadData()
    }
}

// MARK: - Extension: UICollectionViewDelegateFlowLayout

extension TrackersViewController: UICollectionViewDelegateFlowLayout{
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

// MARK: - Extension: TrackersStoresDelegates

extension TrackersViewController: TrackerStoreDelegate, TrackerRecordStoreDelegate, TrackerCategoryStoreDelegate {
    func didUpdate(_ update: TrackerStoreUpdate) {
        collectionView.performBatchUpdates {
            let insertedIndexPath = update.insertedIndexes.map { IndexPath(item: $0, section: $0) }
            let deletedIndexPath = update.deletedIndexes.map { IndexPath(item: $0, section: $0) }
            collectionView.insertItems(at: insertedIndexPath)
            collectionView.deleteItems(at: deletedIndexPath)
        }
    }
    
    func didUpdateRecords(_ update: TrackerCategoryStoreUpdate) {
        collectionView.performBatchUpdates {
            let insertedIndexPath = update.insertedIndexes.map { IndexPath(item: $0, section: $0) }
            let deletedIndexPath = update.deletedIndexes.map { IndexPath(item: $0, section: $0) }
            collectionView.insertItems(at: insertedIndexPath)
            collectionView.deleteItems(at: deletedIndexPath)
        }
    }
    
    func didUpdateCategories(_ update: TrackerCategoryStoreUpdate) {
        categories = trackerCategoryStore.fetchCategories()
        filteredCategories = categories
        reloadVisibleCategories()
        collectionView.reloadData()
    }
}

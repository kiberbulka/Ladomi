//
//  DayCalendarViewController.swift
//  Ritmo
//
//  Created by Codex on 12.08.2026.
//

import UIKit

final class DayCalendarViewController: UIViewController {
    private struct CalendarDay {
        let date: Date
        let isCurrentMonth: Bool
    }

    fileprivate struct DayActivity {
        let habitCount: Int
        let eventCount: Int
        let ritmoColors: [UIColor]

        var totalCount: Int {
            habitCount + eventCount
        }
    }

    fileprivate enum DayMood: String, CaseIterable, Hashable {
        case great
        case good
        case calm
        case tired
        case bad

        var emoji: String {
            switch self {
            case .great: return "🤩"
            case .good: return "🙂"
            case .calm: return "😌"
            case .tired: return "🥱"
            case .bad: return "😞"
            }
        }

        var title: String {
            NSLocalizedString("calendar.mood.\(rawValue)", comment: "Mood title")
        }
    }

    private final class MoodStore {
        private let storageKey = "ritmo.dayMoodByDate"
        private let userDefaults = UserDefaults.standard
        private var calendar: Calendar = {
            var calendar = Calendar.current
            calendar.firstWeekday = 2
            return calendar
        }()

        private lazy var dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()

        func mood(for date: Date) -> DayMood? {
            let moods = userDefaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
            guard let rawValue = moods[key(for: calendar.startOfDay(for: date))] else {
                return nil
            }

            return DayMood(rawValue: rawValue)
        }

        func setMood(_ mood: DayMood, for date: Date) {
            var moods = userDefaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
            moods[key(for: calendar.startOfDay(for: date))] = mood.rawValue
            userDefaults.set(moods, forKey: storageKey)
        }

        private func key(for date: Date) -> String {
            dateFormatter.string(from: date)
        }
    }

    private let ritmoStore = RitmoStore()
    private let ritmoRecordStore = RitmoRecordStore()
    private let moodStore = MoodStore()

    private var calendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }()
    private var displayedMonth = Date()
    private var selectedDate = Date()
    private var days: [CalendarDay] = []
    private var ritmoByID: [UUID: Ritmo] = [:]
    private var recordsByDate: [Date: [RitmoRecord]] = [:]
    private var moodButtons: [DayMood: UIButton] = [:]

    private lazy var monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter
    }()

    private lazy var dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("calendar.title", comment: "Calendar screen title")
        label.font = .ritmoBold(40)
        label.textColor = .ypBlack
        return label
    }()

    private lazy var previousMonthButton: UIButton = {
        makeMonthButton(systemName: "chevron.left", action: #selector(previousMonthDidTap))
    }()

    private lazy var nextMonthButton: UIButton = {
        makeMonthButton(systemName: "chevron.right", action: #selector(nextMonthDidTap))
    }()

    private lazy var monthLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoBold(22)
        label.textColor = .ypBlack
        label.textAlignment = .center
        return label
    }()

    private lazy var monthStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [previousMonthButton, monthLabel, nextMonthButton])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        return stackView
    }()

    private lazy var weekdaysStackView: UIStackView = {
        let labels = weekdaySymbols().map { symbol -> UILabel in
            let label = UILabel()
            label.text = symbol
            label.font = .ritmoMedium(13)
            label.textColor = .ypLightGray
            label.textAlignment = .center
            return label
        }

        let stackView = UIStackView(arrangedSubviews: labels)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        return stackView
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 4
        layout.minimumInteritemSpacing = 4
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .ypWhite
        collectionView.isScrollEnabled = false
        collectionView.register(DayCalendarCell.self, forCellWithReuseIdentifier: DayCalendarCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        return collectionView
    }()

    private lazy var detailView: UIView = {
        let view = UIView()
        view.backgroundColor = .ypGray
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var selectedDateLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoBold(18)
        label.textColor = .ypBlack
        label.numberOfLines = 1
        return label
    }()

    private lazy var summaryStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        return stackView
    }()

    private lazy var habitSummaryView = DaySummaryView(
        title: NSLocalizedString("calendar.habitsCompleted", comment: "Habits completed title")
    )

    private lazy var eventSummaryView = DaySummaryView(
        title: NSLocalizedString("calendar.eventsCompleted", comment: "Events completed title")
    )

    private lazy var totalSummaryView = DaySummaryView(
        title: NSLocalizedString("calendar.totalCompleted", comment: "Total completed title")
    )

    private lazy var moodTitleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("calendar.moodTitle", comment: "Mood selector title")
        label.font = .ritmoBold(16)
        label.textColor = .ypBlack
        return label
    }()

    private lazy var moodStackView: UIStackView = {
        let buttons = DayMood.allCases.map { mood -> UIButton in
            let button = UIButton(type: .system)
            button.setTitle(mood.emoji, for: .normal)
            button.titleLabel?.font = .ritmoRegular(22)
            button.backgroundColor = .ypWhite
            button.layer.cornerRadius = 18
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.clear.cgColor
            button.tag = DayMood.allCases.firstIndex(of: mood) ?? 0
            button.addTarget(self, action: #selector(moodButtonDidTap(_:)), for: .touchUpInside)
            moodButtons[mood] = button
            return button
        }

        let stackView = UIStackView(arrangedSubviews: buttons)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        return stackView
    }()

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private lazy var contentView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        selectedDate = startOfDay(for: selectedDate)
        displayedMonth = startOfDay(for: displayedMonth)
        view.backgroundColor = .ypWhite
        setupUI()
        reloadCalendar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadCalendar()
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        [titleLabel, monthStackView, weekdaysStackView, collectionView, detailView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        [selectedDateLabel, summaryStackView, moodTitleLabel, moodStackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            detailView.addSubview($0)
        }

        [habitSummaryView, eventSummaryView, totalSummaryView].forEach {
            summaryStackView.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 44),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),

            monthStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            monthStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            monthStackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 16),
            monthStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            monthStackView.heightAnchor.constraint(equalToConstant: 36),

            previousMonthButton.widthAnchor.constraint(equalToConstant: 36),
            previousMonthButton.heightAnchor.constraint(equalToConstant: 36),
            nextMonthButton.widthAnchor.constraint(equalToConstant: 36),
            nextMonthButton.heightAnchor.constraint(equalToConstant: 36),

            weekdaysStackView.topAnchor.constraint(equalTo: monthStackView.bottomAnchor, constant: 14),
            weekdaysStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            weekdaysStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            weekdaysStackView.heightAnchor.constraint(equalToConstant: 18),

            collectionView.topAnchor.constraint(equalTo: weekdaysStackView.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            collectionView.heightAnchor.constraint(equalToConstant: 344),

            detailView.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 20),
            detailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            detailView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            selectedDateLabel.topAnchor.constraint(equalTo: detailView.topAnchor, constant: 16),
            selectedDateLabel.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 16),
            selectedDateLabel.trailingAnchor.constraint(equalTo: detailView.trailingAnchor, constant: -16),

            summaryStackView.topAnchor.constraint(equalTo: selectedDateLabel.bottomAnchor, constant: 12),
            summaryStackView.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 12),
            summaryStackView.trailingAnchor.constraint(equalTo: detailView.trailingAnchor, constant: -12),
            summaryStackView.heightAnchor.constraint(equalToConstant: 58),

            moodTitleLabel.topAnchor.constraint(equalTo: summaryStackView.bottomAnchor, constant: 14),
            moodTitleLabel.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 16),
            moodTitleLabel.trailingAnchor.constraint(equalTo: detailView.trailingAnchor, constant: -16),

            moodStackView.topAnchor.constraint(equalTo: moodTitleLabel.bottomAnchor, constant: 10),
            moodStackView.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 12),
            moodStackView.trailingAnchor.constraint(equalTo: detailView.trailingAnchor, constant: -12),
            moodStackView.heightAnchor.constraint(equalToConstant: 36),
            moodStackView.bottomAnchor.constraint(equalTo: detailView.bottomAnchor, constant: -16)
        ])
    }

    private func reloadCalendar() {
        selectedDate = startOfDay(for: selectedDate)
        displayedMonth = startOfDay(for: displayedMonth)
        let ritmos = ritmoStore.fetchRitmos()
        ritmoByID = Dictionary(uniqueKeysWithValues: ritmos.map { ($0.id, $0) })
        recordsByDate = Dictionary(grouping: ritmoRecordStore.fetch()) { record in
            startOfDay(for: record.date)
        }
        days = makeDays(for: displayedMonth)
        updateMonthTitle()
        updateSelectedDayDetails()
        collectionView.reloadData()
    }

    private func updateMonthTitle() {
        monthLabel.text = monthFormatter.string(from: displayedMonth).capitalized
    }

    private func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func makeMonthButton(systemName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemName, withConfiguration: symbolConfiguration), for: .normal)
        button.tintColor = .ypBlack
        button.backgroundColor = .ypGray
        button.layer.cornerRadius = 18
        button.layer.masksToBounds = true
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.imageView?.contentMode = .scaleAspectFit
        button.adjustsImageWhenHighlighted = false
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeDays(for month: Date) -> [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            return []
        }

        let monthStart = startOfDay(for: monthInterval.start)
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingEmptyDays, to: monthStart) else {
            return []
        }

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }

            let isCurrentMonth = calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
            return CalendarDay(date: date, isCurrentMonth: isCurrentMonth)
        }
    }

    private func activity(for date: Date) -> DayActivity {
        let records = recordsByDate[startOfDay(for: date)] ?? []
        var habitCount = 0
        var eventCount = 0

        records.forEach { record in
            guard let ritmo = ritmoByID[record.ritmoID] else {
                return
            }

            if ritmo.isHabit {
                habitCount += 1
            } else {
                eventCount += 1
            }
        }

        let ritmoColors = records.compactMap { record in
            ritmoByID[record.ritmoID]?.color
        }

        return DayActivity(habitCount: habitCount, eventCount: eventCount, ritmoColors: ritmoColors)
    }

    private func updateSelectedDayDetails() {
        let selectedDay = startOfDay(for: selectedDate)
        let activity = activity(for: selectedDay)
        selectedDateLabel.text = dayFormatter.string(from: selectedDay)
        habitSummaryView.configure(value: activity.habitCount)
        eventSummaryView.configure(value: activity.eventCount)
        totalSummaryView.configure(value: activity.totalCount)
        updateMoodButtons()
    }

    private func updateMoodButtons() {
        let selectedDay = startOfDay(for: selectedDate)
        let canEditMood = !isFutureDate(selectedDay)
        let selectedMood = canEditMood ? moodStore.mood(for: selectedDay) : nil
        moodTitleLabel.text = canEditMood
            ? NSLocalizedString("calendar.moodTitle", comment: "Mood selector title")
            : NSLocalizedString("calendar.futureMoodTitle", comment: "Future mood disabled title")

        moodButtons.forEach { mood, button in
            let isSelected = mood == selectedMood
            button.backgroundColor = isSelected ? UIColor.ypBlue.withAlphaComponent(0.16) : .ypWhite
            button.layer.borderColor = isSelected ? UIColor.ypBlue.cgColor : UIColor.clear.cgColor
            button.isEnabled = canEditMood
            button.alpha = canEditMood ? 1 : 0.35
            button.accessibilityLabel = mood.title
        }
    }

    private func isFutureDate(_ date: Date) -> Bool {
        startOfDay(for: date) > startOfDay(for: Date())
    }

    private func weekdaySymbols() -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex]).map { $0.uppercased() }
    }

    @objc private func previousMonthDidTap() {
        guard let month = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else {
            return
        }

        displayedMonth = month
        selectedDate = startOfDay(for: month)
        reloadCalendar()
    }

    @objc private func nextMonthDidTap() {
        guard let month = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else {
            return
        }

        displayedMonth = month
        selectedDate = startOfDay(for: month)
        reloadCalendar()
    }

    @objc private func moodButtonDidTap(_ sender: UIButton) {
        guard DayMood.allCases.indices.contains(sender.tag) else {
            return
        }

        selectedDate = startOfDay(for: selectedDate)
        guard !isFutureDate(selectedDate) else {
            updateMoodButtons()
            return
        }

        let mood = DayMood.allCases[sender.tag]
        moodStore.setMood(mood, for: selectedDate)
        updateSelectedDayDetails()
        collectionView.reloadData()
    }
}

extension DayCalendarViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        days.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DayCalendarCell.reuseIdentifier,
            for: indexPath
        ) as? DayCalendarCell else {
            return UICollectionViewCell()
        }

        let day = days[indexPath.item]
        cell.configure(
            date: day.date,
            isCurrentMonth: day.isCurrentMonth,
            isToday: calendar.isDateInToday(day.date),
            isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
            activity: activity(for: day.date),
            mood: isFutureDate(day.date) ? nil : moodStore.mood(for: day.date)
        )
        return cell
    }
}

extension DayCalendarViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let day = days[indexPath.item]
        selectedDate = startOfDay(for: day.date)

        if !day.isCurrentMonth {
            displayedMonth = selectedDate
            days = makeDays(for: displayedMonth)
            updateMonthTitle()
        }

        updateSelectedDayDetails()
        collectionView.reloadData()
    }
}

extension DayCalendarViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = floor((collectionView.bounds.width - 24) / 7)
        return CGSize(width: width, height: 54)
    }
}

private final class DayCalendarCell: UICollectionViewCell {
    static let reuseIdentifier = "DayCalendarCell"

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoBold(14)
        label.textColor = .ypBlack
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private let moodLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoRegular(12)
        label.textAlignment = .right
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.85
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let dotsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 3
        return stackView
    }()

    private let moreCountLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoBold(10)
        label.textColor = .ypBlack
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .ypGray
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.clear.cgColor

        [dateLabel, moodLabel, dotsStackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 7),
            dateLabel.trailingAnchor.constraint(lessThanOrEqualTo: moodLabel.leadingAnchor, constant: -2),

            moodLabel.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor),
            moodLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),
            moodLabel.widthAnchor.constraint(equalToConstant: 16),

            dotsStackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 4),
            dotsStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -4),
            dotsStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dotsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -9),
            dotsStackView.heightAnchor.constraint(equalToConstant: 8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func configure(
        date: Date,
        isCurrentMonth: Bool,
        isToday: Bool,
        isSelected: Bool,
        activity: DayCalendarViewController.DayActivity,
        mood: DayCalendarViewController.DayMood?
    ) {
        let dayNumber = Calendar.current.component(.day, from: date)
        dateLabel.text = "\(dayNumber)"
        moodLabel.text = mood?.emoji
        configureDots(with: activity.ritmoColors)

        let alpha: CGFloat = isCurrentMonth ? 1 : 0.35
        contentView.alpha = alpha
        contentView.backgroundColor = isSelected ? UIColor.ypBlue.withAlphaComponent(0.14) : .ypGray
        contentView.layer.borderColor = borderColor(isToday: isToday, isSelected: isSelected).cgColor
        dateLabel.textColor = isSelected ? .ypBlue : .ypBlack
    }

    private func configureDots(with colors: [UIColor]) {
        dotsStackView.arrangedSubviews.forEach { view in
            dotsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !colors.isEmpty else {
            return
        }

        let visibleColors = Array(colors.prefix(4))
        visibleColors.forEach { color in
            dotsStackView.addArrangedSubview(makeDotView(color: color))
        }

        let hiddenCount = colors.count - visibleColors.count
        guard hiddenCount > 0 else {
            return
        }

        moreCountLabel.text = "+\(hiddenCount)"
        dotsStackView.addArrangedSubview(moreCountLabel)
    }

    private func makeDotView(color: UIColor) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        view.layer.cornerRadius = 3
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 6),
            view.heightAnchor.constraint(equalToConstant: 6)
        ])
        return view
    }

    private func borderColor(isToday: Bool, isSelected: Bool) -> UIColor {
        if isSelected {
            return .ypBlue
        }

        if isToday {
            return .ypBlack
        }

        return .clear
    }
}

private final class DaySummaryView: UIView {
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoBold(24)
        label.textColor = .ypBlack
        label.textAlignment = .center
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoMedium(11)
        label.textColor = .ypLightGray
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    init(title: String) {
        super.init(frame: .zero)
        backgroundColor = .ypWhite
        layer.cornerRadius = 12
        layer.masksToBounds = true
        titleLabel.text = title

        [valueLabel, titleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            valueLabel.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 1),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(value: Int) {
        valueLabel.text = "\(value)"
    }
}

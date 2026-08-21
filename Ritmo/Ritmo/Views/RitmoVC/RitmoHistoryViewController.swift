import UIKit

final class RitmoHistoryViewController: UIViewController {
    fileprivate enum DayState {
        case empty
        case completed
        case missed
        case planned
    }

    fileprivate struct DayItem {
        let date: Date?
        let dayNumber: String
        let state: DayState
        let isToday: Bool
    }

    private let ritmo: Ritmo
    private let records: [RitmoRecord]
    private let calendar: Calendar
    private var displayedMonth: Date
    private var dayItems: [DayItem] = []

    private lazy var monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .appPreferred
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("ritmoHistory.title", comment: "Ritmo history title")
        label.font = .ritmoBold(24)
        label.textColor = .ypBlack
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.82
        return label
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .ypBlack
        button.addTarget(self, action: #selector(closeButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var ritmoCardView: UIView = {
        let view = UIView()
        view.backgroundColor = ritmo.color
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var emojiLabel: UILabel = {
        let label = UILabel()
        label.text = ritmo.emoji
        label.font = .ritmoRegular(24)
        label.textAlignment = .center
        label.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        label.layer.cornerRadius = 20
        label.layer.masksToBounds = true
        return label
    }()

    private lazy var ritmoNameLabel: UILabel = {
        let label = UILabel()
        label.text = ritmo.name
        label.font = .ritmoBold(22)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private lazy var summaryStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            makeSummaryView(
                value: String(completedDates.count),
                title: NSLocalizedString("historyCompleted", comment: "Completed days in history")
            ),
            makeSummaryView(
                value: String(missedDatesCount),
                title: NSLocalizedString("historyMissed", comment: "Missed days in history")
            ),
            makeSummaryView(
                value: String(currentStreak),
                title: NSLocalizedString("historyCurrentStreak", comment: "Current ritmo streak")
            )
        ])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        return stackView
    }()

    private lazy var previousMonthButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .ypBlack
        button.addTarget(self, action: #selector(previousMonthDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var nextMonthButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        button.tintColor = .ypBlack
        button.addTarget(self, action: #selector(nextMonthDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var monthLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoBold(22)
        label.textColor = .ypBlack
        label.textAlignment = .center
        return label
    }()

    private lazy var monthHeaderStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [previousMonthButton, monthLabel, nextMonthButton])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        return stackView
    }()

    private lazy var weekdaysStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: weekdaySymbols().map { symbol in
            let label = UILabel()
            label.text = symbol
            label.font = .ritmoMedium(13)
            label.textColor = .ypLightGray
            label.textAlignment = .center
            return label
        })
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        return stackView
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 8
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(HistoryDayCell.self, forCellWithReuseIdentifier: HistoryDayCell.reuseIdentifier)
        collectionView.backgroundColor = .ypWhite
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        return collectionView
    }()

    private lazy var legendStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            makeLegendItem(color: ritmo.color, title: NSLocalizedString("historyLegendCompleted", comment: "Completed legend")),
            makeLegendItem(color: .ypLightGray, title: NSLocalizedString("historyLegendMissed", comment: "Missed legend")),
            makeLegendItem(color: .ypGray, title: NSLocalizedString("historyLegendPlanned", comment: "Planned legend"))
        ])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        return stackView
    }()

    private var completedDates: Set<Date> {
        Set(records
            .filter { $0.ritmoID == ritmo.id }
            .map { calendar.startOfDay(for: $0.date) })
    }

    private var historyEndDate: Date {
        calendar.startOfDay(for: ritmo.archivedDate ?? Date())
    }

    private var missedDatesCount: Int {
        let today = calendar.startOfDay(for: Date())
        return historicalActiveDates().filter { date in
            let shouldCountMissed = ritmo.isArchived ? date <= historyEndDate : date < today
            return shouldCountMissed && !completedDates.contains(date)
        }.count
    }

    private var currentStreak: Int {
        let today = calendar.startOfDay(for: Date())
        var streak = 0

        for date in historicalActiveDates().reversed() where ritmo.isArchived || date < today || completedDates.contains(today) {
            if completedDates.contains(date) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    init(ritmo: Ritmo, records: [RitmoRecord]) {
        self.ritmo = ritmo
        self.records = records

        var calendar = Calendar.current
        calendar.firstWeekday = 2
        self.calendar = calendar
        self.displayedMonth = calendar.startOfDay(for: ritmo.archivedDate ?? Date())
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ypWhite
        setupUI()
        reloadMonth()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    private func setupUI() {
        [titleLabel, closeButton, ritmoCardView, summaryStackView, monthHeaderStackView, weekdaysStackView, collectionView, legendStackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        [emojiLabel, ritmoNameLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            ritmoCardView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 27),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            ritmoCardView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            ritmoCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            ritmoCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            ritmoCardView.heightAnchor.constraint(equalToConstant: 108),

            emojiLabel.leadingAnchor.constraint(equalTo: ritmoCardView.leadingAnchor, constant: 16),
            emojiLabel.centerYAnchor.constraint(equalTo: ritmoCardView.centerYAnchor),
            emojiLabel.widthAnchor.constraint(equalToConstant: 40),
            emojiLabel.heightAnchor.constraint(equalToConstant: 40),

            ritmoNameLabel.leadingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 12),
            ritmoNameLabel.trailingAnchor.constraint(equalTo: ritmoCardView.trailingAnchor, constant: -16),
            ritmoNameLabel.centerYAnchor.constraint(equalTo: ritmoCardView.centerYAnchor),

            summaryStackView.topAnchor.constraint(equalTo: ritmoCardView.bottomAnchor, constant: 16),
            summaryStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            summaryStackView.heightAnchor.constraint(equalToConstant: 72),

            monthHeaderStackView.topAnchor.constraint(equalTo: summaryStackView.bottomAnchor, constant: 28),
            monthHeaderStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            monthHeaderStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            monthHeaderStackView.heightAnchor.constraint(equalToConstant: 44),

            previousMonthButton.widthAnchor.constraint(equalToConstant: 44),
            nextMonthButton.widthAnchor.constraint(equalToConstant: 44),

            weekdaysStackView.topAnchor.constraint(equalTo: monthHeaderStackView.bottomAnchor, constant: 8),
            weekdaysStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            weekdaysStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            weekdaysStackView.heightAnchor.constraint(equalToConstant: 20),

            collectionView.topAnchor.constraint(equalTo: weekdaysStackView.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            collectionView.heightAnchor.constraint(equalToConstant: 284),

            legendStackView.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 16),
            legendStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            legendStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func makeSummaryView(value: String, title: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .ypGray
        container.layer.cornerRadius = 16

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .ritmoBold(26)
        valueLabel.textColor = .ypBlack
        valueLabel.textAlignment = .center

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .ritmoMedium(12)
        titleLabel.textColor = .ypBlack
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        let stackView = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4)
        ])

        return container
    }

    private func makeLegendItem(color: UIColor, title: String) -> UIView {
        let markerView = UIView()
        markerView.backgroundColor = color
        markerView.layer.cornerRadius = 5
        markerView.translatesAutoresizingMaskIntoConstraints = false
        markerView.widthAnchor.constraint(equalToConstant: 10).isActive = true
        markerView.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let label = UILabel()
        label.text = title
        label.font = .ritmoMedium(12)
        label.textColor = .ypBlack

        let stackView = UIStackView(arrangedSubviews: [markerView, label])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 6
        return stackView
    }

    private func reloadMonth() {
        monthLabel.text = monthFormatter.string(from: displayedMonth).capitalized
        dayItems = makeDayItems(for: displayedMonth)
        collectionView.reloadData()
    }

    private func makeDayItems(for month: Date) -> [DayItem] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let daysRange = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        var items = Array(
            repeating: DayItem(date: nil, dayNumber: "", state: .empty, isToday: false),
            count: leadingEmptyDays
        )

        for day in daysRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) else {
                continue
            }
            items.append(
                DayItem(
                    date: date,
                    dayNumber: String(day),
                    state: state(for: date),
                    isToday: calendar.isDateInToday(date)
                )
            )
        }

        while items.count % 7 != 0 {
            items.append(DayItem(date: nil, dayNumber: "", state: .empty, isToday: false))
        }

        return items
    }

    private func state(for date: Date) -> DayState {
        let date = calendar.startOfDay(for: date)

        if completedDates.contains(date) {
            return .completed
        }

        guard isRitmoActive(on: date) else {
            return .empty
        }

        if ritmo.isArchived && date > historyEndDate {
            return .empty
        }

        if ritmo.isArchived {
            return .missed
        }

        return date < calendar.startOfDay(for: Date()) ? .missed : .planned
    }

    private func historicalActiveDates() -> [Date] {
        guard let startDate = historyStartDate() else {
            return []
        }

        var dates: [Date] = []
        var date = startDate

        while date <= historyEndDate {
            if isRitmoActive(on: date) {
                dates.append(date)
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = nextDate
        }

        return dates
    }

    private func historyStartDate() -> Date? {
        let completedStartDate = completedDates.min()
        let eventDate = ritmo.eventDate.map { calendar.startOfDay(for: $0) }
        let createdDate = calendar.startOfDay(for: ritmo.createdDate)

        if ritmo.isHabit {
            return [createdDate, completedStartDate].compactMap { $0 }.min()
        }

        return [createdDate, completedStartDate, eventDate].compactMap { $0 }.min()
    }

    private func isRitmoActive(on date: Date) -> Bool {
        if ritmo.isHabit {
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            return ritmo.schedule.contains { $0.numberValue == adjustedWeekday }
        }

        if completedDates.contains(date) {
            return true
        }

        let eventDate = calendar.startOfDay(for: ritmo.eventDate ?? historyEndDate)
        let activeDate = eventDate < historyEndDate ? historyEndDate : eventDate
        return calendar.isDate(activeDate, inSameDayAs: date)
    }

    private func weekdaySymbols() -> [String] {
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        return Array(symbols[1...6]) + [symbols[0]]
    }

    @objc private func closeButtonDidTap() {
        dismiss(animated: true)
    }

    @objc private func previousMonthDidTap() {
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else {
            return
        }

        displayedMonth = previousMonth
        reloadMonth()
    }

    @objc private func nextMonthDidTap() {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else {
            return
        }

        displayedMonth = nextMonth
        reloadMonth()
    }
}

extension RitmoHistoryViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dayItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HistoryDayCell.reuseIdentifier, for: indexPath) as? HistoryDayCell else {
            return UICollectionViewCell()
        }

        cell.configure(with: dayItems[indexPath.item], ritmoColor: ritmo.color)
        return cell
    }
}

extension RitmoHistoryViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let spacing: CGFloat = 6
        let width = (collectionView.bounds.width - spacing * 6) / 7
        return CGSize(width: width, height: 40)
    }
}

private final class HistoryDayCell: UICollectionViewCell {
    static let reuseIdentifier = "HistoryDayCell"

    private lazy var dayLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoMedium(15)
        label.textAlignment = .center
        label.layer.cornerRadius = 18
        label.layer.masksToBounds = true
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: RitmoHistoryViewController.DayItem, ritmoColor: UIColor) {
        dayLabel.text = item.dayNumber
        dayLabel.layer.borderWidth = item.isToday ? 1 : 0
        dayLabel.layer.borderColor = UIColor.ypBlack.cgColor

        switch item.state {
        case .empty:
            dayLabel.backgroundColor = .clear
            dayLabel.textColor = item.date == nil ? .clear : .ypLightGray
        case .completed:
            dayLabel.backgroundColor = ritmoColor
            dayLabel.textColor = .white
        case .missed:
            dayLabel.backgroundColor = .ypLightGray
            dayLabel.textColor = .ypWhite
        case .planned:
            dayLabel.backgroundColor = .ypGray
            dayLabel.textColor = .ypBlack
        }
    }

    private func setupUI() {
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dayLabel)

        NSLayoutConstraint.activate([
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            dayLabel.widthAnchor.constraint(equalToConstant: 36),
            dayLabel.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
}

import UIKit

final class ArchivedDayItemsViewController: UIViewController {
    fileprivate struct ArchiveItem {
        let dayItem: DayItem
        let completedCount: Int
        let missedCount: Int
        let archivedDateText: String
    }

    private let dayItemStore = DayItemStore()
    private let dayItemRecordStore = DayItemRecordStore()
    private var records: [DayItemRecord] = []
    private var items: [ArchiveItem] = []
    private var calendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }()

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .appPreferred
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("archive.title", comment: "Archive screen title")
        label.font = .ladomiBold(40)
        label.textColor = .ypBlack
        return label
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(ArchivedDayItemCell.self, forCellReuseIdentifier: ArchivedDayItemCell.reuseIdentifier)
        tableView.backgroundColor = .ypWhite
        tableView.separatorStyle = .none
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0)
        tableView.verticalScrollIndicatorInsets.bottom = 24
        tableView.showsVerticalScrollIndicator = false
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()

    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("archive.empty", comment: "Empty archive placeholder")
        label.font = .ladomiMedium(12)
        label.textColor = .ypBlack
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ypWhite
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadArchive()
    }

    private func setupUI() {
        [titleLabel, tableView, placeholderLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            placeholderLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            placeholderLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func reloadArchive() {
        records = dayItemRecordStore.fetch()
        items = dayItemStore.fetchDayItems()
            .filter { $0.isArchived }
            .sorted {
                ($0.archivedDate ?? $0.createdDate) > ($1.archivedDate ?? $1.createdDate)
            }
            .map(makeArchiveItem)

        tableView.isHidden = items.isEmpty
        placeholderLabel.isHidden = !items.isEmpty
        tableView.reloadData()
    }

    private func makeArchiveItem(for dayItem: DayItem) -> ArchiveItem {
        let completedCount = records.filter { $0.dayItemID == dayItem.id }.count
        let missedCount = missedDatesCount(for: dayItem)
        let archivedDate = dayItem.archivedDate ?? dayItem.createdDate

        return ArchiveItem(
            dayItem: dayItem,
            completedCount: completedCount,
            missedCount: missedCount,
            archivedDateText: dateFormatter.string(from: archivedDate)
        )
    }

    private func missedDatesCount(for dayItem: DayItem) -> Int {
        let completedDates = Set(records
            .filter { $0.dayItemID == dayItem.id }
            .map { calendar.startOfDay(for: $0.date) })
        let startDate = calendar.startOfDay(for: dayItem.createdDate)
        let endDate = calendar.startOfDay(for: dayItem.archivedDate ?? Date())

        guard startDate <= endDate else {
            return 0
        }

        var missedCount = 0
        var date = startDate

        while date <= endDate {
            if isDayItem(dayItem, activeOn: date), !completedDates.contains(date) {
                missedCount += 1
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = nextDate
        }

        return missedCount
    }

    private func isDayItem(_ dayItem: DayItem, activeOn date: Date) -> Bool {
        if dayItem.isHabit {
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            return dayItem.schedule.contains { $0.numberValue == adjustedWeekday }
        }

        guard let eventDate = dayItem.eventDate else {
            return false
        }

        return calendar.isDate(eventDate, inSameDayAs: date)
    }

    private func restoreDayItem(_ dayItem: DayItem) {
        dayItemStore.setArchived(false, dayItem: dayItem)
        reloadArchive()
    }
}

extension ArchivedDayItemsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ArchivedDayItemCell.reuseIdentifier,
            for: indexPath
        ) as? ArchivedDayItemCell else {
            return UITableViewCell()
        }

        cell.configure(with: items[indexPath.row])
        return cell
    }
}

extension ArchivedDayItemsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        112
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let historyVC = DayItemHistoryViewController(dayItem: items[indexPath.row].dayItem, records: records)
        present(historyVC, animated: true)
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let dayItem = items[indexPath.row].dayItem

        let restoreAction = UIAction(title: NSLocalizedString("archive.restore", comment: "Restore dayItem from archive")) { [weak self] _ in
            self?.restoreDayItem(dayItem)
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(title: "", children: [restoreAction])
        }
    }
}

private final class ArchivedDayItemCell: UITableViewCell {
    static let reuseIdentifier = "ArchivedDayItemCell"

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .ypGray
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private let emojiLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiRegular(22)
        label.textAlignment = .center
        label.layer.cornerRadius = 20
        label.layer.masksToBounds = true
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiBold(18)
        label.textColor = .ypBlack
        label.numberOfLines = 1
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiMedium(13)
        label.textColor = .ypLightGray
        return label
    }()

    private let statsLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiMedium(14)
        label.textColor = .ypBlack
        label.numberOfLines = 1
        return label
    }()

    private lazy var textStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, dateLabel, statsLabel])
        stackView.axis = .vertical
        stackView.spacing = 5
        return stackView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func configure(with item: ArchivedDayItemsViewController.ArchiveItem) {
        emojiLabel.text = item.dayItem.emoji
        emojiLabel.backgroundColor = item.dayItem.color.withAlphaComponent(0.22)
        titleLabel.text = item.dayItem.name
        dateLabel.text = "\(NSLocalizedString("archive.archivedOn", comment: "Archived date label")) \(item.archivedDateText)"
        statsLabel.text = String(
            format: NSLocalizedString("archive.summary", comment: "Archive dayItem summary"),
            item.completedCount,
            item.missedCount
        )
    }

    private func setupUI() {
        backgroundColor = .ypWhite
        selectionStyle = .none

        [containerView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        [emojiLabel, textStackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            emojiLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            emojiLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            emojiLabel.widthAnchor.constraint(equalToConstant: 40),
            emojiLabel.heightAnchor.constraint(equalToConstant: 40),

            textStackView.leadingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 12),
            textStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            textStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
}

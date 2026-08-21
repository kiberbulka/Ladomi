//
//  StatisticViewController.swift
//  Ritmo
//
//  Created by User on 21.03.2025.
//

import Foundation
import UIKit

final class StatisticViewController: UIViewController {
    private struct StatisticsItem {
        let title: String
        let value: String
        let detail: String
    }

    private let statisticsService = StatisticsService()
    private let ritmoRecordStore = RitmoRecordStore()
    private let accentColor = UIColor(red: 0.95, green: 0.44, blue: 0.70, alpha: 1)
    private let secondaryColor = UIColor(red: 0.98, green: 0.75, blue: 0.18, alpha: 1)
    private let blueAccentColor = UIColor(red: 0.12, green: 0.58, blue: 0.95, alpha: 1)

    private var analyticsData: AnalyticsData?
    private var statisticsItems: [StatisticsItem] = []

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("analytics.title", comment: "Analytics screen title")
        label.font = .ritmoBold(40)
        label.textColor = .ypBlack
        return label
    }()

    private lazy var placeholderImage: UIImageView = {
        let image = UIImageView()
        image.image = .statPlaceholder
        return image
    }()

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("statisticPlaceholder", comment: "")
        label.font = .ritmoMedium(12)
        label.textColor = .ypBlack
        return label
    }()

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0)
        return scrollView
    }()

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        return stackView
    }()

    private lazy var overviewCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .ypWhite
        view.layer.cornerRadius = 28
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowRadius = 22
        view.layer.shadowOffset = CGSize(width: 0, height: 12)
        return view
    }()

    private lazy var progressRingView: ProgressRingView = {
        let view = ProgressRingView()
        view.trackColor = .ypGray
        view.progressColor = accentColor
        view.progress = 0
        return view
    }()

    private lazy var progressValueLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoBold(30)
        label.textColor = .ypBlack
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.72
        return label
    }()

    private lazy var overviewTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoBold(24)
        label.textColor = .ypBlack
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.78
        return label
    }()

    private lazy var overviewDetailLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoMedium(14)
        label.textColor = .ypLightGray
        label.numberOfLines = 3
        return label
    }()

    private lazy var moodChipLabel: UILabel = {
        let label = PaddingLabel(horizontalInset: 14, verticalInset: 0)
        label.backgroundColor = UIColor(red: 0.90, green: 0.96, blue: 0.89, alpha: 1)
        label.textColor = UIColor(red: 0.12, green: 0.48, blue: 0.25, alpha: 1)
        label.font = .ritmoBold(14)
        label.textAlignment = .center
        label.layer.cornerRadius = 18
        label.layer.masksToBounds = true
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.78
        return label
    }()

    private lazy var firstMetricCardView = makeMetricCard()
    private lazy var firstMetricValueLabel = makeMetricValueLabel()
    private lazy var firstMetricTitleLabel = makeMetricTitleLabel()
    private lazy var secondMetricCardView = makeMetricCard()
    private lazy var secondMetricValueLabel = makeMetricValueLabel()
    private lazy var secondMetricTitleLabel = makeMetricTitleLabel()
    private lazy var adviceCardView = makeAdviceCard()
    private lazy var adviceValueLabel = makeAdviceValueLabel()
    private lazy var adviceDetailLabel = makeAdviceDetailLabel()
    private lazy var insightsSectionLabel = makeSectionLabel()
    private lazy var insightsStackView = makeInsightsStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        ritmoRecordStore.delegate = self
        reloadStatistics()
    }

    private func reloadStatistics() {
        analyticsData = statisticsService.fetchAnalytics()
        statisticsItems = makeStatisticsItems()

        let hasData = !statisticsItems.isEmpty
        placeholderImage.isHidden = hasData
        placeholderLabel.isHidden = hasData
        scrollView.isHidden = !hasData

        if hasData {
            configureOverview()
            configureInsightCards()
            scrollView.setContentOffset(.zero, animated: false)
        }
    }

    private func makeStatisticsItems() -> [StatisticsItem] {
        guard let analyticsData = analyticsData else {
            return []
        }

        return analyticsData.insights.map {
            StatisticsItem(title: $0.title, value: $0.value, detail: $0.detail)
        }
    }

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1)

        [titleLabel, placeholderImage, placeholderLabel, scrollView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStackView)

        setupOverviewCard()

        [overviewCardView, insightsSectionLabel, insightsStackView].forEach {
            contentStackView.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            placeholderImage.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -273),
            placeholderImage.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            placeholderLabel.topAnchor.constraint(equalTo: placeholderImage.bottomAnchor, constant: 8),
            placeholderLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    private func setupOverviewCard() {
        [
            overviewTitleLabel,
            moodChipLabel,
            progressRingView,
            progressValueLabel,
            overviewDetailLabel,
            firstMetricCardView,
            secondMetricCardView,
            adviceCardView
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            overviewCardView.addSubview($0)
        }

        setupMetricCard(firstMetricCardView, valueLabel: firstMetricValueLabel, titleLabel: firstMetricTitleLabel)
        setupMetricCard(secondMetricCardView, valueLabel: secondMetricValueLabel, titleLabel: secondMetricTitleLabel)
        setupAdviceCardContent()

        NSLayoutConstraint.activate([
            overviewCardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 332),

            overviewTitleLabel.topAnchor.constraint(equalTo: overviewCardView.topAnchor, constant: 24),
            overviewTitleLabel.leadingAnchor.constraint(equalTo: overviewCardView.leadingAnchor, constant: 20),
            overviewTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: moodChipLabel.leadingAnchor, constant: -12),

            moodChipLabel.centerYAnchor.constraint(equalTo: overviewTitleLabel.centerYAnchor),
            moodChipLabel.trailingAnchor.constraint(equalTo: overviewCardView.trailingAnchor, constant: -20),
            moodChipLabel.heightAnchor.constraint(equalToConstant: 36),
            moodChipLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 124),

            progressRingView.topAnchor.constraint(equalTo: overviewTitleLabel.bottomAnchor, constant: 24),
            progressRingView.leadingAnchor.constraint(equalTo: overviewTitleLabel.leadingAnchor),
            progressRingView.widthAnchor.constraint(equalToConstant: 106),
            progressRingView.heightAnchor.constraint(equalToConstant: 106),

            progressValueLabel.centerXAnchor.constraint(equalTo: progressRingView.centerXAnchor),
            progressValueLabel.centerYAnchor.constraint(equalTo: progressRingView.centerYAnchor),
            progressValueLabel.leadingAnchor.constraint(equalTo: progressRingView.leadingAnchor, constant: 14),
            progressValueLabel.trailingAnchor.constraint(equalTo: progressRingView.trailingAnchor, constant: -14),

            firstMetricCardView.topAnchor.constraint(equalTo: progressRingView.topAnchor),
            firstMetricCardView.leadingAnchor.constraint(equalTo: progressRingView.trailingAnchor, constant: 14),
            firstMetricCardView.trailingAnchor.constraint(equalTo: moodChipLabel.trailingAnchor),
            firstMetricCardView.heightAnchor.constraint(equalToConstant: 48),

            secondMetricCardView.topAnchor.constraint(equalTo: firstMetricCardView.bottomAnchor, constant: 10),
            secondMetricCardView.leadingAnchor.constraint(equalTo: firstMetricCardView.leadingAnchor),
            secondMetricCardView.trailingAnchor.constraint(equalTo: firstMetricCardView.trailingAnchor),
            secondMetricCardView.heightAnchor.constraint(equalToConstant: 48),

            overviewDetailLabel.topAnchor.constraint(equalTo: progressRingView.bottomAnchor, constant: 18),
            overviewDetailLabel.leadingAnchor.constraint(equalTo: overviewTitleLabel.leadingAnchor),
            overviewDetailLabel.trailingAnchor.constraint(equalTo: moodChipLabel.trailingAnchor),

            adviceCardView.topAnchor.constraint(equalTo: overviewDetailLabel.bottomAnchor, constant: 18),
            adviceCardView.leadingAnchor.constraint(equalTo: overviewTitleLabel.leadingAnchor),
            adviceCardView.trailingAnchor.constraint(equalTo: moodChipLabel.trailingAnchor),
            adviceCardView.bottomAnchor.constraint(equalTo: overviewCardView.bottomAnchor, constant: -20),
            adviceCardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 104)
        ])
    }

    private func configureOverview() {
        guard let overviewItem = statisticsItems.first else {
            return
        }

        let secondaryItems = statisticsItems.dropFirst().filter { $0.title != NSLocalizedString("analytics.advice.title", comment: "") }
        let adviceItem = statisticsItems.last { $0.title == NSLocalizedString("analytics.advice.title", comment: "") } ?? statisticsItems.last ?? overviewItem

        overviewTitleLabel.text = overviewItem.title
        overviewDetailLabel.text = overviewItem.detail
        progressValueLabel.text = overviewItem.value
        progressRingView.progress = progressValue(from: overviewItem.value)
        moodChipLabel.text = moodChipText(from: secondaryItems.first)

        let analyzedDays = analyticsData?.analyzedDays ?? 0
        let moodDays = analyticsData?.moodDays ?? 0
        firstMetricValueLabel.text = "\(analyzedDays)"
        firstMetricTitleLabel.text = dayMetricTitle(
            count: analyzedDays,
            suffixKey: "analytics.metric.analyzedSuffix"
        )
        secondMetricValueLabel.text = "\(moodDays)"
        secondMetricTitleLabel.text = dayMetricTitle(
            count: moodDays,
            suffixKey: "analytics.metric.moodSuffix"
        )

        adviceValueLabel.text = adviceItem.value
        adviceDetailLabel.text = adviceItem.detail
    }

    private func dayMetricTitle(count: Int, suffixKey: String) -> String {
        let suffix = NSLocalizedString(suffixKey, comment: "")
        return "\(dayWord(for: count)) \(suffix)"
    }

    private func dayWord(for count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100
        if remainder10 == 1 && remainder100 != 11 {
            return NSLocalizedString("ritmo.day", comment: "")
        } else if remainder10 >= 2 && remainder10 <= 4 && (remainder100 < 10 || remainder100 >= 20) {
            return NSLocalizedString("ritmo.2,3,4day", comment: "")
        } else {
            return NSLocalizedString("ritmo.days", comment: "")
        }
    }

    private func configureInsightCards() {
        insightsStackView.arrangedSubviews.forEach {
            insightsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let adviceTitle = NSLocalizedString("analytics.advice.title", comment: "")
        let visibleItems = statisticsItems.dropFirst().filter { $0.title != adviceTitle }
        insightsSectionLabel.isHidden = visibleItems.isEmpty
        insightsStackView.isHidden = visibleItems.isEmpty

        visibleItems.forEach { item in
            insightsStackView.addArrangedSubview(makeInsightCard(item: item))
        }
    }

    private func progressValue(from text: String) -> CGFloat {
        let digits = text.filter { $0.isNumber }
        guard let value = Int(digits) else {
            return 0
        }

        return min(max(CGFloat(value) / 100, 0), 1)
    }

    private func moodChipText(from item: StatisticsItem?) -> String {
        guard
            let item = item,
            item.title == NSLocalizedString("analytics.mood.title", comment: ""),
            item.value.contains(where: { !$0.isNumber && !$0.isWhitespace && $0 != "%" && $0 != "-" && $0 != "+" })
        else {
            let format = NSLocalizedString("analytics.moodChip.rate", comment: "Fallback analytics rate chip")
            return String(format: format, analyticsData?.averageCompletionRate ?? 0)
        }

        return item.value
    }

    private func makeMetricCard() -> UIView {
        let view = UIView()
        view.backgroundColor = .ypGray
        view.layer.cornerRadius = 18
        return view
    }

    private func setupMetricCard(_ cardView: UIView, valueLabel: UILabel, titleLabel: UILabel) {
        let dotView = UIView()
        dotView.layer.cornerRadius = 5
        dotView.backgroundColor = cardView === firstMetricCardView ? accentColor : secondaryColor

        [dotView, valueLabel, titleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            cardView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            dotView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            dotView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 10),
            dotView.heightAnchor.constraint(equalToConstant: 10),

            valueLabel.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 10),
            valueLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 48),

            titleLabel.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            titleLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        ])
    }

    private func makeMetricValueLabel() -> UILabel {
        let label = UILabel()
        label.font = .ritmoBold(18)
        label.textColor = .ypBlack
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.68
        return label
    }

    private func makeMetricTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .ritmoMedium(12)
        label.textColor = .ypLightGray
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.72
        return label
    }

    private func makeAdviceCard() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1)
        view.layer.cornerRadius = 24
        return view
    }

    private func setupAdviceCardContent() {
        let iconLabel = UILabel()
        iconLabel.text = "✦"
        iconLabel.font = .ritmoBold(30)
        iconLabel.textColor = secondaryColor
        iconLabel.textAlignment = .center

        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("analytics.advice.title", comment: "")
        titleLabel.font = .ritmoBold(22)
        titleLabel.textColor = .ypWhite

        [iconLabel, titleLabel, adviceValueLabel, adviceDetailLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            adviceCardView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: adviceCardView.leadingAnchor, constant: 18),
            iconLabel.topAnchor.constraint(equalTo: adviceCardView.topAnchor, constant: 18),
            iconLabel.widthAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: adviceCardView.topAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: adviceCardView.trailingAnchor, constant: -18),

            adviceValueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            adviceValueLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            adviceValueLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            adviceDetailLabel.topAnchor.constraint(equalTo: adviceValueLabel.bottomAnchor, constant: 6),
            adviceDetailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            adviceDetailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            adviceDetailLabel.bottomAnchor.constraint(lessThanOrEqualTo: adviceCardView.bottomAnchor, constant: -18)
        ])
    }

    private func makeAdviceValueLabel() -> UILabel {
        let label = UILabel()
        label.font = .ritmoBold(16)
        label.textColor = .ypWhite
        label.numberOfLines = 1
        return label
    }

    private func makeAdviceDetailLabel() -> UILabel {
        let label = UILabel()
        label.font = .ritmoMedium(13)
        label.textColor = UIColor.white.withAlphaComponent(0.72)
        label.numberOfLines = 3
        return label
    }

    private func makeSectionLabel() -> UILabel {
        let label = UILabel()
        label.text = NSLocalizedString("analytics.insights.title", comment: "Insights section title")
        label.font = .ritmoBold(24)
        label.textColor = .ypBlack
        return label
    }

    private func makeInsightsStackView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        return stackView
    }

    private func makeInsightCard(item: StatisticsItem) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .ypWhite
        cardView.layer.cornerRadius = 20

        let iconView = UIView()
        iconView.backgroundColor = iconColor(for: item.title).withAlphaComponent(0.16)
        iconView.layer.cornerRadius = 22

        let iconImageView = UIImageView(image: UIImage(systemName: iconName(for: item.title)))
        iconImageView.tintColor = iconColor(for: item.title)
        iconImageView.contentMode = .scaleAspectFit

        let valueLabel = UILabel()
        valueLabel.text = item.value
        valueLabel.font = .ritmoBold(26)
        valueLabel.textColor = .ypBlack
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.72

        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = .ritmoBold(16)
        titleLabel.textColor = .ypBlack
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.78

        let detailLabel = UILabel()
        detailLabel.text = item.detail
        detailLabel.font = .ritmoMedium(13)
        detailLabel.textColor = .ypLightGray
        detailLabel.numberOfLines = 3

        [iconView, valueLabel, titleLabel, detailLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            cardView.addSubview($0)
        }

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImageView)

        NSLayoutConstraint.activate([
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 126),

            iconView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            iconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            iconImageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),

            valueLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            valueLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            valueLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: valueLabel.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: valueLabel.trailingAnchor),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            detailLabel.leadingAnchor.constraint(equalTo: valueLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: valueLabel.trailingAnchor),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -16)
        ])

        return cardView
    }

    private func iconName(for title: String) -> String {
        switch title {
        case NSLocalizedString("analytics.mood.title", comment: ""):
            return "face.smiling"
        case NSLocalizedString("analytics.load.title", comment: ""):
            return "gauge.medium"
        case NSLocalizedString("analytics.weekday.title", comment: ""):
            return "calendar"
        default:
            return "chart.bar.fill"
        }
    }

    private func iconColor(for title: String) -> UIColor {
        switch title {
        case NSLocalizedString("analytics.mood.title", comment: ""):
            return UIColor(red: 0.22, green: 0.70, blue: 0.46, alpha: 1)
        case NSLocalizedString("analytics.load.title", comment: ""):
            return secondaryColor
        case NSLocalizedString("analytics.weekday.title", comment: ""):
            return blueAccentColor
        default:
            return accentColor
        }
    }
}

extension StatisticViewController: RitmoStoreDelegate {
    func didUpdate(_ update: RitmoStoreUpdate) {
        reloadStatistics()
    }
}

extension StatisticViewController: RitmoRecordStoreDelegate {
    func didUpdateRecords(_ update: RitmoCategoryStoreUpdate) {
        reloadStatistics()
    }
}

private final class ProgressRingView: UIView {
    var progress: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }

    var trackColor: UIColor = .ypGray {
        didSet {
            setNeedsDisplay()
        }
    }

    var progressColor: UIColor = .ypBlack {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        let lineWidth: CGFloat = 12
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - lineWidth / 2
        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + progress * 2 * CGFloat.pi

        let trackPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        trackColor.setStroke()
        trackPath.lineWidth = lineWidth
        trackPath.stroke()

        let progressPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        progressColor.setStroke()
        progressPath.lineWidth = lineWidth
        progressPath.lineCapStyle = .round
        progressPath.stroke()
    }
}

private final class PaddingLabel: UILabel {
    private let insets: UIEdgeInsets

    init(horizontalInset: CGFloat, verticalInset: CGFloat) {
        self.insets = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
}

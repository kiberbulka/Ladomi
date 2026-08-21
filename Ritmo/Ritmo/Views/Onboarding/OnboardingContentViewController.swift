import UIKit

struct OnboardingPageConfiguration {
    let titleKey: String
    let subtitleKey: String
    let accentColor: UIColor
    let secondaryColor: UIColor
    let isAnalyticsFocused: Bool
}

final class OnboardingContentViewController: UIViewController {

    private let configuration: OnboardingPageConfiguration

    lazy var button: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .ypBlack
        button.setTitle(NSLocalizedString("onboarding.button", comment: "Кнопка на экране онбординга"), for: .normal)
        button.setTitleColor(.ypWhite, for: .normal)
        button.titleLabel?.font = .ritmoMedium(16)
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 18
        return button
    }()

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        return scrollView
    }()

    private let contentView = UIView()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString(configuration.titleKey, comment: "Заголовок страницы онбординга")
        label.font = .ritmoBold(34)
        label.textColor = .ypBlack
        label.textAlignment = .left
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.84
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString(configuration.subtitleKey, comment: "Описание страницы онбординга")
        label.font = .ritmoMedium(17)
        label.textColor = .ypLightGray
        label.numberOfLines = 0
        return label
    }()

    private lazy var featureStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: makeFeaturePills())
        stackView.axis = .vertical
        stackView.spacing = 10
        return stackView
    }()

    private lazy var mockupContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .ypWhite
        view.layer.cornerRadius = 28
        view.layer.masksToBounds = false
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowRadius = 22
        view.layer.shadowOffset = CGSize(width: 0, height: 12)
        return view
    }()

    private lazy var mockupContentView: UIView = {
        configuration.isAnalyticsFocused ? makeAnalyticsMockup() : makeRitmoMockup()
    }()

    init(configuration: OnboardingPageConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1)

        [scrollView, button].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        [mockupContainer, titleLabel, subtitleLabel, featureStackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        mockupContentView.translatesAutoresizingMaskIntoConstraints = false
        mockupContainer.addSubview(mockupContentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: button.topAnchor, constant: -58),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            mockupContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            mockupContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mockupContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mockupContainer.heightAnchor.constraint(equalToConstant: 318),

            mockupContentView.topAnchor.constraint(equalTo: mockupContainer.topAnchor),
            mockupContentView.leadingAnchor.constraint(equalTo: mockupContainer.leadingAnchor),
            mockupContentView.trailingAnchor.constraint(equalTo: mockupContainer.trailingAnchor),
            mockupContentView.bottomAnchor.constraint(equalTo: mockupContainer.bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: mockupContainer.bottomAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            featureStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            featureStackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            featureStackView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            featureStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            button.heightAnchor.constraint(equalToConstant: 60),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func makeFeaturePills() -> [UIView] {
        if configuration.isAnalyticsFocused {
            return [
                makeFeatureRow(iconName: "chart.bar.fill", titleKey: "onboarding.feature.analytics", color: configuration.accentColor),
                makeFeatureRow(iconName: "calendar", titleKey: "onboarding.feature.calendar", color: configuration.secondaryColor),
                makeFeatureRow(iconName: "bell.fill", titleKey: "onboarding.feature.reminders", color: UIColor(red: 0.12, green: 0.58, blue: 0.95, alpha: 1))
            ]
        } else {
            return [
                makeFeatureRow(iconName: "plus.circle.fill", titleKey: "onboarding.feature.create", color: configuration.accentColor),
                makeFeatureRow(iconName: "line.3.horizontal.decrease.circle.fill", titleKey: "onboarding.feature.filters", color: configuration.secondaryColor),
                makeFeatureRow(iconName: "checkmark.circle.fill", titleKey: "onboarding.feature.complete", color: UIColor(red: 0.22, green: 0.70, blue: 0.46, alpha: 1))
            ]
        }
    }

    private func makeFeatureRow(iconName: String, titleKey: String, color: UIColor) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = NSLocalizedString(titleKey, comment: "Функция приложения на онбординге")
        label.font = .ritmoMedium(15)
        label.textColor = .ypBlack
        label.numberOfLines = 2

        let stackView = UIStackView(arrangedSubviews: [iconView, label])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 10
        stackView.backgroundColor = .ypWhite
        stackView.layer.cornerRadius = 18
        stackView.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 14)
        stackView.isLayoutMarginsRelativeArrangement = true

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24)
        ])

        return stackView
    }

    private func makeRitmoMockup() -> UIView {
        let container = UIView()

        let title = makeMockupLabel(text: NSLocalizedString("onboarding.mockup.today", comment: "Сегодня"), font: .ritmoBold(24), color: .ypBlack)
        let dateChip = makeCapsuleLabel(text: NSLocalizedString("onboarding.mockup.date", comment: "Дата"), backgroundColor: .ypGray, textColor: .ypBlack)
        let search = makeSearchView()
        let habitCard = makeMiniRitmoCard(emoji: "💧", title: NSLocalizedString("onboarding.mockup.habit", comment: "Привычка"), subtitle: "5 \(NSLocalizedString("ritmo.days", comment: ""))", color: configuration.accentColor, isDone: true)
        let eventCard = makeMiniRitmoCard(emoji: "📚", title: NSLocalizedString("onboarding.mockup.event", comment: "Событие"), subtitle: NSLocalizedString("onboarding.mockup.eventDate", comment: "Дата события"), color: configuration.secondaryColor, isDone: false)
        let chipStack = makeHorizontalStack([
            makeCapsuleLabel(text: NSLocalizedString("habitsFilter", comment: ""), backgroundColor: .ypBlack, textColor: .ypWhite),
            makeCapsuleLabel(text: NSLocalizedString("eventsFilter", comment: ""), backgroundColor: .ypGray, textColor: .ypLightGray),
            makeCapsuleLabel(text: NSLocalizedString("uncompletedRitmos", comment: ""), backgroundColor: .ypGray, textColor: .ypLightGray)
        ], spacing: 8)
        let cardStack = makeHorizontalStack([habitCard, eventCard], spacing: 10)

        [title, dateChip, search, chipStack, cardStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 22),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),

            dateChip.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            dateChip.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            dateChip.heightAnchor.constraint(equalToConstant: 36),

            search.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 18),
            search.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            search.trailingAnchor.constraint(equalTo: dateChip.trailingAnchor),
            search.heightAnchor.constraint(equalToConstant: 42),

            chipStack.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 12),
            chipStack.leadingAnchor.constraint(equalTo: search.leadingAnchor),
            chipStack.trailingAnchor.constraint(lessThanOrEqualTo: search.trailingAnchor),
            chipStack.heightAnchor.constraint(equalToConstant: 34),

            cardStack.topAnchor.constraint(equalTo: chipStack.bottomAnchor, constant: 16),
            cardStack.leadingAnchor.constraint(equalTo: search.leadingAnchor),
            cardStack.trailingAnchor.constraint(equalTo: search.trailingAnchor),
            cardStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18),
            habitCard.widthAnchor.constraint(equalTo: eventCard.widthAnchor)
        ])

        return container
    }

    private func makeAnalyticsMockup() -> UIView {
        let container = UIView()

        let title = makeMockupLabel(text: NSLocalizedString("analytics.title", comment: ""), font: .ritmoBold(24), color: .ypBlack)
        let progressRing = makeProgressRingView()
        let percentLabel = makeMockupLabel(text: "82%", font: .ritmoBold(28), color: .ypBlack)
        let periodCard = makeStatisticCard(value: "7", titleKey: "currentStreak", tintColor: configuration.accentColor)
        let completedCard = makeStatisticCard(value: "24", titleKey: "numberOfCompletedRitmos", tintColor: configuration.secondaryColor)
        let adviceCard = makeAdviceCard()
        let moodChip = makeCapsuleLabel(text: NSLocalizedString("calendar.mood.good", comment: ""), backgroundColor: UIColor(red: 0.90, green: 0.96, blue: 0.89, alpha: 1), textColor: UIColor(red: 0.12, green: 0.48, blue: 0.25, alpha: 1))

        [title, progressRing, percentLabel, periodCard, completedCard, adviceCard, moodChip].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 22),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),

            moodChip.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            moodChip.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            moodChip.heightAnchor.constraint(equalToConstant: 36),

            progressRing.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 20),
            progressRing.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            progressRing.widthAnchor.constraint(equalToConstant: 102),
            progressRing.heightAnchor.constraint(equalToConstant: 102),

            percentLabel.centerXAnchor.constraint(equalTo: progressRing.centerXAnchor),
            percentLabel.centerYAnchor.constraint(equalTo: progressRing.centerYAnchor),

            periodCard.topAnchor.constraint(equalTo: progressRing.topAnchor),
            periodCard.leadingAnchor.constraint(equalTo: progressRing.trailingAnchor, constant: 14),
            periodCard.trailingAnchor.constraint(equalTo: moodChip.trailingAnchor),
            periodCard.heightAnchor.constraint(equalToConstant: 46),

            completedCard.topAnchor.constraint(equalTo: periodCard.bottomAnchor, constant: 10),
            completedCard.leadingAnchor.constraint(equalTo: periodCard.leadingAnchor),
            completedCard.trailingAnchor.constraint(equalTo: periodCard.trailingAnchor),
            completedCard.heightAnchor.constraint(equalToConstant: 46),

            adviceCard.topAnchor.constraint(equalTo: progressRing.bottomAnchor, constant: 20),
            adviceCard.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            adviceCard.trailingAnchor.constraint(equalTo: moodChip.trailingAnchor),
            adviceCard.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18)
        ])

        return container
    }

    private func makeSearchView() -> UIView {
        let view = UIView()
        view.backgroundColor = .ypGray
        view.layer.cornerRadius = 18

        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = .ypLightGray
        icon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(icon)

        let label = makeMockupLabel(text: NSLocalizedString("searchBar", comment: ""), font: .ritmoRegular(15), color: .ypLightGray)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -14)
        ])

        return view
    }

    private func makeMiniRitmoCard(emoji: String, title: String, subtitle: String, color: UIColor, isDone: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = color
        card.layer.cornerRadius = 22
        card.layer.masksToBounds = true

        let emojiLabel = UILabel()
        emojiLabel.text = emoji
        emojiLabel.font = .ritmoMedium(22)
        emojiLabel.textAlignment = .center
        emojiLabel.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        emojiLabel.layer.cornerRadius = 20
        emojiLabel.layer.masksToBounds = true

        let titleLabel = makeMockupLabel(text: title, font: .ritmoBold(17), color: .ypWhite)
        titleLabel.numberOfLines = 2

        let subtitleLabel = makeMockupLabel(text: subtitle, font: .ritmoMedium(12), color: UIColor.white.withAlphaComponent(0.85))

        let button = UIView()
        button.backgroundColor = UIColor.white.withAlphaComponent(0.26)
        button.layer.cornerRadius = 18

        let buttonIcon = UIImageView(image: UIImage(systemName: isDone ? "checkmark" : "plus"))
        buttonIcon.tintColor = .ypWhite
        buttonIcon.contentMode = .scaleAspectFit

        [emojiLabel, titleLabel, subtitleLabel, button].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview($0)
        }

        buttonIcon.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(buttonIcon)

        NSLayoutConstraint.activate([
            emojiLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            emojiLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            emojiLabel.widthAnchor.constraint(equalToConstant: 40),
            emojiLabel.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -8),

            button.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            button.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            button.widthAnchor.constraint(equalToConstant: 36),
            button.heightAnchor.constraint(equalToConstant: 36),

            buttonIcon.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            buttonIcon.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            buttonIcon.widthAnchor.constraint(equalToConstant: 16),
            buttonIcon.heightAnchor.constraint(equalToConstant: 16)
        ])

        return card
    }

    private func makeProgressRingView() -> UIView {
        let ring = ProgressRingView()
        ring.trackColor = .ypGray
        ring.progressColor = configuration.accentColor
        ring.progress = 0.82
        return ring
    }

    private func makeStatisticCard(value: String, titleKey: String, tintColor: UIColor) -> UIView {
        let view = UIView()
        view.backgroundColor = .ypGray
        view.layer.cornerRadius = 18

        let dot = UIView()
        dot.backgroundColor = tintColor
        dot.layer.cornerRadius = 5

        let valueLabel = makeMockupLabel(text: value, font: .ritmoBold(18), color: .ypBlack)
        let titleLabel = makeMockupLabel(text: NSLocalizedString(titleKey, comment: ""), font: .ritmoMedium(12), color: .ypLightGray)
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.78

        [dot, valueLabel, titleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            dot.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10),

            valueLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10),
            valueLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 30),

            titleLabel.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        return view
    }

    private func makeAdviceCard() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1)
        view.layer.cornerRadius = 22

        let icon = UIImageView(image: UIImage(systemName: "sparkles"))
        icon.tintColor = configuration.secondaryColor
        icon.contentMode = .scaleAspectFit

        let titleLabel = makeMockupLabel(text: NSLocalizedString("analytics.advice.title", comment: ""), font: .ritmoBold(17), color: .ypWhite)
        let detailLabel = makeMockupLabel(text: NSLocalizedString("onboarding.mockup.advice", comment: "Совет аналитики"), font: .ritmoMedium(13), color: UIColor.white.withAlphaComponent(0.72))
        detailLabel.numberOfLines = 2

        [icon, titleLabel, detailLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            icon.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -14)
        ])

        return view
    }

    private func makeHorizontalStack(_ views: [UIView], spacing: CGFloat) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: views)
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = spacing
        return stackView
    }

    private func makeCapsuleLabel(text: String, backgroundColor: UIColor, textColor: UIColor) -> UILabel {
        let label = PaddingLabel(horizontalInset: 12, verticalInset: 0)
        label.text = text
        label.font = .ritmoBold(13)
        label.textColor = textColor
        label.textAlignment = .center
        label.backgroundColor = backgroundColor
        label.layer.cornerRadius = 17
        label.layer.masksToBounds = true
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.76
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }

    private func makeMockupLabel(text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        return label
    }
}

private final class ProgressRingView: UIView {
    var progress: CGFloat = 0.0 {
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

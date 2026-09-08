import Foundation
import UIKit

protocol DayItemCellDelegate: AnyObject {
    func completeDayItem(id: UUID, at indexPath: IndexPath)
    func uncompletedDayItem(id: UUID, at indexPath: IndexPath)
}

final class DayItemCell: UICollectionViewCell {
    
    static let dayItemCellIdentifier = "DayItemCell"

    private let maximumNameFontSize: CGFloat = 15
    private let minimumNameFontSize: CGFloat = 10
    
    private var isCompletedToday: Bool = false
    private var dayItemId: UUID?
    private var indexPath: IndexPath?
    
    weak var delegate: DayItemCellDelegate?
    
    lazy var dayItemCardView: UIView = {
        let view = UIView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 24
        return view
    }()

    private lazy var topCircleView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 58
        return view
    }()

    private lazy var bottomCircleView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 34
        return view
    }()
    
    private lazy var dayItemCardEmojiLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 22
        label.textAlignment = .center
        label.font = .ladomiMedium(24)
        return label
    }()
    
    private lazy var dayItemCardNameLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiBold(maximumNameFontSize)
        label.textColor = .white
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()
    
    private lazy var pinImage: UIImageView = {
        let image = UIImageView()
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        image.image = UIImage(systemName: "pin.fill", withConfiguration: configuration)?.withRenderingMode(.alwaysTemplate)
        image.isHidden = true
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
        return image
    }()
    
    private lazy var emojiAndPinContainer: UIStackView = {
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let stack = UIStackView(arrangedSubviews: [dayItemCardEmojiLabel, spacer])
        
        dayItemCardEmojiLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        dayItemCardEmojiLabel.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stack.axis = .horizontal
        stack.alignment = .center
        return stack
    }()
    
    private lazy var dayItemCardContentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [emojiAndPinContainer, dayItemCardNameLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 4
        return stack
    }()
    
    private lazy var dayItemButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor.white.withAlphaComponent(0.24)
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 22
        button.imageEdgeInsets = UIEdgeInsets(top: 11, left: 11, bottom: 11, right: 11)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(didTapDayItemButton), for: .touchUpInside)
        return button
    }()
    
    private lazy var daysCounterLabel: UILabel = {
        let label = UILabel()
        let labelText = NSLocalizedString("dayItem.day", comment: "")
        label.text = "1 \(labelText)"
        label.textColor = .white
        label.font = .ladomiMedium(15)
        return label
    }()
    
    @objc private func didTapDayItemButton() {
        guard let id = dayItemId, let indexPath = indexPath else {
            assertionFailure("no dayItemId")
            return
        }
        isCompletedToday
            ? delegate?.uncompletedDayItem(id: id, at: indexPath)
            : delegate?.completeDayItem(id: id, at: indexPath)
        AnalyticsService.shared.report(event: "click", screen: "Main", item: "track")
    }
    
    private func setupUI() {
        dayItemCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dayItemCardView)

        [topCircleView, bottomCircleView, dayItemButton, daysCounterLabel, pinImage].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            dayItemCardView.addSubview($0)
        }
        
        dayItemCardContentStack.translatesAutoresizingMaskIntoConstraints = false
        dayItemCardView.addSubview(dayItemCardContentStack)
        
        NSLayoutConstraint.activate([
            dayItemCardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            dayItemCardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            dayItemCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dayItemCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            topCircleView.widthAnchor.constraint(equalToConstant: 116),
            topCircleView.heightAnchor.constraint(equalToConstant: 116),
            topCircleView.topAnchor.constraint(equalTo: dayItemCardView.topAnchor, constant: -30),
            topCircleView.trailingAnchor.constraint(equalTo: dayItemCardView.trailingAnchor, constant: 26),

            bottomCircleView.widthAnchor.constraint(equalToConstant: 68),
            bottomCircleView.heightAnchor.constraint(equalToConstant: 68),
            bottomCircleView.bottomAnchor.constraint(equalTo: dayItemCardView.bottomAnchor, constant: 22),
            bottomCircleView.trailingAnchor.constraint(equalTo: dayItemCardView.trailingAnchor, constant: 16),
            
            dayItemCardContentStack.topAnchor.constraint(equalTo: dayItemCardView.topAnchor, constant: 12),
            dayItemCardContentStack.leadingAnchor.constraint(equalTo: dayItemCardView.leadingAnchor, constant: 16),
            dayItemCardContentStack.trailingAnchor.constraint(equalTo: dayItemCardView.trailingAnchor, constant: -16),
            dayItemCardContentStack.bottomAnchor.constraint(lessThanOrEqualTo: dayItemCardView.bottomAnchor, constant: -60),
            
            pinImage.topAnchor.constraint(equalTo: dayItemCardView.topAnchor, constant: 19),
            pinImage.trailingAnchor.constraint(equalTo: dayItemCardView.trailingAnchor, constant: -19),
            pinImage.widthAnchor.constraint(equalToConstant: 17),
            pinImage.heightAnchor.constraint(equalToConstant: 17),
            
            dayItemButton.heightAnchor.constraint(equalToConstant: 44),
            dayItemButton.widthAnchor.constraint(equalToConstant: 44),
            dayItemButton.trailingAnchor.constraint(equalTo: dayItemCardView.trailingAnchor, constant: -16),
            dayItemButton.bottomAnchor.constraint(equalTo: dayItemCardView.bottomAnchor, constant: -16),
            
            daysCounterLabel.centerYAnchor.constraint(equalTo: dayItemButton.centerYAnchor),
            daysCounterLabel.leadingAnchor.constraint(equalTo: dayItemCardView.leadingAnchor, constant: 16),
        ])
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fitNameIntoTwoLines()
    }
    
    func configureCell(dayItem: DayItem, isCompletedToday: Bool, displayDays: Int, indexPath: IndexPath, isPinned: Bool) {
        self.dayItemId = dayItem.id
        self.isCompletedToday = isCompletedToday
        self.indexPath = indexPath
        dayItemCardView.backgroundColor = dayItem.color
        dayItemCardNameLabel.text = dayItem.name
        dayItemCardNameLabel.font = .ladomiBold(maximumNameFontSize)
        dayItemCardEmojiLabel.text = dayItem.emoji
        daysCounterLabel.isHidden = !(dayItem.isHabit || dayItem.isStopList)
        if dayItem.isStopList {
            let format = NSLocalizedString("stopList.cleanDaysFormat", comment: "Stop-list clean days counter")
            daysCounterLabel.text = String(format: format, pluralizeDays(displayDays))
        } else {
            daysCounterLabel.text = dayItem.isHabit ? pluralizeDays(displayDays) : nil
        }
        
        let imageName = isCompletedToday ? "doneButton" : "plusButton"
        if let image = UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate) {
            dayItemButton.setImage(image, for: .normal)
            dayItemButton.tintColor = .white
        }
        
        pinImage.isHidden = !isPinned
        pinImage.tintColor = .white
    }

    private func fitNameIntoTwoLines() {
        guard let text = dayItemCardNameLabel.text,
              !text.isEmpty,
              dayItemCardNameLabel.bounds.width > 0 else {
            return
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        let availableWidth = dayItemCardNameLabel.bounds.width
        var fontSize = maximumNameFontSize

        while fontSize > minimumNameFontSize {
            let font = UIFont.ladomiBold(fontSize)
            let textBounds = (text as NSString).boundingRect(
                with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [
                    .font: font,
                    .paragraphStyle: paragraphStyle
                ],
                context: nil
            )

            if ceil(textBounds.height) <= ceil(font.lineHeight * 2) {
                break
            }

            fontSize -= 0.5
        }

        let fittedSize = max(fontSize, minimumNameFontSize)
        if dayItemCardNameLabel.font.pointSize != fittedSize {
            dayItemCardNameLabel.font = .ladomiBold(fittedSize)
        }
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
}

import Foundation
import UIKit

protocol RitmoCellDelegate: AnyObject {
    func completeRitmo(id: UUID, at indexPath: IndexPath)
    func uncompletedRitmo(id: UUID, at indexPath: IndexPath)
}

final class RitmoCell: UICollectionViewCell {
    
    static let ritmoCellIdentifier = "RitmoCell"
    
    private var isCompletedToday: Bool = false
    private var ritmoId: UUID?
    private var indexPath: IndexPath?
    
    weak var delegate: RitmoCellDelegate?
    
    lazy var ritmoCardView: UIView = {
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
    
    private lazy var ritmoCardEmojiLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 22
        label.textAlignment = .center
        label.font = .ritmoMedium(24)
        return label
    }()
    
    private lazy var ritmoCardNameLabel: UILabel = {
        let label = UILabel()
        label.font = .ritmoBold(19)
        label.textColor = .white
        label.numberOfLines = 2
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
        
        let stack = UIStackView(arrangedSubviews: [ritmoCardEmojiLabel, spacer])
        
        ritmoCardEmojiLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        ritmoCardEmojiLabel.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stack.axis = .horizontal
        stack.alignment = .center
        return stack
    }()
    
    private lazy var ritmoCardContentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [emojiAndPinContainer, ritmoCardNameLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        return stack
    }()
    
    private lazy var ritmoButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor.white.withAlphaComponent(0.24)
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 22
        button.imageEdgeInsets = UIEdgeInsets(top: 11, left: 11, bottom: 11, right: 11)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(didTapRitmoButton), for: .touchUpInside)
        return button
    }()
    
    private lazy var daysCounterLabel: UILabel = {
        let label = UILabel()
        let labelText = NSLocalizedString("ritmo.day", comment: "")
        label.text = "1 \(labelText)"
        label.textColor = .white
        label.font = .ritmoMedium(15)
        return label
    }()
    
    @objc private func didTapRitmoButton() {
        guard let id = ritmoId, let indexPath = indexPath else {
            assertionFailure("no ritmoId")
            return
        }
        isCompletedToday
            ? delegate?.uncompletedRitmo(id: id, at: indexPath)
            : delegate?.completeRitmo(id: id, at: indexPath)
        AnalyticsService.shared.report(event: "click", screen: "Main", item: "track")
    }
    
    private func setupUI() {
        ritmoCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(ritmoCardView)

        [topCircleView, bottomCircleView, ritmoButton, daysCounterLabel, pinImage].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            ritmoCardView.addSubview($0)
        }
        
        ritmoCardContentStack.translatesAutoresizingMaskIntoConstraints = false
        ritmoCardView.addSubview(ritmoCardContentStack)
        
        NSLayoutConstraint.activate([
            ritmoCardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            ritmoCardView.heightAnchor.constraint(equalToConstant: 156),
            ritmoCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            ritmoCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            topCircleView.widthAnchor.constraint(equalToConstant: 116),
            topCircleView.heightAnchor.constraint(equalToConstant: 116),
            topCircleView.topAnchor.constraint(equalTo: ritmoCardView.topAnchor, constant: -30),
            topCircleView.trailingAnchor.constraint(equalTo: ritmoCardView.trailingAnchor, constant: 26),

            bottomCircleView.widthAnchor.constraint(equalToConstant: 68),
            bottomCircleView.heightAnchor.constraint(equalToConstant: 68),
            bottomCircleView.bottomAnchor.constraint(equalTo: ritmoCardView.bottomAnchor, constant: 22),
            bottomCircleView.trailingAnchor.constraint(equalTo: ritmoCardView.trailingAnchor, constant: 16),
            
            ritmoCardContentStack.topAnchor.constraint(equalTo: ritmoCardView.topAnchor, constant: 16),
            ritmoCardContentStack.leadingAnchor.constraint(equalTo: ritmoCardView.leadingAnchor, constant: 16),
            ritmoCardContentStack.trailingAnchor.constraint(equalTo: ritmoCardView.trailingAnchor, constant: -16),
            ritmoCardContentStack.bottomAnchor.constraint(lessThanOrEqualTo: ritmoCardView.bottomAnchor, constant: -58),
            
            pinImage.topAnchor.constraint(equalTo: ritmoCardView.topAnchor, constant: 19),
            pinImage.trailingAnchor.constraint(equalTo: ritmoCardView.trailingAnchor, constant: -19),
            pinImage.widthAnchor.constraint(equalToConstant: 17),
            pinImage.heightAnchor.constraint(equalToConstant: 17),
            
            ritmoButton.heightAnchor.constraint(equalToConstant: 44),
            ritmoButton.widthAnchor.constraint(equalToConstant: 44),
            ritmoButton.trailingAnchor.constraint(equalTo: ritmoCardView.trailingAnchor, constant: -16),
            ritmoButton.bottomAnchor.constraint(equalTo: ritmoCardView.bottomAnchor, constant: -16),
            
            daysCounterLabel.centerYAnchor.constraint(equalTo: ritmoButton.centerYAnchor),
            daysCounterLabel.leadingAnchor.constraint(equalTo: ritmoCardView.leadingAnchor, constant: 16),
        ])
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureCell(ritmo: Ritmo, isCompletedToday: Bool, completedDays: Int, indexPath: IndexPath, isPinned: Bool) {
        self.ritmoId = ritmo.id
        self.isCompletedToday = isCompletedToday
        self.indexPath = indexPath
        ritmoCardView.backgroundColor = ritmo.color
        ritmoCardNameLabel.text = ritmo.name
        ritmoCardEmojiLabel.text = ritmo.emoji
        daysCounterLabel.isHidden = !ritmo.isHabit
        daysCounterLabel.text = ritmo.isHabit ? pluralizeDays(completedDays) : nil
        
        let imageName = isCompletedToday ? "doneButton" : "plusButton"
        if let image = UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate) {
            ritmoButton.setImage(image, for: .normal)
            ritmoButton.tintColor = .white
        }
        
        pinImage.isHidden = !isPinned
        pinImage.tintColor = .white
    }
    
    private func pluralizeDays(_ count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100
        if remainder10 == 1 && remainder100 != 11 {
            let text = NSLocalizedString("ritmo.day", comment: "")
            return "\(count) \(text)"
        } else if remainder10 >= 2 && remainder10 <= 4 && (remainder100 < 10 || remainder100 >= 20) {
            let text = NSLocalizedString("ritmo.2,3,4day", comment: "")
            return "\(count) \(text)"
        } else {
            let text = NSLocalizedString("ritmo.days", comment: "")
            return "\(count) \(text)"
        }
    }
}

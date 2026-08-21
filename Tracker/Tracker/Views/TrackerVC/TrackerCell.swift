//
//  TrackerCell.swift
//  Tracker
//
//  Created by User on 30.03.2025.
//

import Foundation
import UIKit

protocol TrackerCellDelegate: AnyObject {
    func completeTracker(id: UUID, at indexPath: IndexPath)
    func uncompletedTracker(id: UUID, at indexPath: IndexPath)
}

final class TrackerCell: UICollectionViewCell {
    
    static let trackerCellIdentifier = "TrackerCell"
    
    private var isCompletedToday: Bool = false
    private var trackerId: UUID?
    private var indexPath: IndexPath?
    
    weak var delegate: TrackerCellDelegate?
    
    lazy var trackerCardView: UIView = {
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
    
    private lazy var trackerCardEmojiLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 22
        label.textAlignment = .center
        label.font = .trackerMedium(24)
        return label
    }()
    
    private lazy var trackerCardNameLabel: UILabel = {
        let label = UILabel()
        label.font = .trackerBold(19)
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
        
        let stack = UIStackView(arrangedSubviews: [trackerCardEmojiLabel, spacer])
        
        trackerCardEmojiLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        trackerCardEmojiLabel.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stack.axis = .horizontal
        stack.alignment = .center
        return stack
    }()
    
    private lazy var trackerCardContentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [emojiAndPinContainer, trackerCardNameLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        return stack
    }()
    
    private lazy var trackerButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor.white.withAlphaComponent(0.24)
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 22
        button.imageEdgeInsets = UIEdgeInsets(top: 11, left: 11, bottom: 11, right: 11)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(didTapTrackerButton), for: .touchUpInside)
        return button
    }()
    
    private lazy var daysCounterLabel: UILabel = {
        let label = UILabel()
        let labelText = NSLocalizedString("tracker.day", comment: "")
        label.text = "1 \(labelText)"
        label.textColor = .white
        label.font = .trackerMedium(15)
        return label
    }()
    
    @objc private func didTapTrackerButton() {
        guard let id = trackerId, let indexPath = indexPath else {
            assertionFailure("no trackerId")
            return
        }
        isCompletedToday
            ? delegate?.uncompletedTracker(id: id, at: indexPath)
            : delegate?.completeTracker(id: id, at: indexPath)
        AnalyticsService.shared.report(event: "click", screen: "Main", item: "track")
    }
    
    private func setupUI() {
        trackerCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(trackerCardView)

        [topCircleView, bottomCircleView, trackerButton, daysCounterLabel, pinImage].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            trackerCardView.addSubview($0)
        }
        
        trackerCardContentStack.translatesAutoresizingMaskIntoConstraints = false
        trackerCardView.addSubview(trackerCardContentStack)
        
        NSLayoutConstraint.activate([
            trackerCardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            trackerCardView.heightAnchor.constraint(equalToConstant: 156),
            trackerCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            trackerCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            topCircleView.widthAnchor.constraint(equalToConstant: 116),
            topCircleView.heightAnchor.constraint(equalToConstant: 116),
            topCircleView.topAnchor.constraint(equalTo: trackerCardView.topAnchor, constant: -30),
            topCircleView.trailingAnchor.constraint(equalTo: trackerCardView.trailingAnchor, constant: 26),

            bottomCircleView.widthAnchor.constraint(equalToConstant: 68),
            bottomCircleView.heightAnchor.constraint(equalToConstant: 68),
            bottomCircleView.bottomAnchor.constraint(equalTo: trackerCardView.bottomAnchor, constant: 22),
            bottomCircleView.trailingAnchor.constraint(equalTo: trackerCardView.trailingAnchor, constant: 16),
            
            trackerCardContentStack.topAnchor.constraint(equalTo: trackerCardView.topAnchor, constant: 16),
            trackerCardContentStack.leadingAnchor.constraint(equalTo: trackerCardView.leadingAnchor, constant: 16),
            trackerCardContentStack.trailingAnchor.constraint(equalTo: trackerCardView.trailingAnchor, constant: -16),
            trackerCardContentStack.bottomAnchor.constraint(lessThanOrEqualTo: trackerCardView.bottomAnchor, constant: -58),
            
            pinImage.topAnchor.constraint(equalTo: trackerCardView.topAnchor, constant: 19),
            pinImage.trailingAnchor.constraint(equalTo: trackerCardView.trailingAnchor, constant: -19),
            pinImage.widthAnchor.constraint(equalToConstant: 17),
            pinImage.heightAnchor.constraint(equalToConstant: 17),
            
            trackerButton.heightAnchor.constraint(equalToConstant: 44),
            trackerButton.widthAnchor.constraint(equalToConstant: 44),
            trackerButton.trailingAnchor.constraint(equalTo: trackerCardView.trailingAnchor, constant: -16),
            trackerButton.bottomAnchor.constraint(equalTo: trackerCardView.bottomAnchor, constant: -16),
            
            daysCounterLabel.centerYAnchor.constraint(equalTo: trackerButton.centerYAnchor),
            daysCounterLabel.leadingAnchor.constraint(equalTo: trackerCardView.leadingAnchor, constant: 16),
        ])
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureCell(tracker: Tracker, isCompletedToday: Bool, completedDays: Int, indexPath: IndexPath, isPinned: Bool) {
        self.trackerId = tracker.id
        self.isCompletedToday = isCompletedToday
        self.indexPath = indexPath
        trackerCardView.backgroundColor = tracker.color
        trackerCardNameLabel.text = tracker.name
        trackerCardEmojiLabel.text = tracker.emoji
        daysCounterLabel.isHidden = !tracker.isHabit
        daysCounterLabel.text = tracker.isHabit ? pluralizeDays(completedDays) : nil
        
        let imageName = isCompletedToday ? "doneButton" : "plusButton"
        if let image = UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate) {
            trackerButton.setImage(image, for: .normal)
            trackerButton.tintColor = .white
        }
        
        pinImage.isHidden = !isPinned
        pinImage.tintColor = .white
    }
    
    private func pluralizeDays(_ count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100
        if remainder10 == 1 && remainder100 != 11 {
            let text = NSLocalizedString("tracker.day", comment: "")
            return "\(count) \(text)"
        } else if remainder10 >= 2 && remainder10 <= 4 && (remainder100 < 10 || remainder100 >= 20) {
            let text = NSLocalizedString("tracker.2,3,4day", comment: "")
            return "\(count) \(text)"
        } else {
            let text = NSLocalizedString("tracker.days", comment: "")
            return "\(count) \(text)"
        }
    }
}

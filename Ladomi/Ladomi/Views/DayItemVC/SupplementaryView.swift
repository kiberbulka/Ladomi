import Foundation
import UIKit

final class SupplementaryView: UICollectionReusableView {

    private var titleLeadingConstraint: NSLayoutConstraint!
    private var countTrailingConstraint: NSLayoutConstraint!
    
    private lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = .ladomiBold(20)
        titleLabel.textColor = .ypBlack
        return titleLabel
    }()

    private lazy var countLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiBold(16)
        label.textColor = .ypLightGray
        label.textAlignment = .right
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        [titleLabel, countLabel].forEach {
            addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        titleLeadingConstraint = titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20)
        countTrailingConstraint = countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)

        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLeadingConstraint,

            countLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            countTrailingConstraint,
            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(text: String, count: Int, horizontalInset: CGFloat = 20) {
        titleLabel.text = text
        countLabel.text = "\(count)"
        titleLeadingConstraint.constant = horizontalInset
        countTrailingConstraint.constant = -horizontalInset
    }
}

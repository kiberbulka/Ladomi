//
//  SupplementaryView.swift
//  Tracker
//
//  Created by User on 30.03.2025.
//

import Foundation
import UIKit

final class SupplementaryView: UICollectionReusableView {
    
    private lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = .trackerBold(20)
        titleLabel.textColor = .ypBlack
        return titleLabel
    }()

    private lazy var countLabel: UILabel = {
        let label = UILabel()
        label.font = .trackerBold(16)
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
        
        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            countLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(text: String, count: Int) {
        titleLabel.text = text
        countLabel.text = "\(count)"
    }
}

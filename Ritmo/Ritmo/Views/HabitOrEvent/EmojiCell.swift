//
//  EmojiCell.swift
//  Ritmo
//
//  Created by User on 13.04.2025.
//

import Foundation
import UIKit

final class EmojiCell: UICollectionViewCell {
    static let cellIdentifier = "EmojiCell"
    
    private lazy var label: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 18
        label.layer.borderWidth = 2
        label.layer.borderColor = UIColor.clear.cgColor
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(){
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.heightAnchor.constraint(equalToConstant: frame.width),
            label.widthAnchor.constraint(equalToConstant: frame.width),
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configureEmoji(emoji: String) {
        label.text = emoji
    }
    
    func updateSelection(isSelected: Bool) {
        label.backgroundColor = isSelected
            ? UIColor(red: 0.90, green: 0.91, blue: 0.92, alpha: 1)
            : .clear
        label.layer.borderColor = UIColor.clear.cgColor
    }
}

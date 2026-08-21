//
//  ColorCell.swift
//  Tracker
//
//  Created by User on 13.04.2025.
//

import Foundation
import UIKit

final class ColorCell: UICollectionViewCell {
    static let cellIdentifier = "ColorCell"
    
    private lazy var colorImage: UIView = {
        let view = UIView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 8
        return view
    }()
    
    private lazy var frameView: UIImageView = {
        let image = UIImageView()
        image.image = .frame.withRenderingMode(.alwaysTemplate)
        image.isHidden = true
        return image
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(){
        contentView.addSubview(colorImage)
        contentView.addSubview(frameView)
        frameView.translatesAutoresizingMaskIntoConstraints = false
        colorImage.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            colorImage.heightAnchor.constraint(equalToConstant: frame.width - 12),
            colorImage.widthAnchor.constraint(equalToConstant: frame.width - 12),
            colorImage.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            colorImage.centerYAnchor
                .constraint(equalTo: contentView.centerYAnchor),
            
            frameView.topAnchor.constraint(equalTo: contentView.topAnchor),
            frameView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            frameView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            frameView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            
        ])
    }
    
    func updateColor(color: UIColor) {
        colorImage.backgroundColor = color
    }
    
    func updateFrameColor(color: UIColor, isHidden: Bool) {
        frameView.tintColor = color
        frameView.isHidden = isHidden
    }
    
    
}


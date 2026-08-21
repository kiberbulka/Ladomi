//
//  GradientBorderView.swift
//  Tracker
//
//  Created by Olya on 17.05.2025.
//

import Foundation

import UIKit

final class GradientBorderView: UIView {
    
    private let gradientLayer = CAGradientLayer()
    private let borderLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        backgroundColor = .ypWhite
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        gradientLayer.colors = [
            UIColor(red: 0/255, green: 123/255, blue: 250/255, alpha: 1).cgColor,
            UIColor(red: 70/255, green: 230/255, blue: 157/255, alpha: 1).cgColor,
            UIColor(red: 253/255, green: 76/255, blue: 73/255, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 0, y: 0.5)
        layer.addSublayer(gradientLayer)
        
        borderLayer.lineWidth = 1
        borderLayer.strokeColor = UIColor.black.cgColor
        borderLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(borderLayer)
        
        gradientLayer.mask = borderLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        let cornerRadius = layer.cornerRadius
        let path = UIBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerRadius: cornerRadius).cgPath
        borderLayer.path = path
        borderLayer.cornerRadius = cornerRadius
    }
}

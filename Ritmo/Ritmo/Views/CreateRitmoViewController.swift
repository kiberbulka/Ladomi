//
//  TrackOrHabitView.swift
//  Ritmo
//
//  Created by User on 30.03.2025.
//

import Foundation
import UIKit

final class CreateRitmoViewController: UIViewController {
    
    weak var delegate: NewHabitOrEventViewControllerDelegate?
    var selectedDate: Date = Date()
    
    private lazy var createHabitButton: UIButton = {
        let button = UIButton(type: .system)
        let buttonText = NSLocalizedString("habit", comment: "Кнопка на экране выбора создания трекера или привычки")
        button.setTitle(buttonText, for: .normal)
        button.backgroundColor = .ypWhite
        button.setTitleColor(.ypBlack, for: .normal)
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 24
        button.titleLabel?.font = .ritmoBold(22)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.85
        button.titleLabel?.lineBreakMode = .byClipping
        button.contentHorizontalAlignment = .leading
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 84, bottom: 0, right: 20)
        button.addTarget(self, action: #selector(createHabitButtonDidTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var createEventButton: UIButton = {
        let button = UIButton(type: .system)
        let buttonText = NSLocalizedString("irregularEvent", comment: "Кнопка на экране выбора создания трекера или привычки")
        button.setTitle(buttonText, for: .normal)
        button.backgroundColor = .ypWhite
        button.setTitleColor(.ypBlack, for: .normal)
        button.layer.masksToBounds = true
        button.titleLabel?.font = .ritmoBold(22)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.75
        button.titleLabel?.lineBreakMode = .byClipping
        button.layer.cornerRadius = 24
        button.contentHorizontalAlignment = .leading
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 84, bottom: 0, right: 20)
        button.addTarget(self, action: #selector(createEventButtonDidTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var createLabel: UILabel = {
        let label = UILabel()
        let labelText = NSLocalizedString("createRitmo.title", comment: "Заголовок экрана создания трекера")
        label.text = labelText
        label.font = .ritmoBold(32)
        label.textColor = .ypBlack
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.82
        return label
    }()

    private lazy var habitIconBackgroundView = makeIconBackground(color: .ypBlue, symbolName: "repeat")
    private lazy var eventIconBackgroundView = makeIconBackground(color: .colorSection3, symbolName: "star.fill")
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1)
        setupUI()
    }
    
    private func setupUI(){
        [createHabitButton, createEventButton, createLabel, habitIconBackgroundView, eventIconBackgroundView].forEach{
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            createHabitButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            createHabitButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            createHabitButton.heightAnchor.constraint(equalToConstant: 132),
            createHabitButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -70),
            createEventButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            createEventButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            createEventButton.heightAnchor.constraint(equalToConstant: 132),
            createEventButton.topAnchor.constraint(equalTo: createHabitButton.bottomAnchor, constant: 16),
            createLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 27),
            createLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            habitIconBackgroundView.leadingAnchor.constraint(equalTo: createHabitButton.leadingAnchor, constant: 18),
            habitIconBackgroundView.centerYAnchor.constraint(equalTo: createHabitButton.centerYAnchor),
            habitIconBackgroundView.heightAnchor.constraint(equalToConstant: 56),
            habitIconBackgroundView.widthAnchor.constraint(equalToConstant: 56),

            eventIconBackgroundView.leadingAnchor.constraint(equalTo: createEventButton.leadingAnchor, constant: 18),
            eventIconBackgroundView.centerYAnchor.constraint(equalTo: createEventButton.centerYAnchor),
            eventIconBackgroundView.heightAnchor.constraint(equalToConstant: 56),
            eventIconBackgroundView.widthAnchor.constraint(equalToConstant: 56)
        ])
    }

    private func makeIconBackground(color: UIColor, symbolName: String) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.isUserInteractionEnabled = false

        let imageView = UIImageView(image: UIImage(systemName: symbolName))
        imageView.tintColor = .ypWhite
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 26),
            imageView.widthAnchor.constraint(equalToConstant: 26)
        ])

        return view
    }
    
    @objc private func createHabitButtonDidTap(){
        let createNewHabitVC = NewHabitOrEventViewController()
        createNewHabitVC.delegate = delegate
        createNewHabitVC.isHabit = true
        present(createNewHabitVC, animated: true)
    }
    
    @objc private func createEventButtonDidTap(){
        let createNewEventVC = NewHabitOrEventViewController()
        createNewEventVC.delegate = delegate
        createNewEventVC.isHabit = false
        createNewEventVC.selectedEventDate = selectedDate
        present(createNewEventVC, animated: true)
    }
}

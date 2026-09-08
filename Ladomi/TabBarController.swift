import Foundation
import UIKit

private final class BottomNavigationItemControl: UIControl {
    private let normalImage: UIImage?
    private let selectedImage: UIImage?

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .ladomiMedium(11)
        return label
    }()

    init(title: String, normalImage: UIImage?, selectedImage: UIImage?) {
        self.normalImage = normalImage
        self.selectedImage = selectedImage ?? normalImage
        super.init(frame: .zero)

        titleLabel.text = title
        accessibilityLabel = title

        let stackView = UIStackView(arrangedSubviews: [iconImageView, titleLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelectedAppearance(_ selected: Bool) {
        iconImageView.image = selected ? selectedImage : normalImage
        iconImageView.tintColor = selected ? .ypBlue : .ypLightGray
        titleLabel.textColor = selected ? .ypBlue : .ypBlack
        titleLabel.font = selected ? .ladomiBold(11) : .ladomiMedium(11)
        accessibilityTraits = selected ? [.button, .selected] : [.button]
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.55 : 1
        }
    }
}

private final class AdaptiveContentContainerViewController: UIViewController {
    let contentViewController: UIViewController
    private var contentLeadingConstraint: NSLayoutConstraint!

    init(contentViewController: UIViewController) {
        self.contentViewController = contentViewController
        super.init(nibName: nil, bundle: nil)
        tabBarItem = contentViewController.tabBarItem
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        addChild(contentViewController)
        contentViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentViewController.view)
        contentLeadingConstraint = contentViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        NSLayoutConstraint.activate([
            contentLeadingConstraint,
            contentViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            contentViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        contentViewController.didMove(toParent: self)
    }

    func setContentLeadingInset(_ inset: CGFloat) {
        loadViewIfNeeded()
        contentLeadingConstraint.constant = inset
    }

    override var childForStatusBarStyle: UIViewController? {
        contentViewController
    }

    override var childForStatusBarHidden: UIViewController? {
        contentViewController
    }
}

final class TabBarController: UITabBarController {

    private let sidebarWidth: CGFloat = 264
    private let sidebarOuterMargin: CGFloat = 20
    private let bottomNavigationHeight: CGFloat = 72
    private var isShowingSidebar = false
    private var isShowingBottomNavigation = false
    private var sidebarButtons: [UIButton] = []
    private var bottomNavigationItems: [BottomNavigationItemControl] = []
    private var sidebarImages: [(normal: UIImage?, selected: UIImage?)] = []

    private lazy var sidebarView: UIView = {
        let view = UIView()
        view.backgroundColor = .ypWhite
        view.layer.cornerRadius = 30
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.06
        view.layer.shadowRadius = 20
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        return view
    }()

    private lazy var sidebarTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Ladomi"
        label.font = .ladomiBold(28)
        label.textColor = .ypBlack
        return label
    }()

    private lazy var bottomNavigationView: UIView = {
        let view = UIView()
        view.backgroundColor = .ypWhite
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowRadius = 12
        view.layer.shadowOffset = CGSize(width: 0, height: -3)
        return view
    }()

    private lazy var sidebarCreateButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .ypBlack
        button.tintColor = .ypWhite
        button.setTitleColor(.ypWhite, for: .normal)
        button.setTitle(NSLocalizedString("sidebar.newPlan", comment: "Create plan from iPad sidebar"), for: .normal)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.titleLabel?.font = .ladomiBold(16)
        button.contentHorizontalAlignment = .leading
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 22, bottom: 0, right: 18)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(sidebarCreateButtonDidTap), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTabBarTypography()
        configureViewControllers()

        guard traitCollection.userInterfaceIdiom == .pad else { return }

        view.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1)
        if #available(iOS 18.0, *) {
            mode = .tabBar
        }
        configureTabBarAppearance()
        configureSidebar()
        configureBottomNavigation()
        delegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard traitCollection.userInterfaceIdiom == .pad else { return }
        updateAdaptiveNavigation(animated: false)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard traitCollection.userInterfaceIdiom == .pad else { return }
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.updateAdaptiveNavigation(animated: false, proposedSize: size)
            self?.view.layoutIfNeeded()
        })
    }

    private func configureViewControllers() {
        let dayViewController = DayViewController()
        if traitCollection.userInterfaceIdiom == .pad {
            dayViewController.onStopListModeChange = { [weak self] isStopListMode in
                self?.updateSidebarCreateButtonTitle(isStopListMode: isStopListMode)
            }
        }
        let dayItemViewController = UINavigationController(rootViewController: dayViewController)
        let archiveViewController = ArchivedDayItemsViewController()
        let calendarViewController = DayCalendarViewController()
        let statisticViewController = StatisticViewController()

        let dayItemsTitle = NSLocalizedString("day.tab.title", comment: "Day tab title")
        let archiveTitle = NSLocalizedString("archive.title", comment: "Archive tab title")
        let calendarTitle = NSLocalizedString("calendar.title", comment: "Calendar tab title")
        let statisticsTitle = NSLocalizedString("analytics.title", comment: "Analytics tab title")

        dayItemViewController.tabBarItem = UITabBarItem(
            title: dayItemsTitle,
            image: UIImage(named: "dayTabBarItem"),
            selectedImage: UIImage(named: "selectedDayTabBarItem")
        )
        archiveViewController.tabBarItem = UITabBarItem(
            title: archiveTitle,
            image: UIImage(systemName: "archivebox"),
            selectedImage: UIImage(systemName: "archivebox.fill")
        )
        calendarViewController.tabBarItem = UITabBarItem(
            title: calendarTitle,
            image: UIImage(systemName: "calendar"),
            selectedImage: UIImage(systemName: "calendar.circle.fill")
        )
        statisticViewController.tabBarItem = UITabBarItem(
            title: statisticsTitle,
            image: UIImage(named: "statisticsTabBarItem"),
            selectedImage: UIImage(named: "selectedStatisticsTabBarItem")
        )

        let contentViewControllers: [UIViewController] = [
            dayItemViewController,
            archiveViewController,
            calendarViewController,
            statisticViewController
        ]
        if traitCollection.userInterfaceIdiom == .pad {
            viewControllers = contentViewControllers.map {
                AdaptiveContentContainerViewController(contentViewController: $0)
            }
        } else {
            viewControllers = contentViewControllers
        }
    }

    private func configureTabBarTypography() {
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.ladomiMedium(12),
            .foregroundColor: UIColor.ypBlack
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.ladomiBold(12),
            .foregroundColor: UIColor.ypBlue
        ]

        UITabBarItem.appearance().setTitleTextAttributes(normalAttributes, for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(selectedAttributes, for: .selected)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .ypWhite
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.08)
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = .ypBlue
        tabBar.unselectedItemTintColor = .ypLightGray
        tabBar.itemPositioning = .centered
        tabBar.itemSpacing = 72
    }

    private func configureSidebar() {
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sidebarView)

        sidebarTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        sidebarCreateButton.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(sidebarTitleLabel)
        sidebarView.addSubview(sidebarCreateButton)

        let tabBarItems: [UITabBarItem] = (viewControllers ?? []).compactMap { $0.tabBarItem }
        sidebarImages = tabBarItems.map { item in
            (
                normal: item.image?.withRenderingMode(.alwaysTemplate),
                selected: (item.selectedImage ?? item.image)?.withRenderingMode(.alwaysTemplate)
            )
        }

        let buttons = tabBarItems.enumerated().map { index, item in
            makeSidebarButton(
                title: item.title ?? "",
                image: sidebarImages[index].normal,
                index: index
            )
        }
        sidebarButtons = buttons

        let navigationStack = UIStackView(arrangedSubviews: buttons)
        navigationStack.axis = .vertical
        navigationStack.spacing = 8
        navigationStack.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(navigationStack)

        NSLayoutConstraint.activate([
            sidebarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sidebarOuterMargin),
            sidebarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            sidebarView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            sidebarView.widthAnchor.constraint(equalToConstant: sidebarWidth),

            sidebarTitleLabel.topAnchor.constraint(equalTo: sidebarView.topAnchor, constant: 34),
            sidebarTitleLabel.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: 28),
            sidebarTitleLabel.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -28),

            sidebarCreateButton.topAnchor.constraint(equalTo: sidebarTitleLabel.bottomAnchor, constant: 28),
            sidebarCreateButton.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: 22),
            sidebarCreateButton.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -22),
            sidebarCreateButton.heightAnchor.constraint(equalToConstant: 56),

            navigationStack.topAnchor.constraint(equalTo: sidebarCreateButton.bottomAnchor, constant: 28),
            navigationStack.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: 18),
            navigationStack.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -18)
        ])

        sidebarView.isHidden = true
        updateNavigationSelection()
    }

    private func configureBottomNavigation() {
        bottomNavigationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomNavigationView)

        let tabBarItems: [UITabBarItem] = (viewControllers ?? []).compactMap { $0.tabBarItem }
        bottomNavigationItems = tabBarItems.enumerated().map { index, item in
            let images = sidebarImages[index]
            let control = BottomNavigationItemControl(
                title: item.title ?? "",
                normalImage: images.normal,
                selectedImage: images.selected
            )
            control.tag = index
            control.addTarget(self, action: #selector(bottomNavigationItemDidTap(_:)), for: .touchUpInside)
            return control
        }

        let stackView = UIStackView(arrangedSubviews: bottomNavigationItems)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        bottomNavigationView.addSubview(stackView)

        NSLayoutConstraint.activate([
            bottomNavigationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomNavigationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomNavigationView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -bottomNavigationHeight
            ),
            bottomNavigationView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: bottomNavigationView.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(equalTo: bottomNavigationView.trailingAnchor, constant: -32),
            stackView.topAnchor.constraint(equalTo: bottomNavigationView.topAnchor, constant: 6),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4)
        ])

        bottomNavigationView.isHidden = true
        updateNavigationSelection()
    }

    private func makeSidebarButton(
        title: String,
        image: UIImage?,
        index: Int
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        button.setTitle(title, for: .normal)
        button.setImage(image, for: .normal)
        button.titleLabel?.font = .ladomiMedium(16)
        button.contentHorizontalAlignment = .leading
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 16)
        button.imageEdgeInsets = .zero
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 0)
        button.layer.cornerRadius = 18
        button.heightAnchor.constraint(equalToConstant: 54).isActive = true
        button.addTarget(self, action: #selector(sidebarNavigationButtonDidTap(_:)), for: .touchUpInside)
        return button
    }

    private func updateAdaptiveNavigation(animated: Bool, proposedSize: CGSize? = nil) {
        let size = proposedSize ?? view.bounds.size
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let shouldShowSidebar = isPad && size.width > size.height
        let shouldShowBottomNavigation = isPad && !shouldShowSidebar
        let navigationDidChange = shouldShowSidebar != isShowingSidebar
            || shouldShowBottomNavigation != isShowingBottomNavigation

        setSystemTabBarHidden(isPad, animated: animated)
        sidebarView.isHidden = !shouldShowSidebar
        bottomNavigationView.isHidden = !shouldShowBottomNavigation

        viewControllers?.forEach { controller in
            controller.additionalSafeAreaInsets.bottom = shouldShowBottomNavigation ? bottomNavigationHeight : 0
        }

        guard navigationDidChange else {
            if shouldShowSidebar {
                view.bringSubviewToFront(sidebarView)
            } else if shouldShowBottomNavigation {
                view.bringSubviewToFront(bottomNavigationView)
            }
            return
        }

        isShowingSidebar = shouldShowSidebar
        isShowingBottomNavigation = shouldShowBottomNavigation

        let contentInset = shouldShowSidebar ? sidebarOuterMargin + sidebarWidth + 20 : 0
        viewControllers?.forEach { controller in
            (controller as? AdaptiveContentContainerViewController)?.setContentLeadingInset(contentInset)
        }

        if shouldShowSidebar {
            view.bringSubviewToFront(sidebarView)
        } else if shouldShowBottomNavigation {
            view.bringSubviewToFront(bottomNavigationView)
        }
        updateNavigationSelection()
        view.setNeedsLayout()
    }

    private func setSystemTabBarHidden(_ hidden: Bool, animated: Bool) {
        if #available(iOS 18.0, *) {
            guard isTabBarHidden != hidden else { return }
            setTabBarHidden(hidden, animated: animated)
        } else {
            tabBar.isHidden = hidden
        }
    }

    private func updateNavigationSelection() {
        sidebarButtons.forEach { button in
            let isSelected = button.tag == selectedIndex
            if sidebarImages.indices.contains(button.tag) {
                let images = sidebarImages[button.tag]
                button.setImage(isSelected ? images.selected : images.normal, for: .normal)
            }
            button.backgroundColor = isSelected ? UIColor.ypBlue.withAlphaComponent(0.10) : .clear
            button.tintColor = isSelected ? .ypBlue : .ypLightGray
            button.setTitleColor(isSelected ? .ypBlue : .ypBlack, for: .normal)
            button.titleLabel?.font = isSelected ? .ladomiBold(16) : .ladomiMedium(16)
        }

        bottomNavigationItems.forEach { item in
            item.setSelectedAppearance(item.tag == selectedIndex)
        }
    }

    private func updateSidebarCreateButtonTitle(isStopListMode: Bool) {
        let key = isStopListMode ? "sidebar.newStopItem" : "sidebar.newPlan"
        sidebarCreateButton.setTitle(
            NSLocalizedString(key, comment: "Contextual create button in iPad sidebar"),
            for: .normal
        )
    }

    @objc private func sidebarNavigationButtonDidTap(_ sender: UIButton) {
        selectedIndex = sender.tag
        updateNavigationSelection()
        view.setNeedsLayout()
    }

    @objc private func bottomNavigationItemDidTap(_ sender: BottomNavigationItemControl) {
        selectedIndex = sender.tag
        updateNavigationSelection()
        view.setNeedsLayout()
    }

    @objc private func sidebarCreateButtonDidTap() {
        selectedIndex = 0
        updateNavigationSelection()

        guard let container = selectedViewController as? AdaptiveContentContainerViewController,
              let navigationController = container.contentViewController as? UINavigationController,
              let dayViewController = navigationController.viewControllers.first as? DayViewController else {
            return
        }
        dayViewController.presentCreateDayItem()
    }
}

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        updateNavigationSelection()
        self.view.setNeedsLayout()
    }
}

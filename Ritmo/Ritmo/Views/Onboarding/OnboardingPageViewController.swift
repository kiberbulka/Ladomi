import UIKit

final class OnboardingPageViewController: UIPageViewController {
    
    private lazy var pages: [OnboardingContentViewController] = {
        let dayPage = OnboardingContentViewController(
            configuration: OnboardingPageConfiguration(
                titleKey: "onboarding.day.title",
                subtitleKey: "onboarding.day.subtitle",
                accentColor: UIColor(red: 0.36, green: 0.39, blue: 0.98, alpha: 1),
                secondaryColor: UIColor(red: 1.00, green: 0.47, blue: 0.42, alpha: 1),
                isAnalyticsFocused: false
            )
        )
        let analyticsPage = OnboardingContentViewController(
            configuration: OnboardingPageConfiguration(
                titleKey: "onboarding.analytics.title",
                subtitleKey: "onboarding.analytics.subtitle",
                accentColor: UIColor(red: 0.95, green: 0.44, blue: 0.70, alpha: 1),
                secondaryColor: UIColor(red: 0.98, green: 0.75, blue: 0.18, alpha: 1),
                isAnalyticsFocused: true
            )
        )
        
        dayPage.button.setTitle(NSLocalizedString("onboarding.button.next", comment: "Next onboarding page button"), for: .normal)
        dayPage.button.addTarget(self, action: #selector(showNextOnboardingPage), for: .touchUpInside)
        analyticsPage.button.addTarget(self, action: #selector(finishOnboarding), for: .touchUpInside)
        return [dayPage, analyticsPage]
    }()
    
    private let pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.numberOfPages = 2
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = .lightGray
        pageControl.currentPageIndicatorTintColor = .black
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        return pageControl
    }()

    
    private var currentIndex = 0
    
    init() {
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate = self
        setViewControllers([pages[0]], direction: .forward, animated: true)
        view.addSubview(pageControl)

        NSLayoutConstraint.activate([
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -106),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    @objc private func finishOnboarding() {
        guard let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate else { return }
        sceneDelegate.completeOnboarding()
        sceneDelegate.changeRootViewController(TabBarController())
    }

    @objc private func showNextOnboardingPage() {
        let nextIndex = currentIndex + 1
        guard pages.indices.contains(nextIndex) else {
            finishOnboarding()
            return
        }

        setViewControllers([pages[nextIndex]], direction: .forward, animated: true)
        currentIndex = nextIndex
        pageControl.currentPage = nextIndex
    }
}

extension OnboardingPageViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let index = pages.firstIndex(of: viewController as! OnboardingContentViewController), index > 0 else { return nil }
        return pages[index - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let index = pages.firstIndex(of: viewController as! OnboardingContentViewController), index < pages.count - 1 else { return nil }
        return pages[index + 1]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        if completed,
           let currentVC = pageViewController.viewControllers?.first,
           let index = pages.firstIndex(of: currentVC as! OnboardingContentViewController) {
            currentIndex = index
            pageControl.currentPage = index
        }
    }

}

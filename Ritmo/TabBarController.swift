import Foundation
import UIKit

final class TabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTabBarTypography()
        
        let ritmoViewController = UINavigationController(rootViewController: RitmosViewController())
        let archiveViewController = ArchivedRitmosViewController()
        let calendarViewController = DayCalendarViewController()
        let statisticViewController = StatisticViewController()
        
        let tabBarItemTextRitmos = NSLocalizedString("day.tab.title", comment: "Заголовок вкладки дня")
        let tabBarItemTextArchive = NSLocalizedString("archive.title", comment: "Заголовок таб бара архива")
        let tabBarItemTextCalendar = NSLocalizedString("calendar.title", comment: "Заголовок таб бара календаря")
        let tabBarItemTextStatistics = NSLocalizedString("analytics.title", comment: "Заголовок таб бара аналитики")
        
        
        ritmoViewController.tabBarItem = UITabBarItem(
            title: tabBarItemTextRitmos,
            image: UIImage(
                named: "ritmosTabBarItem"
            ) ,
            selectedImage: UIImage(
                named: "selectedRitmosTabBarItem"
            )
        )
        archiveViewController.tabBarItem = UITabBarItem(
            title: tabBarItemTextArchive,
            image: UIImage(systemName: "archivebox"),
            selectedImage: UIImage(systemName: "archivebox.fill")
        )
        calendarViewController.tabBarItem = UITabBarItem(
            title: tabBarItemTextCalendar,
            image: UIImage(systemName: "calendar"),
            selectedImage: UIImage(systemName: "calendar.circle.fill")
        )
        statisticViewController.tabBarItem = UITabBarItem(
            title: tabBarItemTextStatistics,
            image: UIImage(
                named: "statisticsTabBarItem"
            ),
            selectedImage: UIImage(
                named: "selectedStatisticsTabBarItem"
            )
        )
        
        self.viewControllers = [ritmoViewController, archiveViewController, calendarViewController, statisticViewController]
    }

    private func configureTabBarTypography() {
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.ritmoMedium(12),
            .foregroundColor: UIColor.ypBlack
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.ritmoBold(12),
            .foregroundColor: UIColor.ypBlue
        ]

        UITabBarItem.appearance().setTitleTextAttributes(normalAttributes, for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(selectedAttributes, for: .selected)
    }
}

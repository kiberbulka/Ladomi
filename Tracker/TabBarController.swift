//
//  TabBarController.swift
//  Tracker
//
//  Created by User on 21.03.2025.
//

import Foundation
import UIKit

final class TabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTabBarTypography()
        
        let trackerViewController = UINavigationController(rootViewController: TrackersViewController())
        let archiveViewController = ArchivedTrackersViewController()
        let calendarViewController = DayCalendarViewController()
        let statisticViewController = StatisticViewController()
        
        let tabBarItemTextTrackers = NSLocalizedString("trackers.title", comment: "Заголовок таб бара")
        let tabBarItemTextArchive = NSLocalizedString("archive.title", comment: "Заголовок таб бара архива")
        let tabBarItemTextCalendar = NSLocalizedString("calendar.title", comment: "Заголовок таб бара календаря")
        let tabBarItemTextStatistics = NSLocalizedString("analytics.title", comment: "Заголовок таб бара аналитики")
        
        
        trackerViewController.tabBarItem = UITabBarItem(
            title: tabBarItemTextTrackers,
            image: UIImage(
                named: "trackersTabBarItem"
            ) ,
            selectedImage: UIImage(
                named: "selectedTrackersTabBarItem"
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
        
        self.viewControllers = [trackerViewController, archiveViewController, calendarViewController, statisticViewController]
    }

    private func configureTabBarTypography() {
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.trackerMedium(12),
            .foregroundColor: UIColor.ypBlack
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.trackerBold(12),
            .foregroundColor: UIColor.ypBlue
        ]

        UITabBarItem.appearance().setTitleTextAttributes(normalAttributes, for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(selectedAttributes, for: .selected)
    }
}

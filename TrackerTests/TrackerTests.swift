//
//  TrackerTests.swift
//  TrackerTests
//
//  Created by Olya on 19.05.2025.
//

import XCTest
import SnapshotTesting
@testable import Tracker

final class TrackerTests: XCTestCase {

    func testViewController() {
        
        let vc = TrackersViewController()
        
        let nav = UINavigationController(rootViewController: vc)
        
        assertSnapshot(of: nav, as: .image)
    }

}

//
//  RitmoTests.swift
//  RitmoTests
//
//  Created by Olya on 19.05.2025.
//

import XCTest
import SnapshotTesting
@testable import Ritmo

final class RitmoTests: XCTestCase {

    func testViewController() {
        
        let vc = RitmosViewController()
        
        let nav = UINavigationController(rootViewController: vc)
        
        assertSnapshot(of: nav, as: .image)
    }

}

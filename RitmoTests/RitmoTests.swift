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

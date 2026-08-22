import XCTest
import SnapshotTesting
@testable import Ladomi

final class LadomiTests: XCTestCase {

    func testViewController() {
        
        let vc = DayViewController()
        
        let nav = UINavigationController(rootViewController: vc)
        
        assertSnapshot(of: nav, as: .image)
    }

}

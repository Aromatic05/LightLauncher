import XCTest
@testable import LightLauncher

final class HotkeyManagerTests: XCTestCase {
    func testNeedsPhysical_whenSideSpecifiedOrModifierOnly() {
        let hk1 = HotKey(keyCode: 0, option: true, side: .left) // modifier-only left option
        let hk2 = HotKey(keyCode: 0x0028, command: true, option: true) // combination without side
        let hk3 = HotKey(keyCode: 0x0028, option: true, side: .right) // side-specified combo

        // Helper mimics internal decision logic used in registerAll
        let all1 = [hk1, hk2]
        let needsPhysical1 = all1.contains { $0.hasSideSpecification || $0.isModifierOnly }
        XCTAssertTrue(needsPhysical1)

        let all2 = [hk2]
        let needsPhysical2 = all2.contains { $0.hasSideSpecification || $0.isModifierOnly }
        XCTAssertFalse(needsPhysical2)

        let all3 = [hk3]
        let needsPhysical3 = all3.contains { $0.hasSideSpecification || $0.isModifierOnly }
        XCTAssertTrue(needsPhysical3)
    }

    func testNeedsCarbon_whenNormalCombosExist() {
        let hk1 = HotKey(keyCode: 0x0028, command: true) // normal combo
        let hk2 = HotKey(keyCode: 0, option: true, side: .left) // modifier only

        let all = [hk1, hk2]
        let needsCarbon = all.contains { !$0.hasSideSpecification && !$0.isModifierOnly }
        XCTAssertTrue(needsCarbon)

        let all2 = [hk2]
        let needsCarbon2 = all2.contains { !$0.hasSideSpecification && !$0.isModifierOnly }
        XCTAssertFalse(needsCarbon2)
    }
}

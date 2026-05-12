import XCTest
@testable import RoadTripBingo

final class ToastTests: XCTestCase {

    func test_toastStyle_earn_notEqualThreat() {
        XCTAssertNotEqual(ToastStyle.earn, ToastStyle.threat)
    }

    func test_toastEvent_earn_hasEarnStyle() {
        let event = ToastEvent(message: "+2🪙 Round start", style: .earn)
        XCTAssertEqual(event.style, .earn)
    }

    func test_toastEvent_threat_hasThreatStyle() {
        let event = ToastEvent(message: "💣 Liam downgraded 'Barn'", style: .threat)
        XCTAssertEqual(event.style, .threat)
    }

    func test_toastEvent_message_preserved() {
        let event = ToastEvent(message: "+3🪙 Close call!", style: .earn)
        XCTAssertEqual(event.message, "+3🪙 Close call!")
    }
}

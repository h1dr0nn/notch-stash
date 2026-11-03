import NotchStashCore
import XCTest

final class ShortcutFormatterTests: XCTestCase {
    func testModifiersFollowMacOrder() {
        let text = ShortcutFormatter.display(control: true, option: true, shift: true, command: true, key: "K")
        XCTAssertEqual(text, "⌃⌥⇧⌘K")
    }

    func testSingleModifier() {
        XCTAssertEqual(ShortcutFormatter.display(control: false, option: true, shift: false, command: false, key: "Space"), "⌥Space")
    }

    func testNamedKeys() {
        XCTAssertEqual(ShortcutFormatter.keyName(keyCode: 49, characters: " "), "Space")
        XCTAssertEqual(ShortcutFormatter.keyName(keyCode: 122, characters: nil), "F1")
        XCTAssertEqual(ShortcutFormatter.keyName(keyCode: 126, characters: nil), "↑")
    }

    func testLetterKeysUseUppercasedCharacters() {
        XCTAssertEqual(ShortcutFormatter.keyName(keyCode: 2, characters: "d"), "D")
    }

    func testUnknownKeyWithoutCharacters() {
        XCTAssertEqual(ShortcutFormatter.keyName(keyCode: 200, characters: ""), "Key 200")
    }

    func testFunctionKeys() {
        XCTAssertTrue(ShortcutFormatter.isFunctionKey(keyCode: 96))
        XCTAssertFalse(ShortcutFormatter.isFunctionKey(keyCode: 49))
    }
}

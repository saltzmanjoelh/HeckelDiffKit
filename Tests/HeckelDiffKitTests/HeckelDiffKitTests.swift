import XCTest
@testable import HeckelDiffKit

class HeckelDiffKitTests: XCTestCase {
    
    func testSplitInclusive_empty(){
        let string = ""
        
        let result = Heckel.splitInclusive(string: string, separator: " ")
        
        XCTAssertEqual(result, [])
    }
    func testSplitInclusive_trim(){
        let string = "a b c "
        
        let result = Heckel.splitInclusive(string: string, separator: " ", trim: true)
        
        XCTAssertEqual(result, ["a", "b", "c"])
    }
    func testSplitInclusive(){
        let string = "a b c"
        
        let result = Heckel.splitInclusive(string: string, separator: " ", trim: false)
        
        XCTAssertEqual(result, ["a ", "b ", "c"])
    }

    func testFlattenRepeats_beginning() {
        let tokens = Heckel.splitInclusive(string: "a a b c", separator: " ")
        
        let result = tokens.reduce([], Heckel.flattenRepeats)
        
        let expected = [Token<String>(value: "a ", ref: -1, count: 2),
                        Token<String>(value: "b ", ref: -1, count: 1),
                        Token<String>(value: "c", ref: -1, count: 1)]
        XCTAssertEqual(result, expected)
    }
    func testFlattenRepeats_middle() {
        let tokens = Heckel.splitInclusive(string: "a b b c", separator: " ")
        
        let result = tokens.reduce([], Heckel.flattenRepeats)
        
        let expected = [Token<String>(value: "a ", ref: -1, count: 1),
                        Token<String>(value: "b ", ref: -1, count: 2),
                        Token<String>(value: "c", ref: -1, count: 1)]
        XCTAssertEqual(result, expected)
    }
    func testFlattenRepeats_end() {
        let tokens = Heckel.splitInclusive(string: "a b c c", separator: " ")
        
        let result = tokens.reduce([], Heckel.flattenRepeats)
        
        let expected = [Token<String>(value: "a ", ref: -1, count: 1),
                        Token<String>(value: "b ", ref: -1, count: 1),
                        Token<String>(value: "c ", ref: -1, count: 1),
                        Token<String>(value: "c", ref: -1, count: 1)]
        XCTAssertEqual(result, expected)
    }
    
    func testAddToTable() {
        let left = Heckel.splitInclusive(string: "a a b c d", separator:" ", trim: false)
        let flattenedLeft = left.reduce([], Heckel.flattenRepeats)
        let table = [String:[Int:DiffIndex]]();
        
        let result = Heckel.addToTable(table: table, tokens: flattenedLeft, type: DiffIndex.Side.left);
        
        var expected = ["a ": [2: DiffIndex(left: 0, right: -1)],
                        "b ": [1: DiffIndex(left: 1, right: -1)],
                        "c ": [1: DiffIndex(left: 2, right: -1)],
                        "d": [1: DiffIndex(left: 3, right: -1)]]
        for key in result.keys {
            XCTAssertNotNil(expected[key], "Found unexpected key \"\(key)\" in result")
            XCTAssertEqual(result[key]!, expected[key]!)
            expected.removeValue(forKey: key)
        }
        XCTAssertEqual(expected.count, 0, "\"\(expected.keys)\" not found in results")
    }
    func testAddToTable_combined() {
        let left = Heckel.splitInclusive(string: "a a b c d", separator:" ", trim: false)
        let flattenedLeft = left.reduce([], Heckel.flattenRepeats)
        let right = Heckel.splitInclusive(string: "a a b c d", separator:" ", trim: false)
        let flattenedRight = right.reduce([], Heckel.flattenRepeats)
        let table = Heckel.addToTable(table: [String:[Int:DiffIndex]](), tokens: flattenedLeft, type: DiffIndex.Side.left);
        
        let result = Heckel.addToTable(table: table, tokens: flattenedRight, type: DiffIndex.Side.right);
        
        var expected = ["a ": [2: DiffIndex(left: 0, right: 0)],
                        "b ": [1: DiffIndex(left: 1, right: 1)],
                        "c ": [1: DiffIndex(left: 2, right: 2)],
                        "d": [1: DiffIndex(left: 3, right: 3)]]
        for key in result.keys {
            XCTAssertNotNil(expected[key], "Found unexpected key \"\(key)\" in result")
            XCTAssertEqual(result[key]!, expected[key]!)
            expected.removeValue(forKey: key)
        }
        XCTAssertEqual(expected.count, 0, "\"\(expected.keys)\" not found in results")
    }
    func testAddToTable_diff() {
        let left = Heckel.splitInclusive(string: "a a b c d e", separator:" ", trim: false)
        let flattenedLeft = left.reduce([], Heckel.flattenRepeats)
        let right = Heckel.splitInclusive(string: "a b b c a d", separator:" ", trim: false)
        let flattenedRight = right.reduce([], Heckel.flattenRepeats)
        let table = Heckel.addToTable(table: [String:[Int:DiffIndex]](), tokens: flattenedLeft, type: DiffIndex.Side.left);
        
        let result = Heckel.addToTable(table: table, tokens: flattenedRight, type: DiffIndex.Side.right);
        print(result)

        var expected = ["a ": [2: DiffIndex(left: 0, right: -1), 1: DiffIndex(left: -1, right: -2)],
                        "b ": [2: DiffIndex(left: -1, right: 1), 1: DiffIndex(left: 1, right: -1)],
                        "c ": [1: DiffIndex(left: 2, right: 2)],
                        "d ": [1: DiffIndex(left: 3, right: -1)],
                        "d": [1: DiffIndex(left: -1, right: 4)],
                        "e": [1: DiffIndex(left: 4, right: -1)]]
        for key in result.keys {
            XCTAssertNotNil(expected[key], "Found unexpected key \"\(key)\" in result")
            XCTAssertEqual(result[key]!, expected[key]!)
            expected.removeValue(forKey: key)
        }
        XCTAssertEqual(expected.count, 0, "\"\(expected.keys)\" not found in results")
    }
    
    func testFindUniques(){}
    func testExpandUniques() {
//        Heckel.diffWords(left: "a f f c a", right: "a f c a")
    }
    func testDiffWords_insertEndLeft() {
        let result = Heckel.diffWords(left: "a f f c a z x", right: "a f c a")
        
        let expected = [DiffResult(type: .same, value: "a"),
                        DiffResult(type: .same, value: "f"),
                        DiffResult(type: .delete, value: "f"),
                        DiffResult(type: .same, value: "c"),
                        DiffResult(type: .same, value: "a"),
                        DiffResult(type: .delete, value: "z"),
                        DiffResult(type: .delete, value: "x")]
        
        XCTAssertEqual(result, expected)
    }
    func testDiffWords_insertEndRight() {
        let result = Heckel.diffWords(left: "a f c a", right: "a f f c a z x")
        
        let expected = [DiffResult(type: .same, value: "a"),
                        DiffResult(type: .same, value: "f"),
                        DiffResult(type: .insert, value: "f"),
                        DiffResult(type: .same, value: "c"),
                        DiffResult(type: .same, value: "a"),
                        DiffResult(type: .insert, value: "z"),
                        DiffResult(type: .insert, value: "x")]
        XCTAssertEqual(result, expected)
    }
    func testDiffWords_same() {
        let result = Heckel.diffWords(left: "a f c a", right: "a f c a")
        
        let expected = [DiffResult(type: .same, value: "a"),
                        DiffResult(type: .same, value: "f"),
                        DiffResult(type: .same, value: "c"),
                        DiffResult(type: .same, value: "a")]
        XCTAssertEqual(result, expected)
    }
    func testDiffWords_emptyLeft() {
        let result = Heckel.diffWords(left: "", right: "a f c a")
        
        let expected = [DiffResult(type: .insert, value: "a"),
                        DiffResult(type: .insert, value: "f"),
                        DiffResult(type: .insert, value: "c"),
                        DiffResult(type: .insert, value: "a")]
        XCTAssertEqual(result, expected)
    }
    func testDiffWords_emptyRight() {
        let result = Heckel.diffWords(left: "a f c a", right: "")
        
        let expected = [DiffResult(type: .delete, value: "a"),
                        DiffResult(type: .delete, value: "f"),
                        DiffResult(type: .delete, value: "c"),
                        DiffResult(type: .delete, value: "a")]
        XCTAssertEqual(result, expected)
    }
    
    func testDiffWords_deleteMiddle() {
        let result = Heckel.diffWords(left: "a b a a b", right: "a b")
        
        let expected = [DiffResult(type: .same, value: "a"),
                        DiffResult(type: .same, value: "b"),
                        DiffResult(type: .delete, value: "a"),
                        DiffResult(type: .delete, value: "a"),
                        DiffResult(type: .delete, value: "b")]
        XCTAssertEqual(result, expected)
    }
    func testDiffWords_deleteLeft() {
        let result = Heckel.diffWords(left: "a b c d e", right: "d e")
        
        let expected = [DiffResult(type: .delete, value: "a"),
                        DiffResult(type: .delete, value: "b"),
                        DiffResult(type: .delete, value: "c"),
                        DiffResult(type: .same, value: "d"),
                        DiffResult(type: .same, value: "e")]
        XCTAssertEqual(result, expected)
    }
    func testDiffWords_deleteRight() {
        let result = Heckel.diffWords(left: "a b c d e", right: "a b")
        
        let expected = [DiffResult(type: .same, value: "a"),
                        DiffResult(type: .same, value: "b"),
                        DiffResult(type: .delete, value: "c"),
                        DiffResult(type: .delete, value: "d"),
                        DiffResult(type: .delete, value: "e")]
        XCTAssertEqual(result, expected)
    }
    func testDiffRepeats() {
        
        let result = Heckel.diffWords(left: "a b b b a", right: "c b b b c")
        
        let expected = [DiffResult(type: .delete, value: "a"),
                        DiffResult(type: .insert, value: "c"),
                        DiffResult(type: .same, value: "b"),
                        DiffResult(type: .same, value: "b"),
                        DiffResult(type: .same, value: "b"),
                        DiffResult(type: .delete, value: "a"),
                        DiffResult(type: .insert, value: "c")]
        XCTAssertEqual(result, expected)
    }
    //just testing random values to see if it crashes
    func testDiff_random(){
        var containers = [String]()
        for _ in 0..<2 {
            var string = ""
            for (_, element) in UUID().uuidString.characters.enumerated(){
                string.append("\(element) ")
            }
            containers.append(string)
        }
        
        let result = Heckel.diffWords(left: containers[0], right: containers[1])
        
        XCTAssertTrue(result.count > 1)
    }
    
    func testDiffLines() {
        let left = "a\nb\nc"
        let right = "b\nc\nd"
        
        let result = Heckel.diffLines(left: left, right: right)
        
        let expected = [DiffResult(type: .delete, value: "a"),
                        DiffResult(type: .same, value: "b"),
                        DiffResult(type: .same, value: "c"),
                        DiffResult(type: .insert, value: "d")]
        XCTAssertEqual(result, expected)
    }
    
    func testRightSeek(){
        let result = Heckel.diffWords(left: "a b c d e", right: "a d c b e")
        
        let expected = [DiffResult(type: .same, value: "a"),
                        DiffResult(type: .delete, value: "b"),
                        DiffResult(type: .insert, value: "d"),
                        DiffResult(type: .same, value: "c"),
                        DiffResult(type: .delete, value: "d"),
                        DiffResult(type: .insert, value: "b"),
                        DiffResult(type: .same, value: "e")]
        XCTAssertEqual(result, expected)
    }
    func testLeftUnreferenced(){
        let result = Heckel.diffWords(left: "a b c v d e", right: "a d c b e")
        
        let expected = [DiffResult(type: .same, value: "a"),
                        DiffResult(type: .delete, value: "b"),
                        DiffResult(type: .insert, value: "d"),
                        DiffResult(type: .same, value: "c"),
                        DiffResult(type: .delete, value: "v"),
                        DiffResult(type: .delete, value: "d"),
                        DiffResult(type: .insert, value: "b"),
                        DiffResult(type: .same, value: "e")]
        XCTAssertEqual(result, expected)
    }
    
    static var allTests : [(String, (HeckelDiffKitTests) -> () throws -> Void)] {
        return [
            ("testSplitInclusive_empty", testSplitInclusive_empty),
            ("testSplitInclusive_trim", testSplitInclusive_trim),
            ("testSplitInclusive", testSplitInclusive),
            ("testFlattenRepeats_beginning", testFlattenRepeats_beginning),
            ("testFlattenRepeats_middle", testFlattenRepeats_middle),
            ("testFlattenRepeats_end", testFlattenRepeats_end),
            ("testAddToTable", testAddToTable),
            ("testAddToTable_combined", testAddToTable_combined),
            ("testAddToTable_diff", testAddToTable_diff),
            ("testFindUniques", testFindUniques),
            ("testExpandUniques", testExpandUniques),
            ("testDiffWords_insertEndLeft", testDiffWords_insertEndLeft),
            ("testDiffWords_insertEndRight", testDiffWords_insertEndRight),
            ("testDiffWords_same", testDiffWords_same),
            ("testDiffWords_emptyLeft", testDiffWords_emptyLeft),
            ("testDiffWords_emptyRight", testDiffWords_emptyRight),
            ("testDiffWords_deleteMiddle", testDiffWords_deleteMiddle)
        ]
    }
}

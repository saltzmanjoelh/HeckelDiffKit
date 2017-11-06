import Foundation

public struct Token <V: Hashable>: Equatable {
    public let value: V
    public var ref: Int
    public var count: Int
    public let eof: Bool
    
    public init(value: V, ref: Int, count: Int, eof: Bool = false) {
        self.value = value
        self.ref = ref
        self.count = count
        self.eof = eof
    }
    
    @discardableResult
    public static postfix func ++(x: inout Token) -> Token {
        x.count += 1
        return x
    }
    public static func ==(lhs: Token<V>, rhs: Token<V>) -> Bool {
        return lhs.value == rhs.value && lhs.ref == rhs.ref && lhs.count == rhs.count
    }
}

public struct DiffIndex: Equatable {
    public enum Side {
        case left
        case right
    }
    public var left: Int = -1
    public var right: Int = -1
    
    public subscript(side: Side) -> Int {
        get{
            switch side {
            case .left:
                return left
            case .right:
                return right
            }
        }
        set{
            switch side {
            case .left:
                left = newValue
            case .right:
                right = newValue
            }
        }
    }
    public static func ==(lhs: DiffIndex, rhs: DiffIndex) -> Bool {
        return lhs.left == rhs.left && lhs.right == rhs.right
    }
}
public enum DiffResultType {
    case same
    case insert
    case delete
}
public struct DiffResult<V: Hashable>: Equatable {
    public let type: DiffResultType
    public let value: V
    public static func ==(lhs: DiffResult, rhs: DiffResult) -> Bool {
        return lhs.type == rhs.type && lhs.value == rhs.value
    }
}

public struct Heckel {

    public static func splitInclusive(string inputString: String, separator: String, trim: Bool = false) -> [String] {
        guard inputString.count > 0 else {
            return []
        }
        
        let split = inputString.components(separatedBy: separator)
        if trim {
            return split.filter{
                return $0.count > 0
            }
        }
        var result = [String]()
        for (index, element) in split.enumerated() {
            result.append(index < split.count-1 ? element + separator : element)
        }
        return result
    }

    public static func flattenRepeats<V>(result: [Token<V>], currentValue: V) -> [Token<V>] {
        var resultCopy = result
        if result.count > 0 && result[result.count-1].value == currentValue {
            resultCopy[resultCopy.count-1]++
            return resultCopy
        }
        
        resultCopy.append(Token(value: currentValue, ref: -1, count: 1))
        return resultCopy
    }
    // [ ("d": ["1": ["left":1, "right":2]]) ]
    // [ (V: (count: [left:marker, right:marker]) ) ]
    // side| -1 = uninitialized, -2 = found further out, otherwise index of location
    public static func addToTable<V>(table: [V:[Int:DiffIndex]], tokens: [Token<V>], type: DiffIndex.Side) ->   [V:[Int:DiffIndex]] {
        var result = table //get a copy
        for (index, token) in tokens.enumerated() {
            if result[token.value] == nil {
                result[token.value] = [Int:DiffIndex]()
            }
            if result[token.value]?[token.count] == nil {
                result[token.value]?[token.count] = DiffIndex()
            }
            
             //compare left side of entry, if it's uninitialized, set it to the current index
            if result[token.value]?[token.count]?[type] == -1 {
                result[token.value]?[token.count]?[type] = index
            }else if (result[token.value]?[token.count]?[type])! >= 0 {
                result[token.value]?[token.count]?[type] = -2
            }
            
        }
        return result
    }
    public static func findUnique<V>(table: [V:[Int:DiffIndex]], left: inout [Token<V>], right: inout [Token<V>]) {
        for token in left {
            if let ref = table[token.value]?[token.count] {
                if ref.left >= 0 && ref.right >= 0 {
                    left[ref.left].ref = ref.right
                    right[ref.right].ref = ref.left
                }
            }
        }
    }
    
    public static func expandUnique<V>(table: [V:[Int:DiffIndex]], left: inout [Token<V>], right: inout [Token<V>], direction: Int) {
        for (index, token) in left.enumerated() {
            if token.ref == -1 {
                continue
            }
            var i = index + direction
            var j = token.ref + direction
            let lx = left.count
            let rx = right.count
            
            while i >= 0 && j >= 0 && i < lx && j < rx {
                // not checking counts here has a few subtle effects
                // this means that lines "next to" not-quite-exact (but repeated) lines
                // will be taken to be part of the span:
                // in [a f f c a, a f c a], the first 'a' will be marked as a pair
                // with the second one, because the 'f f' will be marked as a pair with 'f'
                // this is cleaned up when outputting the diff data: ['f f', 'f']
                // will become 'f -f' on output
                if (left[i].value != right[j].value) {
                    break
                }
                left[i].ref = j
                right[j].ref = i
                
                i += direction
                j += direction
            }
        }
    }
    
    public static func push<V>(accumulator: inout [DiffResult<V>], token: Token<V>, type: DiffResultType) {
        for _ in 0..<token.count {
//            print("type: \(type) value: \(token.value)")
            accumulator.append(DiffResult.init(type: type, value: token.value))
        }
    }
    public static func calcDist(lTarget: Int, lPos: Int, rTarget: Int, rPos: Int) -> Int {
        return (lTarget - lPos) + (rTarget - rPos) + abs((lTarget - lPos) - (rTarget - rPos))
    }
    
    public static func processDiff<V>(left: [Token<V>], right: [Token<V>]) -> [DiffResult<V>]
    {
        var acc = [DiffResult<V>]()
        var lPos = 0, rPos = 0, lx = left.count
        var lTarget = 0, rTarget = 0
        var countDiff = 0, rSeek = 0, dist1 = 0, dist2 = 0

        
        while (lPos < lx) {
            lTarget = lPos

            // find the first sync-point on the left
            while (left[lTarget].ref < 0) {
                lTarget += 1
            }

            rTarget = left[lTarget].ref

            // left side referenced something we've already emitted, emit up to here
            if (rTarget < rPos) {
                // left-side un-referenced items are still deletions
                while (lPos < lTarget) {
                    push(accumulator: &acc, token: left[lPos], type: .delete) ///!!!
                    lPos += 1
                }
                
                // ... but since we've already emitted this change, this reference is void
                // and this token should be emitted as a deletion, not .same
                push(accumulator: &acc, token: left[lPos], type: .delete)
                lPos += 1
                continue
            }

//            var rToken = right[rTarget]
            
            dist1 = calcDist(lTarget: lTarget, lPos: lPos, rTarget: rTarget, rPos: rPos)
            
            rSeek = rTarget - 1
            while dist1 > 0 && rSeek >= rPos {
                // if this isn't a paired token, keep seeking
                if (right[rSeek].ref < 0) {
                    rSeek-=1
                    continue
                }
                
                // if we've already emitted the referenced left-side token, keep seeking
                if (right[rSeek].ref < lPos) {
                    rSeek-=1
                    continue
                }
                
                // is this pair "closer" than the current pair?
                dist2 = calcDist(lTarget:right[rSeek].ref, lPos:lPos, rTarget:rSeek, rPos:rPos)
                if (dist2 < dist1) {
                    dist1 = dist2
                    rTarget = rSeek
                    lTarget = right[rSeek].ref
                }
                rSeek-=1
            }

            // emit deletions
            while (lPos < lTarget) {
                push(accumulator: &acc, token: left[lPos], type: .delete)
                lPos+=1
            }
            
            // emit insertions
            while (rPos < rTarget) {
                push(accumulator: &acc, token: right[rPos], type: .insert)
                rPos+=1
            }

            // we're done when we hit the pseudo-token on the left
            if (left[lPos].eof == true) { break }
            
            // emit synced pair
            // since we allow repeats of different lengths to be matched
            // via the pass 4 & 5 expansion, we need to ensure we emit
            // the correct sequence when the counts don't align
            countDiff = left[lPos].count - right[rPos].count
            if (countDiff == 0) {
                push(accumulator: &acc, token: left[lPos], type: .same)
            } else if (countDiff < 0) {
                // more on the right than the left: some same, some insertion
                push(accumulator: &acc, token: Token.init(value: right[rPos].value, ref: -1, count: right[rPos].count + countDiff), type: .same)
                push(accumulator: &acc, token: Token.init(value: right[rPos].value, ref: -1, count: -countDiff), type: .insert)
            } else if (countDiff > 0) {
                // more on the left than the right: some same, some deletion
                push(accumulator: &acc, token: Token.init(value: left[lPos].value, ref: -1, count: left[lPos].count - countDiff), type: .same)
                push(accumulator: &acc, token: Token.init(value: left[lPos].value, ref: -1, count: countDiff), type: .delete)
            }
            
            lPos+=1
            rPos+=1
        }
        
        return acc
    }

    public static func diffLines(left: String, right: String, trim: Bool = true) -> [DiffResult<String>] {
        return diff(
            left: splitInclusive(string: left, separator:"\n", trim: trim),
            right: splitInclusive(string: right, separator:"\n", trim: trim)
        )
    }
    
    public static func diffWords(left: String, right: String, trim: Bool = true) -> [DiffResult<String>] {
        return diff(
            left: splitInclusive(string: left, separator:" ", trim: trim),
            right: splitInclusive(string: right, separator:" ", trim: trim)
        )
    }
    public static func diff<V: Hashable>(left: [V], right: [V]) -> [DiffResult<V>] {

        // if they're the same, no need to do all that work...
        if left == right {
            return left.map{ DiffResult.init(type: .same, value: $0) }
        }
        
        if left.count == 0 {
            return right.map{ DiffResult.init(type: .insert, value: $0) }
        }
        
        if right.count == 0 {
            return left.map{ DiffResult.init(type: .delete, value: $0) }
        }
        
        var flattenedLeft = left.reduce([], flattenRepeats)
        var flattenedRight = right.reduce([], flattenRepeats)
        
        var table = [V:[Int:DiffIndex]]()
        
        table = addToTable(table: table, tokens: flattenedLeft, type: DiffIndex.Side.left)
        table = addToTable(table: table, tokens: flattenedRight, type: DiffIndex.Side.right)
        
        findUnique(table: table, left: &flattenedLeft, right: &flattenedRight)
    
        expandUnique(table: table, left: &flattenedLeft, right: &flattenedRight, direction: 1)
        expandUnique(table: table, left: &flattenedLeft, right: &flattenedRight, direction: -1)
    
        //value and count are ignored on eof
        let eof = Token.init(value: flattenedLeft.first!.value, ref: flattenedRight.count, count: 0, eof: true)
        flattenedLeft.append(eof)// include trailing deletions

        let result = processDiff(left: flattenedLeft, right: flattenedRight)
        return result
    }
}

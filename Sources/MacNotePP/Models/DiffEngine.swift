import Foundation

public enum DiffRowKind: String, Equatable {
    case unchanged
    case modified
    case added
    case removed
}

public struct DiffRow: Identifiable, Equatable {
    public let id: Int
    public let leftLineNumber: Int?
    public let leftText: String?
    public let rightLineNumber: Int?
    public let rightText: String?
    public let kind: DiffRowKind
    public let leftHighlightRanges: [NSRange]
    public let rightHighlightRanges: [NSRange]
}

public struct DiffResult: Equatable {
    public let rows: [DiffRow]
    public let diffBlockRowIndices: [Int]
    public let addedCount: Int
    public let removedCount: Int
    public let modifiedCount: Int
    public let unchangedCount: Int
    /// One file ends with a line break and the other does not.
    public var finalNewlineDiffers: Bool = false

    public var isIdentical: Bool {
        addedCount == 0 && removedCount == 0 && modifiedCount == 0
    }
}

public enum DiffEngine {
    public static func compare(
        leftText: String,
        rightText: String,
        ignoreWhitespace: Bool = false,
        ignoreCase: Bool = false
    ) -> DiffResult {
        // A closing line break ends the last line; it does not start one more.
        func lines(of text: String) -> [String] {
            var result = LineEndingType.normalizeToLF(text).components(separatedBy: "\n")
            if result.last == "" { result.removeLast() }
            return result
        }
        let leftLines = lines(of: leftText)
        let rightLines = lines(of: rightText)

        func normalize(_ line: String) -> String {
            var s = line
            if ignoreWhitespace {
                s = s.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
            }
            if ignoreCase {
                s = s.lowercased()
            }
            return s
        }

        let normLeft = leftLines.map(normalize)
        let normRight = rightLines.map(normalize)

        let n = normLeft.count
        let m = normRight.count

        // Anchor-based LCS for responsiveness even on larger files
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n * m <= 2_500_000 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    if normLeft[i] == normRight[j] {
                        dp[i][j] = 1 + dp[i + 1][j + 1]
                    } else {
                        dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                    }
                }
            }
        }

        enum RawOp {
            case equal(Int, Int)
            case delete(Int)
            case insert(Int)
        }

        var rawOps: [RawOp] = []
        var i = 0
        var j = 0
        if n * m <= 2_500_000 {
            while i < n && j < m {
                if normLeft[i] == normRight[j] {
                    rawOps.append(.equal(i, j))
                    i += 1
                    j += 1
                } else if dp[i + 1][j] >= dp[i][j + 1] {
                    rawOps.append(.delete(i))
                    i += 1
                } else {
                    rawOps.append(.insert(j))
                    j += 1
                }
            }
            while i < n {
                rawOps.append(.delete(i))
                i += 1
            }
            while j < m {
                rawOps.append(.insert(j))
                j += 1
            }
        } else {
            // Fast linear fallback for huge files
            let maxCount = max(n, m)
            for idx in 0..<maxCount {
                if idx < n && idx < m {
                    if normLeft[idx] == normRight[idx] {
                        rawOps.append(.equal(idx, idx))
                    } else {
                        rawOps.append(.delete(idx))
                        rawOps.append(.insert(idx))
                    }
                } else if idx < n {
                    rawOps.append(.delete(idx))
                } else if idx < m {
                    rawOps.append(.insert(idx))
                }
            }
        }

        // Coalesce consecutive deletes + inserts into side-by-side `.modified` rows
        var rows: [DiffRow] = []
        var addedCount = 0
        var removedCount = 0
        var modifiedCount = 0
        var unchangedCount = 0

        var idx = 0
        var rowId = 0
        while idx < rawOps.count {
            switch rawOps[idx] {
            case .equal(let li, let ri):
                rows.append(
                    DiffRow(
                        id: rowId,
                        leftLineNumber: li + 1,
                        leftText: leftLines[li],
                        rightLineNumber: ri + 1,
                        rightText: rightLines[ri],
                        kind: .unchanged,
                        leftHighlightRanges: [],
                        rightHighlightRanges: []
                    )
                )
                rowId += 1
                unchangedCount += 1
                idx += 1

            case .delete, .insert:
                var dels: [Int] = []
                var ins: [Int] = []
                while idx < rawOps.count {
                    if case .delete(let li) = rawOps[idx] {
                        dels.append(li)
                        idx += 1
                    } else if case .insert(let ri) = rawOps[idx] {
                        ins.append(ri)
                        idx += 1
                    } else {
                        break
                    }
                }

                let pairCount = max(dels.count, ins.count)
                for p in 0..<pairCount {
                    let li = p < dels.count ? dels[p] : nil
                    let ri = p < ins.count ? ins[p] : nil
                    if let li = li, let ri = ri {
                        let lStr = leftLines[li]
                        let rStr = rightLines[ri]
                        let (lRanges, rRanges) = inlineCharDiff(left: lStr, right: rStr)
                        rows.append(
                            DiffRow(
                                id: rowId,
                                leftLineNumber: li + 1,
                                leftText: lStr,
                                rightLineNumber: ri + 1,
                                rightText: rStr,
                                kind: .modified,
                                leftHighlightRanges: lRanges,
                                rightHighlightRanges: rRanges
                            )
                        )
                        modifiedCount += 1
                    } else if let li = li {
                        let lStr = leftLines[li]
                        rows.append(
                            DiffRow(
                                id: rowId,
                                leftLineNumber: li + 1,
                                leftText: lStr,
                                rightLineNumber: nil,
                                rightText: nil,
                                kind: .removed,
                                leftHighlightRanges: [NSRange(location: 0, length: (lStr as NSString).length)],
                                rightHighlightRanges: []
                            )
                        )
                        removedCount += 1
                    } else if let ri = ri {
                        let rStr = rightLines[ri]
                        rows.append(
                            DiffRow(
                                id: rowId,
                                leftLineNumber: nil,
                                leftText: nil,
                                rightLineNumber: ri + 1,
                                rightText: rStr,
                                kind: .added,
                                leftHighlightRanges: [],
                                rightHighlightRanges: [NSRange(location: 0, length: (rStr as NSString).length)]
                            )
                        )
                        addedCount += 1
                    }
                    rowId += 1
                }
            }
        }

        // Compute start row indices of contiguous diff blocks for Next/Prev Diff navigation
        var blockIndices: [Int] = []
        var inDiffBlock = false
        for (rIndex, row) in rows.enumerated() {
            if row.kind != .unchanged {
                if !inDiffBlock {
                    blockIndices.append(rIndex)
                    inDiffBlock = true
                }
            } else {
                inDiffBlock = false
            }
        }

        return DiffResult(
            rows: rows,
            diffBlockRowIndices: blockIndices,
            addedCount: addedCount,
            removedCount: removedCount,
            modifiedCount: modifiedCount,
            unchangedCount: unchangedCount,
            finalNewlineDiffers: !leftText.isEmpty && !rightText.isEmpty && leftText.utf8.last != rightText.utf8.last
                && (leftText.utf8.last == 10 || rightText.utf8.last == 10)
        )
    }

    private static func inlineCharDiff(left: String, right: String) -> ([NSRange], [NSRange]) {
        let lChars = Array(left.utf16)
        let rChars = Array(right.utf16)

        var prefixLen = 0
        let minLen = min(lChars.count, rChars.count)
        while prefixLen < minLen && lChars[prefixLen] == rChars[prefixLen] {
            prefixLen += 1
        }

        var suffixLen = 0
        while suffixLen < (minLen - prefixLen)
            && lChars[lChars.count - 1 - suffixLen] == rChars[rChars.count - 1 - suffixLen] {
            suffixLen += 1
        }

        let lDiffLen = max(0, lChars.count - prefixLen - suffixLen)
        let rDiffLen = max(0, rChars.count - prefixLen - suffixLen)

        let lRanges = lDiffLen > 0 ? [NSRange(location: prefixLen, length: lDiffLen)] : []
        let rRanges = rDiffLen > 0 ? [NSRange(location: prefixLen, length: rDiffLen)] : []
        return (lRanges, rRanges)
    }
}

import Foundation

/// Reads the code files App Store Connect hands you.
///
/// Two different files arrive, and telling them apart is most of this file's job.
///
/// **One-time offer codes** come as a CSV with no header — the first line is already a
/// code — and two columns: the code, and a redeem URL carrying `ctx`, the Apple ID and
/// the code again:
///
///     F4ERH8YJF7XETYLY7N,https://apps.apple.com/redeem?ctx=offercodes&id=6759643878&code=F4ERH8YJF7XETYLY7N
///
/// **App promo codes** come as a bare list. No header, no link, no app — just the codes,
/// twelve characters each:
///
///     4KXJPHYRLMNE
///     H7T2WA9DQ3RB
///
/// Both columns of the first are read. Either alone is enough to place a code, and the
/// URL is what says which app the batch is for and which kind of code these are —
/// neither of which the operator should have to type back in.
///
/// The second file states none of that, which is itself the tell: App Store Connect
/// only omits the redeem link for promo codes, because there is no documented redeem
/// link for them to print. `promoShapedList` reads that absence, so dropping a promo
/// file doesn't land as an offer code and quietly build a `ctx=offercodes` link that
/// Apple will reject.
///
/// Deliberately forgiving: a file exported with only the codes, or one pasted with
/// quoting and trailing punctuation, still lands. Deliberately free of dependencies,
/// so it can be exercised on a real file without launching anything.
enum CodeFileParser {

    /// How long an App Store Connect promo code is. Every one of them is exactly this,
    /// which is what separates a link-less promo list from a paste of offer codes with
    /// the URL column cut off — those run to eighteen.
    static let promoCodeLength = 12

    struct Result: Equatable {
        /// The codes, in file order, uppercased, with repeats dropped.
        var codes: [String] = []
        /// The Apple ID the redeem links point at, if any of them said.
        var appleID: Int?
        /// `offercodes` or `apps`, as the links spelled it. Left nil when they didn't.
        var context: String?
        /// Whether any line carried a redeem URL at all.
        var hasRedeemLinks: Bool = false
        /// Non-empty lines that carried no code — a stray header, a repeat, a footer.
        var skipped: Int = 0

        /// Which redeem flow this batch belongs to, letting the file's silence speak.
        ///
        /// A link that spelled out `ctx=` always wins. Failing that, a file with no
        /// links at all whose codes are all promo-length is a promo export — the only
        /// thing App Store Connect ships that way.
        ///
        /// Anything else stays nil rather than guessing: a paste of offer codes with
        /// the URL column stripped looks link-less too, and its eighteen-character
        /// codes are what tell it apart.
        var resolvedContext: String? {
            if let context { return context }
            return promoShapedList ? "apps" : nil
        }

        /// No links anywhere, at least one code, and every code exactly promo-length.
        var promoShapedList: Bool {
            !hasRedeemLinks
                && !codes.isEmpty
                && codes.allSatisfy { $0.count == CodeFileParser.promoCodeLength }
        }
    }

    /// Whether one code, on its own, has the shape of an App Store promo code.
    ///
    /// Lives here rather than in `RedeemLinkBuilder` so this file keeps its promise of
    /// depending on nothing; the builder reads it from here.
    static func looksLikePromoCode(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == promoCodeLength
            && trimmed.range(of: #"^[A-Za-z0-9]+$"#, options: .regularExpression) != nil
    }

    static func parse(_ text: String) -> Result {
        var result = Result()
        var seen = Set<String>()

        // A byte-order mark read as UTF-8 becomes a character on the front of the first
        // field, which would silently corrupt the very first code.
        let text = text.replacingOccurrences(of: "\u{FEFF}", with: "")

        for rawLine in text.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            let url = firstMatch(#"https?://\S*apps\.apple\.com/\S*"#, in: line)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\",;"))

            var code = url.flatMap { capture(#"[?&]code=([^&\s]+)"#, in: $0) }

            if let url {
                result.hasRedeemLinks = true
                if result.appleID == nil, let id = capture(#"[?&]id=(\d+)"#, in: url) {
                    result.appleID = Int(id)
                }
                if result.context == nil, let ctx = capture(#"[?&]ctx=(offercodes|apps)\b"#, in: url) {
                    result.context = ctx.lowercased()
                }
            }

            // No link on this line? Then the first column is the code, if it looks like one.
            if code == nil {
                let first = line
                    .split(separator: ",", maxSplits: 1)
                    .first?
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
                    ?? ""
                if first.range(of: #"^[A-Za-z0-9]{8,24}$"#, options: .regularExpression) != nil {
                    code = first
                }
            }

            guard let found = code?.removingPercentEncoding ?? code else {
                result.skipped += 1
                continue
            }
            let normalized = found.uppercased()
            if seen.insert(normalized).inserted {
                result.codes.append(normalized)
            } else {
                result.skipped += 1
            }
        }

        return result
    }

    // MARK: - Regex helpers

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive])
        else { return nil }
        return String(text[range])
    }

    private static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let captured = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[captured])
    }
}

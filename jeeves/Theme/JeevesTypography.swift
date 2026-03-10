import SwiftUI

extension Font {

    // MARK: - Display

    /// Hero headers, morning greeting — bold and warm
    static let jeevesLargeTitle: Font = .system(size: 30, weight: .bold, design: .rounded)

    /// Card titles, prominent UI elements
    static let jeevesTitle: Font = .system(size: 20, weight: .semibold, design: .rounded)

    // MARK: - Headings

    /// Section headers — rounded for warmth
    static let jeevesHeadline: Font = .system(.headline, design: .rounded)

    // MARK: - Body

    /// Primary readable text
    static let jeevesBody: Font = .body

    // MARK: - Supporting

    /// Metadata, timestamps, secondary labels
    static let jeevesCaption: Font = .caption

    /// Tiny labels, badge text
    static let jeevesCaption2: Font = .caption2

    // MARK: - Technical

    /// Monospaced for data, codes, technical info
    static let jeevesMono: Font = .system(.footnote, design: .monospaced)

    /// Small monospaced badges and labels
    static let jeevesMonoSmall: Font = .system(size: 10, weight: .semibold, design: .monospaced)

    /// Large monospaced metric numbers
    static let jeevesMetric: Font = .system(size: 18, weight: .bold, design: .monospaced)
}

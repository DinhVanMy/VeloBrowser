// Typography.swift
// VeloBrowser
//
// Typography styles using SF Pro with Dynamic Type support.

import SwiftUI

/// Typography styles for VeloBrowser following Apple's type system.
///
/// All styles use SwiftUI's built-in font styles which automatically:
/// - Use SF Pro Display for large sizes and SF Pro Text for body sizes
/// - Support Dynamic Type for accessibility
/// - Scale appropriately for the user's preferred text size
enum TypographyStyles {
    // MARK: - Display

    /// 34pt Bold — screen headers.
    static let largeTitle: Font = .largeTitle

    /// 28pt Bold — section titles.
    static let title: Font = .title

    /// 22pt Bold — subsection titles.
    static let title2: Font = .title2

    /// 20pt Regular — tertiary titles.
    static let title3: Font = .title3

    // MARK: - Body

    /// 17pt Semibold — card titles, emphasis.
    static let headline: Font = .headline

    /// 17pt Regular — main content text.
    static let body: Font = .body

    /// 16pt Regular — secondary content.
    static let callout: Font = .callout

    /// 15pt Regular — metadata.
    static let subheadline: Font = .subheadline

    // MARK: - Small

    /// 13pt Regular — captions and small labels.
    static let footnote: Font = .footnote

    /// 12pt Regular — timestamps and tiny labels.
    static let caption: Font = .caption

    /// 11pt Regular — smallest text style.
    static let caption2: Font = .caption2
}

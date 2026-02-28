// ReaderModeView.swift
// VeloBrowser
//
// Clean reading view with customizable font, size, spacing, and theme.

import SwiftUI
import WebKit

/// Displays extracted article content in a distraction-free reading layout.
///
/// Users can customise font family, size, line spacing, and theme.
/// All preferences persist across sessions via `@AppStorage`.
struct ReaderModeView: View {
    /// The extracted content to display.
    let content: ReaderContent

    /// Callback when the user dismisses reader mode.
    var onDismiss: () -> Void

    /// Callback to share the page URL.
    var onShare: (() -> Void)?

    // MARK: - Preferences

    @AppStorage("readerFont") private var fontFamily: String = ReaderFont.system.rawValue
    @AppStorage("readerFontSize") private var fontSize: Double = 18
    @AppStorage("readerSpacing") private var lineSpacing: String = ReaderSpacing.normal.rawValue
    @AppStorage("readerTheme") private var theme: String = ReaderTheme.auto.rawValue

    @State private var showSettings = false
    @State private var scrollProgress: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                activeTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Reading progress bar
                    GeometryReader { _ in
                        DesignSystem.Colors.accent
                            .frame(width: scrollProgress * UIScreen.main.bounds.width, height: 2)
                    }
                    .frame(height: 2)

                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            // Title
                            Text(content.title)
                                .font(.system(size: fontSize + 8, weight: .bold, design: activeFontDesign))
                                .foregroundStyle(activeTheme.textColor)
                                .fixedSize(horizontal: false, vertical: true)

                            // Meta info
                            HStack(spacing: DesignSystem.Spacing.md) {
                                if let author = content.author {
                                    Label(author, systemImage: "person")
                                        .font(.system(size: fontSize - 4, design: activeFontDesign))
                                        .foregroundStyle(activeTheme.secondaryTextColor)
                                }
                                if let date = content.publishedDate {
                                    Label(formattedDate(date), systemImage: "calendar")
                                        .font(.system(size: fontSize - 4, design: activeFontDesign))
                                        .foregroundStyle(activeTheme.secondaryTextColor)
                                }
                            }

                            // Reading time
                            Text("\(content.estimatedReadingTime) min read · \(content.wordCount) words")
                                .font(.system(size: fontSize - 4, design: activeFontDesign))
                                .foregroundStyle(activeTheme.secondaryTextColor)

                            Divider()
                                .background(activeTheme.secondaryTextColor.opacity(0.3))

                            // Content body via web view
                            ReaderWebContent(
                                html: content.htmlContent,
                                fontSize: fontSize,
                                fontFamily: activeFontCSS,
                                lineHeight: activeLineHeight,
                                textColor: activeTheme.textHex,
                                backgroundColor: activeTheme.bgHex
                            )
                            .frame(minHeight: 400)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.md)
                        .padding(.bottom, 80)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ScrollOffsetKey.self,
                                    value: -geo.frame(in: .named("reader")).origin.y
                                )
                            }
                        )
                    }
                    .coordinateSpace(name: "reader")
                    .onPreferenceChange(ScrollOffsetKey.self) { offset in
                        let maxOffset = max(1, UIScreen.main.bounds.height * 2)
                        scrollProgress = min(1, max(0, offset / maxOffset))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                    }
                    .accessibilityLabel("Close reader mode")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button {
                            showSettings.toggle()
                        } label: {
                            Image(systemName: "textformat.size")
                        }
                        .accessibilityLabel("Reader settings")

                        if let onShare {
                            Button(action: onShare) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Share")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                readerSettingsSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Settings Sheet

    private var readerSettingsSheet: some View {
        NavigationStack {
            Form {
                // Font family
                Section("Font") {
                    Picker("Family", selection: $fontFamily) {
                        ForEach(ReaderFont.allCases, id: \.rawValue) { font in
                            Text(font.displayName)
                                .font(.system(size: 16, design: font.design))
                                .tag(font.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Font size
                Section("Size") {
                    HStack {
                        Text("A")
                            .font(.system(size: 14))
                        Slider(value: $fontSize, in: 14...28, step: 1)
                        Text("A")
                            .font(.system(size: 24))
                    }
                    .accessibilityLabel("Font size \(Int(fontSize)) points")
                }

                // Line spacing
                Section("Spacing") {
                    Picker("Line Spacing", selection: $lineSpacing) {
                        ForEach(ReaderSpacing.allCases, id: \.rawValue) { spacing in
                            Text(spacing.displayName).tag(spacing.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Theme
                Section("Theme") {
                    Picker("Theme", selection: $theme) {
                        ForEach(ReaderTheme.allCases, id: \.rawValue) { t in
                            Text(t.displayName).tag(t.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Computed Properties

    private var activeTheme: ReaderThemeColors {
        (ReaderTheme(rawValue: theme) ?? .auto).colors
    }

    private var activeFontDesign: Font.Design {
        (ReaderFont(rawValue: fontFamily) ?? .system).design
    }

    private var activeFontCSS: String {
        (ReaderFont(rawValue: fontFamily) ?? .system).cssName
    }

    private var activeLineHeight: Double {
        (ReaderSpacing(rawValue: lineSpacing) ?? .normal).multiplier
    }

    private func formattedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = formatter.date(from: dateString) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        // Try full ISO8601
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return dateString
    }
}

// MARK: - Scroll Offset Key

private struct ScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Reader Enums

/// Available font families for reader mode.
enum ReaderFont: String, CaseIterable, Sendable {
    case system = "system"
    case newYork = "newYork"
    case georgia = "georgia"

    var displayName: String {
        switch self {
        case .system: "SF Pro"
        case .newYork: "New York"
        case .georgia: "Georgia"
        }
    }

    var design: Font.Design {
        switch self {
        case .system: .default
        case .newYork: .serif
        case .georgia: .serif
        }
    }

    var cssName: String {
        switch self {
        case .system: "-apple-system, sans-serif"
        case .newYork: "'New York', 'Iowan Old Style', Georgia, serif"
        case .georgia: "Georgia, 'Times New Roman', serif"
        }
    }
}

/// Line spacing options for reader mode.
enum ReaderSpacing: String, CaseIterable, Sendable {
    case compact = "compact"
    case normal = "normal"
    case relaxed = "relaxed"

    var displayName: String {
        switch self {
        case .compact: "Compact"
        case .normal: "Normal"
        case .relaxed: "Relaxed"
        }
    }

    var multiplier: Double {
        switch self {
        case .compact: 1.3
        case .normal: 1.6
        case .relaxed: 2.0
        }
    }
}

/// Theme options for reader mode.
enum ReaderTheme: String, CaseIterable, Sendable {
    case auto = "auto"
    case light = "light"
    case sepia = "sepia"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .auto: "Auto"
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }

    var colors: ReaderThemeColors {
        switch self {
        case .auto:
            return ReaderThemeColors(
                background: Color(.systemBackground),
                textColor: Color(.label),
                secondaryTextColor: Color(.secondaryLabel),
                textHex: "#000000", bgHex: "#FFFFFF"
            )
        case .light:
            return ReaderThemeColors(
                background: .white,
                textColor: Color(red: 0.12, green: 0.12, blue: 0.12),
                secondaryTextColor: Color(red: 0.45, green: 0.45, blue: 0.45),
                textHex: "#1F1F1F", bgHex: "#FFFFFF"
            )
        case .sepia:
            return ReaderThemeColors(
                background: Color(red: 0.984, green: 0.941, blue: 0.851),
                textColor: Color(red: 0.24, green: 0.18, blue: 0.10),
                secondaryTextColor: Color(red: 0.45, green: 0.37, blue: 0.25),
                textHex: "#3D2E1A", bgHex: "#FBF0D9"
            )
        case .dark:
            return ReaderThemeColors(
                background: Color(red: 0.11, green: 0.11, blue: 0.12),
                textColor: Color(red: 0.92, green: 0.92, blue: 0.92),
                secondaryTextColor: Color(red: 0.60, green: 0.60, blue: 0.60),
                textHex: "#EBEBEB", bgHex: "#1C1C1E"
            )
        }
    }
}

/// Color set for a reader theme.
struct ReaderThemeColors {
    let background: Color
    let textColor: Color
    let secondaryTextColor: Color
    let textHex: String
    let bgHex: String
}

// MARK: - Reader Web Content

/// Renders cleaned HTML article content inside a lightweight WKWebView.
struct ReaderWebContent: UIViewRepresentable {
    let html: String
    let fontSize: Double
    let fontFamily: String
    let lineHeight: Double
    let textColor: String
    let backgroundColor: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        loadContent(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        loadContent(webView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func loadContent(_ webView: WKWebView) {
        let css = Self.readerCSS(
            fontFamily: fontFamily,
            fontSize: Int(fontSize),
            lineHeight: lineHeight,
            textColor: textColor,
            backgroundColor: backgroundColor
        )
        let fullHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>\(css)</style>
        </head>
        <body>
        \(html)
        <script>
            function reportHeight() {
                window.webkit.messageHandlers.heightHandler.postMessage(
                    document.body.scrollHeight
                );
            }
            window.addEventListener('load', reportHeight);
            new ResizeObserver(reportHeight).observe(document.body);
        </script>
        </body>
        </html>
        """
        webView.loadHTMLString(fullHTML, baseURL: nil)
    }

    /// Generates CSS for the reader mode HTML template.
    private static func readerCSS(
        fontFamily: String,
        fontSize: Int,
        lineHeight: CGFloat,
        textColor: String,
        backgroundColor: String
    ) -> String {
        """
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: \(fontFamily);
            font-size: \(fontSize)px;
            line-height: \(lineHeight);
            color: \(textColor);
            background: \(backgroundColor);
            -webkit-text-size-adjust: 100%;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 12px 0;
        }
        h1, h2, h3, h4, h5, h6 {
            margin-top: 1.2em;
            margin-bottom: 0.5em;
            line-height: 1.3;
        }
        p { margin-bottom: 0.8em; }
        blockquote {
            border-left: 3px solid \(textColor)40;
            padding-left: 16px;
            margin: 16px 0;
            font-style: italic;
            opacity: 0.85;
        }
        pre, code {
            font-family: 'SF Mono', Menlo, monospace;
            font-size: 0.9em;
            background: \(textColor)10;
            border-radius: 4px;
            padding: 2px 6px;
        }
        pre { padding: 12px; overflow-x: auto; margin: 12px 0; }
        pre code { padding: 0; background: none; }
        table { border-collapse: collapse; width: 100%; margin: 12px 0; }
        th, td { border: 1px solid \(textColor)30; padding: 8px; text-align: left; }
        a { color: #007AFF; text-decoration: none; }
        ul, ol { padding-left: 1.5em; margin-bottom: 0.8em; }
        li { margin-bottom: 0.3em; }
        figure { margin: 12px 0; }
        figcaption { font-size: 0.85em; opacity: 0.7; text-align: center; margin-top: 4px; }
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Resize WKWebView to fit content
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        webView.frame.size.height = height
                        webView.invalidateIntrinsicContentSize()
                    }
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            // Block external navigation — reader is read-only
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    await UIApplication.shared.open(url)
                }
                return .cancel
            }
            return .allow
        }
    }
}

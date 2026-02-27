// DownloadsView.swift
// VeloBrowser
//
// View displaying all downloads with progress and management.

import SwiftUI

/// Displays the list of all file downloads with progress indicators.
///
/// Shows download status (downloading, completed, failed),
/// progress bars for active downloads, and supports
/// swipe-to-delete and clear-completed actions.
struct DownloadsView: View {
    @Bindable var downloadManager: DownloadManagerService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if downloadManager.downloads.isEmpty {
                emptyState
            } else {
                downloadList
            }
        }
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if downloadManager.downloads.contains(where: {
                    [.completed, .failed, .cancelled].contains($0.status)
                }) {
                    Button("Clear") {
                        Task { await downloadManager.clearCompleted() }
                    }
                }
            }
        }
        .task {
            await downloadManager.loadDownloads()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("No Downloads")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Text("Downloaded files will appear here.")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Download List

    private var downloadList: some View {
        List {
            ForEach(downloadManager.downloads) { item in
                DownloadRowView(item: item) {
                    downloadManager.cancelDownload(id: item.id)
                }
            }
            .onDelete { indexSet in
                let ids = indexSet.map { downloadManager.downloads[$0].id }
                Task {
                    for id in ids {
                        await downloadManager.removeDownload(id: id)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

/// A single row displaying a download item's info and progress.
struct DownloadRowView: View {
    let item: DownloadItem
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                // File icon
                Image(systemName: iconForFile(item.fileName))
                    .font(.title2)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    statusText
                }

                Spacer()

                // Action button
                if item.status == .downloading {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel download")
                } else if item.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(DesignSystem.Colors.success)
                }
            }

            // Progress bar for active downloads
            if item.status == .downloading {
                ProgressView(value: item.progress)
                    .tint(DesignSystem.Colors.accent)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    @ViewBuilder
    private var statusText: some View {
        switch item.status {
        case .pending:
            Text("Waiting...")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        case .downloading:
            Group {
                if let total = item.totalBytes, total > 0 {
                    Text("\(formatBytes(item.downloadedBytes)) of \(formatBytes(total))")
                } else {
                    Text(formatBytes(item.downloadedBytes))
                }
            }
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
        case .paused:
            Text("Paused")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        case .completed:
            Group {
                if let total = item.totalBytes {
                    Text(formatBytes(total))
                } else {
                    Text("Completed")
                }
            }
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
        case .failed:
            Text("Failed")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.destructive)
        case .cancelled:
            Text("Cancelled")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    /// Returns an appropriate SF Symbol name for the file type.
    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "webp", "heic": return "photo.fill"
        case "mp4", "mov", "avi", "mkv": return "film.fill"
        case "mp3", "m4a", "wav", "aac", "flac": return "music.note"
        case "zip", "rar", "7z", "tar", "gz": return "archivebox.fill"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells.fill"
        default: return "doc.fill"
        }
    }

    /// Formats byte count into human-readable string.
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

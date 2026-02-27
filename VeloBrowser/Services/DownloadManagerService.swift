// DownloadManagerService.swift
// VeloBrowser
//
// Service managing file downloads with progress tracking.

import Foundation

/// Protocol for download management operations.
@MainActor
protocol DownloadManagerServiceProtocol {
    /// All tracked downloads.
    var downloads: [DownloadItem] { get }

    /// Starts downloading a file from the given URL.
    func startDownload(url: URL, suggestedFileName: String?) async

    /// Cancels an active download.
    func cancelDownload(id: UUID)

    /// Removes a download record and its local file.
    func removeDownload(id: UUID) async

    /// Clears all completed, failed, or cancelled downloads.
    func clearCompleted() async

    /// Loads persisted downloads from the repository.
    func loadDownloads() async
}

/// Manages file downloads using URLSession with progress tracking.
///
/// Downloads files to the app's Documents directory (accessible via
/// iOS Files app through `LSSupportsOpeningDocumentsInPlace`).
/// Persists download records via ``DownloadRepositoryProtocol``.
@Observable
@MainActor
final class DownloadManagerService: DownloadManagerServiceProtocol {
    /// All tracked downloads.
    private(set) var downloads: [DownloadItem] = []

    // MARK: - Private

    private let downloadRepository: DownloadRepositoryProtocol
    private var activeTasks: [UUID: URLSessionDownloadTask] = [:]
    private var taskToItem: [Int: UUID] = [:]
    private let delegate: DownloadSessionDelegate
    private let session: URLSession

    // MARK: - Init

    /// Creates a new DownloadManagerService.
    ///
    /// - Parameter downloadRepository: Repository for persisting download records.
    init(downloadRepository: DownloadRepositoryProtocol) {
        self.downloadRepository = downloadRepository
        let del = DownloadSessionDelegate()
        self.delegate = del
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        self.session = URLSession(configuration: config, delegate: del, delegateQueue: nil)
        setupDelegateCallbacks()
    }

    // MARK: - Public API

    /// Loads previously saved downloads from persistent storage.
    func loadDownloads() async {
        do {
            downloads = try await downloadRepository.fetchAll(status: nil)
        } catch {
            downloads = []
        }
    }

    /// Starts downloading a file from the given URL.
    ///
    /// - Parameters:
    ///   - url: The remote URL to download from.
    ///   - suggestedFileName: Optional file name; derived from URL if nil.
    func startDownload(url: URL, suggestedFileName: String? = nil) async {
        let fileName = suggestedFileName ?? url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        var item = DownloadItem(sourceURL: url, fileName: fileName.isEmpty ? "download" : fileName)
        item.status = .downloading

        downloads.insert(item, at: 0)
        try? await downloadRepository.save(item)

        let task = session.downloadTask(with: url)
        activeTasks[item.id] = task
        taskToItem[task.taskIdentifier] = item.id
        task.resume()
    }

    /// Cancels an active download.
    ///
    /// - Parameter id: The download item's unique identifier.
    func cancelDownload(id: UUID) {
        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)

        if let index = downloads.firstIndex(where: { $0.id == id }) {
            downloads[index].status = .cancelled
            Task {
                try? await downloadRepository.update(downloads[index])
            }
        }
    }

    /// Removes a download record and deletes the local file if present.
    ///
    /// - Parameter id: The download item's unique identifier.
    func removeDownload(id: UUID) async {
        cancelDownload(id: id)

        if let index = downloads.firstIndex(where: { $0.id == id }) {
            if let localURL = downloads[index].localURL {
                try? FileManager.default.removeItem(at: localURL)
            }
            downloads.remove(at: index)
        }
        try? await downloadRepository.delete(id: id)
    }

    /// Clears all completed, failed, or cancelled downloads.
    func clearCompleted() async {
        let completedStatuses: [DownloadStatus] = [.completed, .failed, .cancelled]
        downloads.removeAll { completedStatuses.contains($0.status) }
        try? await downloadRepository.clearCompleted()
    }

    // MARK: - Private

    /// Configures delegate callbacks to update download state.
    private func setupDelegateCallbacks() {
        delegate.onProgress = { [weak self] taskId, bytesWritten, totalBytes in
            Task { @MainActor [weak self] in
                self?.handleProgress(taskId: taskId, bytesWritten: bytesWritten, totalBytes: totalBytes)
            }
        }

        delegate.onCompletion = { [weak self] taskId, location in
            Task { @MainActor [weak self] in
                await self?.handleCompletion(taskId: taskId, location: location)
            }
        }

        delegate.onError = { [weak self] taskId, error in
            Task { @MainActor [weak self] in
                self?.handleError(taskId: taskId, error: error)
            }
        }
    }

    /// Handles download progress updates.
    private func handleProgress(taskId: Int, bytesWritten: Int64, totalBytes: Int64) {
        guard let itemId = taskToItem[taskId],
              let index = downloads.firstIndex(where: { $0.id == itemId }) else { return }

        downloads[index].downloadedBytes = bytesWritten
        if totalBytes > 0 {
            downloads[index].totalBytes = totalBytes
        }
    }

    /// Handles download completion — moves file to Documents directory.
    private func handleCompletion(taskId: Int, location: URL) async {
        guard let itemId = taskToItem[taskId],
              let index = downloads.firstIndex(where: { $0.id == itemId }) else { return }

        let documentsDir = Self.documentsDirectory
        let destURL = Self.uniqueFileURL(in: documentsDir, fileName: downloads[index].fileName)

        do {
            try FileManager.default.moveItem(at: location, to: destURL)

            downloads[index].localURL = destURL
            downloads[index].status = .completed
            try? await downloadRepository.update(downloads[index])
        } catch {
            downloads[index].status = .failed
            try? await downloadRepository.update(downloads[index])
        }

        activeTasks.removeValue(forKey: itemId)
        taskToItem.removeValue(forKey: taskId)
    }

    /// Handles download errors.
    private func handleError(taskId: Int, error: Error) {
        guard let itemId = taskToItem[taskId],
              let index = downloads.firstIndex(where: { $0.id == itemId }) else { return }

        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled else { return }

        downloads[index].status = .failed
        Task {
            try? await downloadRepository.update(downloads[index])
        }

        activeTasks.removeValue(forKey: itemId)
        taskToItem.removeValue(forKey: taskId)
    }

    /// The app's Documents directory for storing downloaded files.
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Returns a unique file URL, appending a counter if the file already exists.
    private static func uniqueFileURL(in directory: URL, fileName: String) -> URL {
        let baseURL = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: baseURL.path) else {
            return baseURL
        }

        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var counter = 1
        while true {
            let newName = ext.isEmpty ? "\(name) (\(counter))" : "\(name) (\(counter)).\(ext)"
            let newURL = directory.appendingPathComponent(newName)
            if !FileManager.default.fileExists(atPath: newURL.path) {
                return newURL
            }
            counter += 1
        }
    }
}

// MARK: - Download Session Delegate

/// URLSession delegate that forwards download events via closures.
///
/// Runs on a background queue; all closures should dispatch to MainActor.
final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    /// Called when download progress updates.
    var onProgress: (@Sendable (Int, Int64, Int64) -> Void)?

    /// Called when a download finishes successfully.
    var onCompletion: (@Sendable (Int, URL) -> Void)?

    /// Called when a download fails.
    var onError: (@Sendable (Int, Error) -> Void)?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        onCompletion?(downloadTask.taskIdentifier, location)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress?(downloadTask.taskIdentifier, totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        if let error {
            onError?(task.taskIdentifier, error)
        }
    }
}

import Foundation
import CryptoKit

/// Typed errors for cached audio download, integrity verification, and eviction.
enum AudioCacheError: Error, LocalizedError {
    case invalidDownloadURL
    case downloadFailed(Error)
    case responseNotHTTP
    case invalidHTTPStatus(Int)
    case fileTooSmall(Int64)
    case checksumMismatch
    case insufficientStorage
    case fileWriteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidDownloadURL: return "音檔下載網址無效。"
        case .downloadFailed: return "音檔下載失敗。"
        case .responseNotHTTP: return "音檔伺服器回應異常。"
        case .invalidHTTPStatus(let status): return "音檔下載失敗（\(status)）。"
        case .fileTooSmall: return "下載的音檔不完整。"
        case .checksumMismatch: return "音檔驗證失敗，已安全移除。"
        case .insufficientStorage: return "裝置可用空間不足，無法快取音檔。"
        case .fileWriteFailed: return "無法寫入音檔快取。"
        }
    }
}

/// Local-first audio cache. Files are atomically written into Application Support/SelahAudio.
/// The cache never uses Documents because generated audio is reproducible data, not user exports.
actor AudioCacheService {
    static let defaultMaximumBytes: Int64 = 100 * 1024 * 1024
    static let minimumValidMP3Bytes: Int64 = 512

    private let fileManager: FileManager
    private let baseDirectory: URL
    private let maximumBytes: Int64

    init(
        fileManager: FileManager = .default,
        maximumBytes: Int64 = AudioCacheService.defaultMaximumBytes,
        baseDirectory: URL? = nil
    ) throws {
        self.fileManager = fileManager
        self.maximumBytes = maximumBytes

        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let applicationSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.baseDirectory = applicationSupport.appendingPathComponent("SelahAudio", isDirectory: true)
        }

        try fileManager.createDirectory(at: self.baseDirectory, withIntermediateDirectories: true)
    }

    /// Returns a stable cache URL for an immutable audio manifest.
    func localURL(manifestID: UUID, sha256: String?) -> URL {
        let filename = "\(manifestID.uuidString.lowercased())-\(sha256 ?? "unverified").mp3"
        return baseDirectory.appendingPathComponent(filename, isDirectory: false)
    }

    func contains(manifestID: UUID, sha256: String?) -> Bool {
        fileManager.fileExists(atPath: localURL(manifestID: manifestID, sha256: sha256).path)
    }

    /// Downloads then atomically moves a verified file into the cache.
    func cache(
        manifestID: UUID,
        from remoteURL: URL,
        expectedSHA256: String?,
        expectedByteSize: Int64 = 0,
        protectedURLs: Set<URL> = []
    ) async throws -> URL {
        let finalURL = localURL(manifestID: manifestID, sha256: expectedSHA256)
        if fileManager.fileExists(atPath: finalURL.path) {
            return finalURL
        }

        let (temporaryURL, response): (URL, URLResponse)
        do {
            (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
        } catch {
            throw AudioCacheError.downloadFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            try? fileManager.removeItem(at: temporaryURL)
            throw AudioCacheError.responseNotHTTP
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            try? fileManager.removeItem(at: temporaryURL)
            throw AudioCacheError.invalidHTTPStatus(httpResponse.statusCode)
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: temporaryURL.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard size >= Self.minimumValidMP3Bytes else {
                try? fileManager.removeItem(at: temporaryURL)
                throw AudioCacheError.fileTooSmall(size)
            }
            if expectedByteSize > 0, size != expectedByteSize {
                try? fileManager.removeItem(at: temporaryURL)
                throw AudioCacheError.checksumMismatch
            }

            if let expectedSHA256 {
                let digest = try digest(of: temporaryURL)
                guard digest.caseInsensitiveCompare(expectedSHA256) == .orderedSame else {
                    try? fileManager.removeItem(at: temporaryURL)
                    throw AudioCacheError.checksumMismatch
                }
            }

            try evictIfNeeded(reserving: size, protectedURLs: protectedURLs)
            try fileManager.moveItem(at: temporaryURL, to: finalURL)
            return finalURL
        } catch let error as AudioCacheError {
            throw error
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw AudioCacheError.fileWriteFailed(error)
        }
    }

    /// Removes least-recently-modified files until an incoming file can fit.
    /// Protected files (currently playing) are never removed.
    func evictIfNeeded(reserving incomingBytes: Int64 = 0, protectedURLs: Set<URL> = []) throws {
        let files = try cachedFiles()
        let currentBytes = files.reduce(Int64(0)) { $0 + $1.size }
        guard currentBytes + incomingBytes > maximumBytes else { return }

        var releasedBytes: Int64 = 0
        for file in files.sorted(by: { $0.lastAccessed < $1.lastAccessed }) {
            guard !protectedURLs.contains(file.url) else { continue }
            try fileManager.removeItem(at: file.url)
            releasedBytes += file.size
            if currentBytes - releasedBytes + incomingBytes <= maximumBytes {
                return
            }
        }

        throw AudioCacheError.insufficientStorage
    }

    func clearAll(excluding protectedURLs: Set<URL> = []) throws {
        for file in try cachedFiles() where !protectedURLs.contains(file.url) {
            try fileManager.removeItem(at: file.url)
        }
    }

    func cacheSizeBytes() throws -> Int64 {
        try cachedFiles().reduce(Int64(0)) { $0 + $1.size }
    }

    private struct CachedFile {
        let url: URL
        let size: Int64
        let lastAccessed: Date
    }

    private func cachedFiles() throws -> [CachedFile] {
        let urls = try fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        return try urls.compactMap { url in
            guard url.pathExtension.lowercased() == "mp3" else { return nil }
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentAccessDateKey, .contentModificationDateKey])
            return CachedFile(
                url: url,
                size: Int64(values.fileSize ?? 0),
                lastAccessed: values.contentAccessDate ?? values.contentModificationDate ?? .distantPast
            )
        }
    }

    private func digest(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

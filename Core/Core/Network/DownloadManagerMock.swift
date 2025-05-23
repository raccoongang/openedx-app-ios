//
//  DownloadManagerMock.swift
//  Core
//
//  Created by Ivan Stepanok on 11.12.2024.
//

import Foundation
import Combine

// Mark - For testing and SwiftUI preview
#if DEBUG
public final class DownloadManagerMock: DownloadManagerProtocol, @unchecked Sendable {
    public func getCurrentDownloadTask() async -> DownloadDataTask? {
        nil
    }
    
    public func downloadTask(for blockId: String) async -> DownloadDataTask? {
        nil
    }
    public init() {}

    public func delete(blocks: [CourseBlock], courseId: String) async {}

    public var currentDownloadTask: DownloadDataTask? {
        return nil
    }

    public func publisher() -> AnyPublisher<Int, Never> {
        return Just(1).eraseToAnyPublisher()
    }

    public func eventPublisher() -> AnyPublisher<DownloadManagerEvent, Never> {
        return Just(
            .canceled(
                [
                .init(
                    id: "",
                    blockId: "",
                    courseId: "",
                    userId: 0,
                    url: "",
                    fileName: "",
                    displayName: "",
                    progress: 1,
                    resumeData: nil,
                    state: .inProgress,
                    type: .video,
                    fileSize: 0,
                    lastModified: "",
                    actualSize: 0
                )
                ]
            )
        ).eraseToAnyPublisher()
    }

    public func addToDownloadQueue(blocks: [CourseBlock]) {}

    public func getDownloadTasks() -> [DownloadDataTask] {
        []
    }

    public func getDownloadTasksForCourse(_ courseId: String) async -> [DownloadDataTask] {
        await withCheckedContinuation { continuation in
            continuation.resume(returning: [])
        }
    }

    public func cancelDownloading(courseId: String, blocks: [CourseBlock]) async throws {}

    public func cancelDownloading(task: DownloadDataTask) {}

    public func cancelDownloading(courseId: String) async {}

    public func cancelAllDownloading() async throws {}

    public func resumeDownloading() {}

    public func deleteFile(blocks: [CourseBlock]) {}

    public func deleteAll() {}
                
    public func fileUrl(for blockId: String) async -> URL? {
        return nil
    }

    public func isLargeVideosSize(blocks: [CourseBlock]) -> Bool {
        false
    }

    public func removeAppSupportDirectoryUnusedContent() {}
}
#endif

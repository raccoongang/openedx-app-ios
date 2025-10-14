//
//  LessonViewModel.swift
//  CourseDetails
//
//  Created by  Stepanok Ivan on 05.10.2022.
//

import SwiftUI
import Core

public enum LessonType: Equatable {
    case web(url: String, injections: [WebviewInjection], blockId: String, isDownloadable: Bool)
    case youtube(youtubeVideoUrl: String, blockId: String)
    case video(videoUrl: String, blockId: String)
    case unknown(String)
    case discussion(String, String, String)
    
    static func from(_ block: CourseBlock, streamingQuality: StreamingQuality) -> Self {
        let mandatoryInjections: [WebviewInjection] = [.colorInversionCss, .ajaxCallback, .readability, .accessibility]
        switch block.type {
        case .course, .chapter, .vertical, .sequential:
            return .unknown(block.studentUrl)
        case .unknown:
            if let multiDevice = block.multiDevice, multiDevice {
                return .web(
                    url: block.studentUrl,
                    injections: mandatoryInjections,
                    blockId: block.id,
                    isDownloadable: block.isDownloadable
                )
            } else {
                return .unknown(block.studentUrl)
            }
        case .html:
            return .web(
                url: block.studentUrl,
                injections: mandatoryInjections,
                blockId: block.id,
                isDownloadable: block.isDownloadable
            )
        case .discussion:
            return .discussion(block.topicId ?? "", block.id, block.displayName)
        case .video:
            if let encodedVideo = block.encodedVideo?.video(streamingQuality: streamingQuality),
               let videoURL = encodedVideo.url {
                if encodedVideo.type == .youtube {
                    return .youtube(youtubeVideoUrl: videoURL, blockId: block.id)
                } else if encodedVideo.isVideoURL {
                    return .video(videoUrl: videoURL, blockId: block.id)
                } else {
                    return .unknown(block.studentUrl)
                }
            } else {
                return .unknown(block.studentUrl)
            }
            
        case .problem:
            return .web(
                url: block.studentUrl,
                injections: mandatoryInjections,
                blockId: block.id,
                isDownloadable: block.isDownloadable
            )
        case .dragAndDropV2:
            return .web(
                url: block.studentUrl,
                injections: mandatoryInjections + [.dragAndDropCss],
                blockId: block.id,
                isDownloadable: block.isDownloadable
            )
        case .survey:
            return .web(
                url: block.studentUrl,
                injections: mandatoryInjections + [.surveyCSS],
                blockId: block.id,
                isDownloadable: block.isDownloadable
            )
        case .openassessment, .peerInstructionTool:
            return .web(
                url: block.studentUrl,
                injections: mandatoryInjections,
                blockId: block.id,
                isDownloadable: block.isDownloadable
            )
        }
    }
}

public struct VerticalData: Equatable {
    public var chapterIndex: Int
    public var sequentialIndex: Int
    public var verticalIndex: Int
    public var blockIndex: Int
    
    public init(chapterIndex: Int, sequentialIndex: Int, verticalIndex: Int, blockIndex: Int) {
        self.chapterIndex = chapterIndex
        self.sequentialIndex = sequentialIndex
        self.verticalIndex = verticalIndex
        self.blockIndex = blockIndex
    }
    
    public static func dataFor(blockId: String?, in chapters: [CourseChapter]) -> VerticalData? {
        guard let blockId = blockId else { return nil }
        for (chapterIndex, chapter) in chapters.enumerated() {
            for (sequentialIndex, sequential) in chapter.childs.enumerated() {
                for (verticalIndex, vertical) in sequential.childs.enumerated() {
                    for (blockIndex, block) in vertical.childs.enumerated() where block.id.contains(blockId) {
                        return VerticalData(
                            chapterIndex: chapterIndex,
                            sequentialIndex: sequentialIndex,
                            verticalIndex: verticalIndex,
                            blockIndex: blockIndex
                        )
                    }
                }
            }
        }
        return nil
    }
}

public struct CourseUnitDisplayItem: Identifiable, Equatable {

    public struct WebContentItem: Identifiable, Equatable {
        public var id: String { block.id }
        public let block: CourseBlock
        public let url: String
        public let injections: [WebviewInjection]
        public let blockId: String
        public let isDownloadable: Bool
    }

    public enum Content: Equatable {
        case webGroup(items: [WebContentItem])
        case lesson(block: CourseBlock, type: LessonType)
    }

    public let id: String
    public let blockIndices: [Int]
    public let content: Content
    public let primaryBlock: CourseBlock

    public var primaryBlockIndex: Int {
        blockIndices.first ?? 0
    }

    public var allBlocks: [CourseBlock] {
        switch content {
        case let .webGroup(items):
            return items.map(\.block)
        case let .lesson(block, _):
            return [block]
        }
    }

    public init(
        id: String,
        blockIndices: [Int],
        content: Content,
        primaryBlock: CourseBlock
    ) {
        self.id = id
        self.blockIndices = blockIndices
        self.content = content
        self.primaryBlock = primaryBlock
    }

    public func contains(blockId: String) -> Bool {
        allBlocks.contains(where: { $0.id.contains(blockId) })
    }
}

@MainActor
public final class CourseUnitViewModel: ObservableObject {
    
    enum LessonAction: Sendable {
        case next
        case previous
    }

    var verticals: [CourseVertical]
    var verticalIndex: Int {
        didSet {
            guard verticalIndex != oldValue else { return }
            rebuildDisplayItems()
            loadIndex()
        }
    }
    var courseName: String
    
    @Published var index: Int = 0
    var previousLesson: String = ""
    var nextLesson: String = ""
    @Published var showError: Bool = false
    var errorMessage: String? {
        didSet {
            showError = errorMessage != nil
        }
    }
    
    var lessonID: String
    var courseID: String
    
    private let interactor: CourseInteractorProtocol
    let router: CourseRouter
    let config: ConfigProtocol
    let analytics: CourseAnalytics
    let connectivity: ConnectivityProtocol
    let storage: CourseStorage
    private let manager: DownloadManagerProtocol
    private var subtitlesDownloaded: Bool = false
    let chapters: [CourseChapter]
    let chapterIndex: Int
    let sequentialIndex: Int
    @Published private(set) var displayItems: [CourseUnitDisplayItem] = []
    private var blockIndexToDisplayIndex: [Int: Int] = [:]

    var streamingQuality: StreamingQuality {
        storage.userSettings?.streamingQuality ?? .auto
    }

    func loadIndex() {
        index = selectLesson()
    }

    var courseUnitProgressEnabled: Bool {
        config.uiComponents.courseUnitProgressEnabled
    }

    public init(
        lessonID: String,
        courseID: String,
        courseName: String,
        chapters: [CourseChapter],
        chapterIndex: Int,
        sequentialIndex: Int,
        verticalIndex: Int,
        interactor: CourseInteractorProtocol,
        config: ConfigProtocol,
        router: CourseRouter,
        analytics: CourseAnalytics,
        connectivity: ConnectivityProtocol,
        storage: CourseStorage,
        manager: DownloadManagerProtocol
    ) {
        self.lessonID = lessonID
        self.courseID = courseID
        self.courseName = courseName
        self.chapters = chapters
        self.chapterIndex = chapterIndex
        self.sequentialIndex = sequentialIndex
        self.interactor = interactor
        self.config = config
        self.router = router
        self.analytics = analytics
        self.connectivity = connectivity
        self.storage = storage
        self.manager = manager
        self.verticals = chapters[chapterIndex].childs[sequentialIndex].childs
        self.verticalIndex = min(verticalIndex, max(self.verticals.count - 1, 0))
        rebuildDisplayItems()
    }
    
    private func selectLesson() -> Int {
        guard !displayItems.isEmpty else { return 0 }

        let sourceBlocks = verticals[verticalIndex].childs
        guard let blockIndex = sourceBlocks.firstIndex(where: { $0.id.contains(lessonID) }) else {
            return 0
        }
        let index = blockIndexToDisplayIndex[blockIndex] ?? 0
        nextTitles()
        return index
    }
    
    func selectedLesson() -> CourseBlock {
        return displayItems[safe: index]?.primaryBlock ?? CourseBlock.empty
    }
    
    func select(move: LessonAction) {
        switch move {
        case .next:
            if index != displayItems.count - 1 { index += 1 }
            let nextBlock = displayItems[index].primaryBlock
            nextTitles()
            analytics.nextBlockClicked(
                courseId: courseID,
                courseName: courseName,
                blockId: nextBlock.blockId,
                blockName: nextBlock.displayName
            )
        case .previous:
            if index != 0 { index -= 1 }
            nextTitles()
            let prevBlock = displayItems[index].primaryBlock
            analytics.prevBlockClicked(
                courseId: courseID,
                courseName: courseName,
                blockId: prevBlock.blockId,
                blockName: prevBlock.displayName
            )
        }
    }
    
    @MainActor
    func blockCompletionRequest(blockID: String) async {
        do {
            try await interactor.blockCompletionRequest(courseID: courseID, blockID: blockID)
            setBlockCompletionForSelectedLesson()
        } catch let error {
            if error.isInternetError || error is NoCachedDataError {
                errorMessage = CoreLocalization.Error.slowOrNoInternetConnection
            } else {
                errorMessage = CoreLocalization.Error.unknownError
            }
        }
    }

    func nextTitles() {
        guard !displayItems.isEmpty else {
            previousLesson = ""
            nextLesson = ""
            return
        }

        if index != 0 {
            previousLesson = displayItems[index - 1].primaryBlock.displayName
        } else {
            previousLesson = ""
        }
        if index != displayItems.count - 1 {
            nextLesson = displayItems[index + 1].primaryBlock.displayName
        } else {
            nextLesson = ""
        }
    }
    
    func urlForVideoFileOrFallback(blockId: String, url: String) async -> URL? {
        guard !connectivity.isInternetAvaliable else { return URL(string: url) }
        if let fileURL = await manager.fileUrl(for: blockId) {
            return fileURL
        } else {
            return URL(string: url)
        }
    }

    func urlForOfflineContent(blockId: String) async -> URL? {
        return await manager.fileUrl(for: blockId)
    }
    
    func trackFinishVerticalBackToOutlineClicked() {
        analytics.finishVerticalBackToOutlineClicked(courseId: courseID, courseName: courseName)
    }

    // MARK: Navigation to next vertical
    var nextData: VerticalData? {
        nextData(
            from: currentData
        )
    }
    
    var currentData: VerticalData {
        VerticalData(
            chapterIndex: chapterIndex,
            sequentialIndex: sequentialIndex,
            verticalIndex: verticalIndex,
            blockIndex: index
        )
    }
    
    private func chapter(for data: VerticalData) -> CourseChapter? {
        guard data.chapterIndex >= 0 && data.chapterIndex < chapters.count else { return nil }
        return chapters[data.chapterIndex]
    }
    
    private func sequential(for data: VerticalData) -> CourseSequential? {
        guard let chapter = chapter(for: data),
              data.sequentialIndex >= 0 && data.sequentialIndex < chapter.childs.count
        else { return nil }
        return chapter.childs[data.sequentialIndex]
    }
    
    func vertical(for data: VerticalData) -> CourseVertical? {
        guard let sequential = sequential(for: data),
            data.verticalIndex >= 0 && data.verticalIndex < sequential.childs.count
        else { return nil }
        return sequential.childs[data.verticalIndex]
    }
        
    private func sequentials(for data: VerticalData) -> [CourseSequential]? {
        guard let chapter = chapter(for: data) else { return nil }
        return chapter.childs
    }
    
    private func verticals(for data: VerticalData) -> [CourseVertical]? {
        guard let sequential = sequential(for: data) else { return nil }
        return sequential.childs
    }
    
    private func nextData(from data: VerticalData) -> VerticalData? {
        var resultData: VerticalData = data
        if let verticals = verticals(for: data), verticals.count > data.verticalIndex + 1 {
            resultData.verticalIndex = data.verticalIndex + 1
        } else if let sequentials = sequentials(for: data), sequentials.count > data.sequentialIndex + 1 {
            resultData.sequentialIndex = data.sequentialIndex + 1
            resultData.verticalIndex = 0
        } else if chapters.count > data.chapterIndex + 1 {
            resultData.chapterIndex = data.chapterIndex + 1
            resultData.sequentialIndex = 0
            resultData.verticalIndex = 0
        } else {
            return nil
        }

        if let vertical = vertical(for: resultData), vertical.childs.count > 0 {
            resultData.blockIndex = 0
            return resultData
        } else {
            return nextData(from: resultData)
        }
    }

    private func setBlockCompletionForSelectedLesson() {
        guard let item = displayItems[safe: index] else { return }
        for blockIndex in item.blockIndices {
            if verticals[verticalIndex].childs.indices.contains(blockIndex) {
                verticals[verticalIndex].childs[blockIndex].completion = 1.0
            }
        }
        NotificationCenter.default.post(
            name: .onBlockCompletion,
            object: nil,
            userInfo: [
                "chapterID": chapters[chapterIndex].id,
                "sequentialID": chapters[chapterIndex].childs[sequentialIndex].id,
                "verticalID": chapters[chapterIndex].childs[sequentialIndex].childs[verticalIndex].id,
                "blockID": item.primaryBlock.id
            ]
        )
    }

    func blockFor(index: Int, in vertical: CourseVertical) -> CourseBlock? {
        guard index >= 0 && index < vertical.childs.count else { return nil }
        return vertical.childs[index]
    }
    
    func route(to data: VerticalData?, animated: Bool = false) {
        guard let data = data, data != currentData else { return }
        if let vertical = vertical(for: data),
                  let block = blockFor(index: data.blockIndex, in: vertical) {
            router.replaceCourseUnit(
                courseName: courseName,
                blockId: block.blockId,
                courseID: courseID,
                verticalIndex: data.verticalIndex,
                chapters: chapters,
                chapterIndex: data.chapterIndex,
                sequentialIndex: data.sequentialIndex,
                animated: animated
            )
        }
    }
    
    public func route(to blockId: String?) {
        guard let data = VerticalData.dataFor(blockId: blockId, in: chapters) else { return }
        route(to: data, animated: true)
    }
    
    public var currentCourseId: String {
        courseID
    }

    private func rebuildDisplayItems() {
        guard verticals.indices.contains(verticalIndex) else {
            displayItems = []
            blockIndexToDisplayIndex = [:]
            return
        }

        let blocks = verticals[verticalIndex].childs
        var items: [CourseUnitDisplayItem] = []
        var mapping: [Int: Int] = [:]
        var currentWebItems: [CourseUnitDisplayItem.WebContentItem] = []
        var currentIndices: [Int] = []

        for (index, block) in blocks.enumerated() {
            let lessonType = LessonType.from(block, streamingQuality: streamingQuality)
            switch lessonType {
            case let .web(url, injections, blockId, isDownloadable):
                let webItem = CourseUnitDisplayItem.WebContentItem(
                    block: block,
                    url: url,
                    injections: injections,
                    blockId: blockId,
                    isDownloadable: isDownloadable
                )
                currentWebItems.append(webItem)
                currentIndices.append(index)
            default:
                if !currentWebItems.isEmpty {
                    if let primary = currentWebItems.first?.block {
                        let item = CourseUnitDisplayItem(
                            id: currentWebItems.map(\.block.id).joined(separator: "-"),
                            blockIndices: currentIndices,
                            content: .webGroup(items: currentWebItems),
                            primaryBlock: primary
                        )
                        items.append(item)
                    }
                    currentWebItems.removeAll()
                    currentIndices.removeAll()
                }
                let item = CourseUnitDisplayItem(
                    id: block.id,
                    blockIndices: [index],
                    content: .lesson(block: block, type: lessonType),
                    primaryBlock: block
                )
                items.append(item)
            }
        }

        if !currentWebItems.isEmpty {
            if let primary = currentWebItems.first?.block {
                let item = CourseUnitDisplayItem(
                    id: currentWebItems.map(\.block.id).joined(separator: "-"),
                    blockIndices: currentIndices,
                    content: .webGroup(items: currentWebItems),
                    primaryBlock: primary
                )
                items.append(item)
            }
        }

        for (displayIndex, item) in items.enumerated() {
            for blockIndex in item.blockIndices {
                mapping[blockIndex] = displayIndex
            }
        }

        displayItems = items
        blockIndexToDisplayIndex = mapping
        if !items.isEmpty {
            index = min(index, items.count - 1)
        } else {
            index = 0
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private extension CourseBlock {
    static var empty: CourseBlock {
        CourseBlock(
            blockId: "",
            id: "",
            courseId: "",
            topicId: nil,
            graded: false,
            due: nil,
            completion: 0,
            type: .unknown,
            displayName: "",
            studentUrl: "",
            webUrl: "",
            encodedVideo: nil,
            multiDevice: nil,
            offlineDownload: nil
        )
    }
}

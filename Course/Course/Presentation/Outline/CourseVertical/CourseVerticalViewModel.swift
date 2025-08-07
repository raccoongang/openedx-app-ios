//
//  CourseVerticalViewModel.swift
//  Course
//
//  Created by  Stepanok Ivan on 14.03.2023.
//

import SwiftUI
import Core
import OEXFoundation

@MainActor
public final class CourseVerticalViewModel: ObservableObject, @unchecked Sendable {

    private let parentVM: CourseContainerViewModel?

    let router: CourseRouter
    let analytics: CourseAnalytics
    let connectivity: ConnectivityProtocol
    @Published var verticals: [CourseVertical]
    @Published var showError: Bool = false
    let chapters: [CourseChapter]
    let chapterIndex: Int
    let sequentialIndex: Int
    
    var errorMessage: String? {
        didSet {
            withAnimation {
                showError = errorMessage != nil
            }
        }
    }
    
    public init(
        parentVM: CourseContainerViewModel?,
        chapters: [CourseChapter],
        chapterIndex: Int,
        sequentialIndex: Int,
        router: CourseRouter,
        analytics: CourseAnalytics,
        connectivity: ConnectivityProtocol
    ) {
        self.parentVM = parentVM
        self.chapters = chapters
        self.chapterIndex = chapterIndex
        self.sequentialIndex = sequentialIndex
        self.router = router
        self.analytics = analytics
        self.connectivity = connectivity

        self.verticals = parentVM?.courseStructure?.childs[chapterIndex].childs[sequentialIndex].childs ?? []

        parentVM?.$courseStructure
            .compactMap { $0?.childs[chapterIndex]
                    .childs[sequentialIndex]
                .childs }
            .assign(to: &$verticals)

    }
    
    func trackVerticalClicked(
        courseId: String,
        courseName: String,
        vertical: CourseVertical
    ) {
        analytics.verticalClicked(
            courseId: courseId,
            courseName: courseName,
            blockId: vertical.blockId,
            blockName: vertical.displayName
        )
    }
}

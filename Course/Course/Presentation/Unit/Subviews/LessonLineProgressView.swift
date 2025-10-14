//
//  LessonLineProgressView.swift
//  Course
//
//  Created by Eugene Yatsenko on 11.12.2023.
//

import SwiftUI
import Theme

struct LessonLineProgressView: View {
    @ObservedObject var viewModel: CourseUnitViewModel

    @Environment(\.isHorizontal) private var isHorizontal

    init(viewModel: CourseUnitViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Colors.background
            HStack(spacing: 8) {
                let vertical = viewModel.verticals[viewModel.verticalIndex]
                let data = Array(viewModel.displayItems.enumerated())
                ForEach(data, id: \.offset) { index, item in
                    let isSelected = index == viewModel.index
                    let isItemDone = item.allBlocks.allSatisfy { $0.completion == 1.0 }
                    let isDone = isItemDone || vertical.completion == 1.0
                    if  isSelected && isDone {
                        Theme.Colors.progressSelectedAndDone
                            .frame(height: 7)
                    } else if isSelected {
                        Theme.Colors.onProgress
                            .frame(height: 7)
                    } else if isDone {
                        Theme.Colors.progressDone
                    } else {
                        Theme.Colors.progressSkip
                    }
                }
            }.frame(height: 5)
        }
        .frame(height: 10)
    }
}

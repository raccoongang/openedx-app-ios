//
//  LessonProgressView.swift
//  Course
//
//  Created by  Stepanok Ivan on 30.05.2023.
//

import SwiftUI
import Core
import Theme

struct LessonProgressView: View {
    @ObservedObject var viewModel: CourseUnitViewModel
    
    @Environment(\.isHorizontal) private var isHorizontal
    
    init(viewModel: CourseUnitViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        HStack {
            Spacer()
            VStack {
                Spacer()
                let items = viewModel.displayItems
                ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                    let isSelected = index == viewModel.index
                    Circle()
                        .frame(
                            width: isSelected ? 5 : 3,
                            height: isSelected ? 5 : 3
                        )
                        .foregroundColor(
                            isSelected ? .accentColor : Theme.Colors.textSecondary
                        )
                }
                Spacer()
            }
            .padding(.trailing, isHorizontal ? 0 : 6)
        }
    }
}

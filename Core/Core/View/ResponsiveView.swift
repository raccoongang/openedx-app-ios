//
//  ResponsiveView.swift
//  Core
//
//  Created by  Stepanok Ivan on 26.03.2024.
//

import SwiftUI

public struct ResponsiveView: View {
    @Binding private var collapsed: Bool
    private var idiom: UIUserInterfaceIdiom
    
    public init(collapsed: Binding<Bool>, idiom: UIUserInterfaceIdiom) {
        self._collapsed = collapsed
        self.idiom = idiom
    }

    public var body: some View {
        VStack {}.frame(height: collapsed ? 250 : 0)
            .overlay(
                GeometryReader { geometry -> Color in
                    DispatchQueue.main.async {
                        let minY = Int(geometry.frame(in: .global).minY)
                        if idiom == .phone {
                            if minY <= 20 {
                                print("Collapsed --  \(minY)")
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.6)) {
                                    self.collapsed = true
                                }
                            } else {
                                print("Expanded --  \(minY)")
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.6)) {
                                    self.collapsed = false
                                }
                            }
                        }
                    }
                    return Color.clear
                }
            )
    }
}



//
//  FlexibleFlowLayout.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 14/11/25.
//

import Foundation
import SwiftUI

struct FlexibleFlowLayout<Data: RandomAccessCollection, Cell: View>: View where Data.Element: Identifiable {
    // ... (this struct is unchanged)
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let cell: (Data.Element) -> Cell

    @State private var totalHeight: CGFloat

    init(data: Data, spacing: CGFloat = 8, alignment: HorizontalAlignment = .leading, @ViewBuilder cell: @escaping (Data.Element) -> Cell) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.cell = cell
        self._totalHeight = State(initialValue: .zero)
    }

    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(self.data) { item in
                self.cell(item)
                    .padding([.horizontal, .vertical], spacing / 2)
                    .alignmentGuide(self.alignment, computeValue: { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        
                        if item.id == self.data.last?.id {
                            width = 0 // last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        
                        if item.id == self.data.last?.id {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}

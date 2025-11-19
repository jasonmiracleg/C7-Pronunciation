//
//  FlowLayout.swift
//  C7-Pronunciation
//
//  Created by Abelito Faleyrio Visese on 19/11/25.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.last?.maxY ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        for row in rows {
            for element in row.elements {
                element.subview.place(at: CGPoint(x: bounds.minX + element.x, y: bounds.minY + row.y), proposal: .unspecified)
            }
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row(y: 0, elements: [])
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > maxWidth && !currentRow.elements.isEmpty {
                rows.append(currentRow)
                currentRow = Row(y: currentRow.maxY + spacing, elements: [])
                x = 0
            }
            
            currentRow.elements.append(Row.Element(x: x, subview: subview))
            x += size.width + spacing
        }
        
        if !currentRow.elements.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    struct Row {
        var y: CGFloat
        var elements: [Element]
        
        var maxY: CGFloat {
            let maxHeight = elements.map { $0.subview.sizeThatFits(.unspecified).height }.max() ?? 0
            return y + maxHeight
        }
        
        struct Element {
            var x: CGFloat
            var subview: LayoutSubview
        }
    }
}

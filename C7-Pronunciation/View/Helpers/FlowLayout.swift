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
            // MARK: - Centering Logic
            // 1. Calculate the actual width occupied by items in this row
            let lastElement = row.elements.last
            let lastElementWidth = lastElement?.subview.sizeThatFits(.unspecified).width ?? 0
            let rowContentWidth = (lastElement?.x ?? 0) + lastElementWidth
            
            // 2. Calculate the offset needed to center the content
            // (Available Width - Content Width) / 2
            let offset = (bounds.width - rowContentWidth) / 2
            
            for element in row.elements {
                // 3. Apply the offset to the X position
                element.subview.place(
                    at: CGPoint(
                        x: bounds.minX + element.x + max(0, offset), // Prevent negative offset
                        y: bounds.minY + row.y
                    ),
                    proposal: .unspecified
                )
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
            
            // Check if adding this item exceeds the max width
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

//
//  WordItem.swift
//  C7-Pronunciation
//
//  Created by Jason Miracle Gunawan on 17/11/25.
//

import Foundation

struct WordItem: Identifiable {
    let id = UUID()
    let index: Int
    let word: String
}

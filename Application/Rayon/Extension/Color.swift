//
//  Color.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import SwiftUI

#if os(iOS)
    private typealias SystemColor = UIColor
#endif

#if os(macOS)
    private typealias SystemColor = NSColor
#endif

extension Color {}

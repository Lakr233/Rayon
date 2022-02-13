//
//  AlignedLabel.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/10.
//

import SwiftUI

struct AlignedLabel: View {
    init(_ str: String, icon: String) {
        text = str
        systemImage = icon
    }

    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: systemImage)
                .frame(width: 20, height: 20)
            Spacer().frame(width: 4)
            Text(text)
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
    }
}

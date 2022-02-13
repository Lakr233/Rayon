//
//  PlaceholderView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import SwiftUI

struct PlaceholderView: View {
    let hint: String
    let image: ImageDescriptor

    init(_ str: String, img: ImageDescriptor? = nil) {
        hint = str
        if let img = img {
            image = img
        } else {
            image = .ghost
        }
    }

    enum ImageDescriptor: String {
        case emptyWindow = "empty_window"
        case fileLock = "file_lock"
        case ghost
        case connectionBroken = "connection_broken"
        case personWarning = "person_warning"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(image.rawValue)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
            ZStack {
                Color(UIColor.systemGray6)
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .frame(maxWidth: 400)
            .overlay(
                Text(hint)
                    .font(.system(.headline, design: .rounded))
            )
            .roundedCorner()
            Spacer()
                .frame(width: 40, height: 40)
        }
        .expended()
        .padding()
    }
}

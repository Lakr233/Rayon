//
//  FileTransferView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/18.
//

import SwiftUI

struct FileTransferView: View {
    let context: FileTransferContext

    var body: some View {
        VStack {
            fileList
            bottomToolbar
        }
        .navigationTitle("SFTP - " + context.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    var fileList: some View {
        ScrollView {}
    }

    var bottomToolbar: some View {
        HStack {}
    }
}

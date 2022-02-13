//
//  CreateSnippetSheetView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/10.
//

import CodeMirrorUI
import SwiftUI

struct EditSnippetSheetView: View {
    // if edit nothing, create one
    let inEdit: RDSnippet.ID?
    let editor = SCodeEditor()

    @EnvironmentObject var store: RayonStore
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    @State var name: String = ""
    @State var group: String = ""
    @State var code: String = ""
    @State var comment: String = ""

    var body: some View {
        SheetTemplate.makeSheet(
            title: "Select Identity",
            body: AnyView(sheetBody)
        ) { confirmed in
            var shouldDismiss = false
            defer { if shouldDismiss { presentationMode.wrappedValue.dismiss() } }
            if !confirmed {
                shouldDismiss = true
                return
            }
            if let inEdit = inEdit {
                var inplaceEdit = store.userSnippets[inEdit]
                inplaceEdit.name = name
                inplaceEdit.group = group
                inplaceEdit.code = code
                inplaceEdit.comment = comment
                store.userSnippets.insert(inplaceEdit)
            } else {
                let create = RDSnippet(
                    name: name,
                    group: group,
                    code: code,
                    comment: comment
                )
                store.userSnippets.insert(create)
            }
            shouldDismiss = true
        }
        .onAppear {
            if let inEdit = inEdit {
                let orig = store.userSnippets[inEdit]
                name = orig.name
                group = orig.group
                code = orig.code
                comment = orig.comment
            } else {
                code = "#!/bin/bash\n"
                comment = "Created at: " + Date().formatted()
            }
            editor.setDocumentData(code)
        }
    }

    var sheetBody: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    AlignedLabel("Name", icon: "tag")
                    TextField("Name", text: $name)
                }
                VStack(alignment: .leading) {
                    AlignedLabel("Group", icon: "square.stack.3d.down.forward")
                    TextField("Default (Optional)", text: $group)
                }
            }
            AlignedLabel("Comment", icon: "text.bubble")
            TextField("No Comment (Optional)", text: $comment)
            editor
                .onContentChange { code = $0 }
        }
        .requiresSheetFrame(500, 300)
    }
}

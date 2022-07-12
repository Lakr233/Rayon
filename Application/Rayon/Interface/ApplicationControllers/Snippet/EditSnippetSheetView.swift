//
//  CreateSnippetSheetView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/10.
//

import CodeEditorUI
import RayonModule
import SwiftUI
import SymbolPicker

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
    @State var avatar: String = ""

    @State var openSymbolPicker: Bool = false

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
                var inplaceEdit = store.snippetGroup[inEdit]
                inplaceEdit.name = name
                inplaceEdit.group = group
                inplaceEdit.code = code
                inplaceEdit.comment = comment
                inplaceEdit.setSFAvatar(sfSymbol: avatar)
                store.snippetGroup.insert(inplaceEdit)
            } else {
                var create = RDSnippet(
                    name: name,
                    group: group,
                    code: code,
                    comment: comment
                )
                create.setSFAvatar(sfSymbol: avatar)
                store.snippetGroup.insert(create)
            }
            shouldDismiss = true
        }
        .onAppear {
            if let inEdit = inEdit {
                let orig = store.snippetGroup[inEdit]
                name = orig.name
                group = orig.group
                code = orig.code
                comment = orig.comment
                avatar = orig.getSFAvatar()
            } else {
                code = "#!/bin/bash\n"
                comment = "Created at: " + Date().formatted()
            }
            editor.setDocumentData(code)
        }
    }

    var sheetBody: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            HStack {
                AlignedLabel("Code", icon: "chevron.left.forwardslash.chevron.right")
                Spacer()
                Image(systemName: avatar)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Button {
                    openSymbolPicker = true
                } label: {
                    Text("Pick Avatar")
                        .underline()
                        .foregroundColor(.accentColor)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .makeHoverPointer()
                }
                .buttonStyle(PlainButtonStyle())
            }
            editor
                .onContentChange { code = $0 }
                .border(Color.gray, width: 0.5)
        }
        .sheet(isPresented: $openSymbolPicker, onDismiss: nil, content: {
            SymbolPicker(symbol: $avatar)
        })
        .requiresSheetFrame(500, 300)
    }
}

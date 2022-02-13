//
//  IdentityPickerView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import RayonModule
import SwiftUI

struct IdentityPickerSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: RayonStore

    let onComplete: (RDIdentity.ID?) -> Void
    @State var currentSelection: RDIdentity.ID?
    @State var hoverFocus: RDIdentity.ID?

    @State var openCreateSheet: Bool = false

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
            onComplete(currentSelection)
            shouldDismiss = true
        }
        .sheet(isPresented: $openCreateSheet, onDismiss: nil) {
            CreateIdentitiesView(selection: .constant(nil)) {
                currentSelection = $0
            }
        }
    }

    var sheetBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    openCreateSheet = true
                } label: {
                    Label("Create New Identity", systemImage: "plus.viewfinder")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .foregroundColor(.accentColor)
                        .background(
                            Color.accentColor
                                .opacity(0.05)
                                .roundedCorner()
                        )
                }
                .buttonStyle(PlainButtonStyle())
                identitiesBody
            }
        }
        .animation(.interactiveSpring(), value: currentSelection)
        .animation(.interactiveSpring(), value: hoverFocus)
        .requiresSheetFrame()
    }

    var identitiesBody: some View {
        ForEach(store.identityGroup.identities) { element in
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "person.fill")
                    Text(element.username)
                    Spacer()
                    if element.group.count > 0 {
                        Text(element.group)
                    }
                }
                HStack {
                    Text("Authenticate with: \(element.getKeyType())")
                    Spacer()
                    if element.comment.count > 0 {
                        Text(element.comment)
                    }
                }
                .font(.system(.caption, design: .rounded))
                Divider()
                Text(element.id.uuidString)
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
            }
            .padding(10)
            .background(
                Color.accentColor
                    .opacity(currentSelection == element.id ? 0.1 : 0)
                    .roundedCorner()
                    .border(
                        Color.gray.opacity(0.5),
                        width: hoverFocus == element.id ? 0.5 : 0
                    )
            )
            .overlay(
                Color.accentColor.opacity(0.001)
            )
            .onTapGesture {
                currentSelection = element.id
            }
            .onHover { hover in
                if hover {
                    hoverFocus = element.id
                } else {
                    hoverFocus = nil
                }
            }
        }
    }
}

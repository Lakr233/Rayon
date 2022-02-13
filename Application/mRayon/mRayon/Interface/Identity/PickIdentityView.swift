//
//  PickIdentityView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/3.
//

import RayonModule
import SwiftUI

struct PickIdentityView: View {
    @StateObject var store = RayonStore.shared

    @Binding var selection: RDIdentity.ID?
    @State var rawSelection: RDIdentity.ID? = nil

    init(selection: Binding<RDIdentity.ID?>) {
        _selection = selection
    }

    private var completion: ((RDIdentity.ID?) -> Void)?

    /// MAKE SURE THIS VIEW IS NOT DISMISSABLE BY DRAG
    /// - Parameter completion: only called when touch checkmark button
    init(completion: @escaping ((RDIdentity.ID?) -> Void)) {
        self.completion = completion
        _selection = Binding<RDIdentity.ID?> { nil } set: { _ in }
    }

    @Environment(\.presentationMode) var presentationMode

    @State var openCreate: Bool = false

    var body: some View {
        List {
            Section {
                if let sid = rawSelection {
                    Label(
                        store
                            .identityGroup[sid]
                            .shortDescription(),
                        systemImage: "person"
                    )
                } else {
                    Label("Not Selected", systemImage: "questionmark.square.dashed")
                }
            } header: {
                Label("Selected Identity", systemImage: "arrow.right")
            }

            Section {
                Button {
                    openCreate = true
                } label: {
                    Label("Create New Identity", systemImage: "arrow.right")
                }
                .background(
                    NavigationLink(isActive: $openCreate) {
                        EditIdentityView()
                    } label: {
                        Group {}
                    }
                )
                ForEach(
                    store
                        .identityGroup
                        .identities
                ) { identity in
                    Button {
                        rawSelection = identity.id
                    } label: {
                        Label(identity.shortDescription(), systemImage: "person")
                    }
                }
            } header: {
                Label("Available Identities", systemImage: "person.3")
            }

            Section {
                Button {
                    rawSelection = nil
                } label: {
                    Label("Clear Selection", systemImage: "xmark")
                }
                .disabled(rawSelection == nil)
            }
        }
        .navigationTitle("Pick Identity")
        .toolbar {
            ToolbarItem {
                Button {
                    presentationMode.wrappedValue.dismiss()
                    completion?(rawSelection)
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
            }
        }
        .onChange(of: rawSelection) { newValue in
            selection = newValue
        }
    }
}

struct PickIdentityView_Previews: PreviewProvider {
    @State static var selection: RDIdentity.ID? = nil

    static var previews: some View {
        createPreview { AnyView(PickIdentityView(selection: $selection)) }
    }
}

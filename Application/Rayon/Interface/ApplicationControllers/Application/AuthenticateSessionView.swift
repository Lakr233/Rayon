//
//  AuthenticateSessionView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import NSRemoteShell
import RayonModule
import SwiftUI

struct AuthenticateSessionView: View {
    @Binding var remote: NSRemoteShell?
    @State var selection: RDIdentity.ID? = nil
    @EnvironmentObject var store: RayonStore

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Group {
            if remote != nil {
                SheetTemplate.makeSheet(
                    title: "Authenticate",
                    body: AnyView(sheetBody)
                ) { confirmed in
                    var shouldDismiss = false
                    defer { if shouldDismiss { presentationMode.wrappedValue.dismiss() }}
                    if !confirmed {
                        shouldDismiss = true
                        return
                    }
                }
            } else {
                Text("")
                    .onAppear {
                        presentationMode.wrappedValue.dismiss()
                        UIBridge.presentError(with: "No session available for authentication")
                    }
            }
        }
    }

    var sheetBody: some View {
        VStack {}
    }
}

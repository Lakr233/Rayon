//
//  SessionView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/10.
//

import RayonModule
import SwiftUI

struct SessionView: View {
    let session: RDSession

    var body: some View {
        NavigationView {
            SessionSidebarView()
                .frame(minWidth: 200)
            SessionPlaceholderView()
                .requiresFrame()
        }
        .environmentObject(session.context)
    }
}

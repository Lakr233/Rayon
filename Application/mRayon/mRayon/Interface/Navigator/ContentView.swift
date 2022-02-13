//
//  ContentView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import SwiftUI

/*

 Why would any body use this app on iPhone?

 */

struct ContentView: View {
//    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
//
//    var useTabs: Bool {
//        if horizontalSizeClass == .compact {
//            return true
//        }
//        if UIDevice.current.userInterfaceIdiom != .pad {
//            return true
//        }
//        return false
//    }

    var body: some View {
//        Group {
//            if useTabs {
//                TabsView()
//            } else {
        SidebarView()
//            }
//        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

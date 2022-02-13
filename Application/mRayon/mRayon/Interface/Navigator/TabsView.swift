////
////  TabsView.swift
////  mRayon
////
////  Created by Lakr Aream on 2022/3/2.
////
//
// import SwiftUI
//
// struct TabsView: View {
//    var body: some View {
//        TabView {
//            NavigationView {
//                MachineView()
//            }
//            .navigationViewStyle(StackNavigationViewStyle())
//            .tabItem {
//                Label("Machine", systemImage: "server.rack")
//            }
//            NavigationView {
//                SnippetView()
//            }
//            .navigationViewStyle(StackNavigationViewStyle())
//            .tabItem {
//                Label("Snippet", systemImage: "chevron.left.forwardslash.chevron.right")
//            }
//            NavigationView {
//                TerminalTabView()
//            }
//            .navigationViewStyle(StackNavigationViewStyle())
//            .tabItem {
//                Label("Terminal", systemImage: "terminal")
//            }
//            NavigationView {
//                PortForwardView()
//            }
//            .navigationViewStyle(StackNavigationViewStyle())
//            .tabItem {
//                Label("Ports", systemImage: "arrow.left.arrow.right")
//            }
//            NavigationView {
//                IdentityView()
//            }
//            .navigationViewStyle(StackNavigationViewStyle())
//            .tabItem {
//                Label("Identity", systemImage: "person")
//            }
//            NavigationView {
//                SettingView()
//            }
//            .navigationViewStyle(StackNavigationViewStyle())
//            .tabItem {
//                Label("Setting", systemImage: "gear")
//            }
//        }
//    }
// }
//
// struct TabsView_Previews: PreviewProvider {
//    static var previews: some View {
//        TabsView()
//            .previewDevice(PreviewDevice(rawValue: "iPod touch (7th generation)"))
//    }
// }

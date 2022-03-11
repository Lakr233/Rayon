////
////  PortForwardExecView.swift
////  mRayon
////
////  Created by Lakr Aream on 2022/3/12.
////
//
// import RayonModule
// import SwiftUI
//
// struct PortForwardExecView: View {
//    @StateObject var context: PortForwardBackend.Context
//
//    var body: some View {
//        ZStack {
//            if context.closed {
//                PlaceholderView("Connection Closed", img: .connectionBroken)
//            } else {
//                content
//                    .environmentObject(context)
//                    .padding()
//                    .toolbar {
//                        ToolbarItem {
//                            Button {
//                                PortForwardBackend.shared.endSession(withPortForwardID: context.info.id)
//                            } label: {
//                                Label("Terminate", systemImage: "trash")
//                            }
//                        }
//                    }
//            }
//        }
//        .expended()
//        .navigationTitle("Port Forward")
//    }
//
//    var content: some View {
//        VStack {
//            if context.info.forwardOrientation == .listenLocal {
//                ListenLocalView()
//            }
//            if context.info.forwardOrientation == .listenRemote {
//                ListenRemoteView()
//            }
//        }
//    }
//
//    struct ListenLocalView: View {
//        @EnvironmentObject var context: PortForwardBackend.Context
//
//        var body: some View {
//            VStack(spacing: 20) {
//                Label("", systemImage: "play.fill")
//                    .font(.system(.headline, design: .rounded))
//                    .foregroundColor(.accentColor)
//                Divider()
//                HStack(spacing: 10) {
//                    Image(systemName: "ear")
//                    Text("localhost:\(String(context.info.bindPort))")
//                    Image(systemName: "tram.fill.tunnel")
//                    Image(systemName: "arrow.right")
//                    Text("\(context.info.getMachineName() ?? "Remote Machine")")
//                    Image(systemName: "chevron.forward")
//                    Text("\(context.info.targetHost):\(String(context.info.targetPort))")
//                }
//                .font(.system(.subheadline, design: .rounded))
//                if !context.lastHint.isEmpty {
//                    Text("STATUS: " + context.lastHint.uppercased())
//                        .font(.caption)
//                }
//            }
//        }
//    }
//
//    struct ListenRemoteView: View {
//        @EnvironmentObject var context: PortForwardBackend.Context
//
//        var body: some View {
//            VStack(spacing: 20) {
//                Label("", systemImage: "play.fill")
//                    .font(.system(.headline, design: .rounded))
//                    .foregroundColor(.accentColor)
//                Divider()
//                HStack(spacing: 10) {
//                    Image(systemName: "ear")
//                    Text("\(context.info.getMachineName() ?? "Remote Machine"):\(String(context.info.bindPort))")
//                    Image(systemName: "tram.fill.tunnel")
//                    Image(systemName: "arrow.right")
//                    Text("localhost")
//                    Image(systemName: "chevron.forward")
//                    Text("\(context.info.targetHost):\(String(context.info.targetPort))")
//                }
//                .font(.system(.subheadline, design: .rounded))
//                if !context.lastHint.isEmpty {
//                    Text("STATUS: " + context.lastHint.uppercased())
//                        .font(.caption)
//                }
//            }
//        }
//    }
// }
//
//// struct PortForwardExecView_Previews: PreviewProvider {
////    static func getView() -> some View {
////        var obj = RDPortForward()
////        obj.id = UUID(uuidString: "587A88BF-823C-46D6-AFA7-987045026EEC")!
////        RayonStore.shared.portForwardGroup.insert(obj)
////        PortForwardBackend.shared.createSession(withPortForwardID: obj.id)
////        return PortForwardExecView(context: PortForwardBackend.shared.sessionContext(withPortForwardID: obj.id)!)
////    }
//
////    static var previews: some View {
////        createPreview {
////            AnyView(ListenLocalView())
////        }
////    }
//// }

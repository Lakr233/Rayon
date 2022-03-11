//
//  PortForwardElementView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/12.
//

import RayonModule
import SwiftUI

struct PortForwardElementView: View {
    @EnvironmentObject var store: RayonStore
    @StateObject var backend = PortForwardBackend.shared
    @State var context: PortForwardBackend.Context? = nil

    let forward: RDPortForward.ID

    @State var openEdit: Bool = false

    var title: String {
        switch store.portForwardGroup[forward].forwardOrientation {
        case .listenLocal: return "Local Forward"
        case .listenRemote: return "Remote Forward"
        }
    }

    var body: some View {
        contentView
            .overlay {
                Menu {
                    Section {
                        if backend.sessionExists(withPortForwardID: forward) {
                            Button {
                                stopForwardSession()
                            } label: {
                                Label("Stop Forward", systemImage: "trash")
                            }
                        } else {
                            Button {
                                startForwardSession()
                            } label: {
                                Label("Open Forward", systemImage: "paperplane")
                            }
                        }
                    }

                    if !backend.sessionExists(withPortForwardID: forward) {
                        Section {
                            Button {
                                openEdit = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                var newForward = store.portForwardGroup[forward]
                                newForward.id = .init()
                                store.portForwardGroup.insert(newForward)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                        }
                    }

                    Section {
                        Button {
                            if let command = store
                                .portForwardGroup[forward]
                                .getCommand()
                            {
                                UIBridge.sendPasteboard(str: command)
                            } else {
                                UIBridge.presentError(with: "Failed Get Command")
                            }
                        } label: {
                            Label("Copy Command", systemImage: "doc.on.doc")
                        }
                    }

                    if !backend.sessionExists(withPortForwardID: forward) {
                        Section {
                            Button {
                                UIBridge.requiresConfirmation(
                                    message: "Are you sure you want to delete this forward?"
                                ) { confirmed in
                                    if confirmed {
                                        store.portForwardGroup.delete(forward)
                                    }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } label: {
                    Color.accentColor
                        .opacity(0.0001)
                }
                .offset(x: 0, y: 4)
            }
    }

    var contentView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "sensor.tag.radiowaves.forward")
                HStack {
                    Text(title)
                    Spacer()
                    Text(
                        backend
                            .lastHint[forward, default: ""]
                            .uppercased()
                    )
                    .font(.caption)
                }
            }
            .font(.system(.headline, design: .rounded))
            Divider()
            HStack(spacing: 4) {
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Bind Port:")
                        .lineLimit(1)
                    Text("Machine:")
                        .lineLimit(1)
                    Text("Target Host:")
                        .lineLimit(1)
                    Text("Target Port:")
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(
                        store.portForwardGroup[forward]
                            .bindPort
                    ))
                    .lineLimit(1)
                    Text(
                        store.portForwardGroup[forward]
                            .getMachineName() ?? "Not Set"
                    )
                    .lineLimit(1)
                    Text(
                        store.portForwardGroup[forward]
                            .targetHost
                    )
                    .lineLimit(1)
                    Text(String(
                        store.portForwardGroup[forward]
                            .targetPort
                    ))
                    .lineLimit(1)
                }
            }
            .font(.system(.subheadline, design: .rounded))
            Divider()
            Text(forward.uuidString)
                .textSelection(.enabled)
                .font(.system(size: 8, weight: .light, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            Color(
                backend.sessionExists(withPortForwardID: forward) ?
                    UIColor.systemBlue.withAlphaComponent(0.1)
                    : UIColor.systemGray6
            )
            .roundedCorner()
        )
        .background(
            NavigationLink(isActive: $openEdit) {
                EditPortForwardView { forward }
            } label: {
                Group {}
            }
        )
    }

    func startForwardSession() {
        PortForwardBackend.shared.createSession(withPortForwardID: forward)
    }

    func stopForwardSession() {
        PortForwardBackend.shared.endSession(withPortForwardID: forward)
    }
}

struct PortForwardView_Previews: PreviewProvider {
    static func getView() -> some View {
        var obj = RDPortForward()
        obj.id = UUID(uuidString: "587A88BF-823C-46D6-AFA7-987045026EEC")!
        RayonStore.shared.portForwardGroup.insert(obj)
        return PortForwardView()
    }

    static var previews: some View {
        createPreview {
            AnyView(getView())
        }
    }
}

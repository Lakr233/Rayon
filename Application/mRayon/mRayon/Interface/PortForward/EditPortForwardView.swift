//
//  EditPortForwardView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/12.
//

import RayonModule
import SwiftUI

struct EditPortForwardView: View {
    @Environment(\.presentationMode) var presentationMode

    let inEditWith: (() -> (UUID?))?

    init(requestIdentity: (() -> (UUID?))? = nil) {
        inEditWith = requestIdentity
    }

    @State var initializedOnce = false

    @State var forwardOrientation: RDPortForward.ForwardOrientation = .listenLocal
    @State var bindPort: Int = 3000
    @State var targetHost: String = "127.0.0.1"
    @State var targetPort: Int = 3000
    @State var usingMachine: RDMachine.ID? = nil

    var generateObject: RDPortForward {
        RDPortForward(
            forwardOrientation: forwardOrientation,
            bindPort: bindPort,
            targetHost: targetHost,
            targetPort: targetPort,
            usingMachine: usingMachine
        )
    }

    var forwardDescription: String {
        generateObject.shortDescription()
    }

    var body: some View {
        List {
            Section {
                Picker("Forward Orientation", selection: $forwardOrientation) {
                    ForEach(RDPortForward.ForwardOrientation.allCases, id: \.self) { acase in
                        Text(acase.rawValue)
                            .tag(acase)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            } header: {
                Label("Forward Orientation", systemImage: forwardOrientation == .listenLocal ? "arrow.right" : "arrow.left")
            } footer: {
                Text("Indicate where should we listen on.")
            }

            Section {
                TextField("Bind Port", text: .init(get: {
                    String(bindPort)
                }, set: { str in
                    bindPort = Int(str) ?? 0
                }))
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                .keyboardType(.numberPad)
            } header: {
                Label("Forward Basic", systemImage: "sensor.tag.radiowaves.forward")
            } footer: {
                Text("You should be able to access target using this port on \(forwardOrientation == .listenLocal ? "local host" : "remote host").")
            }

            Section {
                TextField("Target Address", text: $targetHost)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                TextField("Target Port", text: .init(get: {
                    String(targetPort)
                }, set: { str in
                    targetPort = Int(str) ?? 0
                }))
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                .keyboardType(.numberPad)
            } header: {
                Label("Target Host", systemImage: "circle.hexagongrid.circle")
            } footer: {
                Text("The target host and port you want to access, using this ssh tunnel.")
            }

            Section {
                Button {
                    DispatchQueue.global().async {
                        let machine = RayonUtil.selectOneMachine()
                        mainActor {
                            usingMachine = machine.first
                        }
                    }
                } label: {
                    Label("Select Machine", systemImage: "arrow.right")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Label("Machine", systemImage: "server.rack")
            } footer: {
                Text("We will use this machine to create tunnel for you.")
            }

            Section {} footer: { Text(forwardDescription) }
        }
        .onAppear {
            if initializedOnce { return }
            initializedOnce = true
            mainActor(delay: 0.1) { // <-- SwiftUI bug here, don't remove
                if let edit = inEditWith?() {
                    let read = RayonStore.shared.portForwardGroup[edit]
                    forwardOrientation = read.forwardOrientation
                    bindPort = read.bindPort
                    targetHost = read.targetHost
                    targetPort = read.targetPort
                    usingMachine = read.usingMachine
                }
            }
        }
        .navigationTitle("Edit Forward")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    completeSheet()
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
            }
        }
    }

    func completeSheet() {
        var object = generateObject
        if let edit = inEditWith?() {
            object.id = edit
        }
        RayonStore.shared.portForwardGroup.insert(object)
        presentationMode.wrappedValue.dismiss()
    }
}

struct EditPortForwardView_Previews: PreviewProvider {
    static var previews: some View {
        createPreview {
            AnyView(EditPortForwardView())
        }
    }
}

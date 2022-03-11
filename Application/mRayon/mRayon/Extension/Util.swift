//
//  Util.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/3.
//

import Foundation
import LocalAuthentication
import RayonModule
import SwiftUI
import UIKit

let preferredPopOverSize = CGSize(width: 700, height: 555)

enum RayonUtil {
    private static func deviceHasPassword() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    typealias DeviceOwnershipCheckSuccess = Bool
    static func deviceOwnershipAuthenticate(onComplete: @escaping (DeviceOwnershipCheckSuccess) -> Void) {
        DispatchQueue.global().async {
            guard deviceHasPassword() else {
                onComplete(true)
                return
            }
            let context = LAContext()
            let reason = "Performing privacy sensitive operation requires device ownership authenticated"
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { success, error in
                mainActor {
                    if success {
                        debugPrint(#function, "success")
                        onComplete(true)
                    } else {
                        debugPrint(#function, "failure", error?.localizedDescription ?? "Unknown Error")
                        onComplete(false)
                    }
                }
            }
        }
    }

    static func selectIdentity() -> RDIdentity.ID? {
        assert(!Thread.isMainThread, "select identity must be called from background thread")

        var selection: RDIdentity.ID?
        let sem = DispatchSemaphore(value: 0)

        debugPrint("Picking Identity")

        mainActor {
            let picker = NavigationView {
                PickIdentityView {
                    selection = $0
                    sem.signal()
                }
            }
            .expended()
            .navigationViewStyle(StackNavigationViewStyle())
            let controller = UIHostingController(rootView: picker)
            controller.isModalInPresentation = true
            controller.modalTransitionStyle = .coverVertical
            controller.modalPresentationStyle = .formSheet
            controller.preferredContentSize = preferredPopOverSize
            UIWindow.shutUpKeyWindow?
                .topMostViewController?
                .present(controller, animated: true, completion: nil)
        }

        sem.wait()

        return selection
    }

    static func selectMachine(canSelectMany: Bool = true) -> [RDMachine.ID] {
        assert(!Thread.isMainThread, "select identity must be called from background thread")

        var selection: [RDMachine.ID] = []
        let sem = DispatchSemaphore(value: 0)

        debugPrint("Picking Machine")

        mainActor {
            let picker = NavigationView {
                PickMachineView(completion: {
                    selection = $0
                    sem.signal()
                }, canSelectMany: canSelectMany)
            }
            .expended()
            .navigationViewStyle(StackNavigationViewStyle())
            let controller = UIHostingController(rootView: picker)
            controller.isModalInPresentation = true
            controller.modalTransitionStyle = .coverVertical
            controller.modalPresentationStyle = .formSheet
            controller.preferredContentSize = preferredPopOverSize
            UIWindow.shutUpKeyWindow?
                .topMostViewController?
                .present(controller, animated: true, completion: nil)
        }

        sem.wait()

        return selection
    }

    static func selectOneMachine() -> [RDMachine.ID] {
        selectMachine(canSelectMany: false)
    }

    static func createExecuteFor(snippet: RDSnippet) {
        DispatchQueue.global().async {
            let machineIds = selectMachine()
            debugPrint(machineIds)
            guard !machineIds.isEmpty else {
                return
            }
            // so that picker is closed
            mainActor(delay: 0.6) {
                let runner = NavigationView {
                    let context = SnippetExecuteContext(snippet: snippet, machineGroup: machineIds.map { machineId in
                        RayonStore.shared.machineGroup[machineId]
                    })
                    SnippetExecuteView(context: context)
                }
                .expended()
                .navigationViewStyle(StackNavigationViewStyle())
                .navigationBarTitleDisplayMode(.inline)
                let controller = UIHostingController(rootView: runner)
                controller.isModalInPresentation = true
                controller.modalTransitionStyle = .coverVertical
                controller.modalPresentationStyle = .formSheet
                controller.preferredContentSize = preferredPopOverSize
                UIWindow.shutUpKeyWindow?
                    .topMostViewController?
                    .present(controller, animated: true, completion: nil)
            }
        }
    }
}

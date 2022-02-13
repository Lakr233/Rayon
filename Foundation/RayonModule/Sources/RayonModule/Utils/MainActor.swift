//
//  mainActor.swift
//
//
//  Created by Lakr Aream on 2022/3/1.
//

import Foundation

/// Not actually a Actor but I like it
/// - Parameter run: the job to be fired on main thread
func mainActor(delay: Double = 0, run: @escaping () -> Void) {
    guard delay == 0, Thread.isMainThread else {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            run()
        }
        return
    }
    run()
}

//
//  LicenseView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/13.
//

import SwiftUI

struct LicenseView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        SheetTemplate.makeSheet(
            title: "License Information",
            body: AnyView(sheetBody)
        ) { _ in
            presentationMode.wrappedValue.dismiss()
        }
    }

    var sheetBody: some View {
        ScrollView {
            Text(loadLicense())
                .textSelection(.enabled)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
        }
        .frame(width: 600, height: 250)
    }

    func loadLicense() -> String {
        guard let bundle = Bundle.main.url(forResource: "LICENSE", withExtension: nil),
              let str = try? String(contentsOfFile: bundle.path)
        else {
            return "Failed to load license info."
        }
        return str
    }
}

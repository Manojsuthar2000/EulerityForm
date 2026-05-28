//
//  EulerityFormApp.swift
//  EulerityForm
//

import SwiftUI

@main
struct EulerityFormApp: App {
    var body: some Scene {
        WindowGroup {
//            Swap the filename to test the edge-case payload:
//            DynamicFormView(viewModel: FormViewModel(bundleFile: "form_schema_edge_cases"))
//            DynamicFormView(viewModel: FormViewModel(bundleFile: "form_schema"))
            DynamicFormView(viewModel: FormViewModel(bundleFile: "form_schema_showcase"))
        }
    }
}

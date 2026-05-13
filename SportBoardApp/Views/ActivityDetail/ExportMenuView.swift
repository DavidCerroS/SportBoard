//
//  ExportMenuView.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI

struct ExportMenuView: View {
    @Bindable var viewModel: ActivityDetailViewModel
    @State private var shareExport: ShareExport?
    
    var body: some View {
        Menu {
            Button {
                viewModel.copyJSONToClipboard()
            } label: {
                Label("Copiar JSON al portapapeles", systemImage: "doc.on.clipboard")
            }
            
            Button {
                if let url = viewModel.exportJSONToFile() {
                    shareExport = ShareExport(url: url)
                }
            } label: {
                Label("Descargar archivo JSON", systemImage: "arrow.down.doc")
            }
        } label: {
            Label("Exportar", systemImage: "square.and.arrow.up")
        }
        .sheet(item: $shareExport) { export in
            ShareSheet(items: [export.url])
        }
    }
}

private struct ShareExport: Identifiable {
    let url: URL

    var id: URL { url }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

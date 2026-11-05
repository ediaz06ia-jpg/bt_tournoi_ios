import SwiftUI

/// État partagé avec la page : l'affichage public masque la barre d'état et l'indicateur d'accueil.
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var kiosk = false
}

@main
struct BeachTennisTournoiApp: App {
    @StateObject private var state = AppState.shared

    var body: some Scene {
        WindowGroup {
            TournamentWebView()
                // La page gère elle-même les zones sûres (env(safe-area-inset-*))
                .ignoresSafeArea()
                .background(Color("Background").ignoresSafeArea())
                .statusBarHidden(state.kiosk)
                .persistentSystemOverlays(state.kiosk ? .hidden : .automatic)
        }
    }
}

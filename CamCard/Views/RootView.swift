import SwiftUI

enum AppRoute: Hashable {
    case detail(UUID)
}

struct RootView: View {
    let environment: AppEnvironment

    @StateObject private var holder: CardHolderViewModel

    init(environment: AppEnvironment) {
        self.environment = environment
        _holder = StateObject(wrappedValue: CardHolderViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            CardHolderView(viewModel: holder, environment: environment)
                .navigationDestination(for: AppRoute.self) { route in
                    AppRouteDestination(route: route, environment: environment) {
                        Task { await holder.reload() }
                    }
                }
        }
        .task {
            await holder.bootstrap()
        }
    }
}

struct AppRouteDestination: View {
    let route: AppRoute
    let environment: AppEnvironment
    let onChanged: () -> Void

    var body: some View {
        switch route {
        case let .detail(id):
            CardDetailView(
                cardID: id,
                environment: environment,
                onChanged: onChanged
            )
        }
    }
}

#Preview {
    RootView(environment: PreviewData.environment())
}

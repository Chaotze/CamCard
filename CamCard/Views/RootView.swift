import SwiftUI

enum AppRoute: Hashable {
    case capture(photo: Bool)
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
                    switch route {
                    case let .capture(photo):
                        CaptureFlowView(
                            environment: environment,
                            autoStartPhoto: photo,
                            onSaved: {
                                Task { await holder.reload() }
                            }
                        )
                    case let .detail(id):
                        CardDetailView(
                            cardID: id,
                            environment: environment,
                            onChanged: {
                                Task { await holder.reload() }
                            }
                        )
                    }
                }
        }
        .task {
            await holder.bootstrap()
        }
    }
}

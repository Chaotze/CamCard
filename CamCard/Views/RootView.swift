import SwiftUI

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
        }
        .task {
            await holder.bootstrap()
        }
    }
}

#Preview {
    RootView(environment: PreviewData.environment())
}
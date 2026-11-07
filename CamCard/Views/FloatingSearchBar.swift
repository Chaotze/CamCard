import SwiftUI

struct FloatingSearchBar: View {
   @Binding var text: String
   var placeholder = "搜索姓名、公司、电话或标签"
   let onScan: () -> Void
   let onImport: () -> Void

   @FocusState private var isFocused: Bool

   private var isSearchActive: Bool {
       isFocused || !text.isEmpty
   }

   var body: some View {
       HStack(spacing: 10) {
           // --- 搜索输入框 ---
           HStack(spacing: 10) {
               Image(systemName: "magnifyingglass")
                   .foregroundStyle(.secondary)
                   .padding(.leading, 16)
               TextField(placeholder, text: $text)
                   .font(.body)
                   .focused($isFocused)
                   .submitLabel(.search)
                   .onSubmit { isFocused = false }
                   .accessibilityIdentifier("bottomSearchField")
               if !text.isEmpty {
                   Button {
                       text = ""
                   } label: {
                       Image(systemName: "xmark.circle.fill")
                           .foregroundStyle(.secondary)
                   }
                   .buttonStyle(.plain)
                   .padding(.trailing, 10)
                   .accessibilityLabel("清空搜索")
               }
           }
           .frame(height: 50)
           .background {
               if #available(iOS 26.0, *) {
                   Capsule().fill(.clear).glassEffect(.regular.interactive())
               } else {
                   Capsule().fill(.ultraThinMaterial)
               }
           }
           .overlay {
               Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1)
           }

           // --- 右侧按钮 ---
           Button {
               if isSearchActive {
                   text = ""
                   isFocused = false
               }
           } label: {
               Image(systemName: isSearchActive ? "xmark" : "plus")
                   .font(.system(size: 20, weight: .medium))
                   .foregroundStyle(.primary)
                   .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                   .frame(width: 56, height: 50)
                   .contentShape(Circle())
           }
           .buttonStyle(.plain)
           .background {
               if #available(iOS 26.0, *) {
                   Circle().fill(.clear).glassEffect(.regular.interactive())
               } else {
                   Circle().fill(.ultraThinMaterial)
               }
           }
           .overlay {
               Circle().stroke(Color.white.opacity(0.4), lineWidth: 1)
           }
           .accessibilityLabel(isSearchActive ? "退出搜索" : "添加名片")
           .overlay {
               if !isSearchActive {
                   Menu {
                       Button(action: onScan) {
                           Label("扫描名片", systemImage: "camera")
                       }
                       Button(action: onImport) {
                           Label("从相册导入", systemImage: "photo")
                       }
                   } label: {
                       Color.clear.contentShape(Circle())
                   }
               }
           }
       }
       .animation(.interpolatingSpring(stiffness: 200, damping: 20), value: isSearchActive)
   }
}

#Preview {
   @Previewable @State var text = ""
   FloatingSearchBar(text: $text, onScan: {}, onImport: {})
       .padding(16)
       .background(Color(uiColor: .secondarySystemBackground))
}

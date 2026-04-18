import SwiftUI

struct TabBarView: View {
    @Bindable var workspace: Workspace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(workspace.tabs) { tab in
                    TabItemView(
                        title: tab.title,
                        isDirty: tab.isDirty,
                        isActive: tab.id == workspace.activeTabID,
                        onSelect: {
                            workspace.activeTabID = tab.id
                        },
                        onClose: {
                            workspace.closeTab(tab.id)
                        }
                    )
                }
            }
        }
        .frame(height: 32)
        .background(.bar)
    }
}

struct TabItemView: View {
    let title: String
    let isDirty: Bool
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            if isDirty {
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
            }
            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isActive ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .background(isHovering && !isActive ? Color.secondary.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(perform: onSelect)
    }
}

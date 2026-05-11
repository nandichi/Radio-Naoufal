import SwiftUI

struct BrowseDrawerView: View {
    @Binding var isExpanded: Bool
    @State private var selectedTab: DrawerTab = .favorites

    enum DrawerTab: String, CaseIterable, Identifiable {
        case favorites
        case categories
        case search
        case recent

        var id: String { rawValue }

        var label: String {
            switch self {
            case .favorites: return String(localized: "Favorieten")
            case .categories: return String(localized: "Categorieen")
            case .search: return String(localized: "Zoeken")
            case .recent: return String(localized: "Recent")
            }
        }

        var icon: String {
            switch self {
            case .favorites: return "star.fill"
            case .categories: return "square.grid.2x2"
            case .search: return "magnifyingglass"
            case .recent: return "clock"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 11, weight: .heavy))
                        Text(String(localized: "BROWSE STATIONS"))
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .tracking(2)
                        Spacer()
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)

                Spacer()

                if isExpanded {
                    ForEach(DrawerTab.allCases) { tab in
                        TabButton(
                            tab: tab,
                            isSelected: tab == selectedTab,
                            action: { selectedTab = tab }
                        )
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        Rectangle()
                            .fill(BoomboxTheme.chromeBevel)
                            .frame(height: 1)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .opacity(0.3)
                    )
            )

            if isExpanded {
                ZStack {
                    switch selectedTab {
                    case .favorites:
                        FavoritesTab()
                    case .categories:
                        CategoriesTab()
                    case .search:
                        SearchTab()
                    case .recent:
                        RecentTab()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.06, blue: 0.08),
                            Color(red: 0.04, green: 0.04, blue: 0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(maxHeight: isExpanded ? 360 : nil)
    }
}

private struct TabButton: View {
    let tab: BrowseDrawerView.DrawerTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(tab.label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? .black : .white.opacity(0.75))
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? BoomboxTheme.amber : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

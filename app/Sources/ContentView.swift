import FinderSync
import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var extensionEnabled = FIFinderSyncController.isExtensionEnabled

    private let accent = Color(red: 0.18, green: 0.37, blue: 0.66)

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            finderCard
            usageCard
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(width: 470, height: 352)
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                RadialGradient(
                    colors: [
                        accent.opacity(colorScheme == .dark ? 0.14 : 0.075),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 420
                )
            }
            .ignoresSafeArea()
        }
        .tint(accent)
        .onAppear {
            refreshStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.1), radius: 7, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text("ZMacTools")
                    .font(.system(size: 21, weight: .semibold))
                Text("Finder 右键工具")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("v\(version)")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(height: 44)
    }

    private var finderCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill((extensionEnabled ? Color.green : Color.orange).opacity(0.12))
                Image(systemName: extensionEnabled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(extensionEnabled ? .green : .orange)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(extensionEnabled ? "Finder 右键已就绪" : "Finder 扩展未启用")
                    .font(.system(size: 12.5, weight: .semibold))
                Text(extensionEnabled ? "右键菜单已可使用" : "在系统设置中启用扩展")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            Button(extensionEnabled ? "设置" : "启用") {
                FIFinderSyncController.showExtensionManagementInterface()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.68))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        }
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("使用方法")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 15)
                .padding(.top, 10)
                .padding(.bottom, 4)

            UsageRow(
                icon: "doc.on.doc",
                title: "复制路径",
                subtitle: "右键文件或文件夹，选择 ZMacTools"
            )
            Divider()
                .padding(.leading, 47)
            UsageRow(
                icon: "folder",
                title: "复制当前目录",
                subtitle: "在 Finder 空白处右键"
            )
            Divider()
                .padding(.leading, 47)
            UsageRow(
                icon: "doc.badge.plus",
                title: "新建空文件",
                subtitle: "在 Finder 空白处右键，选择新建文件"
            )
        }
        .padding(.bottom, 6)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.68))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        }
    }

    private func refreshStatus() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }
}

private struct UsageRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 15)
        .frame(height: 46)
    }
}

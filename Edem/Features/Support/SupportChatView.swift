import SwiftUI

struct SupportChatView: View {
    @State private var viewModel: SupportChatViewModel
    @FocusState private var isInputFocused: Bool
    private let onResolved: (() async -> Void)?

    init(viewModel: SupportChatViewModel, onResolved: (() async -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onResolved = onResolved
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if viewModel.isOperatorTyping {
                        HStack {
                            Text("\(viewModel.operatorName) печатает…")
                                .font(.footnote)
                                .foregroundStyle(Palette.textSecondary)
                            Spacer()
                        }
                        .id("typing")
                    }
                    if let title = viewModel.resolutionActionTitle, let onResolved {
                        Button(title) {
                            Task { await onResolved() }
                        }
                        .buttonStyle(.edemSuccess)
                        .padding(.top, 8)
                        .id("resolution")
                    }
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Palette.danger)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                guard let lastID = viewModel.messages.last?.id else { return }
                withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                TextField("Сообщение…", text: $viewModel.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .disabled(!viewModel.canSend)
                .accessibilityLabel("Отправить")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "headphones")
                        .foregroundStyle(Palette.accent)
                        .frame(width: 32, height: 32)
                        .background(Palette.accent.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Поддержка «Едем»")
                            .font(.subheadline.weight(.semibold))
                        Text("оператор \(viewModel.operatorName) · онлайн")
                            .font(.caption2)
                            .foregroundStyle(Palette.success)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct MessageBubble: View {
    let message: SupportMessage

    var body: some View {
        switch message.author {
        case .user:
            HStack {
                Spacer(minLength: 48)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("\(Formatters.time.string(from: message.sentAt)) · отправлено")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        case .operatorAgent(let name):
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(name): \(message.text)")
                        .foregroundStyle(Palette.ink)
                        .padding(12)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text(Formatters.time.string(from: message.sentAt))
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 48)
            }
        case .system:
            HStack {
                Text(message.text)
                    .font(.footnote)
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Palette.surface, in: Capsule())
                Spacer()
            }
        }
    }
}

import SwiftUI
import PhotosUI

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = SupportViewModel()
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showPhotoPicker = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                messageList
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { inputBar }
        .task { await vm.load() }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                photoItem = nil
                await vm.uploadImage(data, mimeType: mimeType(for: data))
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .alert("Erreur", isPresented: .init(
            get: { vm.sendError != nil },
            set: { if !$0 { vm.sendError = nil } }
        )) {
            Button("OK", role: .cancel) { vm.sendError = nil }
        } message: {
            Text(vm.sendError ?? "")
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .frame(width: 38, height: 38)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 19)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Réponse sous 2 h")
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text("Nous écrire")
                        .bhGrandTitre()
                }
                .padding(.leading, 12)

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Liste de messages

    @ViewBuilder
    private var messageList: some View {
        switch vm.loadState {
        case .idle, .loading:
            Spacer()
            ProgressView().scaleEffect(1.2)
            Spacer()
        case .error(let msg):
            errorView(msg)
        case .loaded:
            if vm.messages.isEmpty {
                Spacer()
                Text("Aucun message pour l'instant.")
                    .font(.bhCorps)
                    .foregroundStyle(Color.bhAttenue)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.messages) { msg in
                                MessageBubble(msg: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    }
                    .refreshable { await vm.load() }
                    .onAppear {
                        scrollProxy = proxy
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onChange(of: vm.messages.count) {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let last = vm.messages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.22)) { proxy.scrollTo(last.id, anchor: .bottom) }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    // MARK: - Barre de saisie

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button { showPhotoPicker = true } label: {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 38, height: 38)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 19)
            }
            .buttonStyle(.plain)
            .disabled(vm.isSending)

            TextField("Votre message…", text: $vm.draft, axis: .vertical)
                .font(.bhCorps)
                .foregroundStyle(Color.bhEncre)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .glassEffect(in: .rect(cornerRadius: 18))
                        .specularEdge(cornerRadius: 18)
                }
                .disabled(vm.isSending)

            Button {
                Task { await vm.sendText() }
            } label: {
                Group {
                    if vm.isSending {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 38, height: 38)
                .background(
                    Color.bhVert.opacity(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1),
                    in: Circle()
                )
            }
            .buttonStyle(.plain)
            .disabled(vm.isSending || vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .animation(.easeInOut(duration: 0.15), value: vm.draft.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Erreur

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Color.bhAttenue)
            Text(msg)
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
            Button("Réessayer") { Task { await vm.load() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhVert)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mime type

    private func mimeType(for data: Data) -> String {
        guard data.count >= 4 else { return "image/jpeg" }
        let b = [UInt8](data.prefix(4))
        if b[0] == 0xFF && b[1] == 0xD8 { return "image/jpeg" }
        if b[0] == 0x89 && b[1] == 0x50 { return "image/png" }
        if b[0] == 0x47 && b[1] == 0x49 { return "image/gif" }
        if data.count >= 12 {
            let riff = [UInt8](data.prefix(4))
            let webp = [UInt8](data[8..<12])
            if riff == [0x52, 0x49, 0x46, 0x46] && webp == [0x57, 0x45, 0x42, 0x50] { return "image/webp" }
        }
        return "image/jpeg"
    }
}

// MARK: - Bulle de message

private struct MessageBubble: View {
    let msg: SupportMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if msg.isFromUser { Spacer(minLength: 52) }

            VStack(alignment: msg.isFromUser ? .trailing : .leading, spacing: 4) {
                if !msg.isFromUser, let name = msg.senderName {
                    Text(name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.bhAttenue)
                        .padding(.leading, 4)
                }

                bubbleContent

                Text(formatTime(msg.createdAt))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(msg.isFromUser ? .trailing : .leading, 4)
            }

            if !msg.isFromUser { Spacer(minLength: 52) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if let url = msg.imageUrl.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 240, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                case .failure:
                    imagePlaceholder(failed: true)
                default:
                    imagePlaceholder(failed: false)
                }
            }
        } else {
            Text(msg.message)
                .font(.bhCorps)
                .foregroundStyle(msg.isFromUser ? Color.white : Color.bhEncre)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if msg.isFromUser {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.bhVert)
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .glassEffect(in: .rect(cornerRadius: 18))
                    }
                }
        }
    }

    private func imagePlaceholder(failed: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.bhAttenue.opacity(0.15))
                .frame(width: 180, height: 130)
            if failed {
                Image(systemName: "photo.slash")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.bhAttenue)
            } else {
                ProgressView()
            }
        }
    }

    private func formatTime(_ iso: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        var date = parser.date(from: iso)
        if date == nil {
            parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = parser.date(from: iso)
        }
        guard let date else { return "" }
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        return m == 0
            ? "\(h)\u{00A0}h"
            : "\(h)\u{00A0}h\u{00A0}\(String(format: "%02d", m))"
    }
}

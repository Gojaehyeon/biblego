import SwiftUI

struct SearchView: View {
    @ObservedObject var model: SearchViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("성경 구절(예: 요 3:16) 또는 내용 검색…", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .focused($focused)
                .onSubmit { model.confirm() }
                .onKeyPress(.upArrow) { model.move(-1); return .handled }
                .onKeyPress(.downArrow) { model.move(1); return .handled }
                .onKeyPress(.escape) { model.close(); return .handled }

            if !model.results.isEmpty {
                Divider()
                resultsList
            } else if !model.query.isEmpty {
                Divider()
                hint("결과 없음")
            }
        }
        .frame(width: 460)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .onAppear {
            // Defer until the panel is key so the field actually takes focus
            // and shows the caret, letting the user type immediately.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true }
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                        ResultRow(result: result, isSelected: index == model.selected)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.selected = index
                                model.confirm()
                            }
                    }
                }
            }
            .frame(maxHeight: 300)
            .onChange(of: model.selected) { _, new in
                withAnimation(.linear(duration: 0.08)) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
    }
}

private struct ResultRow: View {
    let result: SearchResult
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(result.reference)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : .secondary)
            Text(result.preview)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? Color.white : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
    }
}

import SwiftUI

enum CFGlassMetrics {
    static let panelCornerRadius: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 12
    static let iconColumnWidth: CGFloat = 32
    static let contentMaxWidth: CGFloat = 720
    static let wideContentMaxWidth: CGFloat = 960
}

// MARK: - Page scaffold

/// Scaffold padrão de telas com painéis glass: scroll, container, padding e fundo.
struct CFGlassPage<Content: View>: View {
    var maxWidth: CGFloat = CFGlassMetrics.contentMaxWidth
    @ViewBuilder var content: () -> Content

    var body: some View {
        CFScrollView {
            GlassEffectContainer(spacing: CFGlassMetrics.sectionSpacing) {
                content()
                    .padding(24)
                    .frame(maxWidth: maxWidth)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// VStack interno de uma `CFGlassPage` com espaçamento padrão entre seções.
struct CFGlassPageStack<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        LazyVStack(alignment: .leading, spacing: CFGlassMetrics.sectionSpacing) {
            content()
        }
    }
}

/// Painel com material Liquid Glass — usar dentro de `GlassEffectContainer`.
struct CFGlassPanel<Content: View>: View {
    var glass: Glass = .regular
    var cornerRadius: CGFloat = CFGlassMetrics.panelCornerRadius
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
    }
}

/// Cabeçalho de seção para páginas com painéis glass.
struct CFGlassSection<Content: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    var count: Int?
    var countTint: Color?
    var staggerIndex: Int? = nil
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        count: Int? = nil,
        countTint: Color? = nil,
        staggerIndex: Int? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.count = count
        self.countTint = countTint
        self.staggerIndex = staggerIndex
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if let count, let countTint {
                            CFGlassCountBadge(count: count, tint: countTint)
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.horizontal, 4)

            content()
        }
        .modifier(CFGlassStaggerModifier(index: staggerIndex))
    }
}

struct CFGlassCountBadge: View {
    let count: Int
    var tint: Color = CFTheme.accent

    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}

private struct CFGlassStaggerModifier: ViewModifier {
    let index: Int?

    func body(content: Content) -> some View {
        if let index {
            content.cfStaggerAppear(index: index)
        } else {
            content
        }
    }
}

struct CFGlassInsetDivider: View {
    var leadingInset: CGFloat = CFGlassMetrics.rowHorizontalPadding + CFGlassMetrics.iconColumnWidth + 12

    var body: some View {
        Divider()
            .padding(.leading, leadingInset)
    }
}

struct CFGlassSymbol: View {
    let systemName: String
    var tint: Color = CFTheme.accent
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(tint.opacity(0.14))
            }
    }
}

struct CFGlassRowButton<Label: View>: View {
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Linha com valor à direita — contas, recebíveis e similares.
struct CFGlassAmountRow: View {
    let systemName: String
    var tint: Color = CFTheme.accent
    let title: String
    let subtitle: String
    let amount: String
    var amountColor: Color = .primary
    var trailingCaption: String?
    var statusBadge: String?
    var statusBadgeTint: Color = CFTheme.warning
    var showsChevron = false
    var dimmed = false

    var body: some View {
        HStack(spacing: 12) {
            CFGlassSymbol(systemName: systemName, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(amount)
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(amountColor)
                if let statusBadge {
                    Text(statusBadge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(statusBadgeTint)
                } else if let trailingCaption {
                    Text(trailingCaption)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .opacity(dimmed ? 0.7 : 1)
    }
}

/// Painel de destaque para totais e KPIs no topo da página.
struct CFGlassSummaryPanel<Content: View>: View {
    var title: String
    var staggerIndex: Int? = nil
    var tint: Color = CFTheme.accent
    @ViewBuilder var content: () -> Content

    var body: some View {
        CFGlassPanel(glass: .regular.tint(tint.opacity(0.06))) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                content()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .modifier(CFGlassStaggerModifier(index: staggerIndex))
    }
}

/// Linha padrão com ícone, título, subtítulo opcional e chevron.
struct CFGlassChevronRow: View {
    let systemName: String
    var tint: Color = CFTheme.accent
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            CFGlassSymbol(systemName: systemName, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

/// Painel glass com itens separados por divisor; `row` constrói cada linha (incluindo botão e modifiers).
struct CFGlassEnumeratedPanel<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var glass: Glass = .regular.interactive()
    var dividerStyle: CFGlassDividerStyle = .iconInset
    @ViewBuilder var row: (Item, Int) -> Row

    var body: some View {
        CFGlassPanel(glass: glass) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(item, index)
                    if index < items.count - 1 {
                        dividerStyle.view
                    }
                }
            }
        }
    }
}

enum CFGlassDividerStyle {
    case iconInset
    case fullWidth

    @ViewBuilder
    var view: some View {
        switch self {
        case .iconInset: CFGlassInsetDivider()
        case .fullWidth: CFGlassPanelDivider()
        }
    }
}

/// Linha de item arquivado com botão Restaurar.
struct CFGlassRestoreRow: View {
    let systemName: String
    var tint: Color = CFTheme.textSecondary
    let title: String
    var subtitle: String? = nil
    var onRestore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CFGlassSymbol(systemName: systemName, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.secondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            Button("Restaurar", action: onRestore)
                .cfGlassSecondaryButton()
                .controlSize(.small)
        }
        .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
        .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
    }
}

/// Seção de itens arquivados.
struct CFGlassArchiveSection<Item: Identifiable>: View {
    let title: String
    var staggerIndex: Int? = nil
    let items: [Item]
    let systemName: (Item) -> String
    let itemTitle: (Item) -> String
    var itemSubtitle: (Item) -> String? = { _ in nil }
    let onRestore: (Item) -> Void

    var body: some View {
        CFGlassSection(title: title, staggerIndex: staggerIndex) {
            CFGlassPanel {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        CFGlassRestoreRow(
                            systemName: systemName(item),
                            title: itemTitle(item),
                            subtitle: itemSubtitle(item)
                        ) {
                            onRestore(item)
                        }
                        if index < items.count - 1 {
                            CFGlassInsetDivider()
                        }
                    }
                }
            }
        }
    }
}

/// Cabeçalho de grupo por dia (ex.: lançamentos).
struct CFGlassDayHeader: View {
    let title: String
    let amount: Decimal
    var amountColor: Color = CFTheme.textSecondary

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer(minLength: 8)
            Text(amount.brl)
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(amountColor)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }
}

/// Linha com texto à esquerda e switch ancorado à direita.
struct CFGlassToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(CFTheme.accent)
                .fixedSize()
        }
        .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
        .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CFGlassPanelDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
    }
}

/// Cabeçalho de sheet com ícone e metadados.
struct CFGlassSheetHero: View {
    let systemName: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = CFTheme.accent

    var body: some View {
        CFGlassPanel(glass: .regular.tint(tint.opacity(0.06))) {
            HStack(spacing: 14) {
                CFGlassSymbol(systemName: systemName, tint: tint, size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(18)
        }
    }
}

/// Campo de formulário dentro de painéis glass (label à esquerda, controle à direita).
struct CFGlassLabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
        .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
    }
}

struct CFGlassFormPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        CFGlassSection(title: title) {
            CFGlassPanel {
                content()
            }
        }
    }
}

/// Cabeçalho de valor em sheets — painel glass com `CFAmountHeader`.
struct CFGlassSheetAmountHeader: View {
    let title: String
    @Binding var amount: Decimal
    var amountColor: Color = CFTheme.textPrimary

    var body: some View {
        CFGlassPanel(glass: .regular.tint(CFTheme.accent.opacity(0.06))) {
            CFAmountHeader(title: title, amount: $amount, amountColor: amountColor)
                .padding(18)
        }
    }
}

/// Rodapé padrão de sheets com botões Liquid Glass.
struct CFGlassSheetFooter<Leading: View>: View {
    var cancelTitle: String = "Cancelar"
    var confirmTitle: String = "Salvar"
    var confirmDisabled: Bool = false
    var onCancel: () -> Void
    var onConfirm: () -> Void
    @ViewBuilder var leading: () -> Leading

    init(
        cancelTitle: String = "Cancelar",
        confirmTitle: String = "Salvar",
        confirmDisabled: Bool = false,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() }
    ) {
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.confirmDisabled = confirmDisabled
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.leading = leading
    }

    var body: some View {
        HStack(spacing: 10) {
            leading()
            Spacer(minLength: 0)
            Button(cancelTitle, action: onCancel)
                .cfGlassSecondaryButton()
                .keyboardShortcut(.cancelAction)
            Button(confirmTitle, action: onConfirm)
                .cfGlassProminentButton()
                .keyboardShortcut(.defaultAction)
                .disabled(confirmDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct CFGlassStatusBadge: View {
    let text: String
    var tint: Color = CFTheme.accent

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}

/// Tints for Liquid Glass buttons — blue glass in dark mode (never flat white).
enum CFGlassControls {
    /// Secondary `.glass` buttons — translucent dark blue tint.
    static func secondaryTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.22, green: 0.42, blue: 0.76)
            : CFTheme.accent
    }

    /// Primary `.glassProminent` buttons — deeper blue fill in dark mode.
    static func prominentTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.30, blue: 0.66)
            : CFTheme.accent
    }

    static func destructiveTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.82, green: 0.26, blue: 0.30)
            : CFTheme.danger
    }

    static func secondaryGlass(for colorScheme: ColorScheme) -> Glass {
        .regular.tint(secondaryTint(for: colorScheme)).interactive()
    }

    static func destructiveGlass(for colorScheme: ColorScheme) -> Glass {
        .regular.tint(destructiveTint(for: colorScheme)).interactive()
    }
}

private struct CFGlassDestructiveButtonModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .buttonStyle(.glass(CFGlassControls.destructiveGlass(for: colorScheme)))
    }
}

private struct CFGlassSecondaryButtonModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .buttonStyle(.glass(CFGlassControls.secondaryGlass(for: colorScheme)))
    }
}

private struct CFGlassProminentButtonModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .buttonStyle(.glassProminent)
            .tint(CFGlassControls.prominentTint(for: colorScheme))
    }
}

extension View {
    /// Secondary glass button with readable contrast on dark glass backgrounds.
    func cfGlassSecondaryButton() -> some View {
        modifier(CFGlassSecondaryButtonModifier())
    }

    /// Primary glass button with boosted contrast in dark mode.
    func cfGlassProminentButton() -> some View {
        modifier(CFGlassProminentButtonModifier())
    }

    /// Destructive glass button — red tint on liquid glass.
    func cfGlassDestructiveButton() -> some View {
        modifier(CFGlassDestructiveButtonModifier())
    }

    /// Inset styling for rows inside picker popovers (safe alternative to nested glass).
    func cfGlassPickerOption(isSelected: Bool, tint: Color = CFTheme.accent) -> some View {
        background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? tint.opacity(0.18) : CFTheme.surfaceElevated.opacity(0.38))
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
            }
        }
    }

    /// Inset styling for search bars inside picker popovers.
    func cfGlassPickerSearchBar() -> some View {
        padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(CFTheme.surfaceElevated.opacity(0.42))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(CFTheme.textTertiary.opacity(0.20), lineWidth: 0.5)
            }
    }

    /// Icon-only toolbar control with its own glass capsule (search, Gio, etc.).
    func cfGlassToolbarIconButton() -> some View {
        modifier(CFGlassToolbarIconButtonModifier())
    }

    /// Standalone glass toolbar action (Adicionar).
    func cfGlassToolbarAddButton() -> some View {
        modifier(CFGlassToolbarAddButtonModifier())
    }

    /// Agrupa ícones numa única cápsula glass (ex.: ações da Gio na toolbar).
    func cfGlassToolbarIconCapsule() -> some View {
        modifier(CFGlassToolbarIconCapsuleModifier())
    }

    /// Ícone interativo dentro de uma cápsula agrupada da toolbar.
    func cfGlassToolbarCapsuleSegmentButton() -> some View {
        modifier(CFGlassToolbarCapsuleSegmentButtonModifier())
    }

    /// Bolha do usuário no chat Gio — glass real com borda accent.
    func cfChatUserBubbleGlass(cornerRadius: CGFloat = CFChatGlassMetrics.bubbleCornerRadius) -> some View {
        modifier(CFChatUserBubbleGlassModifier(cornerRadius: cornerRadius))
    }

    /// Chip de atividade de ferramenta no chat Gio.
    func cfChatActivityBubbleGlass(strokeColor: Color = CFTheme.textTertiary.opacity(0.22)) -> some View {
        modifier(CFChatActivityBubbleGlassModifier(strokeColor: strokeColor))
    }

    /// Chip de sugestão no empty state do chat.
    func cfChatSuggestionChipGlass(cornerRadius: CGFloat = CFChatGlassMetrics.chipCornerRadius) -> some View {
        modifier(CFChatSuggestionChipGlassModifier(cornerRadius: cornerRadius))
    }

    /// Campo de entrada do chat Gio.
    func cfChatInputFieldGlass(cornerRadius: CGFloat = CFChatGlassMetrics.inputCornerRadius) -> some View {
        modifier(CFChatInputFieldGlassModifier(cornerRadius: cornerRadius))
    }
}

private struct CFGlassToolbarIconCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 1)
            .padding(.horizontal, 2)
            .glassEffect(.regular.interactive(), in: .capsule)
    }
}

private struct CFGlassToolbarCapsuleSegmentButtonModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .labelStyle(.iconOnly)
            .font(CFGlassToolbarMetrics.iconFont)
            .buttonBorderShape(.circle)
            .buttonStyle(.glass(CFGlassControls.secondaryGlass(for: colorScheme)))
        #else
        content
            .labelStyle(.iconOnly)
            .font(CFGlassToolbarMetrics.iconFont)
            .padding(.horizontal, CFGlassToolbarMetrics.capsuleSegmentHorizontalPadding)
            .padding(.vertical, CFGlassToolbarMetrics.capsuleSegmentVerticalPadding)
            .buttonBorderShape(.circle)
            .buttonStyle(.glass(CFGlassControls.secondaryGlass(for: colorScheme)))
        #endif
    }
}

enum CFGlassToolbarMetrics {
    static let iconSize: CGFloat = 13
    static let iconFont = Font.system(size: iconSize, weight: .medium)
    static let iconHorizontalPadding: CGFloat = 10
    static let iconVerticalPadding: CGFloat = 7
    static let capsuleSegmentHorizontalPadding: CGFloat = 10
    static let capsuleSegmentVerticalPadding: CGFloat = 7
    static let addHorizontalPadding: CGFloat = 12
    static let addVerticalPadding: CGFloat = 7
    static let addFont = Font.system(size: 13, weight: .semibold)
}

private struct CFGlassToolbarIconButtonModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .labelStyle(.iconOnly)
            .font(CFGlassToolbarMetrics.iconFont)
            .buttonBorderShape(.circle)
            .buttonStyle(.glass(CFGlassControls.secondaryGlass(for: colorScheme)))
        #else
        content
            .labelStyle(.iconOnly)
            .font(CFGlassToolbarMetrics.iconFont)
            .padding(.horizontal, CFGlassToolbarMetrics.iconHorizontalPadding)
            .padding(.vertical, CFGlassToolbarMetrics.iconVerticalPadding)
            .buttonBorderShape(.circle)
            .buttonStyle(.glass(CFGlassControls.secondaryGlass(for: colorScheme)))
        #endif
    }
}

private struct CFGlassToolbarAddButtonModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .font(CFGlassToolbarMetrics.addFont)
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.capsule)
            .buttonStyle(.glass(.regular.tint(CFGlassControls.prominentTint(for: colorScheme)).interactive()))
        #else
        content
            .font(CFGlassToolbarMetrics.addFont)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, CFGlassToolbarMetrics.addHorizontalPadding)
            .padding(.vertical, CFGlassToolbarMetrics.addVerticalPadding)
            .buttonBorderShape(.capsule)
            .buttonStyle(.glass(.regular.tint(CFGlassControls.prominentTint(for: colorScheme)).interactive()))
        #endif
    }
}

enum CFChatGlassMetrics {
    static let bubbleCornerRadius: CGFloat = 14
    static let chipCornerRadius: CGFloat = 12
    static let inputCornerRadius: CGFloat = 12
}

/// Fundo do inspector da Gio — gradiente azul + camada glass como `CFPanel`.
struct CFGlassChatPanelBackground: View {
    var body: some View {
        ZStack {
            CFGlassGradientBackground()
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 0))
        }
    }
}

private struct CFChatUserBubbleGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = CFChatGlassMetrics.bubbleCornerRadius

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .glassEffect(
                .regular.tint(CFTheme.accent.opacity(colorScheme == .dark ? 0.12 : 0.08)),
                in: .rect(cornerRadius: cornerRadius)
            )
            .overlay(shape.strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.30), lineWidth: 0.5))
            .overlay(shape.strokeBorder(CFTheme.accent.opacity(0.26), lineWidth: 1))
    }
}

private struct CFChatActivityBubbleGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var strokeColor: Color

    func body(content: Content) -> some View {
        let shape = Capsule(style: .continuous)
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .glassEffect(
                .regular.tint(CFTheme.textPrimary.opacity(colorScheme == .dark ? 0.09 : 0.06)),
                in: .capsule
            )
            .overlay(shape.strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.26), lineWidth: 0.5))
            .overlay(shape.strokeBorder(strokeColor, lineWidth: 1))
    }
}

private struct CFChatSuggestionChipGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = CFChatGlassMetrics.chipCornerRadius

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .glassEffect(
                .regular.tint(CFTheme.accent.opacity(colorScheme == .dark ? 0.09 : 0.06)),
                in: .rect(cornerRadius: cornerRadius)
            )
            .overlay(shape.strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.26), lineWidth: 0.5))
            .overlay(shape.strokeBorder(CFTheme.accent.opacity(0.20), lineWidth: 1))
    }
}

private struct CFChatInputFieldGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = CFChatGlassMetrics.inputCornerRadius

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .glassEffect(
                .regular.tint(CFTheme.textPrimary.opacity(colorScheme == .dark ? 0.06 : 0.04)),
                in: .rect(cornerRadius: cornerRadius)
            )
            .overlay(shape.strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.22), lineWidth: 0.5))
            .overlay(shape.strokeBorder(CFTheme.textTertiary.opacity(0.20), lineWidth: 1))
    }
}

/// Fundo com gradientes radiais usado em páginas e sheets glass.
struct CFGlassGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            CFTheme.surfacePrimary

            RadialGradient(
                colors: [
                    CFTheme.accent.opacity(colorScheme == .dark ? 0.18 : 0.10),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )

            RadialGradient(
                colors: [
                    CFTheme.brandTint.opacity(colorScheme == .dark ? 0.12 : 0.08),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 480
            )
        }
    }
}

private struct CFGlassPageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            CFGlassGradientBackground()
                .ignoresSafeArea()
        }
    }
}

private struct CFTransparentToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.hidden, for: .automatic)
            #if os(iOS)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            #if os(macOS)
            // Mantém o slot da toolbar no layout; só remove o material opaco.
            .toolbarBackground(.clear, for: .windowToolbar)
            #endif
    }
}

private enum CFGlassSheetFocusTarget: Hashable {
    case focusSink
}

private struct CFGlassSheetChromeModifier: ViewModifier {
    @FocusState private var sheetFocus: CFGlassSheetFocusTarget?

    func body(content: Content) -> some View {
        content
            .background {
                CFGlassGradientBackground()
                    .ignoresSafeArea()
            }
            .presentationBackground {
                CFGlassGradientBackground()
            }
            .overlay(alignment: .topLeading) {
                Color.clear
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
                    .focusable()
                    .focused($sheetFocus, equals: .focusSink)
            }
            .defaultFocus($sheetFocus, .focusSink)
    }
}

extension View {
    func cfGlassPageBackground() -> some View {
        modifier(CFGlassPageBackground())
    }

    /// Toolbar/navigation bar transparente para o gradiente aparecer atrás do título.
    func cfTransparentToolbar() -> some View {
        modifier(CFTransparentToolbarModifier())
    }

    /// Fundo glass + toolbar transparente para telas de detalhe.
    func cfGlassDetailChrome() -> some View {
        cfGlassPageBackground()
            .cfTransparentToolbar()
    }

    /// Chrome padrão de sheets: gradiente + foco inicial + presentation background.
    func cfGlassSheetChrome() -> some View {
        modifier(CFGlassSheetChromeModifier())
    }
}

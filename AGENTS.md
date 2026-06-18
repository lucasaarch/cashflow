# CashFlow — orientações para agentes

App nativo de finanças em **Swift / SwiftUI / SwiftData**, alvo **macOS 26.5+** (iOS/iPadOS desligados por enquanto).

## Validação obrigatória

**Nunca declare uma tarefa concluída** sem rodar as validações abaixo no terminal. Se o build ou os testes falharem, corrija e rode de novo até passar.

### Quando validar

| Situação | Build | Testes |
|----------|-------|--------|
| Alterou `.swift`, projeto Xcode ou assets | Sim | Se tocou em lógica testável |
| Só documentação / comentários | Não | Não |
| Refatorou AI, persistência ou modelos | Sim | Sim (suite completa) |

### Xcode no terminal

O `xcodebuild` do PATH costuma apontar para **Command Line Tools**, não para o Xcode completo. Sempre prefixe com `DEVELOPER_DIR`:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Alternativa equivalente:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild ...
```

Se `xcode-select -p` retornar `/Library/Developer/CommandLineTools`, **não** use `xcodebuild` sem `DEVELOPER_DIR`.

### Build

Rodar na raiz do repositório após mudanças de código:

**macOS:**

```bash
cd /Users/lukearch/Projects/My/CashFlow
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
  -destination 'platform=macOS' build 2>&1 | tail -30
```

**iOS Simulator:**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -30
```

Critério de sucesso: linha `** BUILD SUCCEEDED **`.

Para ver só erros e avisos relevantes:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
  -destination 'platform=macOS' build 2>&1 \
  | grep -E 'error:|warning:|BUILD SUCCEEDED|BUILD FAILED'
```

### Testes

Suite completa (macOS):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
  -destination 'platform=macOS' test 2>&1 | tail -30
```

Teste isolado (exemplo):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
  -destination 'platform=macOS' test \
  -only-testing:CashFlowTests/AIServiceTests 2>&1 | tail -20
```

Critério de sucesso: `** TEST SUCCEEDED **`.

### Permissões do sandbox

Comandos `xcodebuild` precisam de permissão **`all`** (ou equivalente fora do sandbox) para acessar DerivedData e o SDK do Xcode.

## Convenções do projeto

- **UI em português** (rótulos, mensagens, empty states).
- **Design system**: reutilize `CFTheme`, `CFHoverRow`, `CFIconBadge`, `CFPillButton`, `cfPageBackground()`, sheets no padrão de `CategoriesView` / `AccountsView`.
- **Seleção em formulários**: use sempre `CFSelectField` (valor obrigatório) ou `CFSelectFieldOptional` (valor opcional) de `Shared/DesignSystem/CFSelectField.swift` — com `CFSelectOption` e, quando existir, `Enum.selectOptions` (ex.: `CategoryKind.selectOptions`, `WishlistPriority.selectOptions`). **Não** use `Picker` com `.menu` / `.wheel` em sheets ou formulários; referência: `AddBillSheet`, `CategoriesView`, `AddWishlistItemSheet`. `Picker` segmentado só para conjuntos binários/pequenos fixos no layout (ex.: direção de transferência).
- **Multiplataforma**: use `cfLayoutMode` / `CFAdaptiveLayout` para popovers, sheets e toolbars em iPhone; `AdaptiveRootView` escolhe TabView (compact) vs `NavigationSplitView` (regular/macOS).
- **iCloud (preparado, desligado)**: sync via `CLOUDKIT_SYNC` + capability CloudKit — ver `CashFlow/Documentation/iCloud-Sync.md`. Conta Apple gratuita: manter flag desligada.
- **Escopo mínimo**: não refatore código não relacionado à tarefa.
- **Commits**: só quando o usuário pedir explicitamente.

## Estrutura útil

```
CashFlow/
├── App/              # Navegação (AdaptiveRootView, RootSidebarView)
├── Features/         # Telas por domínio (AI, Settings, Transactions…)
├── AI/               # Serviços e provedores de IA
├── Models/           # SwiftData
├── Shared/DesignSystem/
└── CashFlowTests/
```

## Checklist antes de encerrar

- [ ] Build passou (`BUILD SUCCEEDED`) — macOS e iOS sim, se tocou em UI multiplataforma
- [ ] Testes passaram, se aplicável
- [ ] Erros de compilação corrigidos (não só linter do editor)
- [ ] Mudança visual alinhada ao design system existente

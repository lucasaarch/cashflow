# Ativar sincronização iCloud (SwiftData + CloudKit)

O CashFlow está **preparado** para sincronizar Mac, iPhone e iPad pela mesma base iCloud. Por padrão isso fica **desligado** para o app continuar funcionando com conta Apple gratuita (sem capability CloudKit na assinatura).

## Estado atual (sem pagar o Developer Program)

- Store **local** em cada dispositivo (comportamento normal).
- Modelos com relacionamentos compatíveis com CloudKit.
- `AppSettings` (orçamento mensal) já no SwiftData — migrado do `UserDefaults` na primeira abertura.
- Flag de compilação `CLOUDKIT_SYNC` **não** definida → build e execução no Mac seguem iguais.

## Requisito para ligar o sync

A capability **iCloud (CloudKit)** exige **Apple Developer Program** (paga). Times pessoais (Apple ID gratuito) não assinam apps com CloudKit.

## Como ativar (quando tiver conta paga)

1. [Apple Developer](https://developer.apple.com) → App ID `com.lucasarch.CashFlow` → **iCloud** → container `iCloud.com.lucasarch.CashFlow`.

2. Xcode → target **CashFlow** → **Signing & Capabilities**:
   - **+ Capability** → **iCloud**
   - **CloudKit** + container `iCloud.com.lucasarch.CashFlow`

3. **Build Settings** → **Active Compilation Conditions** → adicionar `CLOUDKIT_SYNC` (Debug e Release).  
   Alternativa: usar [`Configurations/CloudKit-Sync.xcconfig`](../Configurations/CloudKit-Sync.xcconfig) como base da configuração.

4. Mesmo **Apple ID** no iCloud em Mac, iPhone e iPad.

## Arquivos de referência

| Arquivo | Uso |
|---------|-----|
| [`CloudKitSync.swift`](../Persistence/CloudKitSync.swift) | ID do container e `isEnabled` |
| [`ModelContainerFactory.swift`](../Persistence/ModelContainerFactory.swift) | `.private(container)` quando `CLOUDKIT_SYNC` |
| [`CashFlow-iOS.entitlements`](../CashFlow-iOS.entitlements) | iOS com iCloud (referência) |
| [`CashFlow.entitlements.icloud`](CashFlow/CashFlow.entitlements.icloud) | macOS sandbox + iCloud (referência) |

O Xcode costuma reescrever os entitlements ao adicionar a capability — os arquivos acima são o modelo esperado.

## O que sincroniza (com CloudKit ligado)

- Transações, contas, categorias, contas a pagar, metas, chat, orçamento mensal (`AppSettings`), etc.

## O que permanece por dispositivo

- Chaves de API de IA (Keychain).
- Cache de insights de IA (`UserDefaults`).
- Última conta/categoria usada em formulários (`UserDefaults`).

## Testes

`CashFlowTests` usa `ModelContainer` em memória, sem CloudKit — não muda ao ativar o sync no app.

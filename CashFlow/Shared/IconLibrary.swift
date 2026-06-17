import Foundation

struct IconItem: Hashable {
    let name: String           // SF Symbol name
    let keywords: [String]     // Portuguese keywords for search
    let group: IconGroup
}

enum IconGroup: String, CaseIterable {
    case food = "Comida"
    case transport = "Transporte"
    case home = "Casa"
    case leisure = "Lazer"
    case health = "Saúde"
    case personal = "Pessoal"
    case work = "Trabalho"
    case people = "Pessoas"
    case payment = "Pagamento"
    case other = "Outros"
}

enum IconLibrary {
    static let all: [IconItem] = [
        // Comida
        .init(name: "cart.fill",                            keywords: ["mercado","compra","carrinho","supermercado"], group: .food),
        .init(name: "bag.fill",                             keywords: ["sacola","compra","loja"], group: .food),
        .init(name: "fork.knife",                           keywords: ["restaurante","almoço","jantar","comida"], group: .food),
        .init(name: "cup.and.saucer.fill",                  keywords: ["café","cafeteria","starbucks"], group: .food),
        .init(name: "takeoutbag.and.cup.and.straw.fill",    keywords: ["delivery","ifood","takeout","entrega"], group: .food),
        .init(name: "birthday.cake.fill",                   keywords: ["bolo","aniversário","festa","doce"], group: .food),
        .init(name: "wineglass.fill",                       keywords: ["bar","vinho","drink","balada"], group: .food),
        .init(name: "carrot.fill",                          keywords: ["verdura","legume","feira","hortifruti"], group: .food),

        // Transporte
        .init(name: "car.fill",                             keywords: ["carro","transporte","uber","99"], group: .transport),
        .init(name: "fuelpump.fill",                        keywords: ["combustível","gasolina","posto","álcool"], group: .transport),
        .init(name: "bus.fill",                             keywords: ["ônibus","busão","transporte"], group: .transport),
        .init(name: "tram.fill",                            keywords: ["metrô","trem","cptm","transporte"], group: .transport),
        .init(name: "bicycle",                              keywords: ["bicicleta","bike"], group: .transport),
        .init(name: "airplane",                             keywords: ["avião","viagem","passagem","aéreo"], group: .transport),
        .init(name: "parkingsign.circle.fill",              keywords: ["estacionamento","zona azul"], group: .transport),

        // Casa
        .init(name: "house.fill",                           keywords: ["casa","aluguel","moradia","apartamento"], group: .home),
        .init(name: "bed.double.fill",                      keywords: ["cama","casa","quarto"], group: .home),
        .init(name: "sofa.fill",                            keywords: ["sofá","móvel","casa","sala"], group: .home),
        .init(name: "bolt.fill",                            keywords: ["luz","energia","conta","eletricidade"], group: .home),
        .init(name: "drop.fill",                            keywords: ["água","conta"], group: .home),
        .init(name: "flame.fill",                           keywords: ["gás","conta","botijão"], group: .home),
        .init(name: "wifi",                                 keywords: ["internet","wifi","conta","banda larga"], group: .home),
        .init(name: "key.fill",                             keywords: ["chave","chaveiro","casa"], group: .home),
        .init(name: "hammer.fill",                          keywords: ["ferramenta","reparo","manutenção"], group: .home),

        // Lazer
        .init(name: "gamecontroller.fill",                  keywords: ["jogo","game","lazer","videogame"], group: .leisure),
        .init(name: "tv.fill",                              keywords: ["tv","netflix","streaming","assinatura","disney"], group: .leisure),
        .init(name: "music.note",                           keywords: ["música","spotify","apple music","assinatura"], group: .leisure),
        .init(name: "film.fill",                            keywords: ["cinema","filme","sala"], group: .leisure),
        .init(name: "ticket.fill",                          keywords: ["ingresso","evento","show","teatro"], group: .leisure),
        .init(name: "camera.fill",                          keywords: ["foto","câmera"], group: .leisure),
        .init(name: "book.fill",                            keywords: ["livro","educação","leitura"], group: .leisure),
        .init(name: "graduationcap.fill",                   keywords: ["estudo","faculdade","curso","educação"], group: .leisure),

        // Saúde
        .init(name: "cross.case.fill",                      keywords: ["farmácia","remédio","saúde","drogaria"], group: .health),
        .init(name: "heart.fill",                           keywords: ["coração","saúde","amor"], group: .health),
        .init(name: "pills.fill",                           keywords: ["remédio","medicamento","comprimido"], group: .health),
        .init(name: "stethoscope",                          keywords: ["médico","consulta","saúde"], group: .health),
        .init(name: "dumbbell.fill",                        keywords: ["academia","esporte","exercício","musculação"], group: .health),
        .init(name: "figure.run",                           keywords: ["corrida","esporte","exercício"], group: .health),

        // Pessoal
        .init(name: "tshirt.fill",                          keywords: ["roupa","camiseta","vestuário"], group: .personal),
        .init(name: "eyeglasses",                           keywords: ["óculos","ótica"], group: .personal),
        .init(name: "scissors",                             keywords: ["cabelo","barbeiro","salão","corte"], group: .personal),
        .init(name: "shoeprints.fill",                      keywords: ["sapato","tênis","calçado"], group: .personal),
        .init(name: "drop.degreesign.fill",                 keywords: ["perfume","beleza","cosmético"], group: .personal),

        // Trabalho/Renda
        .init(name: "briefcase.fill",                       keywords: ["trabalho","freela","emprego","escritório"], group: .work),
        .init(name: "banknote.fill",                        keywords: ["dinheiro","salário","renda","grana"], group: .work),
        .init(name: "dollarsign.circle.fill",               keywords: ["dinheiro","renda","real"], group: .work),
        .init(name: "chart.line.uptrend.xyaxis",            keywords: ["investimento","ações","renda","gráfico"], group: .work),
        .init(name: "laptopcomputer",                       keywords: ["computador","trabalho","notebook"], group: .work),

        // Pessoas/Pet
        .init(name: "person.fill",                          keywords: ["pessoa","amigo","gente"], group: .people),
        .init(name: "person.2.fill",                        keywords: ["família","pessoas","casal"], group: .people),
        .init(name: "pawprint.fill",                        keywords: ["pet","cachorro","gato","bicho"], group: .people),
        .init(name: "gift.fill",                            keywords: ["presente","aniversário","regalo"], group: .people),
        .init(name: "figure.and.child.holdinghands",        keywords: ["filho","criança","família"], group: .people),

        // Pagamento
        .init(name: "creditcard.fill",                      keywords: ["cartão","crédito","débito"], group: .payment),
        .init(name: "wallet.pass.fill",                     keywords: ["carteira","conta"], group: .payment),
        .init(name: "building.columns.fill",                keywords: ["banco","instituição"], group: .payment),
        .init(name: "qrcode",                               keywords: ["pix","qr","código"], group: .payment),
        .init(name: "dollarsign.bank.building.fill",        keywords: ["banco","conta","investimento"], group: .payment),

        // Outros
        .init(name: "tag.fill",                             keywords: ["etiqueta","categoria","tag"], group: .other),
        .init(name: "star.fill",                            keywords: ["estrela","favorito"], group: .other),
        .init(name: "flag.fill",                            keywords: ["bandeira","marca"], group: .other),
        .init(name: "bell.fill",                            keywords: ["notificação","alarme","sino"], group: .other),
        .init(name: "ellipsis.circle.fill",                 keywords: ["outros","diverso","mais"], group: .other),
        .init(name: "questionmark.circle.fill",             keywords: ["dúvida","outro"], group: .other)
    ]

    static func filter(_ query: String) -> [IconItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return all }
        let needle = trimmed
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        return all.filter { item in
            if item.name.contains(needle) { return true }
            return item.keywords.contains { keyword in
                keyword
                    .folding(options: .diacriticInsensitive, locale: .current)
                    .lowercased()
                    .contains(needle)
            }
        }
    }
}

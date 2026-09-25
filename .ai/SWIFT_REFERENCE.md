# Referência Swift/SwiftUI

Este documento é a referência estrutural e semântica para projetos Swift/SwiftUI que adotam esta base. Ele define organização de pastas, MVVM, composição de telas, estado, concorrência, performance, segurança e testes. O projeto consumidor pode adaptar nomes de features e recursos, mas não deve ignorar estas regras sem registrar uma exceção no `AGENTS.md` local.

## Princípios da base compartilhada

- MVVM é obrigatório para telas e componentes que possuem estado, eventos ou comportamento de apresentação.
- Swift Testing é a única tecnologia de testes autorizada neste padrão.
- O código deve depender de contratos e abstrações pequenas, com composição explícita no ponto de entrada.
- Views devem ser declarativas, previsíveis e livres de efeitos colaterais no `body`.
- Swift 6 é obrigatório para todo projeto consumidor que adota esta base. O
  projeto deve usar Swift 6 no toolchain e no language mode; a documentação não
  presume apenas o target, a versão mínima de sistema ou outras configurações
  de build que não estejam confirmadas no projeto consumidor.
- Recursos, serviços externos e persistência devem ser isolados atrás de protocolos ou adaptadores quando isso melhorar testabilidade e substituição.
- O comportamento conectado do projeto consumidor continua sendo a fonte de verdade para nomes, fluxos e compatibilidade.

## Plano operacional de uso das skills

Skills são pacotes de instruções para orientar o modelo; sua presença em
`.agents/skills/` não significa que sejam lidas ou executadas automaticamente em
toda tarefa. O modelo deve selecionar as skills pelo escopo real do pedido,
ler integralmente o `SKILL.md` de cada skill aplicável antes do trabalho
correspondente e registrar as decisões no plano e no relatório da execução.

### Matriz de roteamento

| Escopo da tarefa | Skill | Aplicação |
| --- | --- | --- |
| Implementar, corrigir, revisar ou refatorar qualquer código Swift/SwiftUI | [`swiftui-expert-skill`](../.agents/skills/swiftui-expert-skill/SKILL.md) | Obrigatória |
| Qualquer tarefa que leia, escreva ou altere Swift | [`swift-concurrency`](../.agents/skills/swift-concurrency/SKILL.md) | Obrigatória, inclusive no planejamento; confirme as configurações reais de concorrência |
| Construir, alterar ou revisar telas, navegação, controles ou composição SwiftUI | [`swiftui-ui-patterns`](../.agents/skills/swiftui-ui-patterns/SKILL.md) | Obrigatória para o escopo de UI |
| Construir ou revisar janelas, menus, commands, toolbars, Settings, split views ou inspectors de macOS | [`swiftui-patterns`](../.agents/skills/swiftui-patterns/SKILL.md) | Condicional à superfície macOS envolvida |
| Refatorar estrutura de Views, ownership de estado ou composição | [`swiftui-view-refactor`](../.agents/skills/swiftui-view-refactor/SKILL.md) | Condicional à refatoração |
| Adotar, revisar ou corrigir Liquid Glass | [`swiftui-liquid-glass`](../.agents/skills/swiftui-liquid-glass/SKILL.md) | Condicional ao uso solicitado ou existente; não implica redesign geral |
| Construir, executar ou diagnosticar o app no iOS Simulator | [`ios-debugger-agent`](../.agents/skills/ios-debugger-agent/SKILL.md) | Condicional à validação no Simulator |

Não carregue uma skill condicional apenas por hábito. Quando ela não for
aplicável, registre `SKIPPED` e o motivo. A descrição da skill é um gatilho de
seleção, não uma autorização para ampliar o escopo da tarefa.

### Ordem de leitura e aplicação

1. Leia as instruções do checkout, o brief e o guide do projeto consumidor,
   quando existirem, e esta referência.
2. Para qualquer código Swift, leia `swift-concurrency` antes de escolher
   isolamento, `Task`, `Sendable`, `@MainActor` ou APIs relacionadas. Confirme
   que `SWIFT_VERSION` está configurado como `6.0` e avalie
   `SWIFT_STRICT_CONCURRENCY`,
   `SWIFT_DEFAULT_ACTOR_ISOLATION` e upcoming features no projeto real.
3. Leia `swiftui-expert-skill` para estabelecer o baseline de estado,
   composição, APIs, performance e acessibilidade.
4. Leia as skills condicionais conforme a matriz e, quando indicado por elas,
   somente as referências internas necessárias ao caso.
5. Durante a implementação ou revisão, aplique os checklists das skills sem
   substituir contratos, nomes, arquitetura ou compatibilidade já existentes.
6. Antes de concluir, valide os critérios de aceite e registre skills aplicadas,
   ignoradas e conflitos resolvidos.

### Precedência e conflitos

As regras do projeto consumidor e desta referência prevalecem sobre sugestões
genéricas de uma skill. Em particular:

- A exigência de MVVM desta referência prevalece sobre a orientação de
  `swiftui-view-refactor` de usar MV por padrão em projetos genéricos. Use essa
  skill para melhorar a estrutura sem remover ViewModels comportamentais
  exigidos pelo projeto.
- `swiftui-patterns` é uma skill de padrões de macOS; não a use para justificar
  APIs ou layouts de desktop em uma tela iOS.
- Liquid Glass é opcional. Só adote-o quando fizer sentido para o componente,
  quando já existir na feature ou quando o pedido o solicitar, sempre com
  disponibilidade e fallback compatíveis.
- Se uma skill e o código/configuração existente divergirem, preserve o
  comportamento conectado e registre a exceção, o risco e a validação
  necessária.

### Registro obrigatório no plano e no relatório

O Manager deve incluir este bloco no plano, e o Developer deve atualizá-lo no
relatório final:

```text
SKILLS_STATUS:
- APPLIED: caminho — motivo — referências consultadas
- SKIPPED: caminho — motivo de não aplicabilidade
- CONFLICTS: skill/regra — decisão adotada — validação
```

`SKILLS_STATUS` não substitui a leitura das skills. Ele torna a seleção
auditável e impede alegar uso automático sem evidência.

## Base técnica e segurança

- Antes de usar uma API, confirme a versão mínima do target e as configurações
  de concorrência do projeto (`SWIFT_VERSION`, `SWIFT_STRICT_CONCURRENCY`,
  `SWIFT_DEFAULT_ACTOR_ISOLATION` e upcoming features). `SWIFT_VERSION` deve
  ser `6.0`.
- Prefira APIs atuais compatíveis com o target real. Não introduza
  disponibilidade de plataforma apenas porque esta referência foi atualizada.
  Projetos abaixo de Swift 6 devem ser migrados antes de adotar esta base.
- Não aplique `@MainActor` globalmente como correção automática. Use isolamento onde o dado ou a operação realmente exigirem execução no ator principal.
- Segredos, tokens, certificados, chaves privadas e dados pessoais não devem ser armazenados no código-fonte, nos assets, em logs ou em arquivos versionados.
- Dados sensíveis devem usar o mecanismo seguro apropriado à plataforma e ao risco; não use `UserDefaults` como cofre.
- Dependências externas precisam de aprovação explícita e devem ser encapsuladas para que o domínio e as Views não dependam diretamente de SDKs de terceiros.
- Erros de rede, persistência, autenticação e permissões devem ter tipos ou contratos observáveis, mensagens seguras e tratamento determinístico.

## Estrutura esperada

Use a estrutura abaixo como padrão para um app. `MyApp` e os nomes de features são ilustrativos e devem ser substituídos pelo nome real do produto.

Em todo o projeto Xcode, organize arquivos e recursos sempre com **folders** (pastas sincronizadas com o sistema de arquivos), nunca com **groups**. Ao criar ou mover itens, mantenha a hierarquia do projeto correspondente às pastas reais no disco.

```text
MyApp/
├── AGENTS.md
├── README.md
├── Resources/
│   ├── Assets.xcassets
│   ├── Localization/
│   ├── Fonts/
│   ├── Audio/
│   ├── Video/
│   └── Preview Content/
├── Sources/
│   ├── App/
│   │   ├── MyAppApp.swift
│   │   ├── AppRouter.swift
│   │   └── AppContainer.swift
│   ├── Core/
│   │   ├── Data/
│   │   ├── Helpers/
│   │   ├── Integrations/
│   │   ├── Managers/
│   │   ├── Network/
│   │   ├── Persistence/
│   │   ├── Platform/
│   │   └── Services/
│   └── Features/
│       ├── Home/
│       │   ├── HomeView.swift
│       │   ├── HomeViewModel.swift
│       │   └── Components/
│       │       ├── HomeHeroView.swift
│       │       └── HomeContentView.swift
│       ├── Profile/
│       │   ├── ProfileView.swift
│       │   ├── ProfileViewModel.swift
│       │   └── Components/
│       └── SignIn/
│           ├── SignInView.swift
│           ├── SignInViewModel.swift
│           └── Components/
└── Tests/
    ├── Core/
    └── Features/
        ├── Home/
        ├── Profile/
        └── SignIn/
```

### Responsabilidade das pastas

- Modelos de domínio, de apresentação, de previews e fixtures devem ser declarados em arquivos Swift próprios, fora de arquivos que declaram `View`. Arquivos de View compõem a interface e referenciam esses tipos; não definem modelos, mesmo como tipos privados aninhados ou auxiliares no mesmo arquivo.
- `Resources/` contém somente conteúdo empacotado com o app: assets, localizações, fontes, áudio, vídeo e conteúdo de preview. Não coloque código Swift aqui.
- `Sources/App/` contém a raiz do app, a composição das dependências e a fonte de verdade da navegação global.
- `Sources/Core/` contém código reutilizável entre features. Separe por responsabilidade e não use `Core` como depósito genérico para arquivos sem dono claro.
- `Sources/Features/` contém as fatias verticais do produto. Cada feature deve manter sua View, seu ViewModel e seus componentes próximos.
- `Tests/Core/` e `Tests/Features/` espelham os contratos testáveis da implementação. Mantenha os testes próximos à responsabilidade que verificam.

## MVVM e composição

MVVM é obrigatório para telas e componentes comportamentais:

- A `View` descreve a hierarquia visual, encaminha ações e observa o estado de apresentação. Ela referencia modelos definidos em arquivos próprios e não declara tipos de domínio, apresentação, preview ou fixture.
- O `ViewModel` possui o estado de apresentação, expõe intenções nomeadas e coordena chamadas aos serviços ou repositórios injetados.
- Serviços, repositórios, clientes de rede, persistência e integrações não devem ser instanciados dentro do `body` nem escondidos em singletons globais.
- O `ViewModel` não deve conhecer detalhes de layout, modificadores SwiftUI ou controles visuais.
- Uma subview puramente visual, sem estado próprio, pode receber valores prontos e closures sem criar um ViewModel artificial.
- Componentes comportamentais, mesmo pequenos, devem ter um ViewModel se possuírem estado, carregamento, validação, efeitos assíncronos ou regras de interação.
- O fluxo de dados deve ser unidirecional: estado desce; eventos sobem; o ViewModel transforma eventos em novo estado ou efeitos.
- Não duplique o mesmo estado em `@State`, `@Observable`, `@StateObject` ou propriedades locais.

`AppContainer` é o ponto de composição. Ele cria implementações concretas, registra dependências e fornece os objetos às features. `AppRouter` representa o estado de navegação do app; Views não devem manter cópias concorrentes da rota global. Dependências de feature devem ser injetadas explicitamente, por inicializador, ambiente tipado ou outro contrato estável escolhido pelo projeto.

## Estado e Observation

Escolha o mecanismo conforme a responsabilidade do valor:

| Necessidade | Mecanismo recomendado |
| --- | --- |
| Estado local privado da View | `@State private` |
| Estado de apresentação compartilhado no MVVM | modelo observável compatível com o target, normalmente `@Observable` |
| Binding de uma propriedade observável já injetada | `@Bindable` local ou injetado |
| Valor imutável recebido pela View | `let` |
| Mutação de um estado pertencente ao pai | `@Binding` |
| Dependência compartilhada da árvore | ambiente tipado, com valor padrão seguro e estável |

- `@State` deve ser privado e representar somente estado que a View possui.
- Não copie uma entrada do pai para `@State` esperando sincronização automática.
- Em targets que suportam Observation, prefira `@Observable` para modelos observáveis e mantenha o isolamento compatível com o projeto.
- Use `@Bindable` quando uma View precisa criar bindings para propriedades mutáveis de um modelo observável injetado.
- Um valor no ambiente não deve ser uma closure mutável disfarçada. Prefira dependências com contrato explícito e implementação de preview segura.
- Estado derivado barato pode ser calculado; estado derivado caro deve ser preparado fora do `body`, no ViewModel ou em uma camada de transformação testável.
- Estados de carregamento, vazio, erro e sucesso devem ser explícitos quando a tela realmente os suporta.

## Navegação e apresentação

- Prefira `NavigationStack` para navegação hierárquica e rotas tipadas ou valores `Hashable` leves.
- Mantenha o path e a rota em uma única fonte de verdade, normalmente no `AppRouter` ou no ViewModel responsável pela feature.
- Registre destinos com `navigationDestination(for:)` em um nível estável da hierarquia, fora de containers lazy quando isso evitar escopo ou resolução inesperada.
- Use `NavigationSplitView` somente quando o produto exigir navegação adaptativa em múltiplas colunas.
- Use `.sheet(item:)`, `.fullScreenCover(item:)` ou `.popover(item:)` para apresentações identificáveis e mutuamente exclusivas.
- Não espalhe booleans de apresentação para representar o mesmo destino em vários níveis.
- Rotas devem ser pequenas, `Hashable` quando necessário e livres de referências a Views, serviços ou grandes objetos de domínio.
- O destino deve receber dependências e dados suficientes para renderizar ou carregar seu próprio estado; evite acessar estado global implícito.
- Use `Button` para ações; não transforme texto ou imagem em ação com `onTapGesture` quando a semântica de botão for apropriada.
- Toolbars, `safeAreaInset` e ações de navegação devem permanecer próximos da tela que possui o comportamento.

## Composição de Views

- O `body` deve ser uma descrição curta e estável da tela, sem chamadas de rede, escrita em disco, logging operacional ou criação repetida de serviços.
- Extraia subviews nomeadas quando houver responsabilidade visual ou interação própria; não use `AnyView` para esconder uma árvore instável.
- Componentes devem ter entradas claras e não depender de singletons ou de estado global implícito.
- Use modificadores atuais e semânticos, como `foregroundStyle`, `clipShape`, `contentShape`, `safeAreaInset` e estilos de botão, quando compatíveis com o target.
- Prefira `containerRelativeFrame`, `Layout` ou composição de stacks a `GeometryReader` usado apenas para obter tamanhos. Use leitura de geometria quando ela for realmente necessária ao layout.
- Não use `UIScreen` para dimensionar Views. O layout deve responder ao container, ao tamanho disponível e às categorias de acessibilidade.
- Separe lógica de apresentação, transformação de dados e efeitos assíncronos em funções ou tipos testáveis.
- Handlers de ações devem ter nomes semânticos, como `submit()`, `retry()` ou `selectItem(_:)`, e não closures anônimas longas dentro de modificadores.
- Mantenha a ordem de um tipo Swift consistente: ambiente, entradas, estado, propriedades computadas, inicializador, `body`, subviews auxiliares e funções.

## Listas, identidade e acessibilidade

- Toda coleção renderizada deve ter identidade estável e semântica. Prefira modelos `Identifiable` ou IDs persistentes.
- Não use `.indices`, `enumerated()` ou offsets como identidade de linhas mutáveis.
- Não faça `filter`, `sorted`, `map` pesado ou formatação custosa dentro do `ForEach` ou repetidamente no `body`.
- Evite variar drasticamente o tipo de View de uma linha; preserve uma forma de linha estável quando possível.
- Use `List` ou `LazyVStack` conforme a necessidade de comportamento e custo, sem inserir uma camada lazy por hábito.
- Imagens remotas devem ser carregadas, canceladas, redimensionadas e cacheadas por uma camada apropriada; não faça decodificação pesada na thread principal.
- Controles interativos devem ter rótulos acessíveis, ordem lógica de foco, suporte a Dynamic Type e contraste adequado.
- Use `accessibilityLabel`, `accessibilityHint` e `accessibilityValue` para comunicar semântica; `accessibilityIdentifier` serve para diagnóstico e testes e não substitui o rótulo.

## Concorrência e isolamento

- Confirme as configurações reais do projeto antes de escolher anotações ou migrações de Swift Concurrency.
- Prefira `async/await`, `Task`, `async let`, task groups e atores a callbacks manuais, GCD e bloqueios.
- Use `.task` ou `.task(id:)` para trabalho ligado ao ciclo de vida da View. Propague cancelamento e trate `CancellationError` como cancelamento esperado.
- Um `Task` herda o contexto atual antes do primeiro `await`; mantenha esse prefixo síncrono curto. Use execução concorrente explícita somente quando a operação for segura fora do ator atual e retorne ao isolamento correto para publicar estado.
- Use atores para proteger estado mutável compartilhado e `Sendable` para valores que atravessam domínios de concorrência.
- Não use `Task.detached`, `@unchecked Sendable`, `nonisolated(unsafe)`, locks ou pontes de GCD como atalhos. Quando uma ponte for inevitável, documente a invariável que a torna segura e limite-a ao adaptador.
- Não atualize estado de UI fora do isolamento exigido pelo modelo observável. O ViewModel deve expor transições previsíveis para carregamento, sucesso, erro e cancelamento.
- Evite capturar View, ViewModel mutável ou dependências não `Sendable` em trabalhos que possam continuar após o escopo original.

## Performance e diagnóstico

Faça primeiro uma auditoria orientada por código e confirme a hipótese com métricas quando a causa não for evidente.

Procure especialmente:

- invalidações amplas causadas por um modelo observável grande demais ou por dependências lidas em níveis altos da árvore;
- identidade instável em listas e grids;
- trabalho pesado, I/O, criação de formatos e transformações repetidas no `body`;
- `GeometryReader`, preferences ou layouts que causam múltiplas passagens desnecessárias;
- imagens grandes decodificadas no caminho de renderização;
- animações amplas aplicadas a uma árvore inteira quando somente um valor deveria animar;
- tarefas duplicadas, ausência de cancelamento e carregamentos iniciados em mais de um nível;
- caches ad hoc em `@State` que mascaram a fonte de verdade ou ficam inconsistentes.

Para cada suspeita, registre o sintoma, o caminho de invalidação, a mudança proposta e a evidência. Use Instruments, SwiftUI trace, métricas de lançamento, memória ou energia quando a inspeção estática não bastar. `Self._printChanges()` pode ser usado somente em diagnóstico local e não deve chegar ao código de produção.

Use `equatable()` apenas quando a comparação for mais barata que a recomputação e quando a identidade semântica estiver correta. Não faça otimizações especulativas que dificultem a leitura antes de medir.

## Liquid Glass e APIs de plataforma

- Liquid Glass é opcional e só deve ser adotado quando fizer sentido para o produto e para o target; esta referência não autoriza redesign geral.
- Quando usado, prefira APIs nativas, respeite disponibilidade e ofereça fallback funcional para targets sem suporte.
- Agrupe elementos relacionados com `GlassEffectContainer` quando a composição de vários efeitos exigir coordenação visual.
- Use `glassEffect` depois de definir a forma e a aparência base; não empilhe materiais incompatíveis sem necessidade.
- `interactive` deve ser reservado a superfícies realmente interativas.
- Não use APIs novas sem verificar disponibilidade, comportamento degradado, acessibilidade e custo de renderização.

## Organização e estilo

- Adote o [Google Swift Style Guide](https://google.github.io/swift/) como
  convenção geral para todo código Swift do projeto: arquivos com SwiftUI,
  arquivos Swift puro e testes. Não crie um estilo separado para arquivos que
  importam somente Foundation ou outras bibliotecas sem UI.
- **Exceção declarada ao Google Style:** indentação de 4 espaços e largura de
  120 colunas, o padrão do Xcode. Argumentos, parâmetros, coleções e condições
  que não cabem na linha quebram antes do primeiro elemento, um por linha.
- Em cadeias de modificadores SwiftUI, siga os exemplos da Apple em
  [Configuring Views](https://developer.apple.com/documentation/swiftui/configuring-views):
  coloque cada modificador em sua própria linha, encadeado à View ou ao
  modificador anterior, mesmo quando a cadeia caberia em uma linha.
- Use nomes que expressem domínio e intenção; evite `Manager`, `Helper` ou `Service` genéricos quando uma responsabilidade mais precisa for possível.
- Cabeçalhos de arquivo, autores e datas seguem a convenção do projeto
  consumidor. Não invente metadados obrigatórios para uma base compartilhada.
- Quebre chamadas longas quando a leitura ou a revisão melhorarem; preserve argumentos nomeados e evite alinhamento artificial que gere ruído.
- Não altere nomes, pastas ou arquitetura existentes apenas para conformá-los a este documento quando isso estiver fora do escopo da tarefa.

### Seções `MARK:` obrigatórias

- Toda declaração `class`, `actor`, `struct`, `enum` e `extension` cujo corpo
  tenha 10 linhas ou mais começa com uma linha em branco seguida de
  `// MARK: - <responsabilidade>`. Isso vale para tipos aninhados e testes.
  Tipos menores ficam isentos, mas podem usar `MARK:` quando ajudar a leitura.
- Um `MARK:` antes da declaração não conta como seção do tipo.
- Crie a seção junto com o esqueleto do tipo, e não depois da implementação.
  Acrescente outras seções quando separar responsabilidades reais (por exemplo,
  `Public Properties`, `Private Properties`, `Initializer`, `Public Methods`,
  `Private Methods`) e mantenha a ordem das declarações previsível.
- O nome da seção descreve a responsabilidade; não há correção automática para
  `MARK:` ausente, porque o nome não pode ser inferido.

```swift
@MainActor
@Observable
final class CaptureViewModel {

    // MARK: - Public Properties

    let configuration: CaptureConfiguration

    var isRecording = false

    // MARK: - Public Methods

    func startRecording() { ... }
}
```

### Espaçamento entre blocos

O código é lido em blocos: declarações, validações, laços e decisões. Uma
linha em branco separa cada bloco para que o leitor enxergue as etapas sem
ler cada linha.

- **Grupos de `let` e de `var`:** declarações `let` e `var` não se misturam
  no mesmo grupo, nem em membros de tipo nem em corpos de função. Os `let`
  formam um grupo, os `var` outro, separados por uma linha em branco.
  Propriedades armazenadas também são separadas por uma linha em branco do
  primeiro `init`, `func` ou tipo seguinte.
- **Antes de um bloco:** `if`, `guard`, `for`, `while`, `switch`, `do`,
  `repeat` e `defer` são precedidos por uma linha em branco, exceto quando são
  a primeira instrução do escopo (logo após `{`, `in` ou `case ...:`).
- **Depois de um bloco:** a instrução que segue um `}` na mesma indentação é
  precedida por uma linha em branco. `else`, `catch`, `case`, `default`,
  fechamentos (`}`, `)`, `]`) e modificadores encadeados (`.padding()`) não
  contam como nova instrução.
- **Guards:** cada `guard` é seguido por uma linha em branco, inclusive entre
  guards consecutivos.
- **Switch:** casos com corpo de várias linhas são separados por uma linha em
  branco.
- Não comprima código para caber em limites de tamanho de função ou tipo; se
  um limite for atingido, extraia uma função com responsabilidade própria.

```swift
// Errado
func load(_ input: Int?) -> Int {
    let base = 1
    var total = 0
    guard let input else {
        return base
    }
    for value in 0..<input {
        total += value
    }
    return total + base
}

// Certo
func load(_ input: Int?) -> Int {
    let base = 1

    var total = 0

    guard let input else {
        return base
    }

    for value in 0..<input {
        total += value
    }

    return total + base
}
```

## Lint e formatação automática

Projetos consumidores que adotam esta referência usam **SwiftFormat** e
**SwiftLint**, com responsabilidades separadas:

| Ferramenta | Responsabilidade |
|---|---|
| SwiftFormat (`.swiftformat`) | Único formatador: indentação, largura, quebras de linha, imports, chaves, linhas em branco depois de `guard`, entre casos de `switch`, entre escopos e em volta de `MARK:` |
| SwiftLint (`.swiftlint.yml`) | Convenções, segurança (`force_unwrapping`, `force_try`), complexidade, ordem dos membros, `MARK:` obrigatório e as regras de espaçamento que o SwiftFormat não expressa |
| `scripts/fix-swift-spacing.pl` | Corrige automaticamente as regras custom de espaçamento do SwiftLint (`blank_line_before_block`, `blank_line_after_block`, `let_var_group_separation` e o caso de `let_var_whitespace` antes de declarações) |

O `swift-format` da Apple não é usado: ele não insere linhas em branco e
entraria em conflito com o SwiftFormat nas quebras de linha. As regras do
SwiftFormat que alteram comportamento, API ou nomes (por exemplo
`redundantSelf`, `redundantAsync`, `redundantMemberwiseInit`,
`swiftTestingTestCaseNames`, `unusedArguments`) ficam desativadas: o
formatador só altera layout e grafia puramente sintática.

`ai-bootstrap` instala e `ai-update` sincroniza, com manifesto, proteção de
conflito e rollback: `.swiftformat`, `.swiftlint.yml`, `scripts/lint-swift.sh`,
`scripts/fix-swift-spacing.pl`, `scripts/add-type-marks.py`,
`scripts/install-swift-tools.sh` e o workflow `.github/workflows/swift-lint.yml`. Um consumidor que já tinha configurações de
lint próprias, fora do manifesto, usa uma vez `ai-update --adopt-lint-config`
(ou `ai-bootstrap --adopt-lint-config`): os arquivos locais são preservados
como `<arquivo>.local-backup` e substituídos pelos compartilhados. Revise e
remova os backups depois. Ao final, os dois comandos imprimem os próximos
passos de adoção (`scripts/consumer-next-steps.txt`).

A baseline é SwiftLint 0.63.2 e SwiftFormat 0.63.0. As versões ficam fixadas
somente em `scripts/lint-swift.sh`. Instale com Homebrew ou baixe exatamente
essas versões para `.build/quality-tools/bin` (usado em CI e no Xcode Cloud):

```sh
brew install swiftlint swiftformat
scripts/install-swift-tools.sh
```

O gate procura as ferramentas em `.build/quality-tools/bin`,
`/opt/homebrew/bin` e `/usr/local/bin` antes do `PATH`, porque fases de build
do Xcode e o Xcode Cloud não herdam o `PATH` do terminal.

O gate distribuído é `scripts/lint-swift.sh`. Ele coleta as raízes `Sources/`
e `Tests/` do projeto e dos apps, os diretórios `Sources/` e `Tests/` de cada
pacote em `Packages/`, e os respectivos `Package.swift`; ignora submodules
registrados, `.ai/shared`, caches e pastas fora dessas raízes; verifica as
versões e roda `swiftformat --lint` e `swiftlint lint --strict`. Execute-o antes
de concluir cada alteração Swift e no CI. Para formatar e corrigir o
espaçamento, use o modo `--fix`, que aplica SwiftFormat, o fixer de
espaçamento, `swiftlint --fix` e uma passada final de SwiftFormat antes de
verificar:

```sh
scripts/lint-swift.sh --fix          # formata e insere as linhas em branco
scripts/lint-swift.sh --add-marks    # rascunha os MARKs ausentes para revisão
scripts/lint-swift.sh                # verifica sem escrever
scripts/lint-swift.sh --format-only  # só o layout, para fases de build do Xcode
```

`--add-marks` usa `scripts/add-type-marks.py`: extensions de conformidade
recebem o nome dos protocolos, extensions `Tipo+Responsabilidade.swift`
recebem a responsabilidade e os demais tipos recebem a categoria do primeiro
membro (`Cases`, `Public Properties`, `Initializer`, `Body`, `Tests`...).
Os nomes são rascunhos; revise-os antes do commit.

Integração com Xcode: rode `--format-only` numa fase de build de um target
com `ENABLE_USER_SCRIPT_SANDBOXING = NO` (o sandbox bloqueia a leitura das
pastas) e mantenha o SwiftLint como build tool plugin. No Xcode Cloud, chame
`scripts/install-swift-tools.sh` e `scripts/lint-swift.sh` em
`ci_scripts/ci_post_clone.sh`. Testes que leem o código-fonte como texto podem
precisar de ajuste ao layout canônico.

Revise o diff produzido antes de registrá-lo e mantenha a formatação em massa
em um commit separado de mudanças de comportamento.

As regras custom do SwiftLint usam regex, não um parser de Swift. Elas cobrem
o formato produzido pelo formatter (atributos e modificadores antes da
declaração, `{` na mesma linha) e não cobrem sintaxe atípica. Revise também
manualmente os `MARK:` e o espaçamento no diff. Os fixtures das regras ficam
somente na base AI (`scripts/test-required-type-marks.sh` e
`scripts/test-swift-spacing.sh`) e rodam no CI dela.

Distribua as responsabilidades para evitar diagnósticos duplicados:

- Em SwiftLint, preserve as regras padrão de convenções e as regras de
  segurança e complexidade. Os limites (`function_body_length` 60/100,
  `type_body_length` 350/500, `file_length` 500/700) consideram o layout
  vertical exigido por esta referência; não os use para exigir fragmentação
  artificial nem comprima código para cumpri-los.
- Em SwiftFormat, mantenha as regras de layout coerentes com esta referência e
  use a mesma configuração para formatar e verificar.
- Regras de layout do SwiftLint que se sobrepõem ao SwiftFormat ficam
  desativadas no `.swiftlint.yml` compartilhado.
- Em SwiftUI, mantenha as regras estruturais desta referência: `body` sem
  efeitos colaterais ou trabalho pesado, estado e ações nos locais definidos
  por MVVM, identidade estável nas coleções e controles acessíveis. Como essas
  propriedades nem sempre podem ser verificadas por lint, confira-as também
  no checklist de revisão.
- Não desative regras globalmente para silenciar violações pontuais. Quando
  uma exceção for necessária, limite-a à menor linha ou trecho possível e
  explique o motivo junto à supressão.

## Animações

- Anime somente mudanças de estado observáveis e intencionais.
- Prefira `animation(_:value:)` ligado ao valor que mudou, em vez de uma animação implícita sem escopo.
- Não anime cada linha de uma coleção sem uma identidade e uma transição claras.
- Evite trabalho pesado dentro de closures de transição e mantenha acessíveis os estados inicial e final.
- Verifique redução de movimento e outros ajustes de acessibilidade quando a animação for essencial à experiência.

## Previews

- Toda `View` criada deve ter pelo menos um `#Preview` útil, determinístico e
  autocontido. Inclua previews para todos os estados de apresentação que a View
  suporta, com nomes que identifiquem cada estado quando houver mais de um.
- Dentro de `#Preview`, use `@Previewable` em cada propriedade dinâmica local
  necessária para configurar ou dirigir esses estados, como `@State`,
  `@Binding` ou `@Query`. `@Previewable` só pode ser usado no corpo de
  `#Preview`; não é um atributo para aplicar à declaração da própria View nem
  substitui um preview por estado.
- Se o estado for fornecido por um ViewModel, injete uma instância de preview
  determinística para cada estado em vez de duplicar o estado da produção com
  propriedades locais sem relação com a fonte de verdade da View.
- Use dados locais e dependências fakes; previews não devem depender de rede, autenticação real, banco compartilhado ou arquivos mutáveis do usuário.
- Cubra estados representativos: conteúdo, vazio, carregando, erro, conteúdo longo, Dynamic Type e tamanho de dispositivo relevante.
- Injete ViewModels e serviços de preview pelo mesmo contrato usado em produção, com implementações previsíveis.
- Use recursos de preview do target apenas quando o target realmente os suportar.

## Persistência e integrações

- Separe modelo de domínio, DTO de transporte, persistência e modelo de apresentação quando suas responsabilidades divergirem.
- Mapeamentos entre camadas devem ser puros sempre que possível e cobertos por Swift Testing.
- Clientes de rede devem definir timeout, cancelamento, decodificação, tratamento de status e mapeamento de erro.
- Repositórios devem esconder detalhes de armazenamento e oferecer operações que expressem a necessidade do domínio.
- Integrações de plataforma devem ficar em `Core/Platform` ou `Core/Integrations`, com protocolos consumidos pelo ViewModel ou serviço de domínio.
- Migrações de persistência devem ser explícitas, reversíveis quando possível e verificadas com dados representativos.

## Observabilidade e analytics

Analytics, logging e métricas são opcionais e devem seguir a necessidade do produto. Quando existirem:

- defina um protocolo pequeno e uma implementação nula para previews e testes;
- não registre segredos, tokens, conteúdo sensível ou payloads completos sem justificativa e proteção;
- mantenha a instrumentação fora da View quando ela puder viver no ViewModel, serviço ou camada de integração;
- nomeie eventos e propriedades com contrato estável, documentação e política de retenção conhecida.

## Testes

Use exclusivamente Swift Testing (`import Testing`, `@Test`, `#expect` e `#require`) neste padrão. Não introduza XCTest, XCUIAutomation, testes de UI ou snapshots como alternativa.

- Teste ViewModels, serviços, repositórios, adaptadores, mapeamentos, persistência, migrações, cancelamento e regras puras.
- Dê preferência a testes determinísticos, rápidos e independentes, usando fakes locais e relógios ou clientes controláveis quando necessário.
- Cubra estados de sucesso, vazio, erro, repetição, cancelamento e concorrência relevantes ao contrato.
- Testes assíncronos devem aguardar explicitamente os efeitos e nunca depender de `sleep` arbitrário.
- Siga TDD para alterações de comportamento: primeiro um teste Swift Testing que falha, depois a implementação mínima e por fim a refatoração.
- Separe testes focados, suíte completa e compilação. Registre comandos, destino, versão do toolchain e resultado.
- Não alegue validação de dispositivo, desempenho, sensores, permissões ou serviços externos a partir de testes unitários ou de compilação no simulador.

## Checklist de revisão

- [ ] A organização segue `Resources/`, `Sources/App`, `Sources/Core`, `Sources/Features` e `Tests/`.
- [ ] Cada tela ou componente comportamental possui View e ViewModel coerentes com MVVM.
- [ ] Modelos de domínio/apresentação, fixtures e dados de preview ficam em arquivos próprios, fora de arquivos que declaram View.
- [ ] A composição de dependências está em `AppContainer` ou em um ponto equivalente explícito.
- [ ] A navegação tem fonte de verdade única e rotas leves.
- [ ] O `body` não contém efeitos colaterais nem trabalho pesado repetido.
- [ ] Identidades de listas são estáveis e as imagens são tratadas fora do caminho crítico de renderização.
- [ ] O isolamento de concorrência foi confirmado contra as configurações reais do target.
- [ ] Cancelamento, `Sendable`, atores e atualizações de UI foram revisados.
- [ ] Estados de carregamento, vazio, erro e sucesso estão cobertos quando aplicável.
- [ ] Previews são determinísticos e não acessam serviços reais.
- [ ] Testes usam somente Swift Testing e cobrem o contrato alterado.
- [ ] Segredos e dados sensíveis não entram no repositório ou nos logs.
- [ ] Tipos e extensions com 10 linhas ou mais abrem com `// MARK: - <responsabilidade>`.
- [ ] Grupos de `let` e `var` estão separados e cada bloco de controle tem uma linha em branco antes e depois.
- [ ] `scripts/lint-swift.sh` passou sem violações.
- [ ] Links, Markdown, diff e arquivos fora do escopo foram verificados.

## Referências oficiais

- [Google Swift Style Guide](https://google.github.io/swift/)
- [Configuring Views](https://developer.apple.com/documentation/swiftui/configuring-views)
- [Previewable](<https://developer.apple.com/documentation/swiftui/previewable()>)
- [Preview(_:body:)](<https://developer.apple.com/documentation/swiftui/preview(_:body:)>)
- [Previews in Xcode](https://developer.apple.com/documentation/swiftui/previews-in-xcode)
- [Managing model data in your app](https://developer.apple.com/documentation/SwiftUI/Managing-model-data-in-your-app)
- [Bindable](https://developer.apple.com/documentation/swiftui/bindable)
- [Understanding the navigation stack](https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack)
- [navigationDestination(for:destination:)](<https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:)>)
- [Xcode Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)
- [SwiftLint: instalação, execução e configuração](https://github.com/realm/SwiftLint)
- [SwiftFormat: instalação e uso](https://github.com/nicklockwood/SwiftFormat)
- [SwiftFormat: regras e opções](https://github.com/nicklockwood/SwiftFormat/blob/main/Rules.md)

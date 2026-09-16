# Referência Swift/SwiftUI

Este documento é a referência estrutural e semântica para projetos Swift/SwiftUI que adotam esta base. Ele define organização de pastas, MVVM, composição de telas, estado, concorrência, performance, segurança e testes. O projeto consumidor pode adaptar nomes de features e recursos, mas não deve ignorar estas regras sem registrar uma exceção no `AGENTS.md` local.

## Princípios da base compartilhada

- MVVM é obrigatório para telas e componentes que possuem estado, eventos ou comportamento de apresentação.
- Swift Testing é a única tecnologia de testes autorizada neste padrão.
- O código deve depender de contratos e abstrações pequenas, com composição explícita no ponto de entrada.
- Views devem ser declarativas, previsíveis e livres de efeitos colaterais no `body`.
- A documentação não presume um target, uma versão mínima de sistema ou configurações de build que não estejam confirmadas no projeto consumidor.
- Recursos, serviços externos e persistência devem ser isolados atrás de protocolos ou adaptadores quando isso melhorar testabilidade e substituição.
- O comportamento conectado do projeto consumidor continua sendo a fonte de verdade para nomes, fluxos e compatibilidade.

## Plano operacional de uso das skills

Skills são pacotes de instruções para orientar o modelo; sua presença em
`ai/skills/` não significa que sejam lidas ou executadas automaticamente em
toda tarefa. O modelo deve selecionar as skills pelo escopo real do pedido,
ler integralmente o `SKILL.md` de cada skill aplicável antes do trabalho
correspondente e registrar as decisões no plano e no relatório da execução.

### Matriz de roteamento

| Escopo da tarefa | Skill | Aplicação |
| --- | --- | --- |
| Implementar, corrigir, revisar ou refatorar qualquer código Swift/SwiftUI | [`swiftui-expert-skill`](./skills/swiftui-expert-skill/SKILL.md) | Obrigatória |
| Qualquer tarefa que leia, escreva ou altere Swift | [`swift-concurrency`](./skills/swift-concurrency/SKILL.md) | Obrigatória, inclusive no planejamento; confirme as configurações reais de concorrência |
| Construir, alterar ou revisar telas, navegação, controles ou composição SwiftUI | [`swiftui-ui-patterns`](./skills/swiftui-ui-patterns/SKILL.md) | Obrigatória para o escopo de UI |
| Construir ou revisar janelas, menus, commands, toolbars, Settings, split views ou inspectors de macOS | [`swiftui-patterns`](./skills/swiftui-patterns/SKILL.md) | Condicional à superfície macOS envolvida |
| Refatorar estrutura de Views, ownership de estado ou composição | [`swiftui-view-refactor`](./skills/swiftui-view-refactor/SKILL.md) | Condicional à refatoração |
| Adotar, revisar ou corrigir Liquid Glass | [`swiftui-liquid-glass`](./skills/swiftui-liquid-glass/SKILL.md) | Condicional ao uso solicitado ou existente; não implica redesign geral |
| Construir, executar ou diagnosticar o app no iOS Simulator | [`ios-debugger-agent`](./skills/ios-debugger-agent/SKILL.md) | Condicional à validação no Simulator |

Não carregue uma skill condicional apenas por hábito. Quando ela não for
aplicável, registre `SKIPPED` e o motivo. A descrição da skill é um gatilho de
seleção, não uma autorização para ampliar o escopo da tarefa.

### Ordem de leitura e aplicação

1. Leia as instruções do checkout, o brief e o guide do projeto consumidor,
   quando existirem, e esta referência.
2. Para qualquer código Swift, leia `swift-concurrency` antes de escolher
   isolamento, `Task`, `Sendable`, `@MainActor` ou APIs relacionadas. Confirme
   `SWIFT_VERSION`, `SWIFT_STRICT_CONCURRENCY`,
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

- Antes de usar uma API, confirme a versão mínima do target, a versão do Swift e as configurações de concorrência do projeto (`SWIFT_VERSION`, `SWIFT_STRICT_CONCURRENCY`, `SWIFT_DEFAULT_ACTOR_ISOLATION` e upcoming features).
- Prefira APIs atuais compatíveis com o target real. Não introduza disponibilidade de plataforma ou migrações de linguagem apenas porque esta referência foi atualizada.
- Não aplique `@MainActor` globalmente como correção automática. Use isolamento onde o dado ou a operação realmente exigirem execução no ator principal.
- Segredos, tokens, certificados, chaves privadas e dados pessoais não devem ser armazenados no código-fonte, nos assets, em logs ou em arquivos versionados.
- Dados sensíveis devem usar o mecanismo seguro apropriado à plataforma e ao risco; não use `UserDefaults` como cofre.
- Dependências externas precisam de aprovação explícita e devem ser encapsuladas para que o domínio e as Views não dependam diretamente de SDKs de terceiros.
- Erros de rede, persistência, autenticação e permissões devem ter tipos ou contratos observáveis, mensagens seguras e tratamento determinístico.

## Estrutura esperada

Use a estrutura abaixo como padrão para um app. `MyApp` e os nomes de features são ilustrativos e devem ser substituídos pelo nome real do produto.

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

- `Resources/` contém somente conteúdo empacotado com o app: assets, localizações, fontes, áudio, vídeo e conteúdo de preview. Não coloque código Swift aqui.
- `Sources/App/` contém a raiz do app, a composição das dependências e a fonte de verdade da navegação global.
- `Sources/Core/` contém código reutilizável entre features. Separe por responsabilidade e não use `Core` como depósito genérico para arquivos sem dono claro.
- `Sources/Features/` contém as fatias verticais do produto. Cada feature deve manter sua View, seu ViewModel e seus componentes próximos.
- `Tests/Core/` e `Tests/Features/` espelham os contratos testáveis da implementação. Mantenha os testes próximos à responsabilidade que verificam.

## MVVM e composição

MVVM é obrigatório para telas e componentes comportamentais:

- A `View` descreve a hierarquia visual, encaminha ações e observa o estado de apresentação.
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

- Use nomes que expressem domínio e intenção; evite `Manager`, `Helper` ou `Service` genéricos quando uma responsabilidade mais precisa for possível.
- Use `MARK:` somente para separar responsabilidades reais e mantenha a ordem das declarações previsível.
- Cabeçalhos de arquivo, autores, datas e regras de formatação devem seguir a convenção do projeto consumidor. Não invente metadados obrigatórios para uma base compartilhada.
- Mantenha uma linha entre declarações independentes e agrupe modificadores ou propriedades que formam uma única unidade semântica.
- Quebre chamadas longas quando a leitura ou a revisão melhorarem; preserve argumentos nomeados e evite alinhamento artificial que gere ruído.
- Não altere nomes, pastas ou arquitetura existentes apenas para conformá-los a este documento quando isso estiver fora do escopo da tarefa.

## Animações

- Anime somente mudanças de estado observáveis e intencionais.
- Prefira `animation(_:value:)` ligado ao valor que mudou, em vez de uma animação implícita sem escopo.
- Não anime cada linha de uma coleção sem uma identidade e uma transição claras.
- Evite trabalho pesado dentro de closures de transição e mantenha acessíveis os estados inicial e final.
- Verifique redução de movimento e outros ajustes de acessibilidade quando a animação for essencial à experiência.

## Previews

- Cada tela importante e cada componente complexo deve ter preview útil, determinístico e autocontido.
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
- [ ] Links, Markdown, diff e arquivos fora do escopo foram verificados.

## Referências oficiais

- [Managing model data in your app](https://developer.apple.com/documentation/SwiftUI/Managing-model-data-in-your-app)
- [Bindable](https://developer.apple.com/documentation/swiftui/bindable)
- [Understanding the navigation stack](https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack)
- [navigationDestination(for:destination:)](<https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:)>)
- [Xcode Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)

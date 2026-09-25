# Regras de engenharia do projeto

Estas regras valem para a base compartilhada e para os projetos consumidores
que a adotam. Um `AGENTS.md` mais específico pode acrescentar regras para a
sua pasta, mas não remove estas regras sem declarar a exceção.

Este repositório é somente a base de organização da camada de IA. Ele não é um
aplicativo Apple e não possui contexto de produto próprio. Os arquivos
`PROJECT_BRIEF.md` e `PROJECT_GUIDE.md` são criados a partir dos templates nos
projetos consumidores; a ausência deles neste repositório é intencional.

## Escopo e fontes

- No projeto consumidor que adota estas regras, `.ai/PROJECT_BRIEF.md` é a fonte da visão do produto, dos fluxos, dos estados e das pendências de validação daquele projeto. Nesta base, use [`.ai/PROJECT_BRIEF.template.md`](./.ai/PROJECT_BRIEF.template.md) somente como modelo.
- No projeto consumidor que adota estas regras, `.ai/PROJECT_GUIDE.md` registra a baseline, a arquitetura, os comandos e as validações específicas. Nesta base, use [`.ai/PROJECT_GUIDE.template.md`](./.ai/PROJECT_GUIDE.template.md) somente como modelo.
- No checkout que adota estas regras, [SWIFT_REFERENCE.md](./.ai/SWIFT_REFERENCE.md) é a referência normativa para toda estrutura, organização e escrita de código Swift/SwiftUI, inclusive testes. Consulte-a antes de criar ou reorganizar código.
- O código e a configuração existentes continuam sendo a fonte do comportamento efetivamente conectado. Esta documentação não autoriza migração de nomes, pastas ou arquitetura fora do escopo solicitado; preserve o ambiente, as features e as convenções já conectadas.
- Use a terminologia do brief e dos contratos existentes para modos, estados e recursos; não invente categorias de domínio para substituir os nomes do produto.

## Orquestração obrigatória de subagentes

- [`.ai/CODEX_ORCHESTRATOR.md`](./.ai/CODEX_ORCHESTRATOR.md) é o contrato operacional compartilhado que governa a criação, a passagem de contexto, os estados, a revisão e os critérios de aprovação dos subagentes. Consulte-o antes de iniciar qualquer alteração de comportamento em um projeto consumidor e siga o ciclo Manager → Developer → Manager quando os agentes nativos estiverem disponíveis.
- Subagentes são agentes nativos do Codex executados pelo agente principal para assumir um papel delimitado da tarefa. Eles não são apenas nomes alternativos para modelos: recebem escopo, entradas, critérios e permissões próprias, devolvem resultados ao agente principal e não iniciam outro workflow nem delegam recursivamente.
- Para alterações de comportamento, o agente principal deve criar os agentes personalizados `sol` e `luna`, definidos pelas configurações compartilhadas em `.codex/agents/`. `Manager` e `Developer` são os papéis conceituais, não os identificadores de despacho. Antes da implementação, registre o estado inicial e entregue o pedido original a `sol` para planejamento; depois encaminhe o plano READY a `luna`. Cada agente deve receber escopo, entradas e critérios claros.
- O agente `sol`, no papel conceitual Manager, exerce dois papéis somente leitura: prepara o plano e realiza a revisão final da implementação contra o pedido, o plano, os critérios de aceite e o diff.
- O agente `luna`, no papel conceitual Developer, recebe o plano completo de `sol`, implementa, testa e corrige os apontamentos.
- Antes de aceitar cada delegação, confira se o modelo e o esforço de raciocínio observáveis no runtime correspondem ao TOML selecionado. Se houver divergência observável, não aceite a etapa e informe o principal. Se a ferramenta não expuser esses valores, declare a limitação; não afirme que o TOML foi aplicado nem que a correspondência foi verificada.
- O plano do Manager deve entregar ao Developer, de forma executável e sem lacunas conhecidas: requisitos funcionais e não funcionais, escopo e não escopo, arquivos e contratos afetados, abordagem e frameworks/APIs atuais compatíveis com o projeto, skills aplicáveis, riscos, estratégia TDD/validação e critérios objetivos de aceite. O Developer não deve reabrir decisões já resolvidas no plano sem registrar a razão.
- O fluxo é obrigatório: Manager analisa → Developer implementa e valida → Manager revisa → Developer corrige, se necessário → Manager revisa novamente até `APPROVED` ou o limite definido pelo orquestrador. `CHANGES_REQUESTED`, validação obrigatória pendente, saída inválida ou mudança concorrente impede a conclusão.
- O agente principal aguarda cada etapa, encaminha correções e solicita uma nova revisão do Manager, sem editar enquanto a revisão está em andamento. Se a ferramenta não disponibilizar os agentes nativos, informe a limitação; não simule sua criação por nomes em prompts. Não crie tarefas independentes na interface para substituir subagentes.

## Skills obrigatórias

Antes de ler, escrever, revisar ou refatorar código Swift/SwiftUI, carregue e siga:

- [`swiftui-expert-skill`](./.agents/skills/swiftui-expert-skill/SKILL.md) em toda implementação, correção, revisão e refatoração.
- [`swift-concurrency`](./.agents/skills/swift-concurrency/SKILL.md) sempre, inclusive durante o planejamento, para avaliar isolamento, tarefas, cancelamento e transferência entre domínios.
- Ao construir, alterar ou revisar telas, use [`swiftui-ui-patterns`](./.agents/skills/swiftui-ui-patterns/SKILL.md); use [`swiftui-patterns`](./.agents/skills/swiftui-patterns/SKILL.md) quando a superfície envolver janelas, menus, commands, toolbars, Settings, split views ou inspectors de macOS.
- Ao adotar, revisar ou corrigir Liquid Glass, use [`swiftui-liquid-glass`](./.agents/skills/swiftui-liquid-glass/SKILL.md). A skill é condicional e não autoriza redesign geral.
- Ao refatorar código Swift/SwiftUI, acrescente [`swiftui-view-refactor`](./.agents/skills/swiftui-view-refactor/SKILL.md) às skills aplicáveis ao escopo e à revisão.
- Para depuração e validação no simulador iOS, carregue [`ios-debugger-agent`](./.agents/skills/ios-debugger-agent/SKILL.md) quando o escopo exigir esse ambiente.

Selecione, leia e registre as skills conforme a matriz e a ordem definidas em
[`SWIFT_REFERENCE.md`](./.ai/SWIFT_REFERENCE.md). Skills disponíveis não são
prova de uso automático. O plano e o relatório devem conter `SKILLS_STATUS` com
`APPLIED`, `SKIPPED` e `CONFLICTS`. Em caso de conflito, as regras do projeto e
de `SWIFT_REFERENCE.md` prevalecem sobre a orientação genérica da skill.

## Papéis dos subagentes

Os papéis abaixo são executados pelos subagentes nativos definidos nas
configurações compartilhadas. O agente principal não deve tratar esta seção
como um workflow alternativo: a coordenação operacional pertence ao
[`CODEX_ORCHESTRATOR.md`](./.ai/CODEX_ORCHESTRATOR.md).

- Planejamento: `sol` (papel conceitual Manager), somente leitura.
- Implementação e correções: `luna` (papel conceitual Developer).
- Revisões: `sol` (papel conceitual Manager), somente leitura.

O ciclo obrigatório é definido e detalhado pelo orquestrador: Manager planeja →
Developer implementa e valida → Manager revisa → Developer corrige, se
necessário → Manager revisa novamente até resolver todos os apontamentos.

Quando uma ferramenta restringir caracteres, diferencie o identificador técnico do nome de apresentação e preserve exatamente o nome definido acima.

## Fluxo de trabalho

- Preserve alterações locais não relacionadas e nunca sobrescreva o trabalho do usuário. Não use operações destrutivas sem escopo explícito.
- Para alterações de comportamento, siga TDD: escreva primeiro um teste unitário que falhe, implemente o comportamento mínimo e refatore mantendo o teste passando.
- Rode testes focados durante o desenvolvimento, depois a suíte completa de testes e uma compilação para o iOS Simulator quando o ambiente permitir. Registre comando e resultado; não alegue validação que não foi executada.
- Simulator e build genérico comprovam compilação, estados e ciclo de vida compatíveis, mas não comprovam comportamento físico do dispositivo, desempenho, térmica, sensores, áudio, permissões ou equivalência a serviços externos. Essas alegações exigem validação no hardware e nos serviços compatíveis descritos no brief.
- Não adicione dependências de terceiros sem aprovação explícita. Trate avisos do compilador no código alterado como defeitos.
- Escreva código Swift já no formato de [Organização e estilo](./.ai/SWIFT_REFERENCE.md#organização-e-estilo): `MARK:` obrigatório nos tipos, grupos de `let` e `var` separados e linha em branco entre blocos de lógica. Antes de concluir, rode `scripts/lint-swift.sh --fix` e `scripts/lint-swift.sh` no consumidor e registre o resultado.
- Não crie testes de UI nem use XCUIAutomation; a estrutura dos testes segue a seção [Testes](./.ai/SWIFT_REFERENCE.md#testes) do manual.
- Mantenha segredos fora do repositório; as regras de armazenamento seguro ficam na seção [Base técnica e segurança](./.ai/SWIFT_REFERENCE.md#base-técnica-e-segurança) do manual Swift.

Ao terminar, entregue as alterações e a evidência de validação proporcional ao escopo. Para mudanças somente documentais, verifique Markdown, links, diffs e preservação dos arquivos fora do escopo.

## Temporários, caches e evidências do Xcode

- Antes da resposta final de cada execução, inclusive após falhas quando for possível encerrar com segurança, finalize os processos próprios, extraia as evidências necessárias e limpe os artefatos descartáveis comprovadamente criados por esta tarefa e de uso exclusivo dela. Isso inclui temporários, logs, screenshots e gravações de ferramentas, imagens geradas pelo XcodeMCP e DerivedData temporário.
- Mantenha um inventário de caminhos exclusivos por tarefa para esses outputs. Quando a ferramenta permitir, informe um destino explícito. Diferencie screenshots do XcodeBuildMCP de runtimes e imagens de disco do simulador; não suponha caminhos nem trate uma categoria como a outra.
- A remoção restrita acima já está autorizada para temporários próprios; não peça confirmação novamente. Remova somente artefatos descartáveis comprovadamente exclusivos após encerrar os processos que os usam. Preserve entregáveis solicitados e evidências ainda necessárias à depuração. Nunca apague arquivos apenas por estarem ignorados ou não rastreados, e nunca use `git clean`.
- Preserve por padrão o cache incremental compartilhado e nunca faça um clean global a cada build. Não apague globalmente DerivedData, caches do SwiftPM ou do CoreSimulator, runtimes ou imagens de disco do simulador, Archives, dSYMs, signing ou caches de plugins. Para esses itens, faça primeiro um diagnóstico delimitado com caminho, tamanho, inatividade e impacto; a remoção fora do escopo já autorizado exige autorização específica e explícita.
- Evite globs, raízes compartilhadas, symlinks não verificados e qualquer interferência em tarefas paralelas. Registre o que foi removido e preservado, o tamanho medido quando disponível e os bloqueios encontrados. Se o agente for interrompido, não alegue que a limpeza foi garantida.

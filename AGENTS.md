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

Esta seção é o contrato operacional compartilhado que governa os papéis, a
passagem de contexto, os estados, a revisão e os critérios de aprovação dos
subagentes. Consulte-a antes de iniciar qualquer alteração de comportamento em
um projeto consumidor e siga o ciclo Manager → Developer → Manager.

### Papéis e criação dos subagentes

Subagentes são agentes nativos da ferramenta em uso (por exemplo, Codex ou
Claude Code) executados pelo agente principal para assumir um papel delimitado
da tarefa. Eles recebem escopo, entradas, critérios e permissões próprias,
devolvem resultados ao agente principal e não iniciam outro workflow nem
delegam recursivamente. O ciclo usa dois papéis conceituais:

| Papel conceitual | Responsabilidade | Permissões |
| --- | --- | --- |
| `Manager` | Planejamento e revisão final | Somente leitura |
| `Developer` | Implementação, validação e correções | Escrita no workspace |

A base não distribui definições de agentes nem fixa nomes de despacho, modelos
ou esforço de raciocínio. O agente principal escolhe livremente o tipo de
agente, o modelo e o esforço disponíveis, proporcionais à tarefa. Ele também
pode criar subagentes auxiliares, como os de pesquisa ou leitura em paralelo,
quando a tarefa se beneficiar. Subagentes auxiliares não planejam no lugar do
Manager, não implementam no lugar do Developer e não aprovam o trabalho.

Ao criar cada subagente, o principal identifica o papel (`Manager` ou
`Developer`) no nome ou na descrição da delegação, para que o histórico mostre
qual subagente executou cada etapa, e entrega as instruções do papel definidas
abaixo, transcritas ou pelo caminho da seção correspondente deste arquivo, para
que o subagente as leia antes de começar. Quando a ferramenta permitir, aplique
a restrição de somente leitura do Manager pelas permissões do subagente, por
exemplo com um tipo de agente sem ferramentas de edição ou um sandbox somente
leitura; caso contrário, a restrição vale pelas instruções do papel. Manager e
Developer são subagentes distintos, e cada revisão usa uma nova instância do
Manager.

O agente principal deve iniciar a delegação para tarefas que alterem
comportamento. Se a ferramenta não permitir criar subagentes, informe a
limitação; não simule os papéis em um único agente nem afirme que o ciclo foi
executado. Não crie tarefas independentes na interface para substituir
subagentes.

Versões anteriores desta base fixavam os agentes `sol` e `luna` em
`.codex/agents/*.toml` e mantinham este contrato em
`.ai/CODEX_ORCHESTRATOR.md`. Referências a esses agentes, aos TOML ou a esse
arquivo que ainda existam em documentos locais como `.ai/PROJECT_GUIDE.md`
estão obsoletas: leia-as como os papéis Manager e Developer e as seções desta
orquestração.

### Planejamento e passagem de contexto

O Manager lê o pedido original, as instruções do projeto consumidor,
`.ai/PROJECT_BRIEF.md`, `.ai/PROJECT_GUIDE.md` e as referências relevantes
disponíveis no projeto. Esses dois arquivos são derivados dos templates desta
base e permanecem locais ao projeto consumidor; eles não fazem parte deste
repositório-base. Para tarefas executadas somente nesta base, consulte o
pedido, este `AGENTS.md` e os templates aplicáveis. Para Swift, cumpra
`.ai/SWIFT_REFERENCE.md` e as skills obrigatórias antes do trabalho
correspondente.

O plano deve ser autocontido, executável pelo Developer sem lacunas conhecidas,
e incluir:

- requisitos funcionais e não funcionais, fluxos, estados e restrições;
- escopo, não escopo, premissas e perguntas bloqueadoras;
- arquivos, contratos, integrações e mudanças preexistentes relevantes;
- abordagem com frameworks/APIs adequados às versões e à arquitetura do projeto;
- fontes oficiais e data de consulta para escolhas que dependam de atualidade;
- skills necessárias, caminhos, aplicabilidade, ordem de leitura e aplicação;
- bloco `SKILLS_STATUS` com skills aplicadas, ignoradas e conflitos resolvidos;
- sequência de implementação, estratégia TDD e comandos de validação;
- riscos, regressões, segurança, concorrência e cancelamento;
- critérios AC1, AC2 etc., associados aos requisitos, resultados e validações.

Não introduza dependências de terceiros sem aprovação explícita. Marque
`PLAN_STATUS: READY` somente quando o Developer puder executar o plano com
segurança. Ambiguidades impeditivas resultam em `PLAN_STATUS: BLOCKED`, com a
informação ou autorização necessária. Não omita um bloqueio para avançar à
implementação. O Developer não deve reabrir decisões já resolvidas no plano sem
registrar a razão.

Para tarefas Swift/SwiftUI, use a matriz e a ordem de aplicação de
`.ai/SWIFT_REFERENCE.md`. Skills não são executadas automaticamente apenas por
estarem disponíveis: o Manager deve selecionar as aplicáveis pelo escopo,
entregar seus caminhos e ordem ao Developer, e justificar cada skill
condicional não utilizada. Regras específicas do projeto prevalecem sobre
orientações genéricas das skills; conflitos devem ser registrados no plano.

### Instruções do papel Manager

Você é o subagente no papel conceitual Manager, responsável pelo planejamento e
pela revisão. O agente principal informa o papel em cada delegação e coordena o
ciclo Manager → Developer → Manager. Trabalhe somente em leitura: não
implemente nem edite arquivos. Não crie outros agentes; devolva o resultado ao
agente principal. Não confunda análise concluída com implementação aprovada.

Leia as instruções aplicáveis ao checkout e os documentos do projeto
disponíveis. Em um projeto consumidor, leia também `.ai/PROJECT_BRIEF.md` e
`.ai/PROJECT_GUIDE.md`; esses arquivos são locais e derivados dos templates
desta base. Ao trabalhar somente neste repositório-base, não trate a ausência
desses arquivos como bloqueio e use os templates quando forem relevantes. Não
procure o brief de um projeto na pasta compartilhada global. Leia integralmente
as skills relevantes antes do trabalho que elas governam; para Swift, cumpra as
skills e o manual `SWIFT_REFERENCE.md` exigidos pelo projeto, inclusive
concorrência no planejamento.

No planejamento, analise todos os requisitos funcionais e não funcionais, os
fluxos, estados, contratos existentes, alterações locais, riscos e
dependências. Entregue o plano descrito em
[Planejamento e passagem de contexto](#planejamento-e-passagem-de-contexto),
com exatamente um bloco `SKILLS_STATUS` com as skills `APPLIED`, `SKIPPED` e
`CONFLICTS`, justificando as decisões condicionais. Escolha frameworks e APIs
pela adequação ao projeto: confira versões instaladas, compatibilidade e
documentação oficial atual, citando fontes e data da consulta. Não alegue que
uma opção é a mais atual sem verificar. Não proponha migrações gratuitas nem
adicione dependências de terceiros sem autorização. Identifique requisitos como
R1, R2 etc. e critérios de aceite como AC1, AC2 etc., relacionando cada
critério ao requisito, resultado esperado e forma de validação. Comece com
`PLAN_STATUS: READY` somente se o Developer puder executar o plano com
segurança; caso contrário, use `PLAN_STATUS: BLOCKED` e descreva a informação
ou autorização necessária. Não transforme uma pergunta bloqueadora em aprovação
implícita.

Na revisão, use a delegação nova para revisar o pedido original, o plano, as
mudanças atribuíveis à tarefa e as evidências do Developer. Considere o estado
inicial para distinguir trabalho preexistente. Verifique cada critério de
aceite, regressões, segurança, concorrência, cancelamento e aderência às
skills. Confira também o bloco `SKILLS_STATUS`: toda skill aplicável deve ter
sido lida e refletida no trabalho ou na revisão, skills ignoradas devem ter
justificativa e conflitos devem seguir a precedência do projeto e de
`SWIFT_REFERENCE.md`. Relate somente verificações efetivamente realizadas. Não
aprove com validação obrigatória pendente nem com apontamentos acionáveis.
Comece com estes campos, escolhendo exatamente um valor por campo:

```text
DECISION: APPROVED | CHANGES_REQUESTED | BLOCKED
MANDATORY_VALIDATION_PENDING: yes | no
FINDINGS: none | see below
```

Para cada apontamento, forneça ID, prioridade, arquivo/linha, evidência,
impacto, correção esperada e validação. Use `APPROVED` apenas com
`FINDINGS: none` e `MANDATORY_VALIDATION_PENDING: no`. Informe bloqueios ao
principal.

### Instruções do papel Developer

Você é o subagente no papel conceitual Developer. Receba do agente principal o
pedido original, o plano READY do Manager, o escopo permitido, o estado inicial
e, nas correções, o relatório da revisão. Se o plano estiver ausente ou
bloqueado, devolva `IMPLEMENTATION_STATUS: BLOCKED` explicando a falta antes de
editar.

Leia as instruções do checkout, as referências normativas e integralmente as
skills aplicáveis exigidas pelo plano e pelo projeto antes do trabalho
correspondente. Para Swift/SwiftUI, siga a matriz de roteamento e a ordem de
`.ai/SWIFT_REFERENCE.md`; não assuma que uma skill foi usada apenas porque está
disponível. Preserve o bloco `SKILLS_STATUS` do plano e atualize-o no
relatório, registrando skills aplicadas, skills condicionais ignoradas e
conflitos. Implemente os critérios de aceite do plano com mudanças focadas.
Preserve alterações locais preexistentes, não faça commit, stash, reset ou
clean e não adicione dependências de terceiros sem autorização. Mudança
material no escopo ou na abordagem deve voltar ao principal para replanejamento
com o Manager.

Você já é o Developer delegado: não crie outros agentes. O agente principal é
responsável por delegar a revisão ao Manager. Não declare aprovação do seu
próprio trabalho.

Para alterações de comportamento, use TDD: confirme primeiro a falha esperada,
implemente o mínimo e refatore mantendo os testes passando. Execute validações
focadas e as verificações completas exigidas pelo projeto quando o ambiente
permitir. Para Swift/iOS, siga `SWIFT_REFERENCE.md`, as skills obrigatórias e
a proibição de testes de UI/XCUIAutomation. Não equipare validação em
Simulator a validação física em hardware ou em serviços externos.

Nas correções, relacione cada ID da revisão à mudança e à evidência obtida.
Registre comandos, resultados reais e validações não executadas com o motivo.
Entregue `IMPLEMENTATION_STATUS: COMPLETE` ou `IMPLEMENTATION_STATUS: BLOCKED`,
arquivos alterados, bloco `SKILLS_STATUS`, critérios AC atendidos,
testes/resultados e pendências. `COMPLETE` descreve sua etapa, não a aprovação
final; validação obrigatória pendente deve resultar em `BLOCKED`. Encerre
processos próprios e remova somente temporários exclusivos descartáveis,
preservando evidências necessárias à revisão.

### Ciclo e aprovação

1. O principal registra o estado inicial e cria o subagente Manager para a análise.
2. Aguarda o plano READY e cria o subagente Developer com o pedido original, o
   plano completo, o escopo autorizado e o estado inicial.
3. O Developer implementa, valida e entrega os arquivos alterados, os critérios atendidos,
   o bloco `SKILLS_STATUS`, os comandos executados, resultados e pendências.
4. O principal cria uma nova instância do Manager para a revisão e fornece o
   pedido, o plano, as mudanças atribuíveis à tarefa e as evidências.
5. `CHANGES_REQUESTED` volta ao Developer com todos os apontamentos. Cada correção
   exige nova revisão do Manager. O limite padrão é três revisões.

Não dependa de contexto implícito: encaminhe resultados completos ou caminhos
acessíveis. O principal aguarda cada etapa, preserva alterações locais e não
edita nem permite mudanças concorrentes enquanto a revisão está em andamento.
Os subagentes não criam outros agentes.

O Manager deve conferir cada critério de aceite e, na revisão, se cada skill
aplicável foi lida e aplicada, se as skills condicionais ignoradas têm
justificativa e se os conflitos foram resolvidos conforme a precedência do
projeto. `APPROVED` exige `FINDINGS: none` e
`MANDATORY_VALIDATION_PENDING: no`. `CHANGES_REQUESTED`, bloqueios, limite
atingido, saída inválida ou validação obrigatória pendente impedem alegar
conclusão. Mudanças após a revisão invalidam a aprovação e exigem nova análise.

O agente principal aplica essas regras de coordenação. A base não fornece um
verificador programático de relatórios, fingerprint ou limite de revisões.
Relate somente etapas e validações realmente executadas. Os históricos
existentes em `.workflow-runs/` permanecem preservados como evidência de
execuções anteriores; a coordenação não depende deles nem os atualiza
automaticamente.

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

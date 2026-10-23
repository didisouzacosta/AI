# Orquestrador compartilhado de subagentes

## Papéis e criação dos subagentes

O ciclo usa dois papéis conceituais, executados por subagentes que o agente
principal cria com o mecanismo nativo da ferramenta em uso (por exemplo, Codex
ou Claude Code):

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

Ao criar cada subagente, o principal identifica o papel no nome ou na descrição
da delegação e entrega as instruções do papel definidas abaixo, transcritas ou
pelo caminho desta seção, para que o subagente as leia antes de começar. Quando
a ferramenta permitir, aplique a restrição de somente leitura do Manager pelas
permissões do subagente, por exemplo com um tipo de agente sem ferramentas de
edição ou um sandbox somente leitura; caso contrário, a restrição vale pelas
instruções do papel. Manager e Developer são subagentes distintos, e cada
revisão usa uma nova instância do Manager.

O agente principal deve iniciar a delegação para tarefas que alterem
comportamento. Se a ferramenta não permitir criar subagentes, informe a
limitação; não simule os papéis em um único agente nem afirme que o ciclo foi
executado. Não substitua subagentes por tarefas independentes.

## Planejamento e passagem de contexto

O Manager lê o pedido original, as instruções do projeto consumidor,
`.ai/PROJECT_BRIEF.md`, `.ai/PROJECT_GUIDE.md` e as referências
relevantes disponíveis no projeto. Esses dois arquivos são derivados dos
templates desta base e permanecem locais ao projeto consumidor; eles não fazem
parte deste repositório-base. Para tarefas executadas somente nesta base,
consulte o pedido, `AGENTS.md` e os templates aplicáveis. Para Swift, cumpra
`.ai/SWIFT_REFERENCE.md` e as skills obrigatórias antes do trabalho
correspondente.

O plano deve ser autocontido e incluir:

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
`PLAN_STATUS: READY` somente quando o Developer puder executar o plano com segurança.
Ambiguidades impeditivas resultam em `PLAN_STATUS: BLOCKED`, com a informação
ou autorização necessária. Não omita um bloqueio para avançar à implementação.

Para tarefas Swift/SwiftUI, use a matriz e a ordem de aplicação de
`.ai/SWIFT_REFERENCE.md`. Skills não são executadas automaticamente apenas por
estarem disponíveis: o Manager deve selecionar as aplicáveis pelo escopo,
entregar seus caminhos e ordem ao Developer, e justificar cada skill
condicional não utilizada. Regras específicas do projeto prevalecem sobre
orientações genéricas das skills; conflitos devem ser registrados no plano.

## Instruções do papel Manager

Você é o subagente no papel conceitual Manager, responsável pelo planejamento e
pela revisão. O agente principal informa o papel em cada delegação e coordena o
ciclo Manager -> Developer -> Manager. Trabalhe somente em leitura: não
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

## Instruções do papel Developer

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

## Ciclo e aprovação

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
acessíveis. O principal aguarda cada etapa, preserva alterações locais e evita
mudanças concorrentes durante a revisão. Os subagentes não criam outros agentes.

O Manager deve conferir cada critério de aceite. Cada apontamento inclui ID,
prioridade, arquivo/linha, evidência, impacto, correção esperada e validação.
`APPROVED` exige `FINDINGS: none` e `MANDATORY_VALIDATION_PENDING: no`.
Bloqueios, limite atingido ou validação obrigatória pendente impedem alegar
conclusão. Mudanças após a revisão invalidam a aprovação e exigem nova análise.
Na revisão, o Manager também deve conferir se cada skill aplicável foi lida e
aplicada, se as skills condicionais ignoradas têm justificativa e se os conflitos
foram resolvidos conforme a precedência do projeto.

O agente principal aplica essas regras de coordenação. A base não fornece um
verificador programático de relatórios, fingerprint ou limite de revisões.
Relate somente etapas e validações realmente executadas.

## Compartilhamento e históricos

Nos projetos consumidores, prefira adicionar esta base como submodule em
`.ai/shared` e criar links para `AGENTS.md`, o orquestrador e a referência Swift.
O bootstrap copia as skills para `.agents/skills/` e as expõe ao Claude Code
por `.claude/skills/`; a base não distribui definições de agentes.
`PROJECT_BRIEF.md` e `PROJECT_GUIDE.md` contêm contexto próprio de cada
projeto, permanecem locais e jamais devem ser substituídos durante uma
atualização da dependência. Não substitua arquivos existentes por links sem
conferir o alvo e o conteúdo; o script `scripts/setup-consumer.sh` faz essa
instalação de forma idempotente e preserva arquivos locais existentes.

Versões anteriores distribuíam `.codex/agents/sol.toml` e
`.codex/agents/luna.toml`. O `ai-update` remove essas cópias quando estão
intactas, preserva com aviso as que têm edições locais e avisa quando
`.ai/PROJECT_GUIDE.md` ou `.ai/PROJECT_BRIEF.md` ainda citam esses agentes, sem
alterar esses documentos.

Os históricos existentes em `.workflow-runs/` permanecem preservados como
evidência de execuções anteriores. A coordenação não depende deles nem os
atualiza automaticamente. Remova somente temporários exclusivos descartáveis,
conforme as regras de limpeza de `AGENTS.md`.

Execute `ai-bootstrap` para criar a configuração local. Execute `ai-update`
para sincronizar uma nova versão da base depois de revisar o manifesto.

Referência: [subagentes do Codex](https://learn.chatgpt.com/docs/agent-configuration/subagents).

# Orquestrador compartilhado de subagentes

## Configuração nativa

O agente principal deve usar os agentes personalizados nativos do Codex:

| Papel conceitual | Identificador de despacho (`name`) | Fonte versionada | Link global | Responsabilidade |
| --- | --- | --- | --- | --- |
| `Manager` | `ai_manager` | `ai/agents/ai_manager.toml` | `~/.codex/agents/ai_manager.toml` | Planejamento e revisão, somente leitura |
| `Developer` | `ai_developer` | `ai/agents/ai_developer.toml` | `~/.codex/agents/ai_developer.toml` | Implementação e validação |

Os identificadores técnicos usados para iniciar os agentes são `ai_manager` e
`ai_developer`; `Manager` e `Developer` continuam sendo os papéis conceituais
do fluxo. O campo `name` dos TOML é a identidade definitiva. Edite as fontes
versionadas e preserve os links globais quando a instalação local os utilizar.

`scripts/install-agents.sh` instala ou atualiza os links. Conflitos nos nomes
novos são preservados em diretórios exclusivos fora de `agents/`. Os links
legados `Manager.toml` e `Developer.toml` só são arquivados quando o destino
normalizado corresponde à fonte antiga desta mesma cópia da base; arquivos e
links de terceiros permanecem intactos.

Antes de aceitar uma delegação, confira se o modelo e o esforço de raciocínio
observáveis no runtime correspondem aos valores do TOML selecionado. Se houver
divergência observável, bloqueie a etapa e informe o principal. Se a ferramenta
não expuser modelo ou esforço, declare essa limitação e não afirme que o
carregamento foi verificado. Os valores não devem ser passados como override no
despacho: a fonte versionada do agente define modelo e esforço.

O agente principal deve iniciar a delegação para tarefas que alterem comportamento,
usando explicitamente `ai_manager` e `ai_developer` conforme o papel. A instalação
dos TOML disponibiliza os agentes; a coordenação depende das
instruções e das ferramentas da sessão. Se a ferramenta não expuser os agentes,
informe a limitação. Reinicie a sessão após instalar ou atualizar as definições
para verificar sua descoberta. Não substitua subagentes por tarefas independentes.

## Planejamento e passagem de contexto

O Manager lê o pedido original, as instruções do projeto consumidor,
`ai/PROJECT_BRIEF.md`, `ai/PROJECT_GUIDE.md` e as referências
relevantes disponíveis no projeto. Esses dois arquivos são derivados dos
templates desta base e permanecem locais ao projeto consumidor; eles não fazem
parte deste repositório-base. Para tarefas executadas somente nesta base,
consulte o pedido, `AGENTS.md` e os templates aplicáveis. Para Swift, cumpra
`ai/SWIFT_REFERENCE.md` e as skills obrigatórias antes do trabalho
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
`ai/SWIFT_REFERENCE.md`. Skills não são executadas automaticamente apenas por
estarem disponíveis: o Manager deve selecionar as aplicáveis pelo escopo,
entregar seus caminhos e ordem ao Developer, e justificar cada skill
condicional não utilizada. Regras específicas do projeto prevalecem sobre
orientações genéricas das skills; conflitos devem ser registrados no plano.

## Ciclo e aprovação

1. O principal registra o estado inicial e delega a análise a `ai_manager`.
2. Aguarda o plano READY e entrega a `ai_developer` o pedido original, o plano completo,
   o escopo autorizado e o estado inicial.
3. O Developer implementa, valida e entrega os arquivos alterados, os critérios atendidos,
   o bloco `SKILLS_STATUS`, os comandos executados, resultados e pendências.
4. O principal cria uma nova sessão de `ai_manager` no papel de Reviewer e fornece o pedido,
   plano, mudanças atribuíveis à tarefa e evidências.
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

O agente principal aplica essas regras de coordenação. As configurações não fornecem
um verificador programático de relatórios, fingerprint ou limite de revisões.
Relate somente etapas e validações realmente executadas.

## Compartilhamento e históricos

Mantenha os seguintes links globais para a raiz compartilhada existente:

| Link | Alvo relativo à raiz compartilhada |
| --- | --- |
| `~/.codex/AGENTS.md` | `AGENTS.md` |
| `~/.codex/ai` | `ai/` |
| `~/.codex/CODEX_ORCHESTRATOR.md` | `ai/CODEX_ORCHESTRATOR.md` |
| `~/.codex/agents/ai_manager.toml` | `ai/agents/ai_manager.toml` |
| `~/.codex/agents/ai_developer.toml` | `ai/agents/ai_developer.toml` |

Nos projetos consumidores, prefira adicionar esta base como submodule em
`ai/shared` e criar links para `AGENTS.md`, o orquestrador, a referência Swift,
as definições de agentes e as skills compartilhadas. `PROJECT_BRIEF.md` e
`PROJECT_GUIDE.md` contêm contexto próprio de cada projeto, permanecem locais e
jamais devem ser substituídos durante uma atualização da dependência. Não
substitua arquivos existentes por links sem conferir o alvo e o conteúdo; o
script `scripts/setup-consumer.sh` faz essa instalação de forma idempotente e
preserva arquivos locais existentes.

Os históricos existentes em `.workflow-runs/` permanecem preservados como
evidência de execuções anteriores. A configuração nativa não depende deles nem
os atualiza automaticamente. Remova somente temporários exclusivos descartáveis,
conforme as regras de limpeza de `AGENTS.md`.

Instale os agentes com `scripts/install-agents.sh` ou por meio de `ai-bootstrap`,
que chama esse instalador somente depois de configurar o projeto consumidor.

Referência: [agentes personalizados do Codex](https://learn.chatgpt.com/docs/agent-configuration/subagents).

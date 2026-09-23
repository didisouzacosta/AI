# Orquestrador compartilhado de subagentes

## Configuração nativa

O agente principal deve usar os agentes personalizados nativos do Codex:

| Papel conceitual | Identificador de despacho (`name`) | Fonte versionada | Cópia no consumidor | Responsabilidade |
| --- | --- | --- | --- | --- |
| `Manager` | `sol` | `.codex/agents/sol.toml` | `.codex/agents/sol.toml` | Planejamento e revisão, somente leitura |
| `Developer` | `luna` | `.codex/agents/luna.toml` | `.codex/agents/luna.toml` | Implementação e validação |

Os identificadores técnicos usados para iniciar os agentes são `sol` e
`luna`; `Manager` e `Developer` continuam sendo os papéis conceituais
do fluxo. O campo `name` dos TOML é a identidade definitiva. O bootstrap copia
as fontes ao projeto consumidor e nunca instala agentes globais.

`ai-bootstrap` instala ou atualiza cópias regulares byte a byte idênticas dos
dois TOML canônicos em `.codex/agents/`, junto com as skills em
`.agents/skills/`. O manifesto local protege arquivos gerenciados contra
sobrescrita; arquivos extras do projeto permanecem intactos.

Antes de aceitar uma delegação, confira se o modelo e o esforço de raciocínio
observáveis no runtime correspondem aos valores do TOML selecionado. Se houver
divergência observável, bloqueie a etapa e informe o principal. Se a ferramenta
não expuser modelo ou esforço, declare essa limitação e não afirme que o
carregamento foi verificado. Os valores não devem ser passados como override no
despacho: a fonte versionada do agente define modelo e esforço.

O agente principal deve iniciar a delegação para tarefas que alterem comportamento,
usando explicitamente `sol` e `luna` conforme o papel. A instalação
dos TOML disponibiliza os agentes; a coordenação depende das
instruções e das ferramentas da sessão. Se a ferramenta não expuser os agentes,
informe a limitação. Reinicie a sessão após instalar ou atualizar as definições
para verificar sua descoberta. Não substitua subagentes por tarefas independentes.

## Planejamento e passagem de contexto

O Manager lê o pedido original, as instruções do projeto consumidor,
`.ia/PROJECT_BRIEF.md`, `.ia/PROJECT_GUIDE.md` e as referências
relevantes disponíveis no projeto. Esses dois arquivos são derivados dos
templates desta base e permanecem locais ao projeto consumidor; eles não fazem
parte deste repositório-base. Para tarefas executadas somente nesta base,
consulte o pedido, `AGENTS.md` e os templates aplicáveis. Para Swift, cumpra
`.ia/SWIFT_REFERENCE.md` e as skills obrigatórias antes do trabalho
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
`.ia/SWIFT_REFERENCE.md`. Skills não são executadas automaticamente apenas por
estarem disponíveis: o Manager deve selecionar as aplicáveis pelo escopo,
entregar seus caminhos e ordem ao Developer, e justificar cada skill
condicional não utilizada. Regras específicas do projeto prevalecem sobre
orientações genéricas das skills; conflitos devem ser registrados no plano.

## Ciclo e aprovação

1. O principal registra o estado inicial e delega a análise a `sol`.
2. Aguarda o plano READY e entrega a `luna` o pedido original, o plano completo,
   o escopo autorizado e o estado inicial.
3. O Developer implementa, valida e entrega os arquivos alterados, os critérios atendidos,
   o bloco `SKILLS_STATUS`, os comandos executados, resultados e pendências.
4. O principal cria uma nova sessão de `sol` no papel de Reviewer e fornece o pedido,
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

Nos projetos consumidores, prefira adicionar esta base como submodule em
`.ia/shared` e criar links para `AGENTS.md`, o orquestrador e a referência Swift.
O bootstrap copia as definições de agentes e as skills para os diretórios locais
reconhecidos pelo Codex. `PROJECT_BRIEF.md` e
`PROJECT_GUIDE.md` contêm contexto próprio de cada projeto, permanecem locais e
jamais devem ser substituídos durante uma atualização da dependência. Não
substitua arquivos existentes por links sem conferir o alvo e o conteúdo; o
script `scripts/setup-consumer.sh` faz essa instalação de forma idempotente e
preserva arquivos locais existentes.

Os históricos existentes em `.workflow-runs/` permanecem preservados como
evidência de execuções anteriores. A configuração nativa não depende deles nem
os atualiza automaticamente. Remova somente temporários exclusivos descartáveis,
conforme as regras de limpeza de `AGENTS.md`.

Execute `ai-bootstrap` para criar a configuração local. Execute `ai-update`
para sincronizar uma nova versão da base depois de revisar o manifesto.

Referência: [agentes personalizados do Codex](https://learn.chatgpt.com/docs/agent-configuration/subagents).

# Orquestrador compartilhado de subagentes

## Configuração nativa

O agente principal deve usar os agentes personalizados nativos do Codex:

| Papel | Definição global (link simbólico) | Responsabilidade |
| --- | --- | --- |
| `Manager` | `~/.codex/agents/Manager.toml` | Planejamento e revisão, somente leitura |
| `Developer` | `~/.codex/agents/Developer.toml` | Implementação e validação |

As fontes técnicas são `ai/agents/Manager.toml` e `ai/agents/Developer.toml` na cópia
local desta base. Edite as fontes versionadas e preserve os links globais quando
a instalação local os utilizar. Os nomes dos arquivos são detalhes internos;
o contrato operacional usa os papéis `Manager` e `Developer`.

O agente principal deve iniciar a delegação para tarefas que alterem comportamento.
A instalação dos TOML disponibiliza os agentes; a coordenação depende das
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
- skills necessárias, caminhos e ordem de leitura e aplicação;
- sequência de implementação, estratégia TDD e comandos de validação;
- riscos, regressões, segurança, concorrência e cancelamento;
- critérios AC1, AC2 etc., associados aos requisitos, resultados e validações.

Não introduza dependências de terceiros sem aprovação explícita. Marque
`PLAN_STATUS: READY` somente quando o Developer puder executar o plano com segurança.
Ambiguidades impeditivas resultam em `PLAN_STATUS: BLOCKED`, com a informação
ou autorização necessária. Não omita um bloqueio para avançar à implementação.

## Ciclo e aprovação

1. O principal registra o estado inicial e delega a análise ao Manager.
2. Aguarda o plano READY e entrega ao Developer o pedido original, o plano completo,
   o escopo autorizado e o estado inicial.
3. O Developer implementa, valida e entrega os arquivos alterados, os critérios atendidos,
   os comandos executados, resultados e pendências.
4. O principal cria uma nova sessão do Manager como Reviewer e fornece o pedido,
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
| `~/.codex/agents/Manager.toml` | `ai/agents/Manager.toml` |
| `~/.codex/agents/Developer.toml` | `ai/agents/Developer.toml` |

Nos projetos consumidores, preserve os links ou cópias controladas para as
instruções, o orquestrador, a referência Swift, os templates e as skills
compartilhadas. `PROJECT_BRIEF.md` e `PROJECT_GUIDE.md` contêm contexto próprio
de cada projeto e permanecem locais. Não substitua arquivos existentes por
links sem conferir o alvo e o conteúdo.

Os históricos existentes em `.workflow-runs/` permanecem preservados como
evidência de execuções anteriores. A configuração nativa não depende deles nem
os atualiza automaticamente. Remova somente temporários exclusivos descartáveis,
conforme as regras de limpeza de `AGENTS.md`.

Referência: [agentes personalizados do Codex](https://learn.chatgpt.com/docs/agent-configuration/subagents).

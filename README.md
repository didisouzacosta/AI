# AI — base compartilhada para projetos Apple

Esta base fornece regras de engenharia, a orquestração de subagentes Manager e
Developer por nível de risco e skills para projetos Swift.

## Estrutura

```text
AI/
├── AGENTS.md
├── .ai/                         # referências e templates compartilhados
├── .agents/skills/              # sete skills completas
├── .swiftlint.yml               # baseline SwiftLint
├── .swiftformat                 # SwiftFormat: formatador único
├── scripts/lint-swift.sh        # gate estrito local/CI (--fix formata)
├── scripts/fix-swift-spacing.pl # corrige o espaçamento entre blocos
├── scripts/add-type-marks.py    # rascunha os MARKs obrigatórios
├── scripts/install-swift-tools.sh # baixa SwiftLint/SwiftFormat fixos para o cache por usuário
├── scripts/consumer-next-steps.txt # passos impressos por bootstrap/update
└── .github/workflows/ai-base-checks.yml
```

## Configurar um consumidor

Instale os comandos uma vez a partir desta base:

```bash
bash scripts/install-bootstrap.sh
```

Na raiz Git de um projeto consumidor, execute:

```bash
ai-bootstrap
```

O comando cria a seguinte estrutura:

```text
MeuProjeto/
├── AGENTS.md -> .ai/shared/AGENTS.md
├── .ai/
│   ├── shared/                  # submodule desta base
│   ├── PROJECT_BRIEF.md
│   ├── PROJECT_GUIDE.md
│   ├── SWIFT_REFERENCE.md -> shared/.ai/SWIFT_REFERENCE.md
│   └── managed-files.sha256
├── .agents/skills/              # cópias locais das skills compartilhadas
├── .claude/skills/<skill> -> ../../.agents/skills/<skill>  # mesmas skills no Claude Code
├── CLAUDE.md                    # criado só se ausente: importa @AGENTS.md
├── .swiftlint.yml
├── .swiftformat
├── scripts/lint-swift.sh
├── scripts/fix-swift-spacing.pl
├── scripts/add-type-marks.py
└── scripts/install-swift-tools.sh
```

Preencha somente `.ai/PROJECT_BRIEF.md` e `.ai/PROJECT_GUIDE.md`, execute
`scripts/lint-swift.sh` localmente e conecte-o como gate obrigatório do CI
(por exemplo, no `ci_scripts/ci_post_clone.sh` do Xcode Cloud).
Depois registre o submodule, os links e as cópias locais no Git. O bootstrap preserva o README
do consumidor e cria os dois documentos apenas quando estiverem ausentes.

Se já houver `AGENTS.md`, ele é salvo como `AGENTS_backup.md`. O comando para
antes de modificar o projeto se esse backup já existir ou se houver
`AGENTS.override.md`.

## Atualizar

```bash
ai-update
```

O update avança `.ai/shared` para `main`, verifica o manifesto
`.ai/managed-files.sha256` e sincroniza skills, configurações de lint
e formatter e scripts do gate. O gate cobre fontes, testes e
`Package.swift` dos caminhos do consumidor sem percorrer caches ou submodules.
Uma edição local de arquivo gerenciado interrompe a atualização; arquivos extras permanecem intactos.
A base não distribui mais `.github/workflows/swift-lint.yml` nem os agentes
fixos `.codex/agents/sol.toml` e `.codex/agents/luna.toml`: o update remove a
cópia intacta, retira do manifesto a que o consumidor já apagou e preserva, com
aviso, a que tiver edições locais. Registre as remoções no Git do consumidor.
Como `.ai/PROJECT_GUIDE.md` e `.ai/PROJECT_BRIEF.md` nunca são reescritos, o
update apenas avisa, com as linhas, quando eles ainda citam `sol`, `luna` ou os
TOML; `AGENTS.md` declara essas referências obsoletas.
O orquestrador `.ai/CODEX_ORCHESTRATOR.md` também deixou de existir: o
contrato dos subagentes faz parte do `AGENTS.md`. O update remove o link
`.ai/CODEX_ORCHESTRATOR.md -> shared/.ai/CODEX_ORCHESTRATOR.md` criado por
versões anteriores, preserva um arquivo local com esse nome e avisa, com as
linhas, quando os documentos do projeto ainda citam o arquivo.

Se o consumidor já tinha `.swiftlint.yml`, `.swiftformat` ou scripts de lint
próprios fora do manifesto, o update para com conflito. Para adotar a
configuração compartilhada uma única vez, com backup `<arquivo>.local-backup`:

```bash
ai-update --adopt-lint-config
```

`ai-bootstrap` aceita a mesma flag. Ao final, os dois comandos imprimem os passos de
adoção: instalar as ferramentas, `scripts/lint-swift.sh --fix`,
`scripts/lint-swift.sh --add-marks`, verificar e integrar ao CI/Xcode.

Os comandos `ai-bootstrap` e `ai-update` executam os scripts desta pasta
local, mas o conteúdo vem de `main`. Antes de rodar, eles fazem `git pull
--ff-only` nesta base e, se ela mudou, reexecutam com os scripts novos. O pull
é ignorado, com aviso, quando a base tem alterações locais, está fora de
`main` ou a rede falha; defina `AI_SKIP_SELF_UPDATE=1` para desativá-lo. Mesmo
sem o pull, um `setup-consumer.sh` desatualizado é substituído pelo de `main`
antes de qualquer alteração no consumidor.

As skills de `.agents/skills/` seguem o padrão aberto Agent Skills e são
lidas também pelo Claude Code: o setup cria `.claude/skills/<skill>` como
symlink para a mesma pasta, sem duplicar arquivos, e remove links de skills
que deixaram de existir. Entradas locais com o mesmo nome e um `CLAUDE.md`
existente são preservados; para usar as regras no Claude Code, o `CLAUDE.md`
deve importar `@AGENTS.md`. Nenhum comando instala agentes, locais ou globais
(`~/.codex/agents`, `CODEX_CONFIG_DIR`).

## Subagentes

Toda alteração segue os níveis de execução descritos em `AGENTS.md`. O agente
principal classifica a tarefa: mudanças sem efeito no comportamento (nível 0)
ele faz sozinho; alterações localizadas (nível 1) vão para um subagente no
papel Developer e passam pela revisão de um subagente no papel Manager; tarefas
de maior risco (nível 2) seguem o ciclo completo, em que o Manager planeja em
modo somente leitura, o Developer implementa e valida e o Manager revisa até
`APPROVED`. Só apontamentos `BLOCKING` impedem a aprovação, e as re-revisões
conferem apenas as correções. A base não fixa agentes, nomes nem
modelos: o agente principal cria os subagentes com o mecanismo nativo da
ferramenta (Codex, Claude Code ou outra), escolhe tipo, modelo e esforço
conforme a tarefa e pode criar subagentes auxiliares quando precisar. As
instruções de cada papel ficam na seção de orquestração do `AGENTS.md`.

Referências: [subagentes do Codex](https://learn.chatgpt.com/docs/agent-configuration/subagents),
[skills](https://learn.chatgpt.com/docs/build-skills) e
[AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

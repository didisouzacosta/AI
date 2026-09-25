# AI — base compartilhada para projetos Apple

Esta base fornece regras de engenharia, agentes e skills para projetos Swift.

## Estrutura

```text
AI/
├── AGENTS.md
├── .ai/                         # referências e templates compartilhados
├── .codex/agents/               # sol.toml e luna.toml
├── .agents/skills/              # sete skills completas
├── .swiftlint.yml               # baseline SwiftLint
├── .swiftformat                 # SwiftFormat: formatador único
├── scripts/lint-swift.sh        # gate estrito local/CI (--fix formata)
├── scripts/fix-swift-spacing.pl # corrige o espaçamento entre blocos
├── scripts/add-type-marks.py    # rascunha os MARKs obrigatórios
├── scripts/install-swift-tools.sh # baixa SwiftLint/SwiftFormat nas versões fixas
├── scripts/consumer-next-steps.txt # passos impressos por bootstrap/update
├── templates/swift-lint.yml     # workflow instalado nos consumidores
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
│   ├── CODEX_ORCHESTRATOR.md -> shared/.ai/CODEX_ORCHESTRATOR.md
│   ├── SWIFT_REFERENCE.md -> shared/.ai/SWIFT_REFERENCE.md
│   └── managed-files.sha256
├── .codex/agents/               # cópias locais de sol.toml e luna.toml
├── .agents/skills/              # cópias locais das skills compartilhadas
├── .claude/skills/<skill> -> ../../.agents/skills/<skill>  # mesmas skills no Claude Code
├── CLAUDE.md                    # criado só se ausente: importa @AGENTS.md
├── .swiftlint.yml
├── .swiftformat
├── scripts/lint-swift.sh
├── scripts/fix-swift-spacing.pl
├── scripts/add-type-marks.py
├── scripts/install-swift-tools.sh
└── .github/workflows/swift-lint.yml
```

Preencha somente `.ai/PROJECT_BRIEF.md` e `.ai/PROJECT_GUIDE.md`, execute
`scripts/lint-swift.sh` localmente e conecte-o como gate obrigatório do CI.
Depois registre o submodule, os links e as cópias locais no Git. O bootstrap preserva o README
do consumidor e cria os dois documentos apenas quando estiverem ausentes.

Se já houver `AGENTS.md`, ele é salvo como `AGENTS_backup.md`. O comando para
antes de modificar o projeto se esse backup já existir, se houver
`AGENTS.override.md` ou se o caminho legado `ai` estiver presente.

## Atualizar

```bash
ai-update
```

O update avança `.ai/shared` para `main`, verifica o manifesto
`.ai/managed-files.sha256` e sincroniza agentes, skills, configurações de lint
e formatter, scripts do gate e o workflow Swift. O gate cobre fontes, testes e
`Package.swift` dos caminhos do consumidor sem percorrer caches ou submodules.
Uma edição local de arquivo gerenciado interrompe a atualização; arquivos extras permanecem intactos.

Se o consumidor já tinha `.swiftlint.yml`, `.swiftformat` ou scripts de lint
próprios fora do manifesto, o update para com conflito. Para adotar a
configuração compartilhada uma única vez, com backup `<arquivo>.local-backup`:

```bash
ai-update --adopt-lint-config
```

`ai-bootstrap` aceita a mesma flag. Um `.swift-format` legado é movido para
`.swift-format.local-backup`. Ao final, os dois comandos imprimem os passos de
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
deve importar `@AGENTS.md`. Nenhum comando escreve em
`~/.codex/agents` ou respeita `CODEX_CONFIG_DIR` para instalar agentes globais.

Os nomes de despacho são `sol` (Manager, `gpt-6-sol` com esforço `high`) e
`luna` (Developer, `gpt-6-luna` com esforço `high`). Reinicie a sessão Codex
após adicionar ou atualizar as definições do projeto para verificar a descoberta.

Referências: [agentes personalizados](https://learn.chatgpt.com/docs/agent-configuration/subagents),
[skills](https://learn.chatgpt.com/docs/build-skills) e
[AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

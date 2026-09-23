# AI — base compartilhada para projetos Apple

Esta base fornece regras de engenharia, agentes e skills para projetos Swift.

## Estrutura

```text
AI/
├── AGENTS.md
├── .ia/                         # referências e templates compartilhados
├── .codex/agents/               # sol.toml e luna.toml
└── .agents/skills/              # sete skills completas
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
├── AGENTS.md -> .ia/shared/AGENTS.md
├── .ia/
│   ├── shared/                  # submodule desta base
│   ├── PROJECT_BRIEF.md
│   ├── PROJECT_GUIDE.md
│   ├── CODEX_ORCHESTRATOR.md -> shared/.ia/CODEX_ORCHESTRATOR.md
│   ├── SWIFT_REFERENCE.md -> shared/.ia/SWIFT_REFERENCE.md
│   └── managed-files.sha256
├── .codex/agents/               # cópias locais de sol.toml e luna.toml
└── .agents/skills/              # cópias locais das skills compartilhadas
```

Preencha somente `.ia/PROJECT_BRIEF.md` e `.ia/PROJECT_GUIDE.md`, depois registre
o submodule, os links e as cópias locais no Git. O bootstrap preserva o README
do consumidor e cria os dois documentos apenas quando estiverem ausentes.

Se já houver `AGENTS.md`, ele é salvo como `AGENTS_backup.md`. O comando para
antes de modificar o projeto se esse backup já existir, se houver
`AGENTS.override.md` ou se o caminho legado `ai` estiver presente.

## Atualizar

```bash
ai-update
```

O update avança `.ia/shared` para `main`, verifica o manifesto
`.ia/managed-files.sha256` e sincroniza somente `sol.toml`, `luna.toml` e os
arquivos das sete skills. Uma edição local de arquivo gerenciado interrompe a
atualização; arquivos extras permanecem intactos. Nenhum comando escreve em
`~/.codex/agents` ou respeita `CODEX_CONFIG_DIR` para instalar agentes globais.

Os nomes de despacho são `sol` (Manager, `gpt-6-sol` com esforço `high`) e
`luna` (Developer, `gpt-6-luna` com esforço `high`). Reinicie a sessão Codex
após adicionar ou atualizar as definições do projeto para verificar a descoberta.

Referências: [agentes personalizados](https://learn.chatgpt.com/docs/agent-configuration/subagents),
[skills](https://learn.chatgpt.com/docs/build-skills) e
[AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

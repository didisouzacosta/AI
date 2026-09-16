# AI — base compartilhada de organização para projetos Apple

Este repositório é uma base compartilhada de governança para projetos iOS e
macOS com Swift e SwiftUI. Ele não é um aplicativo, não contém um produto
Apple específico e não deve receber `PROJECT_BRIEF.md` ou `PROJECT_GUIDE.md`
preenchidos de um projeto consumidor.

## Organização da base

```text
AI/
├── AGENTS.md
├── README.md
└── ai/
    ├── CODEX_ORCHESTRATOR.md
    ├── SWIFT_REFERENCE.md
    ├── PROJECT_BRIEF.template.md
    ├── PROJECT_GUIDE.template.md
    ├── agents/
    │   ├── Manager.toml
    │   └── Developer.toml
    └── skills/
        ├── README.md
        └── <skills compartilhadas>
```

As responsabilidades são separadas assim:

- `AGENTS.md`: contrato geral de engenharia e validação.
- `ai/CODEX_ORCHESTRATOR.md`: ciclo operacional Manager → Developer → Manager.
- `ai/SWIFT_REFERENCE.md`: organização e semântica de Swift/SwiftUI.
- `ai/agents/`: definições dos agentes compartilhados.
- `ai/skills/`: cópias versionáveis das skills usadas pelo contrato.
- `ai/*.template.md`: modelos de contexto que cada projeto consumidor deve
  preencher localmente.

## Uso em um projeto consumidor

O projeto consumidor mantém seu próprio código, contexto e decisões de
produto. A base compartilhada fornece as regras e os modelos:

```text
MeuProjeto/
├── AGENTS.md -> ai/shared/AGENTS.md
├── ai/
│   ├── shared/              # submodule desta base
│   ├── PROJECT_BRIEF.md
│   ├── PROJECT_GUIDE.md
│   ├── CODEX_ORCHESTRATOR.md -> shared/ai/CODEX_ORCHESTRATOR.md
│   ├── SWIFT_REFERENCE.md -> shared/ai/SWIFT_REFERENCE.md
│   ├── agents/ -> shared/ai/agents
│   └── skills/ -> shared/ai/skills
├── Resources/
├── Sources/
└── Tests/
```

O projeto consumidor deve adicionar esta base como um submodule em `ai/shared`.
Isso registra no Git o commit exato da base usada por cada projeto e permite
atualizações controladas:

```bash
git submodule add -b main https://github.com/didisouzacosta/AI.git ai/shared
bash ai/shared/scripts/setup-consumer.sh
```

Para configurar também os subagents `Manager` e `Developer` no Codex em uma
única operação, execute a partir de uma cópia desta base:

```bash
bash scripts/bootstrap-consumer.sh /caminho/para/MeuProjeto
```

O bootstrap cria links dos subagents para esta cópia versionada da base. Assim,
não é necessário copiar manualmente os arquivos para `~/.codex/agents`.

Para não informar o caminho da base AI em cada execução, instale o comando uma
única vez a partir desta pasta:

```bash
bash scripts/install-bootstrap.sh
```

O instalador cria `~/.local/bin` quando necessário e registra esse diretório no
`~/.zprofile` e no `~/.zshrc`, sem duplicar entradas. Depois, dentro de qualquer
projeto consumidor, use somente:

```bash
ai-bootstrap .
```

As novas sessões do zsh encontrarão o comando automaticamente. Para usar na
sessão atual, aplique a linha de `PATH` exibida pelo instalador ou abra um novo
terminal. Ao finalizar a instalação, feche e abra o terminal para carregar a
configuração automaticamente.

Para um projeto que ainda tem cópias antigas dos arquivos compartilhados, faça
uma migração única com backup:

```bash
bash scripts/bootstrap-consumer.sh --migrate-existing /caminho/para/MeuProjeto
```

O backup é criado em `.ai-base-migration-backup/`. Revise-o antes de decidir
se algum conteúdo específico precisa ser incorporado ao projeto.

O script cria os links dos arquivos compartilhados e, na primeira instalação,
cria os documentos locais a partir dos templates:

```bash
cp ai/shared/ai/PROJECT_BRIEF.template.md ai/PROJECT_BRIEF.md
cp ai/shared/ai/PROJECT_GUIDE.template.md ai/PROJECT_GUIDE.md
```

Os comandos acima são apenas a forma manual equivalente. O script nunca
substitui `ai/PROJECT_BRIEF.md` nem `ai/PROJECT_GUIDE.md`: eles permanecem
versionados no projeto consumidor e não fazem parte da atualização da base.

Para atualizar a base compartilhada:

```bash
bash ai/shared/scripts/setup-consumer.sh --update
git add ai/shared
git commit -m "chore: atualiza base compartilhada de IA"
```

O submodule continua apontando para um commit específico, portanto a
atualização só entra no projeto consumidor quando for explicitamente registrada
em commit. Para reproduzir um checkout existente, use:

```bash
git clone --recurse-submodules <url-do-projeto>
```

ou, em um clone já existente:

```bash
git submodule update --init --recursive
```

## Precedência e fontes de verdade

1. Instruções diretas da tarefa.
2. `AGENTS.md` do projeto consumidor e instruções mais específicas da sua
   subárvore.
3. `PROJECT_BRIEF.md` para produto, fluxos, estados e pendências.
4. `PROJECT_GUIDE.md` para baseline, arquitetura, comandos e validação do
   projeto.
5. Referências compartilhadas em `ai/`, incluindo `SWIFT_REFERENCE.md` e o
   orquestrador.
6. Código e configuração existentes para o comportamento efetivamente
   conectado.

Quando houver conflito, o documento mais específico do projeto consumidor
deve declarar explicitamente a exceção e seu escopo.

## Agentes e links compartilhados

Os arquivos em `ai/agents/` são a fonte versionada das definições técnicas dos
subagentes Manager e Developer. O ambiente Codex pode expô-los por links globais em `~/.codex`; esses
links são uma instalação local e não substituem os arquivos versionados deste
repositório.

O remote oficial desta base é:

```text
https://github.com/didisouzacosta/AI.git
```

Este repositório não publica alterações automaticamente. Commit, push e
atualização de projetos consumidores continuam sendo operações explícitas.

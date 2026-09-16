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
produto. A base AI é adicionada como uma dependência Git versionada, enquanto
`PROJECT_BRIEF.md` e `PROJECT_GUIDE.md` permanecem documentos locais do
projeto:

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

O submodule registra o commit exato da base usado por cada projeto e permite
atualizações controladas.

### Instalação única do comando

Execute uma vez, a partir de uma cópia local desta base:

```bash
cd /caminho/para/AI
bash scripts/install-bootstrap.sh
```

O instalador cria `~/.local/bin` quando necessário e instala dois comandos:

- `ai-bootstrap`: configura um projeto consumidor novo ou existente;
- `ai-update`: atualiza a dependência de um projeto já configurado.

Ele também cria links para `Manager.toml` e `Developer.toml` em
`~/.codex/agents`, preservando cópias existentes em backup. O instalador
registra `~/.local/bin` no `~/.zprofile` e no `~/.zshrc` sem duplicar entradas.

Ao terminar, feche e abra o terminal para carregar o novo `PATH`.

### Configuração de um projeto

Dentro da pasta raiz de um projeto Git, execute:

```bash
cd /caminho/para/MeuProjeto
ai-bootstrap
```

O comando usa a pasta atual automaticamente; não é necessário informar `.` nem
o caminho da base AI. Ele adiciona `ai/shared` como submodule e cria os links
dos arquivos compartilhados. Isso funciona mesmo quando o projeto ainda não
possui a estrutura `ai/`.

Também é possível informar outro projeto explicitamente:

```bash
ai-bootstrap /caminho/para/MeuProjeto
```

Para projetos que já possuem cópias antigas dos arquivos compartilhados, faça
uma migração única com backup:

```bash
ai-bootstrap --migrate-existing
```

O backup é criado em `.ai-base-migration-backup/`. Revise-o antes de decidir
se algum conteúdo específico precisa ser incorporado ao projeto.

### Documentos locais do projeto

Na primeira configuração, o bootstrap cria os documentos a partir dos
templates compartilhados:

```bash
ai/PROJECT_BRIEF.md
ai/PROJECT_GUIDE.md
```

Esses arquivos descrevem o produto e a configuração específica do projeto.
Nunca são substituídos por `ai-update`.

### Atualização da dependência

Dentro da pasta do projeto consumidor, execute:

```bash
ai-update
git status
git add ai/shared ai/CODEX_ORCHESTRATOR.md ai/SWIFT_REFERENCE.md
git commit -m "chore: atualiza base compartilhada de IA"
```

O `ai-update` atualiza o submodule para a versão mais recente de `main`, corrige
links compartilhados quebrados e deixa o projeto consumidor pronto para revisão
e commit. A atualização só passa a fazer parte do projeto depois que o novo
ponteiro do submodule é commitado.

Para reproduzir um checkout existente com a dependência, use:

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
subagentes Manager e Developer. O comando `install-bootstrap.sh` cria links
globais em `~/.codex/agents` para esses arquivos, permitindo que o Codex os
encontre sem cópia manual. Esses links são uma instalação local e apontam para
a cópia da base AI usada durante a instalação.

O remote oficial desta base é:

```text
https://github.com/didisouzacosta/AI.git
```

Este repositório não publica alterações automaticamente. Commit, push e
atualização de projetos consumidores continuam sendo operações explícitas.

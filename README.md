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
├── AGENTS.md
├── ai/
│   ├── PROJECT_BRIEF.md
│   ├── PROJECT_GUIDE.md
│   └── <referências compartilhadas ou links para esta base>
├── Resources/
├── Sources/
└── Tests/
```

Depois de obter esta base, copie os templates para o projeto consumidor e
preencha-os com o contexto real do projeto:

```bash
cp ai/PROJECT_BRIEF.template.md /caminho/para/MeuProjeto/ai/PROJECT_BRIEF.md
cp ai/PROJECT_GUIDE.template.md /caminho/para/MeuProjeto/ai/PROJECT_GUIDE.md
```

Os arquivos preenchidos permanecem no projeto consumidor. Não substitua os
templates desta base por decisões específicas de um aplicativo.

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

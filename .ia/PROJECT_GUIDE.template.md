# Guia de arquitetura e desenvolvimento de {{PROJECT_NAME}}

## Escopo e fontes de verdade

{{PROJECT_NAME}} é um produto {{PLATFORM_AND_CATEGORY}}.

As fontes deste checkout são, nesta ordem:

- AGENTS.md — regras de engenharia, coordenação e validação.
- PROJECT_BRIEF.md — produto, fluxos, estados e pendências.
- README.md — requisitos públicos e comandos.
- Código e configuração existentes — comportamento efetivamente conectado.

Não trate um tipo, string, pacote ou serviço sem callsite de produção como uma
feature disponível. Não faça migrações de nomes, pastas ou arquitetura sem
escopo explícito.

## Baseline efetiva

- Plataforma e versão mínima:
- Projeto/workspace:
- Schemes ou targets:
- Linguagem e versão:
- Dependências permitidas:
- Requisitos de hardware:

## Coordenação dos subagentes

Use os papéis definidos no `AGENTS.md` e detalhados no
`.ia/CODEX_ORCHESTRATOR.md`:

- Planejamento: `sol` (papel conceitual Manager), somente leitura.
- Implementação e correções: `luna` (papel conceitual Developer).
- Revisão: `sol` (papel conceitual Manager), somente leitura.

O ciclo é Manager planeja → Developer implementa e valida → Manager revisa →
Developer corrige → Manager revisa novamente até resolver todos os apontamentos.
Os IDs técnicos vêm do campo `name` dos TOML compartilhados. Confira os valores
de modelo e esforço que o runtime expõe contra esses TOML; bloqueie se forem
divergentes e declare a limitação quando a ferramenta não expuser esses dados.

## Arquitetura

Descreva os módulos, fronteiras de responsabilidade, composição de
dependências, navegação, persistência e integrações externas.

- Entrada e composição:
- Domínio:
- Features:
- Infraestrutura:
- Componentes compartilhados:
- Testes:

## Estado, concorrência e efeitos

- Fonte de verdade de cada estado:
- Isolamento de atores e tarefas:
- Cancelamento e invalidação de resultados obsoletos:
- Limites de memória e trabalho pendente:
- Permissões, rede, arquivos e outros efeitos:

## Regras de implementação

- Injete serviços e protocolos nas fronteiras de comportamento.
- Use dublês nos testes e nas previews.
- Preserve cancelamento, isolamento e tratamento de erros.
- Não adicione dependências sem aprovação explícita.
- Mantenha segredos fora do repositório.
- Preserve alterações locais não relacionadas.

## Testes e validação

Registre comandos e resultados reais. Separe compilação e Simulator de
validação em dispositivo físico e de serviços externos.

- Testes unitários:
- Testes de integração:
- Build:
- Simulator:
- Dispositivo físico:
- Serviços live:
- Validações ainda não executadas:

## Entrega

- Checklist de aceitação:
- Arquivos de documentação a atualizar:
- Artefatos temporários a limpar:
- Estado de commit esperado:
- Riscos conhecidos:

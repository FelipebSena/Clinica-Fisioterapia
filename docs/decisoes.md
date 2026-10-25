# Registro de decisões e correções documentais

Data da revisão: 25/10/2026. Responsabilidade: David, documentação e validação. Base analisada: commit `02e1469`.

## Escopo

Esta revisão abrange dicionário, relatórios das duas etapas, decisões, testes, resultados, backup, crescimento e navegação da documentação. Os arquivos `SQL/etapa01.sql`, `SQL/etapa02.sql` e `interface/ClinicaApp.java` permanecem idênticos à base. Não inclui correção da implementação dos colegas nem produção de slides.

## Decisões

| ID | Problema encontrado | Decisão documental | Evidência/motivo |
| --- | --- | --- | --- |
| D01 | README citava três arquivos inexistentes | Indicar etapa01.sql e depois etapa02.sql | Arquivos versionados em SQL/ |
| D02 | Dicionário conceitual não continha todas as colunas físicas | Criar dicionário físico completo, preservando o conceitual no histórico | Catálogo obtido após execução dos dois scripts |
| D03 | Faltava relatório consolidado da etapa 1 | Consolidar escopo, modelagem, regras, carga, consultas e limites | Escopo original e etapa01.sql |
| D04 | Relatório 2 alegava ganhos sem planos ou números anexos | Incluir EXPLAIN real, medições e resultado sem ganho comprovado quando aplicável | evidencias/explain.json |
| D05 | Consulta 1 do relatório não correspondia à consulta 5 atual | Usar o SQL exato do projeto, sem acrescentar filtro de ATIVO | Query 5 usa GEAP/Saúde Caixa e telefone NULL |
| D06 | Supervisão descrita como FK direta para profissional | Documentar referência real a fisioterapeuta | fk_estagiario_supervisor |
| D07 | Documentos afirmavam garantia total da especialização | Separar intenção conceitual de garantia física | Banco permite profissional ainda sem subtipo |
| D08 | Modelo afirmava ausência de atributo calculado | Explicar coluna gerada armazenada e unicidade condicional | id_especialidade_em_andamento |
| D09 | mysqldump associado a diferencial | Descrever backup lógico completo; não implantar rotina | Manual MySQL e ensaio de dump/restauração |
| D10 | Recomendação de particionar sessão | Retirar recomendação incompatível com FKs InnoDB do modelo atual | Manual MySQL de particionamento |
| D11 | Crescimento de 85% sem demonstração | Remover percentual; explicitar fórmulas e hipóteses | Não há fonte quantitativa para 85% no Git |
| D12 | Números de planejamento sem origem explícita | Atribuir cenário ao relatório de Felipe, sem tratá-lo como confirmação operacional | Commit 6525092, de Felipe Romero, em 23/10 |
| D13 | Arquivos PDF não editáveis dificultavam manutenção | Manter fontes Markdown e geração reproduzível de PDF para os relatórios e o dicionário de David | scripts/gerar_documentacao.py |
| D14 | Interface diverge do esquema | Registrar achados e compilação, sem modificar implementação | Seção 2 do relatório da etapa 2 |
| D15 | Risco de misturar teste com hipótese | Separar executado, inspecionado, proposto e pendente | docs/validacao.md e evidências |

## Critérios de encerramento desta revisão

- Documentação e relatórios alinhados ao código original.
- Dicionário cobrindo as 15 tabelas após a etapa 2.
- Planos e resultados registrados, incluindo limitações.
- Backup e crescimento descritos com premissas e origem.
- PDFs legíveis e fontes editáveis no repositório.
- Nenhuma modificação nos arquivos de implementação dos colegas.

A revisão acadêmica da equipe e a comparação com o enunciado oficial permanecem necessárias. Não se declara aprovação pelo professor.

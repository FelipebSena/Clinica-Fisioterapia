# Documentação do projeto

Versão revisada em 25/10/2026, confrontada com os scripts SQL e com execução em MySQL 8.0.46. Os arquivos Markdown são as fontes editáveis; os PDFs são gerados dessas fontes pelo script `scripts/gerar_documentacao.py`.

| Entrega de David | Fonte atual | Formato para leitura/impressão |
| --- | --- | --- |
| Dicionário completo do banco | [Dicionário](dicionario-dados.md) | [PDF](dicionario-dados.pdf) |
| Relatório da primeira etapa | [Etapa 1](relatorio-etapa1.md) | [PDF](relatorio-etapa1.pdf) |
| Relatório da segunda etapa | [Etapa 2](relatorio-etapa2.md) | [PDF](relatorio-etapa2.pdf) |
| Decisões e correções | [Registro](decisoes.md) | Markdown no Git |
| Testes e resultados | [Validação](validacao.md) | [Evidências](evidencias/) |
| Backup e estimativa de crescimento | [Plano e premissas](backup-crescimento.md) | Também resumidos na etapa 2 |

O [MER original](mer-conceitual.png) e o [arquivo editável](mer-conceitual.drawio) são referências conceituais. O [escopo original](escopo-regras-negocio.pdf) contém RN01 a RN26; a matriz do relatório 1 esclarece quais garantias estão efetivamente implementadas.

## Origem e precedência

O relatório anterior foi incluído no commit `6525092` de 23/10/2026, de Felipe Romero, e preservado em [histórico](historico/relatorio-etapa2.pdf). A cópia enviada separadamente tem o mesmo SHA-256: `708572cda1fe27c662d2a90adad7079197179de4ce0cb91540fbbb70465fad45`.

Documentos históricos não são instruções operacionais atuais. Em divergência: os scripts mostram o comportamento implementado; as evidências mostram o observado no ambiente indicado; os relatórios explicam a relação entre ambos. Uma proposta não equivale a uma função implantada.

## Antes da entrega

- Comparar a entrega com o enunciado e a rubrica oficiais, ainda não presentes no projeto.
- Confirmar com Felipe os parâmetros de crescimento, destino de backup, retenção e metas de recuperação.
- Revisar as limitações RN05, RN15 e agenda descritas na etapa 1.
- Se houver alteração de código ou SQL, repetir os testes afetados e gerar novamente os PDFs.
- A apresentação será preparada após a revisão da equipe; nenhum slide é declarado concluído nesta etapa.

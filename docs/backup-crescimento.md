# Backup, restauração e estimativa de crescimento

Documentação: David. Fonte inicial de planejamento: relatório de Felipe Romero, commit `6525092`, 23/10/2026. Revisão técnica/documental: 25/10/2026. Este documento descreve procedimentos e hipóteses; não instala agendamentos nem altera o banco usado pela equipe.

## 1. O que foi encontrado no Git

O relatório anterior propõe 20 profissionais, 10 sessões diárias, 22 dias por mês, backup às 02h, retenção de 30 dias e cópia em nuvem. O repositório não contém configuração de agendamento, destino de nuvem, medições operacionais nem aprovação formal desses parâmetros. O histórico localiza a inclusão do relatório por Felipe Romero; isso identifica a origem do texto, mas não comprova operação implantada.

## 2. Procedimento de backup completo

mysqldump produz backup lógico. A proposta deste projeto é dump completo, e não diferencial. Binlogs e ferramentas de backup físico exigiriam outra configuração. As tabelas são InnoDB; `--single-transaction` permite snapshot consistente dos dados, desde que não ocorram alterações de estrutura durante o dump.

Preparação: selecionar uma conta de backup com privilégios adequados à versão do servidor e aos objetos existentes; guardar credenciais fora do Git. O exemplo usa um login-path previamente configurado por `mysql_config_editor`, que não está incluído nesta entrega.

Exemplo PowerShell, em computador com os clientes MySQL no PATH:

```powershell
New-Item -ItemType Directory -Force backups | Out-Null
$arquivoBackup = Join-Path (Resolve-Path backups) ('clinica-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.sql')
mysqldump --login-path=clinica-backup --single-transaction --routines --events --triggers --no-tablespaces --set-gtid-purged=OFF --databases clinica_fisioterapia --result-file="$arquivoBackup"
if ($LASTEXITCODE -ne 0) { throw 'Backup falhou; não registrar como cópia válida.' }
if ((Get-Item -LiteralPath $arquivoBackup).Length -eq 0) { throw 'Arquivo vazio.' }
Get-FileHash -Algorithm SHA256 -LiteralPath $arquivoBackup
```

Usar `--result-file` evita conversões de codificação por redirecionamento do PowerShell. Registrar início/fim, versão do MySQL, tamanho, hash e resultado. O hash detecta mudança no arquivo; não substitui restauração. A opção GTID deve ser reavaliada se a equipe futuramente adotar replicação.

O dump do banco não inclui contas e roles globais. Guardar separadamente a política de privilégios e a identificação do DEFINER da view/gatilhos; restaurar as contas necessárias antes de usar esses objetos. `SQL/etapa02.sql` documenta roles e usuários de demonstração, mas a cópia de dados não deve ser confundida com backup completo da configuração do servidor.

## 3. Restauração e critérios de aceitação

Utilizar uma instância isolada, nunca restaurar o ensaio sobre a base de trabalho. O dump com `--databases` contém o nome original do banco; passá-lo a um cliente conectado a outro nome não garante isolamento. O isolamento deve ser feito pelo servidor/porta e diretório de dados.

1. Conferir hash, tamanho e existência de cópia íntegra; registrar versão e horários.
2. Preparar MySQL compatível, contas/roles e DEFINER necessários no ambiente isolado.
3. Importar pelo cliente MySQL, com `SOURCE caminho/do/arquivo.sql;`, verificando todos os erros.
4. Comparar contagens e hashes de dados por tabela, chaves, índices, view e gatilhos.
5. Repetir verificações de integridade e um teste de auditoria; testar consultas e permissões.
6. Registrar duração, falhas, ações corretivas e responsável. Só considerar a cópia recuperável após o ensaio.

O teste automatizado desta revisão executou dump completo, restaurou a base acadêmica no mesmo servidor descartável e comparou as 15 tabelas por contagem e SHA-256. Conferiu a view, os 15 gatilhos e o funcionamento de auditoria após restauração. Não testou perda de máquina, recuperação de nuvem, rede lenta, configuração global nem carga real de produção. Tempos e hash estão em `evidencias/validacao.json`.

## 4. Política proposta, sujeita a confirmação

| Item | Proposta documentada | Situação |
| --- | --- | --- |
| Frequência | Dump completo diário às 02h, America/Sao_Paulo | Não agendado |
| Cópias | Local e externa, com controle de acesso e criptografia em trânsito/repouso | Destino externo não definido |
| Retenção diária | 30 cópias válidas; excluir só após confirmação da cópia externa | Não configurada |
| Retenção mensal | Definir quantidade e finalidade com a equipe | Sem prazo aprovado |
| Verificação de arquivo | Tamanho, código de saída e hash após cada backup | Demonstrada no ensaio |
| Teste de restauração | Inicial, após mudanças relevantes e trimestralmente | Ensaio local executado; rotina futura não agendada |
| RPO | Meta proposta de até 24h de perda, se backups diários tiverem sucesso | Sem aprovação operacional |
| RTO | Definir a partir do tempo aceitável de indisponibilidade e de teste representativo | Não há meta confirmada |
| Monitoramento | Alertar falha, atraso e falta de espaço; identificar responsável | Procedimento futuro |

Manter dump apenas em Git não constitui estratégia de backup. Os dados e credenciais não devem ser versionados; o repositório guarda somente documentação, código de validação e evidências sem senhas. Retenção deve considerar necessidade do projeto e eventual política aplicável; não há alegação de conformidade jurídica neste documento.

## 5. Crescimento: hipóteses, fórmula e cenários

Fórmula anual: profissionais que atendem × sessões por profissional/dia × dias úteis/mês × meses/ano. O número de 20 profissionais vem do relatório, não de observação de produtividade. A carga do projeto contém 20 fisioterapeutas e 20 estagiários; isso não comprova 20 atendentes equivalentes nem produtividade diária. A contagem e a projeção têm finalidades diferentes.

| Cenário ilustrativo | Profissionais | Sessões/dia por profissional | Dias/mês | Meses/ano | Sessões/ano |
| --- | --- | --- | --- | --- | --- |
| Reduzido | 10 | 6 | 22 | 12 | 15.840 |
| Herdado do relatório | 20 | 10 | 22 | 12 | 52.800 |
| Ampliado | 30 | 12 | 22 | 12 | 95.040 |

Para relacionar tabelas, adotar explicitamente, apenas como exercício, 80% de sessões realizadas, uma evolução por realizada e três aplicações por realizada:

| Tabela | Fórmula no cenário herdado | Linhas novas/ano | Acumulado em 5 anos, sem expurgo |
| --- | --- | --- | --- |
| sessao | 52.800 | 52.800 | 264.000 |
| evolucao | 52.800 × 0,80 × 1 | 42.240 | 211.200 |
| aplicacao_exercicio | 52.800 × 0,80 × 3 | 126.720 | 633.600 |
| Subtotal | Soma das três tabelas | 221.760 | 1.108.800 |

O subtotal não representa todas as tabelas. Auditoria depende de atualizações/exclusões, avaliações dependem da periodicidade clínica, e novos pacientes/tratamentos exigem outros parâmetros. Uma evolução é permitida por sessão, mas não é obrigatória; a hipótese de uma por realizada não é uma restrição do banco.

Na carga: 237 sessões e 169 evoluções, com 440 aplicações. Essas proporções são de dados fictícios e não devem ser apresentadas como estatística operacional. O antigo percentual de 85% foi removido por não ter memória de cálculo.

## 6. Como estimar espaço em disco

Após carga representativa e ANALYZE TABLE, consultar o catálogo. TABLE_ROWS é estimativa no InnoDB; usar COUNT(*) em ambiente de dimensionamento para contagem exata.

```sql
SELECT table_name, table_rows,
       data_length, index_length, data_free,
       ROUND((data_length + index_length) / 1024 / 1024, 2) AS mib_alocados
FROM information_schema.tables
WHERE table_schema = 'clinica_fisioterapia'
  AND table_type = 'BASE TABLE'
ORDER BY data_length + index_length DESC;
```

Para cada tabela, estimar bytes por linha observados = (data_length + index_length) / contagem exata, documentando que páginas livres e textos variáveis distorcem bases pequenas. Projetar linhas futuras × bytes por linha; somar tabelas, margem de espaço livre, logs e backups. Exemplo meramente ilustrativo: 221.760 linhas × 1 KiB médio = 216,56 MiB/ano para as três tabelas; 1 KiB não foi medido e não é orçamento de infraestrutura. O tamanho do dump textual também difere do tamanho físico do InnoDB.

## 7. Particionamento e decisões

O banco atual usa FKs entre sessão, tratamento, sala, evolução e aplicação. Tabelas InnoDB particionadas não suportam essas relações de FK no MySQL 8.0; chaves únicas também precisam satisfazer as regras da chave de particionamento. Por isso o projeto atual deve permanecer sem PARTITION BY RANGE. Arquivamento e reorganização física só devem ser estudados após medição, com novo desenho de integridade e plano de recuperação.

## 8. Informações a confirmar com Felipe

- Se os 20 profissionais e 10 atendimentos/dia são hipóteses escolhidas pelo grupo e qual o horizonte desejado.
- Percentual de realizadas, exercícios por sessão, avaliações, tratamentos e alterações geradoras de auditoria.
- Servidor/armazenamento de destino, responsável pela operação, cópia externa e capacidade disponível.
- Retenção mensal, metas RPO/RTO e forma de alerta de falha.

## Referências técnicas

- [mysqldump e opções de backup](https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html).
- [Restrições de particionamento por engine](https://dev.mysql.com/doc/refman/8.0/en/partitioning-limitations-storage-engines.html).
- [Chaves únicas e particionamento](https://dev.mysql.com/doc/refman/8.0/en/partitioning-limitations-partitioning-keys-unique-keys.html).

Consultadas em 25/10/2026. As hipóteses adicionais deste documento são de planejamento e não foram atribuídas como informação confirmada por Felipe.

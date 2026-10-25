# Clínica de Fisioterapia

Relatório das etapas 1 e 2 - Laboratório de Banco de Dados, 2026/2

Documentação e validação: David Fernandes dos Santos. Equipe: David, Felipe Romero, Caio e Felipe Sena. Data: 25/10/2026.

## 1. Apresentação

O projeto organiza o atendimento de uma clínica de fisioterapia, desde o cadastro do paciente até as sessões e o registro da evolução. Este relatório reúne a modelagem, as regras de negócio, os resultados dos testes e o planejamento de backup e crescimento. O [dicionário de dados](../dicionario-dados.pdf) apresenta as colunas e restrições de cada tabela.

O trabalho foi elaborado a partir do [escopo](../escopo-regras-negocio.pdf), do [modelo lógico](../modelo-logico.pdf), do [MER](../mer-conceitual.png) e dos scripts SQL do projeto. A versão utilizada nos testes é a do commit `02e1469`.

## 2. Etapa 1 - modelagem e implementação

### 2.1 Organização do banco

Cada tratamento pertence a um paciente, possui um fisioterapeuta responsável e está associado a uma especialidade. As sessões pertencem ao tratamento e registram horário, sala e situação. Uma sessão realizada pode ter uma evolução e vários exercícios aplicados. As avaliações físicas formam um histórico por paciente e data.

São 12 entidades de domínio e duas tabelas associativas: `habilitacao_profissional` e `aplicacao_exercicio`. A auditoria, acrescentada na etapa 2, é uma tabela técnica. Faturamento, folha de pagamento, estoque e comunicação automática com pacientes ficam fora do escopo.

As principais escolhas de modelagem foram:

- Separar `profissional` em dois subtipos: `fisioterapeuta` e `estagiario`. Ambos usam a chave do profissional. A supervisão do estagiário referencia o subtipo fisioterapeuta.
- Identificar a sessão por `(id_tratamento, numero_sessao)`. A evolução usa a mesma chave, permitindo no máximo um registro por sessão.
- Usar tabelas associativas para guardar a data de habilitação e os parâmetros de cada exercício aplicado.
- Impedir dois tratamentos abertos do mesmo paciente na mesma especialidade. Para isso, a coluna gerada `id_especialidade_em_andamento` recebe a especialidade enquanto não há alta e NULL após a alta; uma chave única controla a combinação com o paciente.

O modelo lógico separa dados de pacientes, convênios, profissionais e especialidades, evitando repetir seus nomes em tratamento. Nas associações, os atributos dependem da chave completa: séries e repetições, por exemplo, pertencem à aplicação de um exercício em uma sessão específica. Essas dependências sustentam a organização em 3FN. No modelo físico, a coluna gerada do tratamento é uma redundância controlada pelo MySQL para atender à RN13; por isso não se afirma que o esquema físico inteiro esteja em BCNF.

### 2.2 Regras de negócio

| Regra | Mecanismo no banco | Observação |
| --- | --- | --- |
| RN01 | CPF do paciente com UNIQUE | Não valida os dígitos verificadores |
| RN02 | Nascimento NOT NULL e gatilhos INSERT/UPDATE | Impede data futura |
| RN03 | FK opcional para convênio | NULL representa atendimento particular |
| RN04 | ENUM e DEFAULT ATIVO | Situação ATIVO ou INATIVO |
| RN05 | PK/FKs e gatilhos dos subtipos | Exclusividade testada; totalidade não é imposta |
| RN06 | CREFITO NOT NULL e UNIQUE | Formato não validado no banco |
| RN07 | Supervisor obrigatório, FK para fisioterapeuta | Gatilhos impedem autossupervisão |
| RN08 | Associação profissional/especialidade | Guarda data de habilitação |
| RN09 | PK composta da habilitação | Impede vínculo repetido |
| RN10 | FKs obrigatórias de tratamento | Paciente, fisioterapeuta e especialidade existentes |
| RN11 | Início obrigatório e alta opcional | Alta NULL indica tratamento aberto |
| RN12 | CHECK das datas | Alta não anterior ao início |
| RN13 | Coluna gerada e UNIQUE composto | Um tratamento aberto por paciente/especialidade |
| RN14 | FKs sem exclusão em cascata de tratamento | Impede excluir paciente/fisioterapeuta com tratamento |
| RN15 | PK composta e número de sessão positivo | Não exige sequência sem lacunas |
| RN16 | Horário e sala obrigatórios | FK garante existência da sala |
| RN17 | UNIQUE de sala/horário | Não controla sobreposição por duração |
| RN18 | ENUM e DEFAULT AGENDADA | AGENDADA, REALIZADA, CANCELADA ou FALTA |
| RN19 | PK/FK e gatilhos de evolução/sessão | Evolução somente em sessão realizada |
| RN20 | Associação sessão/exercício | Séries e repetições positivas |
| RN21 | CHECK de carga | NULL ou valor não negativo |
| RN22 | UNIQUE de paciente/data da avaliação | Uma avaliação por paciente e data |
| RN23 | TINYINT UNSIGNED e CHECK | Dor entre 0 e 10 |
| RN24 | Nome do convênio NOT NULL e UNIQUE | NOT NULL não impede texto vazio |
| RN25 | Código único e capacidade positiva | Capacidade não controla ocupação simultânea |
| RN26 | Nome do exercício único e região obrigatória | Região não pode ser NULL |

O banco foi testado em modo SQL estrito. Formatos de telefone e e-mail, textos vazios e dígitos verificadores do CPF não são validados por todas as restrições. Na carga, o atendimento particular aparece tanto pela ausência de convênio (NULL) quanto pelo cadastro chamado Particular.

### 2.3 Carga e consultas

`SQL/etapa01.sql` reúne criação do banco, restrições, carga fictícia e 15 consultas. As tabelas usam InnoDB, utf8mb4 e collation utf8mb4_0900_ai_ci. As 69 instruções do arquivo foram executadas sem erro no MySQL 8.0.46.

A carga contém 1.186 linhas nas 14 tabelas de domínio: 40 pacientes, 40 profissionais, 20 fisioterapeutas, 20 estagiários, 8 convênios, 8 especialidades, 40 habilitações, 40 tratamentos, 8 salas, 237 sessões, 169 evoluções, 13 exercícios, 440 aplicações e 103 avaliações. A auditoria começa vazia. A data de referência dos dados fictícios é 24/10/2026.

| Consultas | Conteúdo | Recursos SQL |
| --- | --- | --- |
| 1 a 4 | Nome/situação, pacientes ativos, ordem alfabética e nome Ana | SELECT, WHERE, ORDER BY e LIKE |
| 5 | Nascimento entre 1985 e 1995, sem telefone, convênios GEAP/Saúde Caixa | BETWEEN, IN, NULL e JOIN |
| 6 e 7 | Tratamentos com responsáveis; pacientes com ou sem avaliação | JOIN e LEFT JOIN |
| 8 a 10 | Tratamentos por especialidade, mínimo de cinco e sessões realizadas por paciente | GROUP BY, HAVING e COUNT |
| 11 a 13 | Dor acima da média individual, habilitação em Respiratória e exercícios nunca aplicados | Subconsulta, EXISTS e NOT EXISTS |
| 14 e 15 | Sessão realizada com dor média >= 6; fisioterapeutas acima da média entre os que atendem | Junção, agregação e subconsulta |

## 3. Etapa 2 - segurança, auditoria e desempenho

### 3.1 Perfis de acesso (B5)

| Perfil | Acesso implementado | Resultado verificado |
| --- | --- | --- |
| Administrador | Todos os privilégios no banco do projeto | Role ativada na conexão |
| Fisioterapeuta | Consulta cadastros; consulta, insere e atualiza dados operacionais | Leitura de paciente permitida; exclusão recusada |
| Estagiario | Consulta a view restrita e tratamentos; consulta, insere e atualiza evolução | View acessível; leitura direta de CPF recusada |

As contas recebem senhas aleatórias e roles padrão. A view `vw_paciente_restrito` expõe id, nome, nascimento e situação, sem CPF, telefone e convênio. Ela usa SQL SECURITY DEFINER e não limita pacientes por supervisor. Essa política restringe objetos e colunas, mas não anonimiza os dados nem controla acesso individual por paciente.

### 3.2 Auditoria (B6)

A tabela `auditoria_evolucao` registra alterações e exclusões, textos anteriores/novos, chaves da sessão, usuário conectado e horário. Os gatilhos usam USER() para identificar a conexão. Não há FK para a sessão, pois o histórico precisa permanecer após sua exclusão.

Há quatro gatilhos de auditoria: UPDATE e DELETE de evolução, além de DELETE direto em sessão e tratamento. Os dois últimos cobrem exclusões em cascata, que não acionam gatilhos nas tabelas dependentes do MySQL. Os testes conferiram os três caminhos de exclusão e o conteúdo do registro de alteração.

A auditoria participa da transação e também é desfeita por ROLLBACK. Não registra consultas, inserções de evolução nem tentativas recusadas. A conta Administrador pode alterá-la; portanto, ela não é um histórico imutável.

### 3.3 Análise das consultas (B4)

Foram comparadas as consultas 5, 10 e 14 antes e depois dos índices da etapa 2. Cada cenário recebeu ANALYZE TABLE, uma execução de aquecimento e 15 medições no cliente Python. Também foram salvos EXPLAIN FORMAT=JSON e EXPLAIN ANALYZE. Os resultados das consultas permaneceram iguais, conferidos por hash.

<!-- PERF_INICIO -->
| Consulta | Resultado (linhas) | Custo antes/depois | Mediana antes/depois (ms) |
| --- | --- | --- | --- |
| 5 | 2 | 3,07 / 3,07 | 0,3053 / 0,2896 |
| 10 | 40 | 52,00 / 40,76 | 0,6585 / 0,6387 |
| 14 | 14 | 68,72 / 61,91 | 0,7702 / 0,6506 |
<!-- PERF_FIM -->

O custo é a estimativa do otimizador, não o tempo em milissegundos. As medianas incluem comunicação e leitura dos resultados. Como a carga é pequena e não houve concorrência, os valores não demonstram desempenho de produção.

- **Consulta 5:** `idx_paciente_busca (data_nascimento, id_convenio, telefone)` não foi escolhido. O plano manteve os índices de nome do convênio e de convênio do paciente. Não houve benefício demonstrado nessa carga. A consulta atual não contém filtro de paciente ativo.
- **Consulta 10:** `idx_sessao_situacao (situacao, id_tratamento)` passou a ser usado como acesso coberto. O custo estimado caiu, e a mediana apresentou uma pequena redução. Agrupamento e ordenação continuam necessários.
- **Consulta 14:** o plano posterior usa os índices de situação da sessão e de avaliação por paciente/dor. O custo estimado diminuiu. Como os índices foram aplicados juntos, não foi isolada a contribuição de cada um.

### 3.4 Integração com a interface

`ClinicaApp.java` compilou com JDK 21.0.5, mas não passou por teste funcional. A leitura do código identificou os seguintes pontos para os responsáveis pela implementação:

- Uso de `id`, `id_sessao`, `s.id_paciente` e campos de sala/fisioterapeuta que não correspondem ao esquema; referência à tabela `equipamento`, que não existe.
- Botões Criar e Atualizar sem ação implementada e SELECT encaminhado a `executeUpdate`.
- Referência à view `vw_relatorio_consolidado`, ausente nos scripts.
- Credencial padrão embutida e resposta clínica positiva fixa na transação.

O código usa PreparedStatement, COMMIT e ROLLBACK. O funcionamento desses fluxos ainda depende de teste da aplicação com o banco; a compilação, sozinha, não verifica essa integração.

## 4. Testes e resultados

<!-- TESTES_INICIO -->
Foram concluídos 54 testes, sem falhas, em MySQL 8.0.46, no dia 25/10/2026. O dump completo teve 113.803 bytes; levou 0,136 s para gerar e 1,357 s para restaurar. Esses tempos se referem à base acadêmica local e não estimam a recuperação de uma clínica em produção.
<!-- TESTES_FIM -->

Os testes usaram uma instância isolada em 127.0.0.1:33317, com dados fictícios. A lista de casos, códigos de erro, contagens, hashes e planos está reunida em [apoio/evidencias.json](../apoio/evidencias.json).

| Grupo | Conferência realizada |
| --- | --- |
| Instalação | Execução das etapas 1 e 2 e reexecução da etapa 2 sem alterar dados |
| Integridade | Duplicidades, FKs, datas, situações, carga, séries, repetições e nível de dor |
| Coerência da carga | Um subtipo por profissional; habilitação dos responsáveis; sessões dentro do período do tratamento |
| Segurança e auditoria | Roles ativas, permissões e registros de UPDATE/DELETE direto e em cascata |
| Consultas | Resultados iguais antes/depois dos índices |
| Restauração | Contagens e hashes das 15 tabelas iguais; view e 15 gatilhos presentes; auditoria funcionando |

Nos testes negativos, a operação inválida só foi considerada corretamente bloqueada quando retornou o código de erro esperado. Os testes de dados foram revertidos para preservar a carga. Não foram testados concorrência, volume de produção, perda de máquina ou recuperação de nuvem.

## 5. Backup e crescimento (B7)

### 5.1 Backup e restauração

O plano adota backup lógico completo com mysqldump. A classificação como diferencial, usada no relatório anterior, não corresponde a esse procedimento. Para InnoDB, o comando usa snapshot consistente, sem alterações de estrutura durante a cópia, e inclui rotinas, eventos e gatilhos.

Exemplo para PowerShell, com um login-path de backup já configurado fora do Git:

```powershell
mysqldump --login-path=clinica-backup --single-transaction `
  --routines --events --triggers --no-tablespaces `
  --set-gtid-purged=OFF --databases clinica_fisioterapia `
  --result-file=clinica-backup.sql
if ($LASTEXITCODE -ne 0) { throw 'Falha no backup.' }
Get-FileHash -Algorithm SHA256 -LiteralPath clinica-backup.sql
```

Usar um nome de arquivo diferente a cada cópia. `--result-file` evita conversão de codificação pelo PowerShell. Registrar horário, tamanho, hash e resultado; arquivo vazio ou comando com erro não conta como backup válido. O dump não inclui contas e roles globais: permissões e contas DEFINER devem ser guardadas separadamente.

Para testar a restauração, usar outro servidor/porta, importar com `SOURCE caminho/clinica-backup.sql;` no cliente MySQL e comparar tabelas, view, gatilhos e consultas. O dump com `--databases` contém o nome original da base; apenas trocar o banco selecionado no cliente não isola o teste. O ensaio realizado conferiu a recuperação dos dados, mas não mediu um desastre completo.

| Item | Política proposta |
| --- | --- |
| Frequência | Backup completo diário às 02h, horário de São Paulo |
| Armazenamento | Cópia local e externa, com acesso restrito e criptografia |
| Retenção | 30 cópias diárias válidas; prazo mensal ainda não definido |
| Restauração de teste | Inicial, após mudanças relevantes e trimestralmente |
| RPO | Até 24h de perda, condicionado ao sucesso das cópias diárias |
| RTO | Prazo de recuperação ainda não definido |

Horário e retenção vieram do relatório de Felipe. Não há agendamento, destino externo ou monitoramento configurados no projeto; são parâmetros de planejamento, não uma rotina implantada.

### 5.2 Estimativa de crescimento

O cenário do relatório de Felipe considera 20 profissionais, 10 sessões diárias por profissional, 22 dias úteis por mês e 12 meses: **20 × 10 × 22 × 12 = 52.800 sessões por ano**. O valor é uma hipótese de capacidade. A existência de 20 fisioterapeutas na carga fictícia não comprova essa produtividade.

Para estimar as tabelas dependentes, foi acrescentada a hipótese de 80% de sessões realizadas, uma evolução e três aplicações de exercício por sessão realizada:

| Tabela | Linhas novas por ano | Em cinco anos, sem exclusões |
| --- | --- | --- |
| sessao | 52.800 | 264.000 |
| evolucao | 42.240 | 211.200 |
| aplicacao_exercicio | 126.720 | 633.600 |
| Subtotal | 221.760 | 1.108.800 |

Pacientes, tratamentos, avaliações e auditoria precisam de estimativas próprias. Uma evolução por sessão realizada é uma hipótese de uso, não uma obrigação do banco. O percentual anterior de 85% de crescimento foi retirado por não possuir memória de cálculo.

Para dimensionar armazenamento, medir `data_length + index_length` em `information_schema.tables`, dividir pela contagem exata de linhas e aplicar a projeção por tabela. A medição deve usar carga representativa: páginas livres e campos TEXT distorcem bases pequenas. Acrescentar espaço para logs, backups e margem livre. O tamanho do dump não equivale ao espaço ocupado pelo InnoDB.

Os tipos físicos incluem INT UNSIGNED nas chaves, TINYINT UNSIGNED com CHECK na dor, DECIMAL(8,2) na carga e ENUM nas situações. Não se recomenda particionar a tabela sessão atual: o particionamento InnoDB no MySQL 8.0 é incompatível com suas FKs, além de impor regras às chaves únicas.

## 6. Registro das decisões

| Decisão | Motivo |
| --- | --- |
| Chaves compostas em sessão e evolução | Identificar cada sessão dentro do tratamento e vincular sua evolução |
| Coluna gerada no tratamento | Impedir dois tratamentos abertos por paciente e especialidade |
| Auditoria sem FK para sessão | Manter o registro após a exclusão dos dados de origem |
| Comparação dos índices com EXPLAIN | Verificar a escolha do otimizador; a consulta 5 não usou o índice proposto |
| Backup lógico completo | Manter um procedimento de cópia e restauração com mysqldump |
| Sessão sem particionamento | Preservar as FKs do modelo atual |

As regras RN01 a RN26 foram relacionadas às restrições do banco; os casos executados estão resumidos na seção 4. A totalidade da especialização, a sequência sem lacunas e a sobreposição de sessões por duração não são garantidas pelo banco. A concorrência não foi testada. Os parâmetros de backup e crescimento são hipóteses de planejamento.

## 7. Como reproduzir a validação

As ferramentas ficam em `docs/apoio/ferramentas/`. **O teste do banco apaga e recria clinica_fisioterapia e troca as senhas das contas de demonstração: executar somente em instância descartável.**

1. Instalar as dependências de `docs/apoio/ferramentas/requirements.txt`.
2. Configurar MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASSWORD e MYSQL_BIN para a instância de teste; não gravar senhas no Git.
3. Executar `python docs/apoio/ferramentas/validar_banco.py --confirmar-base-descartavel` e conferir código de saída zero e resultados completos.
4. Executar `python docs/apoio/ferramentas/gerar_documentacao.py` para atualizar os PDFs e `python docs/apoio/ferramentas/verificar_documentacao.py` para conferir cobertura, links e arquivos preservados.

Os resultados foram obtidos em 25/10/2026, sobre o commit `02e1469`. Alterações nos scripts exigem nova execução dos testes.

## 8. Referências

- Arquivos do projeto: SQL/etapa01.sql, SQL/etapa02.sql, interface/ClinicaApp.java, escopo, MER e modelo lógico.
- MySQL, índices compostos: https://dev.mysql.com/doc/refman/8.0/en/multiple-column-indexes.html
- MySQL, mysqldump: https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html
- MySQL, restrições de particionamento: https://dev.mysql.com/doc/refman/8.0/en/partitioning-limitations-storage-engines.html

Referências consultadas em 25/10/2026. Houve apoio de IA na organização dos documentos, redação e conferência dos resultados.

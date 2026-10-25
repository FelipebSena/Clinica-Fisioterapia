# Dicionário de dados físico

Clínica de Fisioterapia | Documentação: David | Revisão: 25/10/2026

Escopo: 14 tabelas do domínio e auditoria da etapa 2, conforme os scripts originais. Fonte técnica: catálogo MySQL 8.0.46 em `docs/evidencias/catalogo.json`. Este dicionário físico complementa o conceitual preservado em `docs/historico/dicionário-dados.pdf`. Elaborado com apoio de IA e confrontado com o catálogo executado; não altera o DDL.

## Convenções e limites

PK: chave primária; UQ: unicidade; FK: chave estrangeira. NULL significa ausência de valor. Campos de PK são implicitamente NOT NULL. Sem padrão significa valor obrigatório fornecido pelo cliente, salvo AUTO_INCREMENT ou geração automática. DEFAULT NULL é descrito como NULL. As ações omitidas nas FKs seguem RESTRICT/NO ACTION do InnoDB. Todas as tabelas usam InnoDB, utf8mb4 e utf8mb4_0900_ai_ci.

INT UNSIGNED admite 0 a 4.294.967.295; nem todo identificador possui CHECK de positividade. TINYINT UNSIGNED admite 0 a 255, reduzido por CHECK na dor a 0-10. DECIMAL(8,2) reserva oito dígitos totais, dois decimais; a carga não pode ser negativa. TEXT suporta até 65.535 bytes; o número de caracteres depende da codificação. VARCHAR limita caracteres. ENUM depende de modo SQL estrito para rejeitar valores inválidos, como no ambiente de teste.

O banco não valida todos os formatos de CPF, telefone, e-mail e textos não vazios. Restrições de coluna, índices, FKs, CHECKs e gatilhos têm papéis distintos. A matriz RN01-RN26 no relatório 1 identifica limites da implementação.

## 1. convenio

Catálogo de convênios; paciente pode não possuir vínculo.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_convenio` | int unsigned | Não | AUTO_INCREMENT | PK (ver composição abaixo). Identificador de convenio. |
| `nome` | varchar(150) | Não | Sem padrão | Nome de cadastro. NOT NULL não impede texto vazio. |

### Chaves, índices e restrições

- PRIMARY KEY (id_convenio)
- UNIQUE KEY uq_convenio_nome (nome)

## 2. paciente

Cadastro de pacientes e situação administrativa.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_paciente` | int unsigned | Não | AUTO_INCREMENT | PK (ver composição abaixo). Identificador de paciente. |
| `cpf` | char(11) | Não | Sem padrão | Identificador CPF, armazenado como texto. UNIQUE; não valida dígitos verificadores no banco. |
| `nome` | varchar(150) | Não | Sem padrão | Nome de cadastro. NOT NULL não impede texto vazio. |
| `data_nascimento` | date | Não | Sem padrão | Data de nascimento. Gatilhos impedem data futura. |
| `telefone` | varchar(20) | Sim | NULL | Um contato principal; NULL indica ausência. |
| `situacao` | enum('ATIVO','INATIVO') | Não | ATIVO | Estado cadastral ou da sessão conforme os valores ENUM declarados. |
| `id_convenio` | int unsigned | Sim | NULL | Identificador de convenio. |

### Chaves, índices e restrições

- PRIMARY KEY (id_paciente)
- UNIQUE KEY uq_paciente_cpf (cpf)
- KEY idx_paciente_convenio (id_convenio)
- KEY idx_paciente_busca (data_nascimento,id_convenio,telefone)
- CONSTRAINT fk_paciente_convenio FOREIGN KEY (id_convenio) REFERENCES convenio (id_convenio) ON DELETE SET NULL ON UPDATE CASCADE

## 3. profissional

Dados comuns aos dois subtipos de profissionais.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_profissional` | int unsigned | Não | AUTO_INCREMENT | PK (ver composição abaixo). Identificador de profissional. |
| `nome` | varchar(150) | Não | Sem padrão | Nome de cadastro. NOT NULL não impede texto vazio. |
| `cpf` | char(11) | Não | Sem padrão | Identificador CPF, armazenado como texto. UNIQUE; não valida dígitos verificadores no banco. |
| `telefone` | varchar(20) | Sim | NULL | Um contato principal; NULL indica ausência. |
| `email` | varchar(254) | Sim | NULL | Um endereço de e-mail; formato não validado por CHECK. |

### Chaves, índices e restrições

- PRIMARY KEY (id_profissional)
- UNIQUE KEY uq_profissional_cpf (cpf)

## 4. fisioterapeuta

Subtipo profissional habilitado a responder por tratamento.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_profissional` | int unsigned | Não | Sem padrão | PK (ver composição abaixo). Identificador de profissional. |
| `crefito` | varchar(30) | Não | Sem padrão | Registro profissional único; formato não validado pelo banco. |

### Chaves, índices e restrições

- PRIMARY KEY (id_profissional)
- UNIQUE KEY uq_fisioterapeuta_crefito (crefito)
- CONSTRAINT fk_fisioterapeuta_profissional FOREIGN KEY (id_profissional) REFERENCES profissional (id_profissional) ON DELETE CASCADE ON UPDATE CASCADE

## 5. estagiario

Subtipo com instituição de ensino e supervisor fisioterapeuta.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_profissional` | int unsigned | Não | Sem padrão | PK (ver composição abaixo). Identificador de profissional. |
| `instituicao_ensino` | varchar(150) | Não | Sem padrão | Instituição do estagiário. |
| `id_supervisor` | int unsigned | Não | Sem padrão | Fisioterapeuta supervisor; obrigatório; não pode ser o próprio estagiário. |

### Chaves, índices e restrições

- PRIMARY KEY (id_profissional)
- KEY fk_estagiario_supervisor (id_supervisor)
- CONSTRAINT fk_estagiario_profissional FOREIGN KEY (id_profissional) REFERENCES profissional (id_profissional) ON DELETE CASCADE ON UPDATE CASCADE
- CONSTRAINT fk_estagiario_supervisor FOREIGN KEY (id_supervisor) REFERENCES fisioterapeuta (id_profissional) ON DELETE RESTRICT ON UPDATE CASCADE

## 6. especialidade

Catálogo de especialidades de atendimento.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_especialidade` | int unsigned | Não | AUTO_INCREMENT | PK (ver composição abaixo). Identificador de especialidade. |
| `nome` | varchar(100) | Não | Sem padrão | Nome de cadastro. NOT NULL não impede texto vazio. |
| `descricao` | text | Sim | NULL | Descrição livre opcional do catálogo. |

### Chaves, índices e restrições

- PRIMARY KEY (id_especialidade)
- UNIQUE KEY uq_especialidade_nome (nome)

## 7. habilitacao_profissional

Associação N:N entre profissional e especialidade, com data.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_profissional` | int unsigned | Não | Sem padrão | PK (ver composição abaixo). Identificador de profissional. |
| `id_especialidade` | int unsigned | Não | Sem padrão | PK (ver composição abaixo). Identificador de especialidade. |
| `data_habilitacao` | date | Não | Sem padrão | Data em que o profissional obteve habilitação na especialidade. |

### Chaves, índices e restrições

- PRIMARY KEY (id_profissional,id_especialidade)
- KEY idx_habilitacao_especialidade (id_especialidade)
- CONSTRAINT fk_habilitacao_especialidade FOREIGN KEY (id_especialidade) REFERENCES especialidade (id_especialidade) ON DELETE RESTRICT ON UPDATE CASCADE
- CONSTRAINT fk_habilitacao_profissional FOREIGN KEY (id_profissional) REFERENCES profissional (id_profissional) ON DELETE CASCADE ON UPDATE CASCADE

## 8. tratamento

Plano de atendimento vinculado a paciente, responsável e especialidade.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_tratamento` | int unsigned | Não | AUTO_INCREMENT | PK (ver composição abaixo). Identificador de tratamento. |
| `descricao_condicao` | varchar(255) | Não | Sem padrão | Condição ou objetivo terapêutico do tratamento. |
| `data_inicio` | date | Não | Sem padrão | Início do tratamento; obrigatório. |
| `data_alta` | date | Sim | NULL | Alta do tratamento; NULL indica aberto; não anterior ao início. |
| `id_paciente` | int unsigned | Não | Sem padrão | Identificador de paciente. |
| `id_fisioterapeuta` | int unsigned | Não | Sem padrão | Identificador de fisioterapeuta. |
| `id_especialidade` | int unsigned | Não | Sem padrão | Identificador de especialidade. |
| `id_especialidade_em_andamento` | int unsigned | Sim | Gerada STORED; ver expressão abaixo | Campo gerado: especialidade se alta é NULL; caso contrário NULL. Não preencher manualmente. |

### Chaves, índices e restrições

- PRIMARY KEY (id_tratamento)
- UNIQUE KEY uq_tratamento_paciente_especialidade_aberto (id_paciente,id_especialidade_em_andamento)
- KEY idx_tratamento_paciente (id_paciente)
- KEY idx_tratamento_fisioterapeuta (id_fisioterapeuta)
- KEY idx_tratamento_especialidade (id_especialidade)
- CONSTRAINT fk_tratamento_especialidade FOREIGN KEY (id_especialidade) REFERENCES especialidade (id_especialidade)
- CONSTRAINT fk_tratamento_fisioterapeuta FOREIGN KEY (id_fisioterapeuta) REFERENCES fisioterapeuta (id_profissional)
- CONSTRAINT fk_tratamento_paciente FOREIGN KEY (id_paciente) REFERENCES paciente (id_paciente)
- CONSTRAINT ck_tratamento_datas CHECK (((data_alta is null) or (data_alta >= data_inicio)))

Expressão gerada: `(case when (`data_alta` is null) then `id_especialidade` else NULL end)`.

## 9. sala

Local físico; a capacidade é descritiva e não controla concorrência de agenda.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_sala` | int unsigned | Não | AUTO_INCREMENT | PK (ver composição abaixo). Identificador de sala. |
| `codigo` | varchar(30) | Não | Sem padrão | Código único de identificação da sala. |
| `capacidade` | int unsigned | Não | Sem padrão | Capacidade declarada positiva; não calcula ocupação. |

### Chaves, índices e restrições

- PRIMARY KEY (id_sala)
- UNIQUE KEY uq_sala_codigo (codigo)
- CONSTRAINT ck_sala_capacidade CHECK ((capacidade > 0))

## 10. sessao

Atendimento identificado dentro de um tratamento.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_tratamento` | int unsigned | Não | Sem padrão | PK (ver composição abaixo). Identificador de tratamento. |
| `numero_sessao` | int unsigned | Não | Sem padrão | PK (ver composição abaixo). Número positivo dentro do tratamento. Não há garantia de sequência sem lacunas. |
| `data_hora` | datetime | Não | Sem padrão | Data/hora da sessão ou do evento de auditoria; DATETIME sem fuso armazenado. |
| `situacao` | enum('AGENDADA','REALIZADA','CANCELADA','FALTA') | Não | AGENDADA | Estado cadastral ou da sessão conforme os valores ENUM declarados. |
| `id_sala` | int unsigned | Não | Sem padrão | Identificador de sala. |

### Chaves, índices e restrições

- PRIMARY KEY (id_tratamento,numero_sessao)
- UNIQUE KEY uq_sessao_sala_horario (id_sala,data_hora)
- KEY idx_sessao_sala (id_sala)
- KEY idx_sessao_data_hora (data_hora)
- KEY idx_sessao_situacao (situacao,id_tratamento)
- CONSTRAINT fk_sessao_sala FOREIGN KEY (id_sala) REFERENCES sala (id_sala) ON DELETE RESTRICT ON UPDATE CASCADE
- CONSTRAINT fk_sessao_tratamento FOREIGN KEY (id_tratamento) REFERENCES tratamento (id_tratamento) ON DELETE CASCADE ON UPDATE CASCADE
- CONSTRAINT ck_sessao_numero CHECK ((numero_sessao > 0))

## 11. evolucao

Registro de conduta e resposta de uma sessão realizada.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_tratamento` | int unsigned | Não | Sem padrão | PK (ver composição abaixo). Identificador de tratamento. |
| `numero_sessao` | int unsigned | Não | Sem padrão | PK (ver composição abaixo). Número positivo dentro do tratamento. Não há garantia de sequência sem lacunas. |
| `conduta_aplicada` | text | Não | Sem padrão | Texto da conduta da sessão realizada. |
| `resposta_observada` | text | Não | Sem padrão | Texto da resposta observada na sessão. |

### Chaves, índices e restrições

- PRIMARY KEY (id_tratamento,numero_sessao)
- CONSTRAINT fk_evolucao_sessao FOREIGN KEY (id_tratamento, numero_sessao) REFERENCES sessao (id_tratamento, numero_sessao) ON DELETE CASCADE ON UPDATE CASCADE

## 12. exercicio

Catálogo de exercícios terapêuticos.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_exercicio` | int unsigned | Não | AUTO_INCREMENT | PK (ver composição abaixo). Identificador de exercicio. |
| `nome` | varchar(100) | Não | Sem padrão | Nome de cadastro. NOT NULL não impede texto vazio. |
| `regiao_corpo` | varchar(100) | Não | Sem padrão | Região corporal trabalhada pelo exercício. |
| `descricao` | text | Sim | NULL | Descrição livre opcional do catálogo. |

### Chaves, índices e restrições

- PRIMARY KEY (id_exercicio)
- UNIQUE KEY uq_exercicio_nome (nome)

## 13. aplicacao_exercicio

Exercício aplicado em sessão, com parâmetros de execução.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_tratamento` | int unsigned | Não | Sem padrão | PK (ver composição abaixo). Identificador de tratamento. |
| `numero_sessao` | int unsigned | Não | Sem padrão | PK (ver composição abaixo). Número positivo dentro do tratamento. Não há garantia de sequência sem lacunas. |
| `id_exercicio` | int unsigned | Não | Sem padrão | PK (ver composição abaixo). Identificador de exercicio. |
| `series` | int unsigned | Não | Sem padrão | Quantidade positiva de séries. |
| `repeticoes` | int unsigned | Não | Sem padrão | Quantidade positiva de repetições por série. |
| `carga` | decimal(8,2) | Sim | NULL | Carga numérica não negativa ou NULL. Unidade não definida no esquema; confirmar com a equipe. |

### Chaves, índices e restrições

- PRIMARY KEY (id_tratamento,numero_sessao,id_exercicio)
- KEY idx_aplicacao_exercicio (id_exercicio)
- CONSTRAINT fk_aplicacao_exercicio FOREIGN KEY (id_exercicio) REFERENCES exercicio (id_exercicio) ON DELETE RESTRICT ON UPDATE CASCADE
- CONSTRAINT fk_aplicacao_sessao FOREIGN KEY (id_tratamento, numero_sessao) REFERENCES sessao (id_tratamento, numero_sessao) ON DELETE CASCADE ON UPDATE CASCADE
- CONSTRAINT ck_aplicacao_carga CHECK (((carga is null) or (carga >= 0)))
- CONSTRAINT ck_aplicacao_repeticoes CHECK ((repeticoes > 0))
- CONSTRAINT ck_aplicacao_series CHECK ((series > 0))

## 14. avaliacao_fisica

Histórico de avaliações por paciente e data.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_avaliacao` | int unsigned | Não | AUTO_INCREMENT | PK (ver composição abaixo). Identificador de avaliacao. |
| `data_avaliacao` | date | Não | Sem padrão | Data da avaliação; única por paciente. |
| `nivel_dor` | tinyint unsigned | Não | Sem padrão | Inteiro de 0 a 10, conforme CHECK. |
| `amplitude_movimento` | varchar(100) | Sim | NULL | Descrição textual até 100 caracteres; unidade/padrão clínico não definido. |
| `observacoes` | text | Sim | NULL | Observações livres opcionais. |
| `id_paciente` | int unsigned | Não | Sem padrão | Identificador de paciente. |

### Chaves, índices e restrições

- PRIMARY KEY (id_avaliacao)
- UNIQUE KEY uq_avaliacao_paciente_data (id_paciente,data_avaliacao)
- KEY idx_avaliacao_dor (id_paciente,nivel_dor)
- CONSTRAINT fk_avaliacao_paciente FOREIGN KEY (id_paciente) REFERENCES paciente (id_paciente) ON DELETE CASCADE ON UPDATE CASCADE
- CONSTRAINT ck_avaliacao_nivel_dor CHECK ((nivel_dor between 0 and 10))

## 15. auditoria_evolucao

Registro técnico de alterações/exclusões de evolução; etapa 2.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_auditoria` | int unsigned | Não | AUTO_INCREMENT | PK (ver composição abaixo). Identificador de auditoria. |
| `id_tratamento` | int unsigned | Não | Sem padrão | Identificador de tratamento. |
| `numero_sessao` | int unsigned | Não | Sem padrão | Número positivo dentro do tratamento. Não há garantia de sequência sem lacunas. |
| `acao` | varchar(10) | Não | Sem padrão | Gatilhos registram UPDATE, DELETE ou DEL_CASC. VARCHAR sem CHECK de domínio. |
| `conduta_anterior` | text | Sim | NULL | Conduta antes da alteração/exclusão. |
| `conduta_nova` | text | Sim | NULL | Conduta após UPDATE; NULL na exclusão. |
| `resposta_anterior` | text | Sim | NULL | Resposta antes da alteração/exclusão. |
| `resposta_nova` | text | Sim | NULL | Resposta após UPDATE; NULL na exclusão. |
| `usuario_db` | varchar(288) | Não | Sem padrão | Usuário e host da conexão, obtidos por USER(); até 288 caracteres. |
| `data_hora` | datetime | Não | Sem padrão | Data/hora da sessão ou do evento de auditoria; DATETIME sem fuso armazenado. |

### Chaves, índices e restrições

- PRIMARY KEY (id_auditoria)

## View e gatilhos

`vw_paciente_restrito` expõe id_paciente, nome, data_nascimento e situacao. É uma projeção com SQL SECURITY DEFINER; não armazena cópia dos dados, não anonimiza o paciente e não limita linhas por supervisor. Não existe view gerencial consolidada nos scripts atuais.

A etapa 1 cria 11 gatilhos: dois de anti-autossupervisão, dois de nascimento, quatro de exclusividade dos subtipos, dois de evolução em sessão realizada e um de manutenção de situação da sessão com evolução. A etapa 2 cria quatro gatilhos de auditoria: UPDATE/DELETE de evolução e DELETE direto em sessão/tratamento. Auditoria não possui FK intencionalmente, para sobreviver às exclusões.

Os nomes de constraints e a ordem das colunas dos índices acima vêm de SHOW CREATE TABLE. A etapa 2 remove idx_avaliacao_paciente e mantém idx_avaliacao_dor, cujo prefixo atende a mesma FK. Os procedimentos auxiliares de índices são removidos ao final da etapa 2.

-- ==============================================================================
-- ETAPA 1 — CRIAÇÃO DO BANCO E ESTRUTURA (antigo 01_ddl.sql)
-- ==============================================================================

-- ============================================================
-- 01_ddl.sql
-- Projeto Final — Laboratório de Banco de Dados
-- Domínio: Clínica de Fisioterapia
-- SGBD: MySQL 8.0+
-- ============================================================

DROP DATABASE IF EXISTS clinica_fisioterapia;
CREATE DATABASE clinica_fisioterapia
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE clinica_fisioterapia;

-- RN24: nome do convênio é obrigatório e único.
CREATE TABLE convenio (
    id_convenio INT UNSIGNED AUTO_INCREMENT,
    nome VARCHAR(150) NOT NULL,

    CONSTRAINT pk_convenio PRIMARY KEY (id_convenio),
    CONSTRAINT uq_convenio_nome UNIQUE (nome)
) ENGINE=InnoDB;

-- RN01: CPF do paciente é único.
-- RN02: data de nascimento não pode ser futura.
-- RN04: situação do paciente é ATIVO ou INATIVO, com padrão ATIVO.
CREATE TABLE paciente (
    id_paciente INT UNSIGNED AUTO_INCREMENT,
    cpf CHAR(11) NOT NULL,
    nome VARCHAR(150) NOT NULL,
    data_nascimento DATE NOT NULL,
    telefone VARCHAR(20) NULL,
    situacao ENUM('ATIVO', 'INATIVO') NOT NULL DEFAULT 'ATIVO',
    id_convenio INT UNSIGNED NULL,

    CONSTRAINT pk_paciente PRIMARY KEY (id_paciente),
    CONSTRAINT uq_paciente_cpf UNIQUE (cpf),
    CONSTRAINT fk_paciente_convenio
        FOREIGN KEY (id_convenio)
        REFERENCES convenio (id_convenio)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- CONVENIO precisa ser criada antes de PACIENTE.


-- PROFISSIONAL é o supertipo da especialização.
CREATE TABLE profissional (
    id_profissional INT UNSIGNED AUTO_INCREMENT,
    nome VARCHAR(150) NOT NULL,
    cpf CHAR(11) NOT NULL,
    telefone VARCHAR(20) NULL,
    email VARCHAR(254) NULL,

    CONSTRAINT pk_profissional PRIMARY KEY (id_profissional),
    CONSTRAINT uq_profissional_cpf UNIQUE (cpf)
) ENGINE=InnoDB;

-- RN05/RN06: especialização total e exclusiva; CREFITO único e obrigatório.
CREATE TABLE fisioterapeuta (
    id_profissional INT UNSIGNED,
    crefito VARCHAR(30) NOT NULL,

    CONSTRAINT pk_fisioterapeuta PRIMARY KEY (id_profissional),
    CONSTRAINT uq_fisioterapeuta_crefito UNIQUE (crefito),
    CONSTRAINT fk_fisioterapeuta_profissional
        FOREIGN KEY (id_profissional)
        REFERENCES profissional (id_profissional)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- RN07: cada estagiário possui exatamente um supervisor.
CREATE TABLE estagiario (
    id_profissional INT UNSIGNED,
    instituicao_ensino VARCHAR(150) NOT NULL,
    id_supervisor INT UNSIGNED NOT NULL,

    CONSTRAINT pk_estagiario PRIMARY KEY (id_profissional),
    CONSTRAINT fk_estagiario_profissional
        FOREIGN KEY (id_profissional)
        REFERENCES profissional (id_profissional)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_estagiario_supervisor
        FOREIGN KEY (id_supervisor)
        REFERENCES fisioterapeuta (id_profissional)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB;

DELIMITER $$

CREATE TRIGGER ck_estagiario_nao_supervisiona_a_si_mesmo_ins
BEFORE INSERT ON estagiario
FOR EACH ROW
BEGIN
    IF NEW.id_supervisor = NEW.id_profissional THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Um estagiario nao pode supervisionar a si mesmo.';
    END IF;
END$$

CREATE TRIGGER ck_estagiario_nao_supervisiona_a_si_mesmo_upd
BEFORE UPDATE ON estagiario
FOR EACH ROW
BEGIN
    IF NEW.id_supervisor = NEW.id_profissional THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Um estagiario nao pode supervisionar a si mesmo.';
    END IF;
END$$

DELIMITER ;

CREATE TABLE especialidade (
    id_especialidade INT UNSIGNED AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT NULL,

    CONSTRAINT pk_especialidade PRIMARY KEY (id_especialidade),
    CONSTRAINT uq_especialidade_nome UNIQUE (nome)
) ENGINE=InnoDB;

-- RN08/RN09: N:N entre profissional e especialidade, com data da habilitação.
CREATE TABLE habilitacao_profissional (
    id_profissional INT UNSIGNED,
    id_especialidade INT UNSIGNED,
    data_habilitacao DATE NOT NULL,

    CONSTRAINT pk_habilitacao_profissional
        PRIMARY KEY (id_profissional, id_especialidade),
    CONSTRAINT fk_habilitacao_profissional
        FOREIGN KEY (id_profissional)
        REFERENCES profissional (id_profissional)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_habilitacao_especialidade
        FOREIGN KEY (id_especialidade)
        REFERENCES especialidade (id_especialidade)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- RN11/RN12: data de início obrigatória; alta pode ser nula, mas não anterior ao início.
-- As FKs abaixo usam a acao padrao do InnoDB (RESTRICT/NO ACTION).
-- Isso evita o erro 1215 observado ao combinar ON UPDATE CASCADE nesta tabela.
CREATE TABLE tratamento (
    id_tratamento INT UNSIGNED AUTO_INCREMENT,
    descricao_condicao VARCHAR(255) NOT NULL,
    data_inicio DATE NOT NULL,
    data_alta DATE NULL,
    id_paciente INT UNSIGNED NOT NULL,
    id_fisioterapeuta INT UNSIGNED NOT NULL,
    id_especialidade INT UNSIGNED NOT NULL,
    id_especialidade_em_andamento INT UNSIGNED
        GENERATED ALWAYS AS (CASE WHEN data_alta IS NULL THEN id_especialidade ELSE NULL END) STORED,

    CONSTRAINT pk_tratamento PRIMARY KEY (id_tratamento),
    CONSTRAINT uq_tratamento_paciente_especialidade_aberto
        UNIQUE (id_paciente, id_especialidade_em_andamento),
    CONSTRAINT fk_tratamento_paciente
        FOREIGN KEY (id_paciente)
        REFERENCES paciente (id_paciente),
    CONSTRAINT fk_tratamento_fisioterapeuta
        FOREIGN KEY (id_fisioterapeuta)
        REFERENCES fisioterapeuta (id_profissional),
    CONSTRAINT fk_tratamento_especialidade
        FOREIGN KEY (id_especialidade)
        REFERENCES especialidade (id_especialidade),
    CONSTRAINT ck_tratamento_datas
        CHECK (data_alta IS NULL OR data_alta >= data_inicio)
) ENGINE=InnoDB;

-- RN25: código da sala único e capacidade positiva.
CREATE TABLE sala (
    id_sala INT UNSIGNED AUTO_INCREMENT,
    codigo VARCHAR(30) NOT NULL,
    capacidade INT UNSIGNED NOT NULL,

    CONSTRAINT pk_sala PRIMARY KEY (id_sala),
    CONSTRAINT uq_sala_codigo UNIQUE (codigo),
    CONSTRAINT ck_sala_capacidade CHECK (capacidade > 0)
) ENGINE=InnoDB;

-- RN15/RN16/RN18: sessão é entidade fraca identificada por tratamento + número.
CREATE TABLE sessao (
    id_tratamento INT UNSIGNED,
    numero_sessao INT UNSIGNED,
    data_hora DATETIME NOT NULL,
    situacao ENUM('AGENDADA', 'REALIZADA', 'CANCELADA', 'FALTA')
        NOT NULL DEFAULT 'AGENDADA',
    id_sala INT UNSIGNED NOT NULL,

    CONSTRAINT pk_sessao PRIMARY KEY (id_tratamento, numero_sessao),
    CONSTRAINT fk_sessao_tratamento
        FOREIGN KEY (id_tratamento)
        REFERENCES tratamento (id_tratamento)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_sessao_sala
        FOREIGN KEY (id_sala)
        REFERENCES sala (id_sala)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT uq_sessao_sala_horario UNIQUE (id_sala, data_hora),
    CONSTRAINT ck_sessao_numero CHECK (numero_sessao > 0)
) ENGINE=InnoDB;

-- EVOLUCAO depende da sessão e deve existir no máximo uma vez por sessão.
CREATE TABLE evolucao (
    id_tratamento INT UNSIGNED,
    numero_sessao INT UNSIGNED,
    conduta_aplicada TEXT NOT NULL,
    resposta_observada TEXT NOT NULL,

    CONSTRAINT pk_evolucao PRIMARY KEY (id_tratamento, numero_sessao),
    CONSTRAINT fk_evolucao_sessao
        FOREIGN KEY (id_tratamento, numero_sessao)
        REFERENCES sessao (id_tratamento, numero_sessao)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- RN26: exercício com nome único.
CREATE TABLE exercicio (
    id_exercicio INT UNSIGNED AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    regiao_corpo VARCHAR(100) NOT NULL,
    descricao TEXT NULL,

    CONSTRAINT pk_exercicio PRIMARY KEY (id_exercicio),
    CONSTRAINT uq_exercicio_nome UNIQUE (nome)
) ENGINE=InnoDB;

-- RN20/RN21: N:N entre sessão e exercício, com séries, repetições e carga.
CREATE TABLE aplicacao_exercicio (
    id_tratamento INT UNSIGNED,
    numero_sessao INT UNSIGNED,
    id_exercicio INT UNSIGNED,
    series INT UNSIGNED NOT NULL,
    repeticoes INT UNSIGNED NOT NULL,
    carga DECIMAL(8,2) NULL,

    CONSTRAINT pk_aplicacao_exercicio
        PRIMARY KEY (id_tratamento, numero_sessao, id_exercicio),
    CONSTRAINT fk_aplicacao_sessao
        FOREIGN KEY (id_tratamento, numero_sessao)
        REFERENCES sessao (id_tratamento, numero_sessao)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_aplicacao_exercicio
        FOREIGN KEY (id_exercicio)
        REFERENCES exercicio (id_exercicio)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT ck_aplicacao_series CHECK (series > 0),
    CONSTRAINT ck_aplicacao_repeticoes CHECK (repeticoes > 0),
    CONSTRAINT ck_aplicacao_carga CHECK (carga IS NULL OR carga >= 0)
) ENGINE=InnoDB;

-- RN22/RN23: uma avaliação por paciente por data; dor entre 0 e 10.
CREATE TABLE avaliacao_fisica (
    id_avaliacao INT UNSIGNED AUTO_INCREMENT,
    data_avaliacao DATE NOT NULL,
    nivel_dor TINYINT UNSIGNED NOT NULL,
    amplitude_movimento VARCHAR(100) NULL,
    observacoes TEXT NULL,
    id_paciente INT UNSIGNED NOT NULL,

    CONSTRAINT pk_avaliacao_fisica PRIMARY KEY (id_avaliacao),
    CONSTRAINT fk_avaliacao_paciente
        FOREIGN KEY (id_paciente)
        REFERENCES paciente (id_paciente)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT uq_avaliacao_paciente_data UNIQUE (id_paciente, data_avaliacao),
    CONSTRAINT ck_avaliacao_nivel_dor CHECK (nivel_dor BETWEEN 0 AND 10)
) ENGINE=InnoDB;

-- Índices nomeados para FKs e consultas frequentes.
CREATE INDEX idx_paciente_convenio ON paciente (id_convenio);
CREATE INDEX idx_tratamento_paciente ON tratamento (id_paciente);
CREATE INDEX idx_tratamento_fisioterapeuta ON tratamento (id_fisioterapeuta);
CREATE INDEX idx_tratamento_especialidade ON tratamento (id_especialidade);
CREATE INDEX idx_sessao_sala ON sessao (id_sala);
CREATE INDEX idx_sessao_data_hora ON sessao (data_hora);
CREATE INDEX idx_avaliacao_paciente ON avaliacao_fisica (id_paciente);
CREATE INDEX idx_habilitacao_especialidade ON habilitacao_profissional (id_especialidade);
CREATE INDEX idx_aplicacao_exercicio ON aplicacao_exercicio (id_exercicio);

-- RN02: MySQL não permite CURRENT_DATE em uma expressão CHECK.
-- A regra é validada por gatilhos de INSERT e UPDATE.
DELIMITER $$

CREATE TRIGGER ck_paciente_data_nascimento_ins
BEFORE INSERT ON paciente
FOR EACH ROW
BEGIN
    IF NEW.data_nascimento > CURRENT_DATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A data de nascimento nao pode ser futura.';
    END IF;
END$$

CREATE TRIGGER ck_paciente_data_nascimento_upd
BEFORE UPDATE ON paciente
FOR EACH ROW
BEGIN
    IF NEW.data_nascimento > CURRENT_DATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A data de nascimento nao pode ser futura.';
    END IF;
END$$

-- RN05: impede que o mesmo profissional seja cadastrado nos dois subtipos.
-- A totalidade (todo profissional precisa pertencer a um subtipo) requer
-- alinhamento com o modelo lógico e não é garantida apenas por estas tabelas.
CREATE TRIGGER ck_profissional_exclusivo_fisio_ins
BEFORE INSERT ON fisioterapeuta
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM estagiario WHERE id_profissional = NEW.id_profissional) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O profissional ja esta cadastrado como estagiario.';
    END IF;
END$$

CREATE TRIGGER ck_profissional_exclusivo_fisio_upd
BEFORE UPDATE ON fisioterapeuta
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM estagiario WHERE id_profissional = NEW.id_profissional) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O profissional ja esta cadastrado como estagiario.';
    END IF;
END$$

CREATE TRIGGER ck_profissional_exclusivo_estagiario_ins
BEFORE INSERT ON estagiario
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM fisioterapeuta WHERE id_profissional = NEW.id_profissional) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O profissional ja esta cadastrado como fisioterapeuta.';
    END IF;
END$$

CREATE TRIGGER ck_profissional_exclusivo_estagiario_upd
BEFORE UPDATE ON estagiario
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM fisioterapeuta WHERE id_profissional = NEW.id_profissional) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O profissional ja esta cadastrado como fisioterapeuta.';
    END IF;
END$$

-- RN19: evolução somente para sessão REALIZADA.
CREATE TRIGGER ck_evolucao_sessao_realizada_ins
BEFORE INSERT ON evolucao
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM sessao
        WHERE id_tratamento = NEW.id_tratamento
          AND numero_sessao = NEW.numero_sessao
          AND situacao = 'REALIZADA'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Evolucao somente pode ser registrada para sessao REALIZADA.';
    END IF;
END$$

CREATE TRIGGER ck_evolucao_sessao_realizada_upd
BEFORE UPDATE ON evolucao
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM sessao
        WHERE id_tratamento = NEW.id_tratamento
          AND numero_sessao = NEW.numero_sessao
          AND situacao = 'REALIZADA'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Evolucao somente pode ser registrada para sessao REALIZADA.';
    END IF;
END$$

-- RN19: uma sessão com evolução não pode deixar de estar REALIZADA.
CREATE TRIGGER ck_sessao_evolucao_status_upd
BEFORE UPDATE ON sessao
FOR EACH ROW
BEGIN
    IF NEW.situacao <> 'REALIZADA'
       AND EXISTS (
           SELECT 1 FROM evolucao
           WHERE id_tratamento = OLD.id_tratamento
             AND numero_sessao = OLD.numero_sessao
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Sessao com evolucao registrada deve permanecer REALIZADA.';
    END IF;
END$$

DELIMITER ;


-- ==============================================================================
-- ETAPA 1 — CARGA DOS DADOS (antigo 02_Carga.sql) — versão corrigida
-- ==============================================================================

-- ============================================================
-- 02_carga.sql
-- Dados fictícios e plausíveis para a Clínica de Fisioterapia
-- Não utilizar dados pessoais reais.
--
-- Premissas de coerência desta carga (data de referência: 24/10/2026):
--  * sessões ficam dentro do período do tratamento (data_inicio .. data_alta);
--  * numero_sessao segue a ordem cronológica;
--  * sessões AGENDADA só existem em datas futuras e apenas em tratamentos em andamento;
--  * evolução e exercícios aplicados só existem em sessões REALIZADA;
--  * o fisioterapeuta de cada tratamento é habilitado na especialidade do tratamento;
--  * especialidade Pediátrica atende menores de 18 anos; Geriátrica, maiores de 60;
--  * pacientes INATIVO não possuem tratamento em andamento;
--  * fisioterapeutas têm quantidades diferentes de tratamentos (alguns nenhum).
-- ============================================================

USE clinica_fisioterapia;

INSERT INTO convenio (nome) VALUES
('Particular'),
('Unimed'),
('Bradesco Saúde'),
('SulAmérica'),
('Amil'),
('NotreDame Intermédica'),
('GEAP'),
('Saúde Caixa');

INSERT INTO paciente (cpf,nome,data_nascimento,telefone,situacao,id_convenio) VALUES
('10000000000', 'Ana Almeida', '1948-03-12', NULL, 'ATIVO', NULL),
('10000000001', 'Bruno Barbosa', '1952-07-21', '6199100001', 'ATIVO', 2),
('10000000002', 'Carlos Carvalho', '1955-11-05', '6199100002', 'ATIVO', 3),
('10000000003', 'Daniela Dias', '1960-05-30', '6199100003', 'ATIVO', 4),
('10000000004', 'Eduardo Ferreira', '1979-05-05', '6199100004', 'ATIVO', 5),
('10000000005', 'Fernanda Gomes', '1980-06-06', '6199100005', 'ATIVO', NULL),
('10000000006', 'Gabriel Lima', '1981-07-07', '6199100006', 'ATIVO', 7),
('10000000007', 'Helena Martins', '1982-08-08', NULL, 'INATIVO', 8),
('10000000008', 'Igor Nogueira', '1983-09-09', '6199100008', 'ATIVO', 1),
('10000000009', 'Juliana Oliveira', '1984-10-10', '6199100009', 'ATIVO', 2),
('10000000010', 'Lucas Pereira', '1985-11-11', '6199100010', 'ATIVO', NULL),
('10000000011', 'Mariana Ramos', '1986-12-12', '6199100011', 'ATIVO', 4),
('10000000012', 'Nicolas Santos', '1987-01-13', '6199100012', 'ATIVO', 5),
('10000000013', 'Olivia Teixeira', '1988-02-14', '6199100013', 'ATIVO', 6),
('10000000014', 'Paulo Vieira', '1989-03-15', NULL, 'ATIVO', 7),
('10000000015', 'Renata Almeida', '1990-04-16', '6199100015', 'ATIVO', NULL),
('10000000016', 'Samuel Barbosa', '1991-05-17', '6199100016', 'ATIVO', 1),
('10000000017', 'Tatiana Carvalho', '1992-06-18', '6199100017', 'ATIVO', 2),
('10000000018', 'Vinicius Dias', '1993-07-19', '6199100018', 'ATIVO', 3),
('10000000019', 'Yasmin Ferreira', '1994-08-20', '6199100019', 'ATIVO', 4),
('10000000020', 'Ana Gomes', '1995-09-21', '6199100020', 'ATIVO', NULL),
('10000000021', 'Bruno Lima', '1996-10-22', NULL, 'ATIVO', 6),
('10000000022', 'Carlos Martins', '1997-11-23', '6199100022', 'ATIVO', 7),
('10000000023', 'Daniela Nogueira', '1998-12-24', '6199100023', 'ATIVO', 8),
('10000000024', 'Eduardo Oliveira', '1999-01-25', '6199100024', 'ATIVO', 1),
('10000000025', 'Fernanda Pereira', '1975-02-26', '6199100025', 'ATIVO', NULL),
('10000000026', 'Gabriel Ramos', '1976-03-27', '6199100026', 'ATIVO', 3),
('10000000027', 'Helena Santos', '1977-04-01', '6199100027', 'ATIVO', 4),
('10000000028', 'Igor Teixeira', '1978-05-02', NULL, 'ATIVO', 5),
('10000000029', 'Juliana Vieira', '1979-06-03', '6199100029', 'ATIVO', 6),
('10000000030', 'Lucas Almeida', '1980-07-04', '6199100030', 'ATIVO', NULL),
('10000000031', 'Mariana Barbosa', '1981-08-05', '6199100031', 'INATIVO', 8),
('10000000032', 'Nicolas Carvalho', '1982-09-06', '6199100032', 'ATIVO', 1),
('10000000033', 'Olivia Dias', '1983-10-07', '6199100033', 'ATIVO', 2),
('10000000034', 'Paulo Ferreira', '1984-11-08', '6199100034', 'ATIVO', 3),
('10000000035', 'Renata Gomes', '1985-12-09', NULL, 'ATIVO', 8),
('10000000036', 'Samuel Lima', '1986-01-10', '6199100036', 'ATIVO', 5),
('10000000037', 'Tatiana Martins', '2015-04-13', '6199100037', 'ATIVO', 6),
('10000000038', 'Vinicius Nogueira', '2017-09-02', '6199100038', 'ATIVO', 7),
('10000000039', 'Yasmin Oliveira', '2019-01-18', '6199100039', 'ATIVO', 8);

INSERT INTO profissional (nome,cpf,telefone,email) VALUES
('Daniela Gomes','20000000000','6198200000',NULL),
('Eduardo Lima','20000000001','6198200001','prof2@clinica-fisio.test'),
('Fernanda Martins','20000000002','6198200002','prof3@clinica-fisio.test'),
('Gabriel Nogueira','20000000003','6198200003','prof4@clinica-fisio.test'),
('Helena Oliveira','20000000004','6198200004','prof5@clinica-fisio.test'),
('Igor Pereira','20000000005','6198200005','prof6@clinica-fisio.test'),
('Juliana Ramos','20000000006','6198200006','prof7@clinica-fisio.test'),
('Lucas Santos','20000000007','6198200007','prof8@clinica-fisio.test'),
('Mariana Teixeira','20000000008','6198200008','prof9@clinica-fisio.test'),
('Nicolas Vieira','20000000009','6198200009',NULL),
('Olivia Almeida','20000000010','6198200010','prof11@clinica-fisio.test'),
('Paulo Barbosa','20000000011','6198200011','prof12@clinica-fisio.test'),
('Renata Carvalho','20000000012','6198200012','prof13@clinica-fisio.test'),
('Samuel Dias','20000000013','6198200013','prof14@clinica-fisio.test'),
('Tatiana Ferreira','20000000014','6198200014','prof15@clinica-fisio.test'),
('Vinicius Gomes','20000000015','6198200015','prof16@clinica-fisio.test'),
('Yasmin Lima','20000000016','6198200016','prof17@clinica-fisio.test'),
('Ana Martins','20000000017','6198200017','prof18@clinica-fisio.test'),
('Bruno Nogueira','20000000018','6198200018',NULL),
('Carlos Oliveira','20000000019','6198200019','prof20@clinica-fisio.test'),
('Daniela Pereira','20000000020','6198200020','prof21@clinica-fisio.test'),
('Eduardo Ramos','20000000021','6198200021','prof22@clinica-fisio.test'),
('Fernanda Santos','20000000022','6198200022','prof23@clinica-fisio.test'),
('Gabriel Teixeira','20000000023','6198200023','prof24@clinica-fisio.test'),
('Helena Vieira','20000000024','6198200024','prof25@clinica-fisio.test'),
('Igor Almeida','20000000025','6198200025','prof26@clinica-fisio.test'),
('Juliana Barbosa','20000000026','6198200026','prof27@clinica-fisio.test'),
('Lucas Carvalho','20000000027','6198200027',NULL),
('Mariana Dias','20000000028','6198200028','prof29@clinica-fisio.test'),
('Nicolas Ferreira','20000000029','6198200029','prof30@clinica-fisio.test'),
('Olivia Gomes','20000000030','6198200030','prof31@clinica-fisio.test'),
('Paulo Lima','20000000031','6198200031','prof32@clinica-fisio.test'),
('Renata Martins','20000000032','6198200032','prof33@clinica-fisio.test'),
('Samuel Nogueira','20000000033','6198200033','prof34@clinica-fisio.test'),
('Tatiana Oliveira','20000000034','6198200034','prof35@clinica-fisio.test'),
('Vinicius Pereira','20000000035','6198200035','prof36@clinica-fisio.test'),
('Yasmin Ramos','20000000036','6198200036',NULL),
('Ana Santos','20000000037','6198200037','prof38@clinica-fisio.test'),
('Bruno Teixeira','20000000038','6198200038','prof39@clinica-fisio.test'),
('Carlos Vieira','20000000039','6198200039','prof40@clinica-fisio.test');

INSERT INTO fisioterapeuta (id_profissional,crefito) VALUES
(1,'CREFITO-00001-F'),
(2,'CREFITO-00002-F'),
(3,'CREFITO-00003-F'),
(4,'CREFITO-00004-F'),
(5,'CREFITO-00005-F'),
(6,'CREFITO-00006-F'),
(7,'CREFITO-00007-F'),
(8,'CREFITO-00008-F'),
(9,'CREFITO-00009-F'),
(10,'CREFITO-00010-F'),
(11,'CREFITO-00011-F'),
(12,'CREFITO-00012-F'),
(13,'CREFITO-00013-F'),
(14,'CREFITO-00014-F'),
(15,'CREFITO-00015-F'),
(16,'CREFITO-00016-F'),
(17,'CREFITO-00017-F'),
(18,'CREFITO-00018-F'),
(19,'CREFITO-00019-F'),
(20,'CREFITO-00020-F');

INSERT INTO estagiario (id_profissional,instituicao_ensino,id_supervisor) VALUES
(21,'Universidade Acadêmica de Brasília',1),
(22,'Universidade Acadêmica de Brasília',2),
(23,'Universidade Acadêmica de Brasília',3),
(24,'Universidade Acadêmica de Brasília',4),
(25,'Universidade Acadêmica de Brasília',5),
(26,'Universidade Acadêmica de Brasília',6),
(27,'Universidade Acadêmica de Brasília',7),
(28,'Universidade Acadêmica de Brasília',8),
(29,'Universidade Acadêmica de Brasília',9),
(30,'Universidade Acadêmica de Brasília',10),
(31,'Universidade Acadêmica de Brasília',11),
(32,'Universidade Acadêmica de Brasília',12),
(33,'Universidade Acadêmica de Brasília',13),
(34,'Universidade Acadêmica de Brasília',14),
(35,'Universidade Acadêmica de Brasília',15),
(36,'Universidade Acadêmica de Brasília',16),
(37,'Universidade Acadêmica de Brasília',17),
(38,'Universidade Acadêmica de Brasília',18),
(39,'Universidade Acadêmica de Brasília',19),
(40,'Universidade Acadêmica de Brasília',20);

INSERT INTO especialidade (nome,descricao) VALUES
('Ortopédica','Tratamentos do sistema musculoesquelético.'),
('Neurológica','Reabilitação neurológica.'),
('Desportiva','Reabilitação relacionada a atividades esportivas.'),
('Respiratória','Fisioterapia respiratória.'),
('Pediátrica','Atendimento fisioterapêutico infantil.'),
('Geriátrica','Atendimento e reabilitação de idosos.'),
('Cardiorrespiratória','Reabilitação cardiorrespiratória.'),
('Traumato-ortopédica','Reabilitação após traumas e lesões.');

INSERT INTO habilitacao_profissional (id_profissional,id_especialidade,data_habilitacao) VALUES
(1,1,'2024-01-15'),
(1,2,'2025-01-10'),
(2,2,'2024-02-15'),
(2,3,'2025-02-10'),
(3,3,'2024-03-15'),
(3,4,'2025-03-10'),
(4,4,'2024-04-15'),
(4,5,'2025-04-10'),
(5,5,'2024-05-15'),
(5,6,'2025-05-10'),
(6,6,'2024-06-15'),
(6,7,'2025-06-10'),
(7,7,'2024-07-15'),
(7,8,'2025-07-10'),
(8,8,'2024-08-15'),
(8,1,'2025-08-10'),
(9,1,'2024-09-15'),
(9,2,'2025-09-10'),
(10,2,'2024-10-15'),
(10,3,'2025-10-10'),
(11,3,'2024-11-15'),
(11,4,'2025-11-10'),
(12,4,'2024-12-15'),
(12,5,'2025-12-10'),
(13,5,'2024-01-15'),
(13,6,'2025-01-10'),
(14,6,'2024-02-15'),
(14,7,'2025-02-10'),
(15,7,'2024-03-15'),
(15,8,'2025-03-10'),
(16,8,'2024-04-15'),
(16,1,'2025-04-10'),
(17,1,'2024-05-15'),
(17,2,'2025-05-10'),
(18,2,'2024-06-15'),
(18,3,'2025-06-10'),
(19,3,'2024-07-15'),
(19,4,'2025-07-10'),
(20,4,'2024-08-15'),
(20,5,'2025-08-10');

INSERT INTO tratamento (descricao_condicao,data_inicio,data_alta,id_paciente,id_fisioterapeuta,id_especialidade) VALUES
('Dor lombar crônica', '2026-01-19', '2026-02-17', 15, 1, 1),
('Tendinopatia patelar', '2026-01-26', '2026-04-22', 8, 3, 3),
('Tendinopatia patelar', '2026-02-04', '2026-04-02', 16, 3, 3),
('Reabilitação pós-AVC', '2026-02-18', '2026-05-01', 26, 10, 2),
('Tendinopatia patelar', '2026-03-16', '2026-04-20', 18, 11, 3),
('Insuficiência cardíaca - condicionamento', '2026-04-09', '2026-07-04', 19, 14, 7),
('Lombociatalgia', '2026-04-13', '2026-05-21', 2, 16, 1),
('Neuropatia periférica', '2026-04-20', '2026-06-02', 24, 18, 2),
('Tendinopatia patelar', '2026-04-20', '2026-05-28', 34, 18, 3),
('Luxação de ombro - pós-imobilização', '2026-05-13', '2026-06-04', 6, 8, 8),
('Reabilitação pós-AVC', '2026-05-14', '2026-08-08', 27, 10, 2),
('Reabilitação pulmonar pós-COVID', '2026-05-25', '2026-07-07', 7, 4, 4),
('Reabilitação de lesão do ligamento cruzado anterior', '2026-06-01', '2026-06-30', 25, 10, 3),
('Reabilitação pós-AVC', '2026-06-03', '2026-08-12', 32, 18, 2),
('Lesão muscular de coxa', '2026-06-05', '2026-07-19', 29, 3, 3),
('Torcicolo congênito', '2026-06-08', '2026-07-29', 39, 20, 5),
('Reabilitação cardíaca pós-infarto', '2026-06-25', '2026-07-18', 28, 6, 7),
('Torcicolo congênito', '2026-07-06', '2026-08-11', 40, 4, 5),
('Insuficiência cardíaca - condicionamento', '2026-07-23', '2026-08-21', 21, 7, 7),
('Reabilitação de lesão do ligamento cruzado anterior', '2026-08-03', '2026-09-08', 14, 10, 3),
('Reabilitação pós-AVC', '2026-08-06', '2026-08-27', 36, 10, 2),
('DPOC - reabilitação respiratória', '2026-08-20', '2026-10-09', 35, 12, 4),
('Pós-operatório de cirurgia cardíaca', '2026-08-24', '2026-09-15', 33, 14, 7),
('Fortalecimento e prevenção de quedas', '2026-09-07', NULL, 3, 6, 6),
('Síndrome do impacto do ombro', '2026-09-11', NULL, 1, 17, 1),
('Reabilitação de fratura de quadril', '2026-09-11', NULL, 4, 14, 6),
('Torcicolo congênito', '2026-09-11', NULL, 38, 13, 5),
('Dor lombar crônica', '2026-09-14', '2026-10-13', 20, 16, 1),
('Pós-operatório de artroplastia de joelho', '2026-09-15', NULL, 17, 9, 1),
('Entorse de tornozelo grau II', '2026-09-16', NULL, 23, 16, 8),
('Reabilitação pulmonar pós-COVID', '2026-09-18', NULL, 12, 3, 4),
('Doença de Parkinson - reabilitação motora', '2026-09-18', NULL, 37, 18, 2),
('Recuperação pós-pneumonia', '2026-09-25', NULL, 22, 12, 4),
('Doença de Parkinson - reabilitação motora', '2026-09-30', NULL, 9, 1, 2),
('Insuficiência cardíaca - condicionamento', '2026-10-05', NULL, 11, 7, 7),
('Doença de Parkinson - reabilitação motora', '2026-10-05', NULL, 30, 2, 2),
('Reabilitação pós-AVC', '2026-10-05', NULL, 31, 2, 2),
('Fratura de rádio distal', '2026-10-12', NULL, 5, 8, 8),
('Reabilitação pulmonar pós-COVID', '2026-10-14', NULL, 13, 19, 4),
('Reabilitação de lesão do ligamento cruzado anterior', '2026-10-16', NULL, 10, 2, 3);

INSERT INTO sala (codigo,capacidade) VALUES
('Sala 01',4),
('Sala 02',4),
('Sala 03',3),
('Sala 04',2),
('Sala 05',4),
('Sala 06',3),
('Sala 07',2),
('Sala 08',5);

INSERT INTO sessao (id_tratamento,numero_sessao,data_hora,situacao,id_sala) VALUES
(1, 1, '2026-01-19 10:00:00', 'REALIZADA', 1),
(1, 2, '2026-01-27 10:00:00', 'REALIZADA', 1),
(1, 3, '2026-02-02 10:00:00', 'REALIZADA', 1),
(1, 4, '2026-02-09 10:00:00', 'REALIZADA', 1),
(1, 5, '2026-02-16 10:00:00', 'REALIZADA', 1),
(2, 1, '2026-01-26 11:00:00', 'REALIZADA', 6),
(2, 2, '2026-02-09 11:00:00', 'REALIZADA', 6),
(2, 3, '2026-02-23 11:00:00', 'REALIZADA', 6),
(2, 4, '2026-03-09 11:00:00', 'CANCELADA', 6),
(2, 5, '2026-03-23 11:00:00', 'FALTA', 6),
(2, 6, '2026-04-06 11:00:00', 'REALIZADA', 6),
(2, 7, '2026-04-21 11:00:00', 'REALIZADA', 6),
(3, 1, '2026-02-04 13:00:00', 'REALIZADA', 4),
(3, 2, '2026-02-19 13:00:00', 'FALTA', 4),
(3, 3, '2026-03-04 13:00:00', 'REALIZADA', 4),
(3, 4, '2026-03-18 13:00:00', 'CANCELADA', 4),
(3, 5, '2026-04-02 13:00:00', 'REALIZADA', 4),
(4, 1, '2026-02-18 12:00:00', 'REALIZADA', 1),
(4, 2, '2026-03-04 12:00:00', 'REALIZADA', 1),
(4, 3, '2026-03-19 12:00:00', 'REALIZADA', 1),
(4, 4, '2026-04-01 12:00:00', 'REALIZADA', 1),
(4, 5, '2026-04-16 12:00:00', 'CANCELADA', 1),
(4, 6, '2026-04-29 12:00:00', 'REALIZADA', 1),
(5, 1, '2026-03-16 09:00:00', 'REALIZADA', 4),
(5, 2, '2026-03-23 09:00:00', 'REALIZADA', 4),
(5, 3, '2026-03-30 09:00:00', 'REALIZADA', 4),
(5, 4, '2026-04-06 09:00:00', 'FALTA', 4),
(5, 5, '2026-04-13 09:00:00', 'REALIZADA', 4),
(5, 6, '2026-04-20 09:00:00', 'REALIZADA', 4),
(6, 1, '2026-04-09 10:00:00', 'REALIZADA', 4),
(6, 2, '2026-04-24 10:00:00', 'REALIZADA', 4),
(6, 3, '2026-05-07 10:00:00', 'REALIZADA', 4),
(6, 4, '2026-05-21 10:00:00', 'REALIZADA', 4),
(6, 5, '2026-06-05 10:00:00', 'REALIZADA', 4),
(6, 6, '2026-06-19 10:00:00', 'REALIZADA', 4),
(6, 7, '2026-07-02 10:00:00', 'REALIZADA', 4),
(7, 1, '2026-04-13 16:00:00', 'REALIZADA', 1),
(7, 2, '2026-04-21 16:00:00', 'REALIZADA', 1),
(7, 3, '2026-04-28 16:00:00', 'REALIZADA', 1),
(7, 4, '2026-05-05 16:00:00', 'REALIZADA', 1),
(7, 5, '2026-05-11 16:00:00', 'REALIZADA', 1),
(7, 6, '2026-05-19 16:00:00', 'REALIZADA', 1),
(8, 1, '2026-04-20 15:00:00', 'REALIZADA', 4),
(8, 2, '2026-04-27 15:00:00', 'REALIZADA', 4),
(8, 3, '2026-05-04 15:00:00', 'REALIZADA', 4),
(8, 4, '2026-05-11 15:00:00', 'REALIZADA', 4),
(8, 5, '2026-05-18 15:00:00', 'REALIZADA', 4),
(8, 6, '2026-05-26 15:00:00', 'REALIZADA', 4),
(8, 7, '2026-06-02 15:00:00', 'REALIZADA', 4),
(9, 1, '2026-04-20 12:00:00', 'REALIZADA', 5),
(9, 2, '2026-04-27 12:00:00', 'REALIZADA', 5),
(9, 3, '2026-05-04 12:00:00', 'REALIZADA', 5),
(9, 4, '2026-05-11 12:00:00', 'REALIZADA', 5),
(9, 5, '2026-05-18 12:00:00', 'REALIZADA', 5),
(9, 6, '2026-05-26 12:00:00', 'REALIZADA', 5),
(10, 1, '2026-05-13 14:00:00', 'REALIZADA', 1),
(10, 2, '2026-05-20 14:00:00', 'REALIZADA', 1),
(10, 3, '2026-05-27 14:00:00', 'REALIZADA', 1),
(10, 4, '2026-06-04 14:00:00', 'REALIZADA', 1),
(11, 1, '2026-05-14 16:00:00', 'REALIZADA', 8),
(11, 2, '2026-05-28 16:00:00', 'REALIZADA', 8),
(11, 3, '2026-06-11 16:00:00', 'REALIZADA', 8),
(11, 4, '2026-06-25 16:00:00', 'REALIZADA', 8),
(11, 5, '2026-07-09 16:00:00', 'REALIZADA', 8),
(11, 6, '2026-07-23 16:00:00', 'REALIZADA', 8),
(11, 7, '2026-08-06 16:00:00', 'REALIZADA', 8),
(12, 1, '2026-05-25 10:00:00', 'REALIZADA', 7),
(12, 2, '2026-06-02 10:00:00', 'REALIZADA', 7),
(12, 3, '2026-06-08 10:00:00', 'CANCELADA', 7),
(12, 4, '2026-06-16 10:00:00', 'REALIZADA', 7),
(12, 5, '2026-06-23 10:00:00', 'REALIZADA', 7),
(12, 6, '2026-06-29 10:00:00', 'REALIZADA', 7),
(12, 7, '2026-07-06 10:00:00', 'REALIZADA', 7),
(13, 1, '2026-06-01 14:00:00', 'REALIZADA', 3),
(13, 2, '2026-06-08 14:00:00', 'REALIZADA', 3),
(13, 3, '2026-06-15 14:00:00', 'REALIZADA', 3),
(13, 4, '2026-06-23 14:00:00', 'REALIZADA', 3),
(13, 5, '2026-06-29 14:00:00', 'REALIZADA', 3),
(14, 1, '2026-06-03 10:00:00', 'REALIZADA', 1),
(14, 2, '2026-06-17 10:00:00', 'CANCELADA', 1),
(14, 3, '2026-07-01 10:00:00', 'REALIZADA', 1),
(14, 4, '2026-07-15 10:00:00', 'REALIZADA', 1),
(14, 5, '2026-07-30 10:00:00', 'REALIZADA', 1),
(14, 6, '2026-08-12 10:00:00', 'REALIZADA', 1),
(15, 1, '2026-06-05 11:00:00', 'REALIZADA', 2),
(15, 2, '2026-06-12 11:00:00', 'REALIZADA', 2),
(15, 3, '2026-06-19 11:00:00', 'REALIZADA', 2),
(15, 4, '2026-06-26 11:00:00', 'CANCELADA', 2),
(15, 5, '2026-07-03 11:00:00', 'REALIZADA', 2),
(15, 6, '2026-07-10 11:00:00', 'REALIZADA', 2),
(15, 7, '2026-07-17 11:00:00', 'REALIZADA', 2),
(16, 1, '2026-06-08 10:00:00', 'REALIZADA', 5),
(16, 2, '2026-06-15 10:00:00', 'REALIZADA', 5),
(16, 3, '2026-06-22 10:00:00', 'REALIZADA', 5),
(16, 4, '2026-06-30 10:00:00', 'REALIZADA', 5),
(16, 5, '2026-07-06 10:00:00', 'REALIZADA', 5),
(16, 6, '2026-07-13 10:00:00', 'REALIZADA', 5),
(16, 7, '2026-07-20 10:00:00', 'REALIZADA', 5),
(16, 8, '2026-07-27 10:00:00', 'REALIZADA', 5),
(17, 1, '2026-06-25 10:00:00', 'REALIZADA', 5),
(17, 2, '2026-07-03 10:00:00', 'CANCELADA', 5),
(17, 3, '2026-07-09 10:00:00', 'REALIZADA', 5),
(17, 4, '2026-07-16 10:00:00', 'REALIZADA', 5),
(18, 1, '2026-07-06 16:00:00', 'REALIZADA', 3),
(18, 2, '2026-07-14 16:00:00', 'REALIZADA', 3),
(18, 3, '2026-07-20 16:00:00', 'REALIZADA', 3),
(18, 4, '2026-07-27 16:00:00', 'REALIZADA', 3),
(18, 5, '2026-08-03 16:00:00', 'REALIZADA', 3),
(18, 6, '2026-08-10 16:00:00', 'REALIZADA', 3),
(19, 1, '2026-07-23 13:00:00', 'REALIZADA', 5),
(19, 2, '2026-07-31 13:00:00', 'CANCELADA', 5),
(19, 3, '2026-08-06 13:00:00', 'CANCELADA', 5),
(19, 4, '2026-08-14 13:00:00', 'REALIZADA', 5),
(19, 5, '2026-08-20 13:00:00', 'REALIZADA', 5),
(20, 1, '2026-08-03 12:00:00', 'REALIZADA', 7),
(20, 2, '2026-08-10 12:00:00', 'REALIZADA', 7),
(20, 3, '2026-08-17 12:00:00', 'REALIZADA', 7),
(20, 4, '2026-08-25 12:00:00', 'REALIZADA', 7),
(20, 5, '2026-08-31 12:00:00', 'REALIZADA', 7),
(20, 6, '2026-09-08 12:00:00', 'REALIZADA', 7),
(21, 1, '2026-08-06 12:00:00', 'REALIZADA', 3),
(21, 2, '2026-08-14 12:00:00', 'CANCELADA', 3),
(21, 3, '2026-08-20 12:00:00', 'REALIZADA', 3),
(21, 4, '2026-08-27 12:00:00', 'REALIZADA', 3),
(22, 1, '2026-08-20 14:00:00', 'REALIZADA', 5),
(22, 2, '2026-08-27 14:00:00', 'CANCELADA', 5),
(22, 3, '2026-09-03 14:00:00', 'REALIZADA', 5),
(22, 4, '2026-09-10 14:00:00', 'REALIZADA', 5),
(22, 5, '2026-09-17 14:00:00', 'REALIZADA', 5),
(22, 6, '2026-09-24 14:00:00', 'REALIZADA', 5),
(22, 7, '2026-10-01 14:00:00', 'CANCELADA', 5),
(22, 8, '2026-10-08 14:00:00', 'REALIZADA', 5),
(23, 1, '2026-08-24 10:00:00', 'REALIZADA', 4),
(23, 2, '2026-08-31 10:00:00', 'REALIZADA', 4),
(23, 3, '2026-09-08 10:00:00', 'REALIZADA', 4),
(23, 4, '2026-09-15 10:00:00', 'REALIZADA', 4),
(24, 1, '2026-09-07 11:00:00', 'REALIZADA', 8),
(24, 2, '2026-09-21 11:00:00', 'FALTA', 8),
(24, 3, '2026-10-05 11:00:00', 'REALIZADA', 8),
(24, 4, '2026-10-20 11:00:00', 'REALIZADA', 8),
(24, 5, '2026-11-02 11:00:00', 'AGENDADA', 8),
(24, 6, '2026-11-16 11:00:00', 'AGENDADA', 8),
(25, 1, '2026-09-11 15:00:00', 'REALIZADA', 3),
(25, 2, '2026-09-18 15:00:00', 'CANCELADA', 3),
(25, 3, '2026-09-25 15:00:00', 'REALIZADA', 3),
(25, 4, '2026-10-02 15:00:00', 'REALIZADA', 3),
(25, 5, '2026-10-09 15:00:00', 'REALIZADA', 3),
(25, 6, '2026-10-16 15:00:00', 'REALIZADA', 3),
(25, 7, '2026-10-23 15:00:00', 'REALIZADA', 3),
(25, 8, '2026-10-30 15:00:00', 'AGENDADA', 3),
(25, 9, '2026-11-06 15:00:00', 'AGENDADA', 3),
(26, 1, '2026-09-11 08:00:00', 'REALIZADA', 7),
(26, 2, '2026-09-18 08:00:00', 'REALIZADA', 7),
(26, 3, '2026-09-25 08:00:00', 'FALTA', 7),
(26, 4, '2026-10-02 08:00:00', 'REALIZADA', 7),
(26, 5, '2026-10-09 08:00:00', 'CANCELADA', 7),
(26, 6, '2026-10-16 08:00:00', 'FALTA', 7),
(26, 7, '2026-10-23 08:00:00', 'REALIZADA', 7),
(26, 8, '2026-10-30 08:00:00', 'AGENDADA', 7),
(26, 9, '2026-11-06 08:00:00', 'AGENDADA', 7),
(27, 1, '2026-09-11 16:00:00', 'REALIZADA', 5),
(27, 2, '2026-09-25 16:00:00', 'REALIZADA', 5),
(27, 3, '2026-10-09 16:00:00', 'CANCELADA', 5),
(27, 4, '2026-10-23 16:00:00', 'REALIZADA', 5),
(27, 5, '2026-11-06 16:00:00', 'AGENDADA', 5),
(27, 6, '2026-11-20 16:00:00', 'AGENDADA', 5),
(28, 1, '2026-09-14 10:00:00', 'REALIZADA', 5),
(28, 2, '2026-09-21 10:00:00', 'REALIZADA', 5),
(28, 3, '2026-09-28 10:00:00', 'REALIZADA', 5),
(28, 4, '2026-10-05 10:00:00', 'REALIZADA', 5),
(28, 5, '2026-10-13 10:00:00', 'REALIZADA', 5),
(29, 1, '2026-09-15 08:00:00', 'REALIZADA', 6),
(29, 2, '2026-09-22 08:00:00', 'REALIZADA', 6),
(29, 3, '2026-09-29 08:00:00', 'REALIZADA', 6),
(29, 4, '2026-10-06 08:00:00', 'REALIZADA', 6),
(29, 5, '2026-10-13 08:00:00', 'REALIZADA', 6),
(29, 6, '2026-10-21 08:00:00', 'REALIZADA', 6),
(29, 7, '2026-10-27 08:00:00', 'AGENDADA', 6),
(29, 8, '2026-11-04 08:00:00', 'AGENDADA', 6),
(30, 1, '2026-09-16 08:00:00', 'REALIZADA', 3),
(30, 2, '2026-09-30 08:00:00', 'REALIZADA', 3),
(30, 3, '2026-10-14 08:00:00', 'REALIZADA', 3),
(30, 4, '2026-10-28 08:00:00', 'AGENDADA', 3),
(30, 5, '2026-11-11 08:00:00', 'AGENDADA', 3),
(31, 1, '2026-09-18 11:00:00', 'REALIZADA', 3),
(31, 2, '2026-09-25 11:00:00', 'REALIZADA', 3),
(31, 3, '2026-10-02 11:00:00', 'REALIZADA', 3),
(31, 4, '2026-10-09 11:00:00', 'REALIZADA', 3),
(31, 5, '2026-10-16 11:00:00', 'CANCELADA', 3),
(31, 6, '2026-10-23 11:00:00', 'REALIZADA', 3),
(31, 7, '2026-10-30 11:00:00', 'AGENDADA', 3),
(31, 8, '2026-11-06 11:00:00', 'AGENDADA', 3),
(32, 1, '2026-09-18 14:00:00', 'REALIZADA', 3),
(32, 2, '2026-09-25 14:00:00', 'REALIZADA', 3),
(32, 3, '2026-10-02 14:00:00', 'REALIZADA', 3),
(32, 4, '2026-10-09 14:00:00', 'REALIZADA', 3),
(32, 5, '2026-10-16 14:00:00', 'REALIZADA', 3),
(32, 6, '2026-10-23 14:00:00', 'REALIZADA', 3),
(32, 7, '2026-10-30 14:00:00', 'AGENDADA', 3),
(32, 8, '2026-11-06 14:00:00', 'AGENDADA', 3),
(33, 1, '2026-09-25 12:00:00', 'REALIZADA', 4),
(33, 2, '2026-10-02 12:00:00', 'REALIZADA', 4),
(33, 3, '2026-10-09 12:00:00', 'REALIZADA', 4),
(33, 4, '2026-10-16 12:00:00', 'REALIZADA', 4),
(33, 5, '2026-10-23 12:00:00', 'REALIZADA', 4),
(33, 6, '2026-10-30 12:00:00', 'AGENDADA', 4),
(33, 7, '2026-11-06 12:00:00', 'AGENDADA', 4),
(34, 1, '2026-09-30 12:00:00', 'REALIZADA', 6),
(34, 2, '2026-10-07 12:00:00', 'CANCELADA', 6),
(34, 3, '2026-10-14 12:00:00', 'REALIZADA', 6),
(34, 4, '2026-10-22 12:00:00', 'REALIZADA', 6),
(34, 5, '2026-10-29 12:00:00', 'AGENDADA', 6),
(34, 6, '2026-11-05 12:00:00', 'AGENDADA', 6),
(35, 1, '2026-10-05 10:00:00', 'REALIZADA', 6),
(35, 2, '2026-10-19 10:00:00', 'REALIZADA', 6),
(35, 3, '2026-11-03 10:00:00', 'AGENDADA', 6),
(35, 4, '2026-11-16 10:00:00', 'AGENDADA', 6),
(36, 1, '2026-10-05 09:00:00', 'REALIZADA', 8),
(36, 2, '2026-10-12 09:00:00', 'REALIZADA', 8),
(36, 3, '2026-10-19 09:00:00', 'REALIZADA', 8),
(36, 4, '2026-10-26 09:00:00', 'AGENDADA', 8),
(36, 5, '2026-11-02 09:00:00', 'AGENDADA', 8),
(37, 1, '2026-10-05 13:00:00', 'REALIZADA', 3),
(37, 2, '2026-10-13 13:00:00', 'REALIZADA', 3),
(37, 3, '2026-10-19 13:00:00', 'REALIZADA', 3),
(37, 4, '2026-10-27 13:00:00', 'AGENDADA', 3),
(37, 5, '2026-11-02 13:00:00', 'AGENDADA', 3),
(38, 1, '2026-10-12 15:00:00', 'REALIZADA', 3),
(38, 2, '2026-10-19 15:00:00', 'REALIZADA', 3),
(38, 3, '2026-10-27 15:00:00', 'AGENDADA', 3),
(38, 4, '2026-11-02 15:00:00', 'AGENDADA', 3),
(39, 1, '2026-10-14 12:00:00', 'REALIZADA', 7),
(39, 2, '2026-10-28 12:00:00', 'AGENDADA', 6),
(39, 3, '2026-11-11 12:00:00', 'AGENDADA', 6),
(40, 1, '2026-10-16 16:00:00', 'REALIZADA', 7),
(40, 2, '2026-10-30 16:00:00', 'AGENDADA', 7),
(40, 3, '2026-11-13 16:00:00', 'AGENDADA', 7);

INSERT INTO evolucao (id_tratamento,numero_sessao,conduta_aplicada,resposta_observada) VALUES
(1, 1, 'Aplicação de elevação pélvica, agachamento assistido, associada a terapia manual e cinesioterapia.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(1, 2, 'Aplicação de elevação pélvica, alongamento de panturrilha, agachamento assistido, associada a terapia manual e cinesioterapia.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(1, 3, 'Aplicação de alongamento de panturrilha, agachamento assistido, associada a terapia manual e cinesioterapia.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(1, 4, 'Aplicação de ponte unilateral, alongamento de panturrilha, associada a terapia manual e cinesioterapia.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(1, 5, 'Aplicação de alongamento de panturrilha, ponte unilateral, agachamento assistido, associada a terapia manual e cinesioterapia.', 'Paciente praticamente assintomático e com função recuperada.'),
(2, 1, 'Aplicação de agachamento assistido, alongamento de panturrilha, associada a fortalecimento específico e controle neuromuscular.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(2, 2, 'Aplicação de flexão de joelho, agachamento assistido, associada a fortalecimento específico e controle neuromuscular.', 'Boa evolução funcional; mantida a progressão planejada.'),
(2, 3, 'Aplicação de extensão de joelho, agachamento assistido, flexão de joelho, associada a fortalecimento específico e controle neuromuscular.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(2, 6, 'Aplicação de flexão de joelho, alongamento de panturrilha, agachamento assistido, associada a fortalecimento específico e controle neuromuscular.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(2, 7, 'Aplicação de alongamento de panturrilha, extensão de joelho, associada a fortalecimento específico e controle neuromuscular.', 'Resultados compatíveis com os objetivos do tratamento; paciente com bom controle motor.'),
(3, 1, 'Aplicação de extensão de joelho, agachamento assistido, associada a fortalecimento específico e controle neuromuscular.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(3, 3, 'Aplicação de flexão de joelho, alongamento de panturrilha, associada a fortalecimento específico e controle neuromuscular.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(3, 5, 'Aplicação de alongamento de panturrilha, agachamento assistido, extensão de joelho, associada a fortalecimento específico e controle neuromuscular.', 'Resultados compatíveis com os objetivos do tratamento; paciente com bom controle motor.'),
(4, 1, 'Aplicação de mobilização de tornozelo, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(4, 2, 'Aplicação de marcha estacionária, ponte unilateral, mobilização de tornozelo, associada a estimulação sensório-motora e treino de marcha.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(4, 4, 'Aplicação de marcha estacionária, ponte unilateral, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(4, 6, 'Aplicação de mobilização de tornozelo, marcha estacionária, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Ganhos mantidos; orientado a seguir o programa domiciliar.'),
(5, 1, 'Aplicação de extensão de joelho, flexão de joelho, agachamento assistido, associada a fortalecimento específico e controle neuromuscular.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(5, 2, 'Aplicação de extensão de joelho, alongamento de panturrilha, associada a fortalecimento específico e controle neuromuscular.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(5, 5, 'Aplicação de extensão de joelho, flexão de joelho, alongamento de panturrilha, associada a fortalecimento específico e controle neuromuscular.', 'Boa evolução funcional; mantida a progressão planejada.'),
(5, 6, 'Aplicação de extensão de joelho, alongamento de panturrilha, flexão de joelho, associada a fortalecimento específico e controle neuromuscular.', 'Paciente praticamente assintomático e com função recuperada.'),
(6, 1, 'Aplicação de alongamento de panturrilha, exercício respiratório diafragmático, marcha estacionária, associada a condicionamento aeróbico monitorado.', 'Resposta inicial satisfatória; orientado quanto à execução correta dos movimentos.'),
(6, 2, 'Aplicação de marcha estacionária, alongamento de panturrilha, associada a condicionamento aeróbico monitorado.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(6, 3, 'Aplicação de alongamento de panturrilha, marcha estacionária, associada a condicionamento aeróbico monitorado.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(6, 4, 'Aplicação de marcha estacionária, alongamento de panturrilha, exercício respiratório diafragmático, associada a condicionamento aeróbico monitorado.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(6, 5, 'Aplicação de exercício respiratório diafragmático, marcha estacionária, alongamento de panturrilha, associada a condicionamento aeróbico monitorado.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(6, 6, 'Aplicação de alongamento de panturrilha, exercício respiratório diafragmático, associada a condicionamento aeróbico monitorado.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(6, 7, 'Aplicação de alongamento de panturrilha, exercício respiratório diafragmático, marcha estacionária, associada a condicionamento aeróbico monitorado.', 'Paciente praticamente assintomático e com função recuperada.'),
(7, 1, 'Aplicação de agachamento assistido, elevação pélvica, associada a terapia manual e cinesioterapia.', 'Resposta inicial satisfatória; orientado quanto à execução correta dos movimentos.'),
(7, 2, 'Aplicação de ponte unilateral, agachamento assistido, associada a terapia manual e cinesioterapia.', 'Boa evolução funcional; mantida a progressão planejada.'),
(7, 3, 'Aplicação de alongamento de panturrilha, agachamento assistido, elevação pélvica, associada a terapia manual e cinesioterapia.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(7, 4, 'Aplicação de ponte unilateral, agachamento assistido, alongamento de panturrilha, associada a terapia manual e cinesioterapia.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(7, 6, 'Aplicação de agachamento assistido, alongamento de panturrilha, associada a terapia manual e cinesioterapia.', 'Paciente praticamente assintomático e com função recuperada.'),
(8, 1, 'Aplicação de alongamento de panturrilha, mobilização de tornozelo, marcha estacionária, associada a estimulação sensório-motora e treino de marcha.', 'Paciente colaborativo, referiu desconforto leve que cedeu ao repouso.'),
(8, 2, 'Aplicação de mobilização de tornozelo, alongamento de panturrilha, associada a estimulação sensório-motora e treino de marcha.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(8, 3, 'Aplicação de marcha estacionária, alongamento de panturrilha, associada a estimulação sensório-motora e treino de marcha.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(8, 4, 'Aplicação de marcha estacionária, mobilização de tornozelo, associada a estimulação sensório-motora e treino de marcha.', 'Boa evolução funcional; mantida a progressão planejada.'),
(8, 5, 'Aplicação de marcha estacionária, mobilização de tornozelo, alongamento de panturrilha, associada a estimulação sensório-motora e treino de marcha.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(8, 6, 'Aplicação de alongamento de panturrilha, marcha estacionária, associada a estimulação sensório-motora e treino de marcha.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(8, 7, 'Aplicação de alongamento de panturrilha, mobilização de tornozelo, associada a estimulação sensório-motora e treino de marcha.', 'Resultados compatíveis com os objetivos do tratamento; paciente com bom controle motor.'),
(9, 1, 'Aplicação de agachamento assistido, flexão de joelho, associada a fortalecimento específico e controle neuromuscular.', 'Paciente colaborativo, referiu desconforto leve que cedeu ao repouso.'),
(9, 2, 'Aplicação de alongamento de panturrilha, agachamento assistido, associada a fortalecimento específico e controle neuromuscular.', 'Boa evolução funcional; mantida a progressão planejada.'),
(9, 4, 'Aplicação de extensão de joelho, alongamento de panturrilha, associada a fortalecimento específico e controle neuromuscular.', 'Boa evolução funcional; mantida a progressão planejada.'),
(9, 5, 'Aplicação de agachamento assistido, extensão de joelho, alongamento de panturrilha, associada a fortalecimento específico e controle neuromuscular.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(9, 6, 'Aplicação de extensão de joelho, agachamento assistido, associada a fortalecimento específico e controle neuromuscular.', 'Resultados compatíveis com os objetivos do tratamento; paciente com bom controle motor.'),
(10, 1, 'Aplicação de flexão de ombro, rotação externa de ombro, abdução de ombro, associada a mobilização articular e ganho de amplitude.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(10, 2, 'Aplicação de flexão de ombro, rotação externa de ombro, abdução de ombro, associada a mobilização articular e ganho de amplitude.', 'Boa evolução funcional; mantida a progressão planejada.'),
(10, 3, 'Aplicação de rotação externa de ombro, flexão de ombro, associada a mobilização articular e ganho de amplitude.', 'Boa evolução funcional; mantida a progressão planejada.'),
(10, 4, 'Aplicação de rotação externa de ombro, flexão de ombro, associada a mobilização articular e ganho de amplitude.', 'Ganhos mantidos; orientado a seguir o programa domiciliar.'),
(11, 1, 'Aplicação de marcha estacionária, ponte unilateral, mobilização de tornozelo, associada a estimulação sensório-motora e treino de marcha.', 'Resposta inicial satisfatória; orientado quanto à execução correta dos movimentos.'),
(11, 2, 'Aplicação de ponte unilateral, mobilização de tornozelo, associada a estimulação sensório-motora e treino de marcha.', 'Boa evolução funcional; mantida a progressão planejada.'),
(11, 3, 'Aplicação de ponte unilateral, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(11, 4, 'Aplicação de agachamento assistido, ponte unilateral, associada a estimulação sensório-motora e treino de marcha.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(11, 5, 'Aplicação de mobilização de tornozelo, marcha estacionária, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(11, 7, 'Aplicação de agachamento assistido, ponte unilateral, marcha estacionária, associada a estimulação sensório-motora e treino de marcha.', 'Paciente praticamente assintomático e com função recuperada.'),
(12, 1, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Paciente colaborativo, referiu desconforto leve que cedeu ao repouso.'),
(12, 2, 'Aplicação de exercício respiratório diafragmático, marcha estacionária, associada a higiene brônquica e reexpansão pulmonar.', 'Boa evolução funcional; mantida a progressão planejada.'),
(12, 4, 'Aplicação de exercício respiratório diafragmático, marcha estacionária, associada a higiene brônquica e reexpansão pulmonar.', 'Boa evolução funcional; mantida a progressão planejada.'),
(12, 5, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Boa evolução funcional; mantida a progressão planejada.'),
(12, 6, 'Aplicação de exercício respiratório diafragmático, marcha estacionária, associada a higiene brônquica e reexpansão pulmonar.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(12, 7, 'Aplicação de exercício respiratório diafragmático, marcha estacionária, associada a higiene brônquica e reexpansão pulmonar.', 'Resultados compatíveis com os objetivos do tratamento; paciente com bom controle motor.'),
(13, 1, 'Aplicação de ponte unilateral, extensão de joelho, agachamento assistido, associada a fortalecimento específico e controle neuromuscular.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(13, 2, 'Aplicação de extensão de joelho, agachamento assistido, associada a fortalecimento específico e controle neuromuscular.', 'Boa evolução funcional; mantida a progressão planejada.'),
(13, 3, 'Aplicação de extensão de joelho, agachamento assistido, ponte unilateral, associada a fortalecimento específico e controle neuromuscular.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(13, 4, 'Aplicação de extensão de joelho, agachamento assistido, ponte unilateral, associada a fortalecimento específico e controle neuromuscular.', 'Boa evolução funcional; mantida a progressão planejada.'),
(13, 5, 'Aplicação de extensão de joelho, flexão de joelho, ponte unilateral, associada a fortalecimento específico e controle neuromuscular.', 'Paciente praticamente assintomático e com função recuperada.'),
(14, 1, 'Aplicação de mobilização de tornozelo, marcha estacionária, ponte unilateral, associada a estimulação sensório-motora e treino de marcha.', 'Resposta inicial satisfatória; orientado quanto à execução correta dos movimentos.'),
(14, 3, 'Aplicação de mobilização de tornozelo, ponte unilateral, associada a estimulação sensório-motora e treino de marcha.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(14, 4, 'Aplicação de ponte unilateral, agachamento assistido, marcha estacionária, associada a estimulação sensório-motora e treino de marcha.', 'Boa evolução funcional; mantida a progressão planejada.'),
(14, 5, 'Aplicação de ponte unilateral, marcha estacionária, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(14, 6, 'Aplicação de marcha estacionária, ponte unilateral, mobilização de tornozelo, associada a estimulação sensório-motora e treino de marcha.', 'Resultados compatíveis com os objetivos do tratamento; paciente com bom controle motor.'),
(15, 1, 'Aplicação de alongamento de panturrilha, ponte unilateral, flexão de joelho, associada a fortalecimento específico e controle neuromuscular.', 'Paciente colaborativo, referiu desconforto leve que cedeu ao repouso.'),
(15, 2, 'Aplicação de elevação pélvica, flexão de joelho, alongamento de panturrilha, associada a fortalecimento específico e controle neuromuscular.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(15, 3, 'Aplicação de elevação pélvica, ponte unilateral, flexão de joelho, associada a fortalecimento específico e controle neuromuscular.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(15, 5, 'Aplicação de flexão de joelho, ponte unilateral, associada a fortalecimento específico e controle neuromuscular.', 'Boa evolução funcional; mantida a progressão planejada.'),
(15, 6, 'Aplicação de alongamento de panturrilha, elevação pélvica, associada a fortalecimento específico e controle neuromuscular.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(15, 7, 'Aplicação de ponte unilateral, alongamento de panturrilha, associada a fortalecimento específico e controle neuromuscular.', 'Paciente praticamente assintomático e com função recuperada.'),
(16, 1, 'Aplicação de marcha estacionária, elevação pélvica, associada a estimulação motora lúdica.', 'Resposta inicial satisfatória; orientado quanto à execução correta dos movimentos.'),
(16, 2, 'Aplicação de mobilização de tornozelo, marcha estacionária, elevação pélvica, associada a estimulação motora lúdica.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(16, 4, 'Aplicação de elevação pélvica, marcha estacionária, mobilização de tornozelo, associada a estimulação motora lúdica.', 'Boa evolução funcional; mantida a progressão planejada.'),
(16, 5, 'Aplicação de mobilização de tornozelo, elevação pélvica, marcha estacionária, associada a estimulação motora lúdica.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(16, 6, 'Aplicação de elevação pélvica, marcha estacionária, associada a estimulação motora lúdica.', 'Boa evolução funcional; mantida a progressão planejada.'),
(16, 7, 'Aplicação de marcha estacionária, mobilização de tornozelo, associada a estimulação motora lúdica.', 'Boa evolução funcional; mantida a progressão planejada.'),
(16, 8, 'Aplicação de mobilização de tornozelo, elevação pélvica, marcha estacionária, associada a estimulação motora lúdica.', 'Resultados compatíveis com os objetivos do tratamento; paciente com bom controle motor.'),
(17, 1, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a condicionamento aeróbico monitorado.', 'Paciente colaborativo, referiu desconforto leve que cedeu ao repouso.'),
(17, 3, 'Aplicação de alongamento de panturrilha, marcha estacionária, associada a condicionamento aeróbico monitorado.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(17, 4, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, alongamento de panturrilha, associada a condicionamento aeróbico monitorado.', 'Paciente praticamente assintomático e com função recuperada.'),
(18, 1, 'Aplicação de marcha estacionária, elevação pélvica, associada a estimulação motora lúdica.', 'Resposta inicial satisfatória; orientado quanto à execução correta dos movimentos.'),
(18, 2, 'Aplicação de elevação pélvica, marcha estacionária, associada a estimulação motora lúdica.', 'Boa evolução funcional; mantida a progressão planejada.'),
(18, 3, 'Aplicação de elevação pélvica, mobilização de tornozelo, associada a estimulação motora lúdica.', 'Boa evolução funcional; mantida a progressão planejada.'),
(18, 4, 'Aplicação de elevação pélvica, mobilização de tornozelo, marcha estacionária, associada a estimulação motora lúdica.', 'Boa evolução funcional; mantida a progressão planejada.'),
(18, 5, 'Aplicação de marcha estacionária, mobilização de tornozelo, associada a estimulação motora lúdica.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(18, 6, 'Aplicação de marcha estacionária, elevação pélvica, mobilização de tornozelo, associada a estimulação motora lúdica.', 'Ganhos mantidos; orientado a seguir o programa domiciliar.'),
(19, 1, 'Aplicação de exercício respiratório diafragmático, alongamento de panturrilha, marcha estacionária, associada a condicionamento aeróbico monitorado.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(19, 5, 'Aplicação de exercício respiratório diafragmático, alongamento de panturrilha, associada a condicionamento aeróbico monitorado.', 'Resultados compatíveis com os objetivos do tratamento; paciente com bom controle motor.'),
(20, 1, 'Aplicação de extensão de joelho, ponte unilateral, associada a fortalecimento específico e controle neuromuscular.', 'Paciente colaborativo, referiu desconforto leve que cedeu ao repouso.'),
(20, 3, 'Aplicação de agachamento assistido, extensão de joelho, associada a fortalecimento específico e controle neuromuscular.', 'Boa evolução funcional; mantida a progressão planejada.'),
(20, 4, 'Aplicação de agachamento assistido, extensão de joelho, flexão de joelho, associada a fortalecimento específico e controle neuromuscular.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(20, 5, 'Aplicação de flexão de joelho, extensão de joelho, associada a fortalecimento específico e controle neuromuscular.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(20, 6, 'Aplicação de ponte unilateral, extensão de joelho, associada a fortalecimento específico e controle neuromuscular.', 'Ganhos mantidos; orientado a seguir o programa domiciliar.'),
(21, 1, 'Aplicação de mobilização de tornozelo, agachamento assistido, marcha estacionária, associada a estimulação sensório-motora e treino de marcha.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(21, 3, 'Aplicação de agachamento assistido, ponte unilateral, marcha estacionária, associada a estimulação sensório-motora e treino de marcha.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(21, 4, 'Aplicação de agachamento assistido, marcha estacionária, mobilização de tornozelo, associada a estimulação sensório-motora e treino de marcha.', 'Paciente praticamente assintomático e com função recuperada.'),
(22, 1, 'Aplicação de exercício respiratório diafragmático, marcha estacionária, associada a higiene brônquica e reexpansão pulmonar.', 'Resposta inicial satisfatória; orientado quanto à execução correta dos movimentos.'),
(22, 3, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(22, 4, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(22, 5, 'Aplicação de exercício respiratório diafragmático, marcha estacionária, associada a higiene brônquica e reexpansão pulmonar.', 'Boa evolução funcional; mantida a progressão planejada.'),
(22, 6, 'Aplicação de exercício respiratório diafragmático, marcha estacionária, associada a higiene brônquica e reexpansão pulmonar.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(22, 8, 'Aplicação de exercício respiratório diafragmático, marcha estacionária, associada a higiene brônquica e reexpansão pulmonar.', 'Ganhos mantidos; orientado a seguir o programa domiciliar.'),
(23, 1, 'Aplicação de alongamento de panturrilha, marcha estacionária, exercício respiratório diafragmático, associada a condicionamento aeróbico monitorado.', 'Paciente colaborativo, referiu desconforto leve que cedeu ao repouso.'),
(23, 3, 'Aplicação de alongamento de panturrilha, marcha estacionária, exercício respiratório diafragmático, associada a condicionamento aeróbico monitorado.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(23, 4, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a condicionamento aeróbico monitorado.', 'Resultados compatíveis com os objetivos do tratamento; paciente com bom controle motor.'),
(24, 1, 'Aplicação de elevação pélvica, extensão de joelho, associada a treino de equilíbrio e fortalecimento global.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(24, 3, 'Aplicação de extensão de joelho, elevação pélvica, marcha estacionária, associada a treino de equilíbrio e fortalecimento global.', 'Boa evolução funcional; mantida a progressão planejada.'),
(24, 4, 'Aplicação de marcha estacionária, agachamento assistido, elevação pélvica, associada a treino de equilíbrio e fortalecimento global.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(25, 1, 'Aplicação de flexão de ombro, rotação externa de ombro, associada a terapia manual e cinesioterapia.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(25, 3, 'Aplicação de flexão de ombro, abdução de ombro, rotação externa de ombro, associada a terapia manual e cinesioterapia.', 'Boa evolução funcional; mantida a progressão planejada.'),
(25, 4, 'Aplicação de flexão de ombro, rotação externa de ombro, associada a terapia manual e cinesioterapia.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(25, 5, 'Aplicação de rotação externa de ombro, abdução de ombro, flexão de ombro, associada a terapia manual e cinesioterapia.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(25, 6, 'Aplicação de rotação externa de ombro, abdução de ombro, flexão de ombro, associada a terapia manual e cinesioterapia.', 'Boa evolução funcional; mantida a progressão planejada.'),
(25, 7, 'Aplicação de flexão de ombro, abdução de ombro, associada a terapia manual e cinesioterapia.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(26, 1, 'Aplicação de agachamento assistido, elevação pélvica, associada a treino de equilíbrio e fortalecimento global.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(26, 2, 'Aplicação de ponte unilateral, marcha estacionária, agachamento assistido, associada a treino de equilíbrio e fortalecimento global.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(26, 7, 'Aplicação de marcha estacionária, agachamento assistido, associada a treino de equilíbrio e fortalecimento global.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(27, 1, 'Aplicação de mobilização de tornozelo, marcha estacionária, elevação pélvica, associada a estimulação motora lúdica.', 'Paciente colaborativo, referiu desconforto leve que cedeu ao repouso.'),
(27, 2, 'Aplicação de marcha estacionária, mobilização de tornozelo, associada a estimulação motora lúdica.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(27, 4, 'Aplicação de elevação pélvica, marcha estacionária, associada a estimulação motora lúdica.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(28, 1, 'Aplicação de elevação pélvica, ponte unilateral, associada a terapia manual e cinesioterapia.', 'Resposta inicial satisfatória; orientado quanto à execução correta dos movimentos.'),
(28, 2, 'Aplicação de alongamento de panturrilha, elevação pélvica, associada a terapia manual e cinesioterapia.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(28, 3, 'Aplicação de agachamento assistido, elevação pélvica, associada a terapia manual e cinesioterapia.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(28, 4, 'Aplicação de alongamento de panturrilha, ponte unilateral, agachamento assistido, associada a terapia manual e cinesioterapia.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(28, 5, 'Aplicação de agachamento assistido, elevação pélvica, associada a terapia manual e cinesioterapia.', 'Paciente praticamente assintomático e com função recuperada.'),
(29, 1, 'Aplicação de extensão de joelho, agachamento assistido, alongamento de panturrilha, associada a terapia manual e cinesioterapia.', 'Resposta inicial satisfatória; orientado quanto à execução correta dos movimentos.'),
(29, 2, 'Aplicação de alongamento de panturrilha, agachamento assistido, flexão de joelho, associada a terapia manual e cinesioterapia.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(29, 3, 'Aplicação de alongamento de panturrilha, agachamento assistido, extensão de joelho, associada a terapia manual e cinesioterapia.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(29, 4, 'Aplicação de alongamento de panturrilha, agachamento assistido, extensão de joelho, associada a terapia manual e cinesioterapia.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(29, 5, 'Aplicação de extensão de joelho, alongamento de panturrilha, agachamento assistido, associada a terapia manual e cinesioterapia.', 'Boa evolução funcional; mantida a progressão planejada.'),
(29, 6, 'Aplicação de flexão de joelho, extensão de joelho, associada a terapia manual e cinesioterapia.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(30, 1, 'Aplicação de mobilização de tornozelo, flexão de joelho, alongamento de panturrilha, associada a mobilização articular e ganho de amplitude.', 'Resposta inicial satisfatória; orientado quanto à execução correta dos movimentos.'),
(30, 2, 'Aplicação de alongamento de panturrilha, flexão de joelho, mobilização de tornozelo, associada a mobilização articular e ganho de amplitude.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(30, 3, 'Aplicação de alongamento de panturrilha, flexão de joelho, mobilização de tornozelo, associada a mobilização articular e ganho de amplitude.', 'Boa evolução funcional; mantida a progressão planejada.'),
(31, 1, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Paciente colaborativo, referiu desconforto leve que cedeu ao repouso.'),
(31, 2, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(31, 3, 'Aplicação de exercício respiratório diafragmático, marcha estacionária, associada a higiene brônquica e reexpansão pulmonar.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(31, 6, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(32, 1, 'Aplicação de elevação pélvica, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(32, 2, 'Aplicação de elevação pélvica, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Boa evolução funcional; mantida a progressão planejada.'),
(32, 4, 'Aplicação de marcha estacionária, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(32, 6, 'Aplicação de marcha estacionária, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(33, 1, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(33, 2, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(33, 3, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(33, 4, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Boa evolução funcional; mantida a progressão planejada.'),
(33, 5, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Boa evolução funcional; mantida a progressão planejada.'),
(34, 1, 'Aplicação de marcha estacionária, elevação pélvica, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Paciente colaborativo, referiu desconforto leve que cedeu ao repouso.'),
(34, 3, 'Aplicação de elevação pélvica, marcha estacionária, associada a estimulação sensório-motora e treino de marcha.', 'Boa evolução funcional; mantida a progressão planejada.'),
(34, 4, 'Aplicação de marcha estacionária, elevação pélvica, associada a estimulação sensório-motora e treino de marcha.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(35, 1, 'Aplicação de alongamento de panturrilha, marcha estacionária, exercício respiratório diafragmático, associada a condicionamento aeróbico monitorado.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(35, 2, 'Aplicação de alongamento de panturrilha, marcha estacionária, associada a condicionamento aeróbico monitorado.', 'Boa evolução funcional; mantida a progressão planejada.'),
(36, 1, 'Aplicação de elevação pélvica, marcha estacionária, associada a estimulação sensório-motora e treino de marcha.', 'Resposta inicial satisfatória; orientado quanto à execução correta dos movimentos.'),
(36, 2, 'Aplicação de elevação pélvica, marcha estacionária, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(36, 3, 'Aplicação de marcha estacionária, elevação pélvica, agachamento assistido, associada a estimulação sensório-motora e treino de marcha.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(37, 1, 'Aplicação de ponte unilateral, mobilização de tornozelo, associada a estimulação sensório-motora e treino de marcha.', 'Paciente colaborativo, referiu desconforto leve que cedeu ao repouso.'),
(37, 2, 'Aplicação de mobilização de tornozelo, marcha estacionária, associada a estimulação sensório-motora e treino de marcha.', 'Boa evolução funcional; mantida a progressão planejada.'),
(37, 3, 'Aplicação de ponte unilateral, mobilização de tornozelo, marcha estacionária, associada a estimulação sensório-motora e treino de marcha.', 'Melhora progressiva da amplitude de movimento e redução da dor relatada.'),
(38, 1, 'Aplicação de abdução de ombro, flexão de ombro, associada a mobilização articular e ganho de amplitude.', 'Paciente apresentou boa tolerância ao início do protocolo, com dor leve ao final.'),
(38, 2, 'Aplicação de flexão de ombro, abdução de ombro, rotação externa de ombro, associada a mobilização articular e ganho de amplitude.', 'Paciente tolerou o aumento de carga sem intercorrências.'),
(39, 1, 'Aplicação de marcha estacionária, exercício respiratório diafragmático, associada a higiene brônquica e reexpansão pulmonar.', 'Resposta inicial satisfatória; orientado quanto à execução correta dos movimentos.'),
(40, 1, 'Aplicação de ponte unilateral, agachamento assistido, associada a fortalecimento específico e controle neuromuscular.', 'Paciente colaborativo, referiu desconforto leve que cedeu ao repouso.');

INSERT INTO exercicio (nome,regiao_corpo,descricao) VALUES
('Alongamento de panturrilha', 'Pernas', 'Alongamento com apoio na parede.'),
('Elevação pélvica', 'Quadril', 'Elevação do quadril em decúbito dorsal.'),
('Extensão de joelho', 'Joelho', 'Extensão controlada do joelho.'),
('Flexão de joelho', 'Joelho', 'Flexão controlada do joelho.'),
('Abdução de ombro', 'Ombro', 'Elevação lateral controlada.'),
('Flexão de ombro', 'Ombro', 'Elevação frontal controlada.'),
('Rotação externa de ombro', 'Ombro', 'Rotação com faixa elástica.'),
('Agachamento assistido', 'Pernas', 'Agachamento com apoio.'),
('Ponte unilateral', 'Quadril', 'Ponte com apoio de uma perna.'),
('Marcha estacionária', 'Corpo inteiro', 'Marcha sem deslocamento.'),
('Exercício respiratório diafragmático', 'Tórax', 'Respiração com foco diafragmático.'),
('Mobilização de tornozelo', 'Tornozelo', 'Mobilização ativa do tornozelo.'),
('Alongamento de isquiotibiais', 'Pernas', 'Alongamento em decúbito dorsal com faixa (ainda não utilizado em sessões).');

INSERT INTO aplicacao_exercicio (id_tratamento,numero_sessao,id_exercicio,series,repeticoes,carga) VALUES
(1, 1, 2, 2, 10, NULL),
(1, 1, 8, 2, 10, NULL),
(1, 2, 2, 2, 10, NULL),
(1, 2, 1, 2, 10, NULL),
(1, 2, 8, 2, 10, NULL),
(1, 3, 1, 3, 12, NULL),
(1, 3, 8, 3, 12, NULL),
(1, 4, 9, 3, 12, NULL),
(1, 4, 1, 3, 12, NULL),
(1, 5, 1, 3, 15, NULL),
(1, 5, 9, 3, 15, NULL),
(1, 5, 8, 3, 15, NULL),
(2, 1, 8, 2, 10, NULL),
(2, 1, 1, 2, 10, NULL),
(2, 2, 4, 2, 10, 1.5),
(2, 2, 8, 2, 10, NULL),
(2, 3, 3, 3, 12, 2.0),
(2, 3, 8, 3, 12, NULL),
(2, 3, 4, 3, 12, 2.5),
(2, 6, 4, 3, 12, 2.5),
(2, 6, 1, 3, 12, NULL),
(2, 6, 8, 3, 12, NULL),
(2, 7, 1, 3, 15, NULL),
(2, 7, 3, 3, 15, 3.5),
(3, 1, 3, 2, 10, 1.5),
(3, 1, 8, 2, 10, NULL),
(3, 3, 4, 2, 10, 2.0),
(3, 3, 1, 2, 10, NULL),
(3, 5, 1, 3, 12, NULL),
(3, 5, 8, 3, 12, NULL),
(3, 5, 3, 3, 12, 2.0),
(4, 1, 12, 2, 10, NULL),
(4, 1, 8, 2, 10, NULL),
(4, 2, 10, 2, 10, NULL),
(4, 2, 9, 2, 10, NULL),
(4, 2, 12, 2, 10, NULL),
(4, 3, 9, 3, 12, NULL),
(4, 3, 8, 3, 12, NULL),
(4, 3, 10, 3, 12, NULL),
(4, 4, 10, 3, 12, NULL),
(4, 4, 9, 3, 12, NULL),
(4, 4, 8, 3, 12, NULL),
(4, 6, 12, 3, 15, NULL),
(4, 6, 10, 3, 15, NULL),
(4, 6, 8, 3, 15, NULL),
(5, 1, 3, 2, 10, 1.0),
(5, 1, 4, 2, 10, 1.5),
(5, 1, 8, 2, 10, NULL),
(5, 2, 3, 2, 10, 1.5),
(5, 2, 1, 2, 10, NULL),
(5, 3, 4, 3, 12, 2.0),
(5, 3, 8, 3, 12, NULL),
(5, 5, 3, 3, 12, 2.5),
(5, 5, 4, 3, 12, 2.5),
(5, 5, 1, 3, 12, NULL),
(5, 6, 3, 3, 15, 3.5),
(5, 6, 1, 3, 15, NULL),
(5, 6, 4, 3, 15, 3.5),
(6, 1, 1, 2, 10, NULL),
(6, 1, 11, 3, 10, NULL),
(6, 1, 10, 2, 10, NULL),
(6, 2, 10, 2, 10, NULL),
(6, 2, 1, 2, 10, NULL),
(6, 3, 1, 3, 12, NULL),
(6, 3, 10, 3, 12, NULL),
(6, 4, 10, 3, 12, NULL),
(6, 4, 1, 3, 12, NULL),
(6, 4, 11, 3, 10, NULL),
(6, 5, 11, 3, 10, NULL),
(6, 5, 10, 3, 15, NULL),
(6, 5, 1, 3, 15, NULL),
(6, 6, 1, 3, 15, NULL),
(6, 6, 11, 3, 10, NULL),
(6, 7, 1, 3, 15, NULL),
(6, 7, 11, 3, 10, NULL),
(6, 7, 10, 3, 15, NULL),
(7, 1, 8, 2, 10, NULL),
(7, 1, 2, 2, 10, NULL),
(7, 2, 9, 2, 10, NULL),
(7, 2, 8, 2, 10, NULL),
(7, 3, 1, 3, 12, NULL),
(7, 3, 8, 3, 12, NULL),
(7, 3, 2, 3, 12, NULL),
(7, 4, 9, 3, 12, NULL),
(7, 4, 8, 3, 12, NULL),
(7, 4, 1, 3, 12, NULL),
(7, 5, 9, 3, 15, NULL),
(7, 5, 2, 3, 15, NULL),
(7, 6, 8, 3, 15, NULL),
(7, 6, 1, 3, 15, NULL),
(8, 1, 1, 2, 10, NULL),
(8, 1, 12, 2, 10, NULL),
(8, 1, 10, 2, 10, NULL),
(8, 2, 12, 2, 10, NULL),
(8, 2, 1, 2, 10, NULL),
(8, 3, 10, 3, 12, NULL),
(8, 3, 1, 3, 12, NULL),
(8, 4, 10, 3, 12, NULL),
(8, 4, 12, 3, 12, NULL),
(8, 5, 10, 3, 15, NULL),
(8, 5, 12, 3, 15, NULL),
(8, 5, 1, 3, 15, NULL),
(8, 6, 1, 3, 15, NULL),
(8, 6, 10, 3, 15, NULL),
(8, 7, 1, 3, 15, NULL),
(8, 7, 12, 3, 15, NULL),
(9, 1, 8, 2, 10, NULL),
(9, 1, 4, 2, 10, 1.5),
(9, 2, 1, 2, 10, NULL),
(9, 2, 8, 2, 10, NULL),
(9, 3, 4, 3, 12, 2.5),
(9, 3, 1, 3, 12, NULL),
(9, 4, 3, 3, 12, 3.0),
(9, 4, 1, 3, 12, NULL),
(9, 5, 8, 3, 15, NULL),
(9, 5, 3, 3, 15, 3.5),
(9, 5, 1, 3, 15, NULL),
(9, 6, 3, 3, 15, 4.0),
(9, 6, 8, 3, 15, NULL),
(10, 1, 6, 2, 10, 1.5),
(10, 1, 7, 2, 10, 1.0),
(10, 1, 5, 2, 10, 1.5),
(10, 2, 6, 2, 10, 1.5),
(10, 2, 7, 2, 10, 2.0),
(10, 2, 5, 2, 10, 2.0),
(10, 3, 7, 3, 12, 2.0),
(10, 3, 6, 3, 12, 2.5),
(10, 4, 7, 3, 12, 2.5),
(10, 4, 6, 3, 12, 3.0),
(11, 1, 10, 2, 10, NULL),
(11, 1, 9, 2, 10, NULL),
(11, 1, 12, 2, 10, NULL),
(11, 2, 9, 2, 10, NULL),
(11, 2, 12, 2, 10, NULL),
(11, 3, 9, 3, 12, NULL),
(11, 3, 8, 3, 12, NULL),
(11, 4, 8, 3, 12, NULL),
(11, 4, 9, 3, 12, NULL),
(11, 5, 12, 3, 15, NULL),
(11, 5, 10, 3, 15, NULL),
(11, 5, 8, 3, 15, NULL),
(11, 6, 8, 3, 15, NULL),
(11, 6, 10, 3, 15, NULL),
(11, 7, 8, 3, 15, NULL),
(11, 7, 9, 3, 15, NULL),
(11, 7, 10, 3, 15, NULL),
(12, 1, 10, 3, 10, NULL),
(12, 1, 11, 3, 10, NULL),
(12, 2, 11, 3, 10, NULL),
(12, 2, 10, 3, 10, NULL),
(12, 4, 11, 3, 10, NULL),
(12, 4, 10, 3, 10, NULL),
(12, 5, 10, 3, 10, NULL),
(12, 5, 11, 3, 10, NULL),
(12, 6, 11, 3, 10, NULL),
(12, 6, 10, 3, 10, NULL),
(12, 7, 11, 3, 10, NULL),
(12, 7, 10, 3, 10, NULL),
(13, 1, 9, 2, 10, NULL),
(13, 1, 3, 2, 10, 1.0),
(13, 1, 8, 2, 10, NULL),
(13, 2, 3, 2, 10, 1.5),
(13, 2, 8, 2, 10, NULL),
(13, 3, 3, 3, 12, 2.5),
(13, 3, 8, 3, 12, NULL),
(13, 3, 9, 3, 12, NULL),
(13, 4, 3, 3, 12, 2.5),
(13, 4, 8, 3, 12, NULL),
(13, 4, 9, 3, 12, NULL),
(13, 5, 3, 3, 15, 3.0),
(13, 5, 4, 3, 15, 3.0),
(13, 5, 9, 3, 15, NULL),
(14, 1, 12, 2, 10, NULL),
(14, 1, 10, 2, 10, NULL),
(14, 1, 9, 2, 10, NULL),
(14, 3, 12, 2, 10, NULL),
(14, 3, 9, 2, 10, NULL),
(14, 4, 9, 3, 12, NULL),
(14, 4, 8, 3, 12, NULL),
(14, 4, 10, 3, 12, NULL),
(14, 5, 9, 3, 12, NULL),
(14, 5, 10, 3, 12, NULL),
(14, 5, 8, 3, 12, NULL),
(14, 6, 10, 3, 15, NULL),
(14, 6, 9, 3, 15, NULL),
(14, 6, 12, 3, 15, NULL),
(15, 1, 1, 2, 10, NULL),
(15, 1, 9, 2, 10, NULL),
(15, 1, 4, 2, 10, 1.5),
(15, 2, 2, 2, 10, NULL),
(15, 2, 4, 2, 10, 1.5),
(15, 2, 1, 2, 10, NULL),
(15, 3, 2, 3, 12, NULL),
(15, 3, 9, 3, 12, NULL),
(15, 3, 4, 3, 12, 2.5),
(15, 5, 4, 3, 12, 2.5),
(15, 5, 9, 3, 12, NULL),
(15, 6, 1, 3, 15, NULL),
(15, 6, 2, 3, 15, NULL),
(15, 7, 9, 3, 15, NULL),
(15, 7, 1, 3, 15, NULL),
(16, 1, 10, 2, 10, NULL),
(16, 1, 2, 2, 10, NULL),
(16, 2, 12, 2, 10, NULL),
(16, 2, 10, 2, 10, NULL),
(16, 2, 2, 2, 10, NULL),
(16, 3, 12, 3, 12, NULL),
(16, 3, 10, 3, 12, NULL),
(16, 4, 2, 3, 12, NULL),
(16, 4, 10, 3, 12, NULL),
(16, 4, 12, 3, 12, NULL),
(16, 5, 12, 3, 15, NULL),
(16, 5, 2, 3, 15, NULL),
(16, 5, 10, 3, 15, NULL),
(16, 6, 2, 3, 15, NULL),
(16, 6, 10, 3, 15, NULL),
(16, 7, 10, 3, 15, NULL),
(16, 7, 12, 3, 15, NULL),
(16, 8, 12, 3, 15, NULL),
(16, 8, 2, 3, 15, NULL),
(16, 8, 10, 3, 15, NULL),
(17, 1, 10, 2, 10, NULL),
(17, 1, 11, 3, 10, NULL),
(17, 3, 1, 2, 10, NULL),
(17, 3, 10, 2, 10, NULL),
(17, 4, 10, 3, 12, NULL),
(17, 4, 11, 3, 10, NULL),
(17, 4, 1, 3, 12, NULL),
(18, 1, 10, 2, 10, NULL),
(18, 1, 2, 2, 10, NULL),
(18, 2, 2, 2, 10, NULL),
(18, 2, 10, 2, 10, NULL),
(18, 3, 2, 3, 12, NULL),
(18, 3, 12, 3, 12, NULL),
(18, 4, 2, 3, 12, NULL),
(18, 4, 12, 3, 12, NULL),
(18, 4, 10, 3, 12, NULL),
(18, 5, 10, 3, 15, NULL),
(18, 5, 12, 3, 15, NULL),
(18, 6, 10, 3, 15, NULL),
(18, 6, 2, 3, 15, NULL),
(18, 6, 12, 3, 15, NULL),
(19, 1, 11, 3, 10, NULL),
(19, 1, 1, 2, 10, NULL),
(19, 1, 10, 2, 10, NULL),
(19, 4, 1, 2, 10, NULL),
(19, 4, 11, 3, 10, NULL),
(19, 5, 11, 3, 10, NULL),
(19, 5, 1, 3, 12, NULL),
(20, 1, 3, 2, 10, 1.5),
(20, 1, 9, 2, 10, NULL),
(20, 2, 8, 2, 10, NULL),
(20, 2, 9, 2, 10, NULL),
(20, 3, 8, 3, 12, NULL),
(20, 3, 3, 3, 12, 2.5),
(20, 4, 8, 3, 12, NULL),
(20, 4, 3, 3, 12, 3.0),
(20, 4, 4, 3, 12, 2.5),
(20, 5, 4, 3, 15, 3.5),
(20, 5, 3, 3, 15, 3.5),
(20, 6, 9, 3, 15, NULL),
(20, 6, 3, 3, 15, 3.5),
(21, 1, 12, 2, 10, NULL),
(21, 1, 8, 2, 10, NULL),
(21, 1, 10, 2, 10, NULL),
(21, 3, 8, 2, 10, NULL),
(21, 3, 9, 2, 10, NULL),
(21, 3, 10, 2, 10, NULL),
(21, 4, 8, 3, 12, NULL),
(21, 4, 10, 3, 12, NULL),
(21, 4, 12, 3, 12, NULL),
(22, 1, 11, 3, 10, NULL),
(22, 1, 10, 3, 10, NULL),
(22, 3, 10, 3, 10, NULL),
(22, 3, 11, 3, 10, NULL),
(22, 4, 10, 3, 10, NULL),
(22, 4, 11, 3, 10, NULL),
(22, 5, 11, 3, 10, NULL),
(22, 5, 10, 3, 10, NULL),
(22, 6, 11, 3, 10, NULL),
(22, 6, 10, 3, 10, NULL),
(22, 8, 11, 3, 10, NULL),
(22, 8, 10, 3, 10, NULL),
(23, 1, 1, 2, 10, NULL),
(23, 1, 10, 2, 10, NULL),
(23, 1, 11, 3, 10, NULL),
(23, 2, 1, 2, 10, NULL),
(23, 2, 11, 3, 10, NULL),
(23, 2, 10, 2, 10, NULL),
(23, 3, 1, 3, 12, NULL),
(23, 3, 10, 3, 12, NULL),
(23, 3, 11, 3, 10, NULL),
(23, 4, 10, 3, 12, NULL),
(23, 4, 11, 3, 10, NULL),
(24, 1, 2, 2, 10, NULL),
(24, 1, 3, 2, 10, 1.5),
(24, 3, 3, 2, 10, 1.5),
(24, 3, 2, 2, 10, NULL),
(24, 3, 10, 2, 10, NULL),
(24, 4, 10, 3, 12, NULL),
(24, 4, 8, 3, 12, NULL),
(24, 4, 2, 3, 12, NULL),
(25, 1, 6, 2, 10, 1.5),
(25, 1, 7, 2, 10, 1.0),
(25, 3, 6, 2, 10, 1.5),
(25, 3, 5, 2, 10, 1.5),
(25, 3, 7, 2, 10, 1.5),
(25, 4, 6, 3, 12, 2.0),
(25, 4, 7, 3, 12, 2.0),
(25, 5, 7, 3, 12, 3.0),
(25, 5, 5, 3, 12, 2.5),
(25, 5, 6, 3, 12, 2.5),
(25, 6, 7, 3, 15, 3.5),
(25, 6, 5, 3, 15, 3.5),
(25, 6, 6, 3, 15, 3.5),
(25, 7, 6, 3, 15, 3.5),
(25, 7, 5, 3, 15, 3.5),
(26, 1, 8, 2, 10, NULL),
(26, 1, 2, 2, 10, NULL),
(26, 2, 9, 2, 10, NULL),
(26, 2, 10, 2, 10, NULL),
(26, 2, 8, 2, 10, NULL),
(26, 4, 8, 3, 12, NULL),
(26, 4, 2, 3, 12, NULL),
(26, 4, 10, 3, 12, NULL),
(26, 7, 10, 3, 12, NULL),
(26, 7, 8, 3, 12, NULL),
(27, 1, 12, 2, 10, NULL),
(27, 1, 10, 2, 10, NULL),
(27, 1, 2, 2, 10, NULL),
(27, 2, 10, 2, 10, NULL),
(27, 2, 12, 2, 10, NULL),
(27, 4, 2, 3, 12, NULL),
(27, 4, 10, 3, 12, NULL),
(28, 1, 2, 2, 10, NULL),
(28, 1, 9, 2, 10, NULL),
(28, 2, 1, 2, 10, NULL),
(28, 2, 2, 2, 10, NULL),
(28, 3, 8, 3, 12, NULL),
(28, 3, 2, 3, 12, NULL),
(28, 4, 1, 3, 12, NULL),
(28, 4, 9, 3, 12, NULL),
(28, 4, 8, 3, 12, NULL),
(28, 5, 8, 3, 15, NULL),
(28, 5, 2, 3, 15, NULL),
(29, 1, 3, 2, 10, 1.5),
(29, 1, 8, 2, 10, NULL),
(29, 1, 1, 2, 10, NULL),
(29, 2, 1, 2, 10, NULL),
(29, 2, 8, 2, 10, NULL),
(29, 2, 4, 2, 10, 1.5),
(29, 3, 1, 3, 12, NULL),
(29, 3, 8, 3, 12, NULL),
(29, 3, 3, 3, 12, 2.0),
(29, 4, 1, 3, 12, NULL),
(29, 4, 8, 3, 12, NULL),
(29, 4, 3, 3, 12, 2.5),
(29, 5, 3, 3, 15, 3.0),
(29, 5, 1, 3, 15, NULL),
(29, 5, 8, 3, 15, NULL),
(29, 6, 4, 3, 15, 4.0),
(29, 6, 3, 3, 15, 3.5),
(30, 1, 12, 2, 10, NULL),
(30, 1, 4, 2, 10, 1.0),
(30, 1, 1, 2, 10, NULL),
(30, 2, 1, 2, 10, NULL),
(30, 2, 4, 2, 10, 2.0),
(30, 2, 12, 2, 10, NULL),
(30, 3, 1, 3, 12, NULL),
(30, 3, 4, 3, 12, 2.0),
(30, 3, 12, 3, 12, NULL),
(31, 1, 10, 3, 10, NULL),
(31, 1, 11, 3, 10, NULL),
(31, 2, 10, 3, 10, NULL),
(31, 2, 11, 3, 10, NULL),
(31, 3, 11, 3, 10, NULL),
(31, 3, 10, 3, 10, NULL),
(31, 4, 10, 3, 10, NULL),
(31, 4, 11, 3, 10, NULL),
(31, 6, 10, 3, 10, NULL),
(31, 6, 11, 3, 10, NULL),
(32, 1, 2, 2, 10, NULL),
(32, 1, 8, 2, 10, NULL),
(32, 2, 2, 2, 10, NULL),
(32, 2, 8, 2, 10, NULL),
(32, 3, 10, 3, 12, NULL),
(32, 3, 2, 3, 12, NULL),
(32, 3, 8, 3, 12, NULL),
(32, 4, 10, 3, 12, NULL),
(32, 4, 8, 3, 12, NULL),
(32, 5, 2, 3, 15, NULL),
(32, 5, 10, 3, 15, NULL),
(32, 6, 10, 3, 15, NULL),
(32, 6, 8, 3, 15, NULL),
(33, 1, 10, 3, 10, NULL),
(33, 1, 11, 3, 10, NULL),
(33, 2, 10, 3, 10, NULL),
(33, 2, 11, 3, 10, NULL),
(33, 3, 10, 3, 10, NULL),
(33, 3, 11, 3, 10, NULL),
(33, 4, 10, 3, 10, NULL),
(33, 4, 11, 3, 10, NULL),
(33, 5, 10, 3, 10, NULL),
(33, 5, 11, 3, 10, NULL),
(34, 1, 10, 2, 10, NULL),
(34, 1, 2, 2, 10, NULL),
(34, 1, 8, 2, 10, NULL),
(34, 3, 2, 2, 10, NULL),
(34, 3, 10, 2, 10, NULL),
(34, 4, 10, 3, 12, NULL),
(34, 4, 2, 3, 12, NULL),
(35, 1, 1, 2, 10, NULL),
(35, 1, 10, 2, 10, NULL),
(35, 1, 11, 3, 10, NULL),
(35, 2, 1, 2, 10, NULL),
(35, 2, 10, 2, 10, NULL),
(36, 1, 2, 2, 10, NULL),
(36, 1, 10, 2, 10, NULL),
(36, 2, 2, 2, 10, NULL),
(36, 2, 10, 2, 10, NULL),
(36, 2, 8, 2, 10, NULL),
(36, 3, 10, 3, 12, NULL),
(36, 3, 2, 3, 12, NULL),
(36, 3, 8, 3, 12, NULL),
(37, 1, 9, 2, 10, NULL),
(37, 1, 12, 2, 10, NULL),
(37, 2, 12, 2, 10, NULL),
(37, 2, 10, 2, 10, NULL),
(37, 3, 9, 3, 12, NULL),
(37, 3, 12, 3, 12, NULL),
(37, 3, 10, 3, 12, NULL),
(38, 1, 5, 2, 10, 1.5),
(38, 1, 6, 2, 10, 1.5),
(38, 2, 6, 2, 10, 2.0),
(38, 2, 5, 2, 10, 2.0),
(38, 2, 7, 2, 10, 1.5),
(39, 1, 10, 3, 10, NULL),
(39, 1, 11, 3, 10, NULL),
(40, 1, 9, 2, 10, NULL),
(40, 1, 8, 2, 10, NULL);

INSERT INTO avaliacao_fisica (data_avaliacao,nivel_dor,amplitude_movimento,observacoes,id_paciente) VALUES
('2026-01-19', 6, 'reduzida', 'Avaliação inicial do paciente.', 15),
('2026-01-26', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 8),
('2026-02-02', 6, 'reduzida', 'Paciente relata melhora progressiva.', 15),
('2026-02-04', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 16),
('2026-02-17', 6, 'reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 15),
('2026-02-18', 5, 'reduzida', 'Avaliação inicial do paciente.', 26),
('2026-02-23', 6, 'reduzida', 'Paciente relata melhora progressiva.', 8),
('2026-03-16', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 18),
('2026-03-19', 4, 'moderadamente reduzida', 'Paciente relata melhora progressiva.', 26),
('2026-03-30', 5, 'reduzida', 'Paciente relata melhora progressiva.', 18),
('2026-04-02', 5, 'reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 16),
('2026-04-09', 5, 'reduzida', 'Avaliação inicial do paciente.', 19),
('2026-04-13', 9, 'muito reduzida', 'Avaliação inicial do paciente.', 2),
('2026-04-20', 3, 'moderadamente reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 18),
('2026-04-20', 8, 'muito reduzida', 'Avaliação inicial do paciente.', 24),
('2026-04-20', 5, 'reduzida', 'Avaliação inicial do paciente.', 34),
('2026-04-22', 4, 'moderadamente reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 8),
('2026-05-01', 3, 'moderadamente reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 26),
('2026-05-05', 8, 'muito reduzida', 'Paciente relata melhora progressiva.', 2),
('2026-05-11', 7, 'muito reduzida', 'Paciente relata melhora progressiva.', 24),
('2026-05-11', 4, 'moderadamente reduzida', 'Paciente relata melhora progressiva.', 34),
('2026-05-13', 8, 'muito reduzida', 'Avaliação inicial do paciente.', 6),
('2026-05-14', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 27),
('2026-05-18', 3, 'moderadamente reduzida', 'Paciente relata melhora progressiva.', 34),
('2026-05-21', 7, 'muito reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 2),
('2026-05-21', 2, 'próxima do normal', 'Paciente relata melhora progressiva.', 19),
('2026-05-25', 6, 'reduzida', 'Avaliação inicial do paciente.', 7),
('2026-05-27', 5, 'reduzida', 'Paciente relata melhora progressiva.', 6),
('2026-05-28', 2, 'próxima do normal', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 34),
('2026-06-01', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 25),
('2026-06-02', 6, 'reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 24),
('2026-06-03', 5, 'reduzida', 'Avaliação inicial do paciente.', 32),
('2026-06-04', 4, 'moderadamente reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 6),
('2026-06-05', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 29),
('2026-06-08', 8, 'muito reduzida', 'Avaliação inicial do paciente.', 39),
('2026-06-15', 5, 'reduzida', 'Paciente relata melhora progressiva.', 25),
('2026-06-23', 5, 'reduzida', 'Paciente relata melhora progressiva.', 7),
('2026-06-25', 4, 'moderadamente reduzida', 'Paciente relata melhora progressiva.', 27),
('2026-06-25', 5, 'reduzida', 'Avaliação inicial do paciente.', 28),
('2026-06-29', 5, 'reduzida', 'Paciente relata melhora progressiva.', 7),
('2026-06-30', 3, 'moderadamente reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 25),
('2026-07-03', 4, 'moderadamente reduzida', 'Paciente relata melhora progressiva.', 29),
('2026-07-04', 0, 'normal', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 19),
('2026-07-06', 6, 'reduzida', 'Paciente relata melhora progressiva.', 39),
('2026-07-06', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 40),
('2026-07-07', 5, 'reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 7),
('2026-07-15', 4, 'moderadamente reduzida', 'Paciente relata melhora progressiva.', 32),
('2026-07-18', 4, 'moderadamente reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 28),
('2026-07-19', 1, 'próxima do normal', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 29),
('2026-07-20', 3, 'moderadamente reduzida', 'Paciente relata melhora progressiva.', 39),
('2026-07-23', 5, 'reduzida', 'Avaliação inicial do paciente.', 21),
('2026-07-27', 4, 'moderadamente reduzida', 'Paciente relata melhora progressiva.', 40),
('2026-07-29', 2, 'próxima do normal', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 39),
('2026-08-03', 8, 'muito reduzida', 'Avaliação inicial do paciente.', 14),
('2026-08-06', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 36),
('2026-08-08', 2, 'próxima do normal', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 27),
('2026-08-11', 2, 'próxima do normal', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 40),
('2026-08-12', 4, 'moderadamente reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 32),
('2026-08-20', 8, 'muito reduzida', 'Avaliação inicial do paciente.', 35),
('2026-08-21', 4, 'moderadamente reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 21),
('2026-08-24', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 33),
('2026-08-25', 7, 'muito reduzida', 'Paciente relata melhora progressiva.', 14),
('2026-08-27', 6, 'reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 36),
('2026-09-07', 5, 'reduzida', 'Avaliação inicial do paciente.', 3),
('2026-09-08', 5, 'reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 14),
('2026-09-08', 6, 'reduzida', 'Paciente relata melhora progressiva.', 33),
('2026-09-11', 8, 'muito reduzida', 'Avaliação inicial do paciente.', 1),
('2026-09-11', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 4),
('2026-09-11', 5, 'reduzida', 'Avaliação inicial do paciente.', 38),
('2026-09-14', 6, 'reduzida', 'Avaliação inicial do paciente.', 20),
('2026-09-15', 8, 'muito reduzida', 'Avaliação inicial do paciente.', 17),
('2026-09-15', 5, 'reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 33),
('2026-09-16', 6, 'reduzida', 'Avaliação inicial do paciente.', 23),
('2026-09-17', 6, 'reduzida', 'Paciente relata melhora progressiva.', 35),
('2026-09-18', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 12),
('2026-09-18', 9, 'muito reduzida', 'Avaliação inicial do paciente.', 37),
('2026-09-25', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 22),
('2026-09-28', 3, 'moderadamente reduzida', 'Paciente relata melhora progressiva.', 20),
('2026-09-30', 5, 'reduzida', 'Avaliação inicial do paciente.', 9),
('2026-10-02', 5, 'reduzida', 'Paciente relata melhora progressiva.', 4),
('2026-10-02', 4, 'moderadamente reduzida', 'Paciente relata melhora progressiva.', 12),
('2026-10-05', 7, 'muito reduzida', 'Avaliação inicial do paciente.', 11),
('2026-10-05', 5, 'reduzida', 'Avaliação inicial do paciente.', 30),
('2026-10-05', 9, 'muito reduzida', 'Avaliação inicial do paciente.', 31),
('2026-10-06', 7, 'muito reduzida', 'Paciente relata melhora progressiva.', 17),
('2026-10-09', 6, 'reduzida', 'Paciente relata melhora progressiva.', 1),
('2026-10-09', 7, 'muito reduzida', 'Paciente relata melhora progressiva.', 22),
('2026-10-09', 5, 'reduzida', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 35),
('2026-10-09', 8, 'muito reduzida', 'Paciente relata melhora progressiva.', 37),
('2026-10-13', 1, 'próxima do normal', 'Avaliação de alta; paciente orientado a manter exercícios em casa.', 20),
('2026-10-14', 5, 'reduzida', 'Paciente relata melhora progressiva.', 23),
('2026-10-19', 6, 'reduzida', 'Paciente relata melhora progressiva.', 11),
('2026-10-19', 5, 'reduzida', 'Paciente relata melhora progressiva.', 30),
('2026-10-19', 8, 'muito reduzida', 'Paciente relata melhora progressiva.', 31),
('2026-10-20', 2, 'próxima do normal', 'Paciente relata melhora progressiva.', 3),
('2026-10-21', 6, 'reduzida', 'Paciente relata melhora progressiva.', 17),
('2026-10-22', 2, 'próxima do normal', 'Paciente relata melhora progressiva.', 9),
('2026-10-23', 4, 'moderadamente reduzida', 'Paciente relata melhora progressiva.', 1),
('2026-10-23', 2, 'próxima do normal', 'Paciente relata melhora progressiva.', 4),
('2026-10-23', 2, 'próxima do normal', 'Paciente relata melhora progressiva.', 12),
('2026-10-23', 6, 'reduzida', 'Paciente relata melhora progressiva.', 22),
('2026-10-23', 7, 'muito reduzida', 'Paciente relata melhora progressiva.', 37),
('2026-10-23', 5, 'reduzida', 'Paciente relata melhora progressiva.', 38);


-- Conferência rápida da carga:
SELECT 'CONVENIO' AS tabela, COUNT(*) AS quantidade FROM convenio
UNION ALL SELECT 'PACIENTE', COUNT(*) FROM paciente
UNION ALL SELECT 'PROFISSIONAL', COUNT(*) FROM profissional
UNION ALL SELECT 'FISIOTERAPEUTA', COUNT(*) FROM fisioterapeuta
UNION ALL SELECT 'ESTAGIARIO', COUNT(*) FROM estagiario
UNION ALL SELECT 'ESPECIALIDADE', COUNT(*) FROM especialidade
UNION ALL SELECT 'HABILITACAO_PROFISSIONAL', COUNT(*) FROM habilitacao_profissional
UNION ALL SELECT 'TRATAMENTO', COUNT(*) FROM tratamento
UNION ALL SELECT 'SALA', COUNT(*) FROM sala
UNION ALL SELECT 'SESSAO', COUNT(*) FROM sessao
UNION ALL SELECT 'EVOLUCAO', COUNT(*) FROM evolucao
UNION ALL SELECT 'EXERCICIO', COUNT(*) FROM exercicio
UNION ALL SELECT 'APLICACAO_EXERCICIO', COUNT(*) FROM aplicacao_exercicio
UNION ALL SELECT 'AVALIACAO_FISICA', COUNT(*) FROM avaliacao_fisica;


-- ==============================================================================
-- ETAPA 1 — CONSULTAS (antigo 03_Consultas.sql) — versão corrigida
-- ==============================================================================

-- ============================================================
-- 03_consultas.sql
-- A8 — Consultas de verificação
-- 15 consultas comentadas com a pergunta de negócio.
-- ============================================================

USE clinica_fisioterapia;

-- ============================================================
-- 1. BÁSICA — Projeção
-- Pergunta: Quais são os nomes e situações cadastrais dos pacientes?
-- ============================================================
SELECT nome, situacao
FROM paciente;

-- ============================================================
-- 2. BÁSICA — WHERE
-- Pergunta: Quais pacientes estão atualmente ativos?
-- ============================================================
SELECT id_paciente, nome, cpf
FROM paciente
WHERE situacao = 'ATIVO';

-- ============================================================
-- 3. BÁSICA — ORDER BY
-- Pergunta: Quais pacientes estão em ordem alfabética?
-- ============================================================
SELECT id_paciente, nome
FROM paciente
ORDER BY nome ASC;

-- ============================================================
-- 4. BÁSICA — LIKE
-- Pergunta: Quais pacientes possuem o nome "Ana" (como palavra inteira)?
-- Obs.: '%Ana%' também traria Mariana, Tatiana e Juliana, pois a
-- collation utf8mb4_0900_ai_ci ignora maiúsculas/minúsculas.
-- ============================================================
SELECT id_paciente, nome
FROM paciente
WHERE nome LIKE 'Ana %'
   OR nome LIKE '% Ana %'
   OR nome LIKE '% Ana'
ORDER BY nome;

-- ============================================================
-- 5. BÁSICA — BETWEEN / IN / NULL
-- Pergunta: Quais pacientes nasceram entre 1985 e 1995, não possuem
-- telefone informado e estão vinculados aos convênios GEAP ou Saúde Caixa?
-- ============================================================
SELECT p.id_paciente, p.nome, p.data_nascimento, p.telefone, c.nome AS convenio
FROM paciente p
JOIN convenio c ON c.id_convenio = p.id_convenio
WHERE p.data_nascimento BETWEEN '1985-01-01' AND '1995-12-31'
  AND c.nome IN ('GEAP', 'Saúde Caixa')
  AND p.telefone IS NULL;

-- ============================================================
-- 6. JUNÇÃO — várias tabelas
-- Pergunta: Quais tratamentos estão vinculados a quais pacientes,
-- fisioterapeutas e especialidades? (junção de cinco tabelas)
-- ============================================================
SELECT
    t.id_tratamento,
    p.nome AS paciente,
    f.nome AS fisioterapeuta,
    e.nome AS especialidade,
    t.data_inicio
FROM tratamento t
JOIN paciente p ON p.id_paciente = t.id_paciente
JOIN fisioterapeuta ft ON ft.id_profissional = t.id_fisioterapeuta
JOIN profissional f ON f.id_profissional = ft.id_profissional
JOIN especialidade e ON e.id_especialidade = t.id_especialidade
ORDER BY t.id_tratamento;

-- ============================================================
-- 7. JUNÇÃO — LEFT JOIN
-- Pergunta: Quais pacientes possuem ou não avaliações físicas?
-- ============================================================
SELECT
    p.id_paciente,
    p.nome,
    a.data_avaliacao,
    a.nivel_dor
FROM paciente p
LEFT JOIN avaliacao_fisica a ON a.id_paciente = p.id_paciente
ORDER BY p.id_paciente, a.data_avaliacao;

-- ============================================================
-- 8. AGREGAÇÃO — GROUP BY
-- Pergunta: Quantos tratamentos cada especialidade possui?
-- ============================================================
SELECT
    e.nome AS especialidade,
    COUNT(t.id_tratamento) AS quantidade_tratamentos
FROM especialidade e
LEFT JOIN tratamento t ON t.id_especialidade = e.id_especialidade
GROUP BY e.id_especialidade, e.nome
ORDER BY quantidade_tratamentos DESC, e.nome;

-- ============================================================
-- 9. AGREGAÇÃO — HAVING
-- Pergunta: Quais especialidades possuem pelo menos 5 tratamentos?
-- ============================================================
SELECT
    e.nome AS especialidade,
    COUNT(t.id_tratamento) AS quantidade_tratamentos
FROM especialidade e
JOIN tratamento t ON t.id_especialidade = e.id_especialidade
GROUP BY e.id_especialidade, e.nome
HAVING COUNT(t.id_tratamento) >= 5
ORDER BY quantidade_tratamentos DESC, e.nome;

-- ============================================================
-- 10. JUNÇÃO + AGREGAÇÃO
-- Pergunta: Quantas sessões realizadas cada paciente possui?
-- ============================================================
SELECT
    p.nome AS paciente,
    COUNT(s.numero_sessao) AS sessoes_realizadas
FROM paciente p
JOIN tratamento t ON t.id_paciente = p.id_paciente
JOIN sessao s ON s.id_tratamento = t.id_tratamento
WHERE s.situacao = 'REALIZADA'
GROUP BY p.id_paciente, p.nome
ORDER BY sessoes_realizadas DESC, paciente;

-- ============================================================
-- 11. AVANÇADA — subconsulta correlacionada
-- Pergunta: Quais avaliações registraram dor acima da média das
-- avaliações daquele mesmo paciente?
-- ============================================================
SELECT
    a.id_paciente,
    p.nome,
    a.data_avaliacao,
    a.nivel_dor
FROM avaliacao_fisica a
JOIN paciente p ON p.id_paciente = a.id_paciente
WHERE a.nivel_dor > (
    SELECT AVG(a2.nivel_dor)
    FROM avaliacao_fisica a2
    WHERE a2.id_paciente = a.id_paciente
)
ORDER BY p.nome, a.data_avaliacao;

-- ============================================================
-- 12. AVANÇADA — EXISTS
-- Pergunta: Quais fisioterapeutas possuem habilitação registrada
-- na especialidade Respiratória?
-- ============================================================
SELECT
    f.id_profissional,
    p.nome,
    f.crefito
FROM fisioterapeuta f
JOIN profissional p ON p.id_profissional = f.id_profissional
WHERE EXISTS (
    SELECT 1
    FROM habilitacao_profissional h
    JOIN especialidade e ON e.id_especialidade = h.id_especialidade
    WHERE h.id_profissional = f.id_profissional
      AND e.nome = 'Respiratória'
)
ORDER BY p.nome;

-- ============================================================
-- 13. AVANÇADA — NOT EXISTS
-- Pergunta: Quais exercícios ainda não foram aplicados em nenhuma sessão?
-- ============================================================
SELECT
    e.id_exercicio,
    e.nome
FROM exercicio e
WHERE NOT EXISTS (
    SELECT 1
    FROM aplicacao_exercicio ae
    WHERE ae.id_exercicio = e.id_exercicio
)
ORDER BY e.nome;

-- ============================================================
-- 14. AVANÇADA — pergunta não trivial
-- Pergunta: Quais pacientes tiveram pelo menos uma sessão realizada
-- e possuem média de dor nas avaliações igual ou superior a 6?
-- ============================================================
SELECT
    p.id_paciente,
    p.nome,
    ROUND(AVG(a.nivel_dor), 2) AS media_dor
FROM paciente p
JOIN avaliacao_fisica a ON a.id_paciente = p.id_paciente
WHERE EXISTS (
    SELECT 1
    FROM tratamento t
    JOIN sessao s ON s.id_tratamento = t.id_tratamento
    WHERE t.id_paciente = p.id_paciente
      AND s.situacao = 'REALIZADA'
)
GROUP BY p.id_paciente, p.nome
HAVING AVG(a.nivel_dor) >= 6
ORDER BY media_dor DESC, p.nome;

-- ============================================================
-- 15. AVANÇADA — pergunta não trivial
-- Pergunta: Quais fisioterapeutas possuem mais tratamentos do que
-- a média de tratamentos por fisioterapeuta (entre os que atendem)?
-- ============================================================
SELECT
    p.nome AS fisioterapeuta,
    COUNT(t.id_tratamento) AS quantidade_tratamentos
FROM fisioterapeuta f
JOIN profissional p ON p.id_profissional = f.id_profissional
JOIN tratamento t ON t.id_fisioterapeuta = f.id_profissional
GROUP BY f.id_profissional, p.nome
HAVING COUNT(t.id_tratamento) > (
    SELECT AVG(qtd)
    FROM (
        SELECT COUNT(*) AS qtd
        FROM tratamento
        GROUP BY id_fisioterapeuta
    ) AS medias
)
ORDER BY quantidade_tratamentos DESC, fisioterapeuta;
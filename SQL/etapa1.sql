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
    CONSTRAINT ck_paciente_data_nascimento CHECK (data_nascimento <= CURRENT_DATE),
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
        REFERENCES profissional (id_profissional)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT ck_estagiario_nao_supervisiona_a_si_mesmo
        CHECK (id_supervisor <> id_profissional)
) ENGINE=InnoDB;

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
CREATE TABLE tratamento (
    id_tratamento INT UNSIGNED AUTO_INCREMENT,
    descricao_condicao VARCHAR(255) NOT NULL,
    data_inicio DATE NOT NULL,
    data_alta DATE NULL,
    id_paciente INT UNSIGNED NOT NULL,
    id_fisioterapeuta INT UNSIGNED NOT NULL,
    id_especialidade INT UNSIGNED NOT NULL,

    CONSTRAINT pk_tratamento PRIMARY KEY (id_tratamento),
    CONSTRAINT fk_tratamento_paciente
        FOREIGN KEY (id_paciente)
        REFERENCES paciente (id_paciente)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_tratamento_fisioterapeuta
        FOREIGN KEY (id_fisioterapeuta)
        REFERENCES fisioterapeuta (id_profissional)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_tratamento_especialidade
        FOREIGN KEY (id_especialidade)
        REFERENCES especialidade (id_especialidade)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
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

-- RN07: o supervisor precisa ser um fisioterapeuta.
DELIMITER $$

CREATE TRIGGER ck_supervisor_fisioterapeuta_ins
BEFORE INSERT ON estagiario
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM fisioterapeuta
        WHERE id_profissional = NEW.id_supervisor
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O supervisor do estagiario deve ser um fisioterapeuta.';
    END IF;
END$$

CREATE TRIGGER ck_supervisor_fisioterapeuta_upd
BEFORE UPDATE ON estagiario
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM fisioterapeuta
        WHERE id_profissional = NEW.id_supervisor
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O supervisor do estagiario deve ser um fisioterapeuta.';
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

DELIMITER ;

-- ============================================================
-- 02_carga.sql
-- Dados fictícios e plausíveis para a Clínica de Fisioterapia
-- Não utilizar dados pessoais reais.
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
('10000000000', 'Ana Almeida', '1975-01-01', NULL, 'ATIVO', NULL),
('10000000001', 'Bruno Barbosa', '1976-02-02', '6199100001', 'ATIVO', 2),
('10000000002', 'Carlos Carvalho', '1977-03-03', '6199100002', 'ATIVO', 3),
('10000000003', 'Daniela Dias', '1978-04-04', '6199100003', 'ATIVO', 4),
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
('10000000035', 'Renata Gomes', '1985-12-09', NULL, 'ATIVO', NULL),
('10000000036', 'Samuel Lima', '1986-01-10', '6199100036', 'ATIVO', 5),
('10000000037', 'Tatiana Martins', '1987-02-11', '6199100037', 'ATIVO', 6),
('10000000038', 'Vinicius Nogueira', '1988-03-12', '6199100038', 'ATIVO', 7),
('10000000039', 'Yasmin Oliveira', '1989-04-13', '6199100039', 'ATIVO', 8);

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
('Dor lombar', '2026-01-02', NULL, 1, 1, 1),
('Lesão de joelho', '2026-02-04', '2026-05-05', 2, 2, 2),
('Reabilitação de ombro', '2026-03-06', '2026-06-07', 3, 3, 3),
('Recuperação pós-operatória', '2026-04-08', NULL, 4, 4, 4),
('Reabilitação neurológica', '2026-05-10', NULL, 5, 5, 5),
('Dor cervical', '2026-06-12', '2026-01-13', 6, 6, 6),
('Entorse de tornozelo', '2026-07-14', '2026-02-15', 7, 7, 7),
('Reabilitação esportiva', '2026-08-16', NULL, 8, 8, 8),
('Dor lombar', '2026-01-18', NULL, 9, 9, 1),
('Lesão de joelho', '2026-02-20', '2026-05-21', 10, 10, 2),
('Reabilitação de ombro', '2026-03-22', '2026-06-23', 11, 11, 3),
('Recuperação pós-operatória', '2026-04-24', NULL, 12, 12, 4),
('Reabilitação neurológica', '2026-05-01', NULL, 13, 13, 5),
('Dor cervical', '2026-06-03', '2026-01-04', 14, 14, 6),
('Entorse de tornozelo', '2026-07-05', '2026-02-06', 15, 15, 7),
('Reabilitação esportiva', '2026-08-07', NULL, 16, 16, 8),
('Dor lombar', '2026-01-09', NULL, 17, 17, 1),
('Lesão de joelho', '2026-02-11', '2026-05-12', 18, 18, 2),
('Reabilitação de ombro', '2026-03-13', '2026-06-14', 19, 19, 3),
('Recuperação pós-operatória', '2026-04-15', NULL, 20, 20, 4),
('Reabilitação neurológica', '2026-05-17', NULL, 21, 1, 5),
('Dor cervical', '2026-06-19', '2026-01-20', 22, 2, 6),
('Entorse de tornozelo', '2026-07-21', '2026-02-22', 23, 3, 7),
('Reabilitação esportiva', '2026-08-23', NULL, 24, 4, 8),
('Dor lombar', '2026-01-25', NULL, 25, 5, 1),
('Lesão de joelho', '2026-02-02', '2026-05-03', 26, 6, 2),
('Reabilitação de ombro', '2026-03-04', '2026-06-05', 27, 7, 3),
('Recuperação pós-operatória', '2026-04-06', NULL, 28, 8, 4),
('Reabilitação neurológica', '2026-05-08', NULL, 29, 9, 5),
('Dor cervical', '2026-06-10', '2026-01-11', 30, 10, 6),
('Entorse de tornozelo', '2026-07-12', '2026-02-13', 31, 11, 7),
('Reabilitação esportiva', '2026-08-14', NULL, 32, 12, 8),
('Dor lombar', '2026-01-16', NULL, 33, 13, 1),
('Lesão de joelho', '2026-02-18', '2026-05-19', 34, 14, 2),
('Reabilitação de ombro', '2026-03-20', '2026-06-21', 35, 15, 3),
('Recuperação pós-operatória', '2026-04-22', NULL, 36, 16, 4),
('Reabilitação neurológica', '2026-05-24', NULL, 37, 17, 5),
('Dor cervical', '2026-06-01', '2026-01-02', 38, 18, 6),
('Entorse de tornozelo', '2026-07-03', '2026-02-04', 39, 19, 7),
('Reabilitação esportiva', '2026-08-05', NULL, 40, 20, 8);

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
(1,1,'2026-01-01 08:00:00','REALIZADA',1),
(1,2,'2026-02-03 09:10:00','REALIZADA',2),
(1,3,'2026-03-05 10:20:00','AGENDADA',3),
(2,1,'2026-04-07 11:30:00','REALIZADA',4),
(2,2,'2026-05-09 12:40:00','REALIZADA',5),
(2,3,'2026-06-11 13:50:00','AGENDADA',6),
(3,1,'2026-07-13 14:00:00','REALIZADA',7),
(3,2,'2026-08-15 15:10:00','AGENDADA',8),
(3,3,'2026-01-17 16:20:00','AGENDADA',1),
(4,1,'2026-02-19 08:30:00','REALIZADA',2),
(4,2,'2026-03-21 09:40:00','REALIZADA',3),
(4,3,'2026-04-23 10:50:00','AGENDADA',4),
(5,1,'2026-05-25 11:00:00','REALIZADA',5),
(5,2,'2026-06-02 12:10:00','REALIZADA',6),
(5,3,'2026-07-04 13:20:00','CANCELADA',7),
(6,1,'2026-08-06 14:30:00','REALIZADA',8),
(6,2,'2026-01-08 15:40:00','AGENDADA',1),
(6,3,'2026-02-10 16:50:00','AGENDADA',2),
(7,1,'2026-03-12 08:00:00','REALIZADA',3),
(7,2,'2026-04-14 09:10:00','REALIZADA',4),
(7,3,'2026-05-16 10:20:00','AGENDADA',5),
(8,1,'2026-06-18 11:30:00','REALIZADA',6),
(8,2,'2026-07-20 12:40:00','REALIZADA',7),
(8,3,'2026-08-22 13:50:00','AGENDADA',8),
(9,1,'2026-01-24 14:00:00','REALIZADA',1),
(9,2,'2026-02-01 15:10:00','AGENDADA',2),
(9,3,'2026-03-03 16:20:00','AGENDADA',3),
(10,1,'2026-04-05 08:30:00','REALIZADA',4),
(10,2,'2026-05-07 09:40:00','REALIZADA',5),
(10,3,'2026-06-09 10:50:00','CANCELADA',6),
(11,1,'2026-07-11 11:00:00','REALIZADA',7),
(11,2,'2026-08-13 12:10:00','REALIZADA',8),
(11,3,'2026-01-15 13:20:00','AGENDADA',1),
(12,1,'2026-02-17 14:30:00','REALIZADA',2),
(12,2,'2026-03-19 15:40:00','AGENDADA',3),
(12,3,'2026-04-21 16:50:00','AGENDADA',4),
(13,1,'2026-05-23 08:00:00','REALIZADA',5),
(13,2,'2026-06-25 09:10:00','REALIZADA',6),
(13,3,'2026-07-02 10:20:00','AGENDADA',7),
(14,1,'2026-08-04 11:30:00','REALIZADA',8),
(14,2,'2026-01-06 12:40:00','REALIZADA',1),
(14,3,'2026-02-08 13:50:00','AGENDADA',2),
(15,1,'2026-03-10 14:00:00','REALIZADA',3),
(15,2,'2026-04-12 15:10:00','CANCELADA',4),
(15,3,'2026-05-14 16:20:00','CANCELADA',5),
(16,1,'2026-06-16 08:30:00','REALIZADA',6),
(16,2,'2026-07-18 09:40:00','REALIZADA',7),
(16,3,'2026-08-20 10:50:00','AGENDADA',8),
(17,1,'2026-01-22 11:00:00','REALIZADA',1),
(17,2,'2026-02-24 12:10:00','REALIZADA',2),
(17,3,'2026-03-01 13:20:00','AGENDADA',3),
(18,1,'2026-04-03 14:30:00','REALIZADA',4),
(18,2,'2026-05-05 15:40:00','AGENDADA',5),
(18,3,'2026-06-07 16:50:00','AGENDADA',6),
(19,1,'2026-07-09 08:00:00','REALIZADA',7),
(19,2,'2026-08-11 09:10:00','REALIZADA',8),
(19,3,'2026-01-13 10:20:00','AGENDADA',1),
(20,1,'2026-02-15 11:30:00','REALIZADA',2),
(20,2,'2026-03-17 12:40:00','REALIZADA',3),
(20,3,'2026-04-19 13:50:00','CANCELADA',4),
(21,1,'2026-05-21 14:00:00','REALIZADA',5),
(21,2,'2026-06-23 15:10:00','AGENDADA',6),
(21,3,'2026-07-25 16:20:00','AGENDADA',7),
(22,1,'2026-08-02 08:30:00','REALIZADA',8),
(22,2,'2026-01-04 09:40:00','REALIZADA',1),
(22,3,'2026-02-06 10:50:00','AGENDADA',2),
(23,1,'2026-03-08 11:00:00','REALIZADA',3),
(23,2,'2026-04-10 12:10:00','REALIZADA',4),
(23,3,'2026-05-12 13:20:00','AGENDADA',5),
(24,1,'2026-06-14 14:30:00','REALIZADA',6),
(24,2,'2026-07-16 15:40:00','AGENDADA',7),
(24,3,'2026-08-18 16:50:00','AGENDADA',8),
(25,1,'2026-01-20 08:00:00','REALIZADA',1),
(25,2,'2026-02-22 09:10:00','REALIZADA',2),
(25,3,'2026-03-24 10:20:00','CANCELADA',3),
(26,1,'2026-04-01 11:30:00','REALIZADA',4),
(26,2,'2026-05-03 12:40:00','REALIZADA',5),
(26,3,'2026-06-05 13:50:00','AGENDADA',6),
(27,1,'2026-07-07 14:00:00','REALIZADA',7),
(27,2,'2026-08-09 15:10:00','AGENDADA',8),
(27,3,'2026-01-11 16:20:00','AGENDADA',1),
(28,1,'2026-02-13 08:30:00','REALIZADA',2),
(28,2,'2026-03-15 09:40:00','REALIZADA',3),
(28,3,'2026-04-17 10:50:00','AGENDADA',4),
(29,1,'2026-05-19 11:00:00','REALIZADA',5),
(29,2,'2026-06-21 12:10:00','REALIZADA',6),
(29,3,'2026-07-23 13:20:00','AGENDADA',7),
(30,1,'2026-08-25 14:30:00','REALIZADA',8),
(30,2,'2026-01-02 15:40:00','CANCELADA',1),
(30,3,'2026-02-04 16:50:00','CANCELADA',2),
(31,1,'2026-03-06 08:00:00','REALIZADA',3),
(31,2,'2026-04-08 09:10:00','REALIZADA',4),
(31,3,'2026-05-10 10:20:00','AGENDADA',5),
(32,1,'2026-06-12 11:30:00','REALIZADA',6),
(32,2,'2026-07-14 12:40:00','REALIZADA',7),
(32,3,'2026-08-16 13:50:00','AGENDADA',8),
(33,1,'2026-01-18 14:00:00','REALIZADA',1),
(33,2,'2026-02-20 15:10:00','AGENDADA',2),
(33,3,'2026-03-22 16:20:00','AGENDADA',3),
(34,1,'2026-04-24 08:30:00','REALIZADA',4),
(34,2,'2026-05-01 09:40:00','REALIZADA',5),
(34,3,'2026-06-03 10:50:00','AGENDADA',6),
(35,1,'2026-07-05 11:00:00','REALIZADA',7),
(35,2,'2026-08-07 12:10:00','REALIZADA',8),
(35,3,'2026-01-09 13:20:00','CANCELADA',1),
(36,1,'2026-02-11 14:30:00','REALIZADA',2),
(36,2,'2026-03-13 15:40:00','AGENDADA',3),
(36,3,'2026-04-15 16:50:00','AGENDADA',4),
(37,1,'2026-05-17 08:00:00','REALIZADA',5),
(37,2,'2026-06-19 09:10:00','REALIZADA',6),
(37,3,'2026-07-21 10:20:00','AGENDADA',7),
(38,1,'2026-08-23 11:30:00','REALIZADA',8),
(38,2,'2026-01-25 12:40:00','REALIZADA',1),
(38,3,'2026-02-02 13:50:00','AGENDADA',2),
(39,1,'2026-03-04 14:00:00','REALIZADA',3),
(39,2,'2026-04-06 15:10:00','AGENDADA',4),
(39,3,'2026-05-08 16:20:00','AGENDADA',5),
(40,1,'2026-06-10 08:30:00','REALIZADA',6),
(40,2,'2026-07-12 09:40:00','REALIZADA',7),
(40,3,'2026-08-14 10:50:00','CANCELADA',8);

INSERT INTO evolucao (id_tratamento,numero_sessao,conduta_aplicada,resposta_observada) VALUES
(1,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(1,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(2,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(2,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(3,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(4,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(4,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(5,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(5,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(6,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(7,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(7,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(8,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(8,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(9,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(10,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(10,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(11,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(11,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(12,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(13,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(13,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(14,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(14,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(15,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(16,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(16,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(17,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(17,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(18,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(19,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(19,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(20,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(20,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(21,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(22,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(22,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(23,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(23,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(24,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(25,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(25,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(26,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(26,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(27,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(28,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(28,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(29,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(29,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(30,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(31,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(31,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(32,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(32,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(33,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(34,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(34,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(35,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(35,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(36,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(37,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(37,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(38,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(38,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.'),
(39,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(40,1,'Aplicação de exercícios terapêuticos e técnicas manuais.','Paciente apresentou resposta compatível com a evolução esperada.'),
(40,2,'Progressão de exercícios e mobilidade funcional.','Paciente tolerou a sessão sem intercorrências.');

INSERT INTO exercicio (nome,regiao_corpo,descricao) VALUES
('Alongamento de panturrilha','Pernas','Alongamento com apoio na parede.'),
('Elevação pélvica','Quadril','Elevação do quadril em decúbito dorsal.'),
('Extensão de joelho','Joelho','Extensão controlada do joelho.'),
('Flexão de joelho','Joelho','Flexão controlada do joelho.'),
('Abdução de ombro','Ombro','Elevação lateral controlada.'),
('Flexão de ombro','Ombro','Elevação frontal controlada.'),
('Rotação externa de ombro','Ombro','Rotação com faixa elástica.'),
('Agachamento assistido','Pernas','Agachamento com apoio.'),
('Ponte unilateral','Quadril','Ponte com apoio de uma perna.'),
('Marcha estacionária','Corpo inteiro','Marcha sem deslocamento.'),
('Exercício respiratório diafragmático','Tórax','Respiração com foco diafragmático.'),
('Mobilização de tornozelo','Tornozelo','Mobilização ativa do tornozelo.');

INSERT INTO aplicacao_exercicio (id_tratamento,numero_sessao,id_exercicio,series,repeticoes,carga) VALUES
(1,1,1,2,25,2.50),
(1,1,3,2,15,3.50),
(1,2,2,3,15,3.00),
(1,2,4,3,25,NULL),
(1,3,3,2,25,NULL),
(1,3,5,2,15,4.50),
(2,1,2,3,15,3.50),
(2,1,4,3,25,NULL),
(2,2,3,2,25,NULL),
(2,2,5,2,15,5.00),
(2,3,4,3,15,4.50),
(2,3,6,3,25,1.50),
(3,1,3,2,25,NULL),
(3,1,5,2,15,1.50),
(3,2,4,3,15,5.00),
(3,2,6,3,25,2.00),
(3,3,5,2,25,1.50),
(3,3,7,2,15,2.50),
(4,1,4,3,15,1.50),
(4,1,6,3,25,2.50),
(4,2,5,2,25,2.00),
(4,2,7,2,15,3.00),
(4,3,6,3,15,2.50),
(4,3,8,3,25,3.50),
(5,1,5,2,25,2.50),
(5,1,7,2,15,3.50),
(5,2,6,3,15,3.00),
(5,2,8,3,25,4.00),
(5,3,7,2,25,3.50),
(5,3,9,2,15,4.50),
(6,1,6,3,15,3.50),
(6,1,8,3,25,4.50),
(6,2,7,2,25,4.00),
(6,2,9,2,15,5.00),
(6,3,8,3,15,4.50),
(6,3,10,3,25,1.50),
(7,1,7,2,25,4.50),
(7,1,9,2,15,1.50),
(7,2,8,3,15,5.00),
(7,2,10,3,25,2.00),
(7,3,9,2,25,1.50),
(7,3,11,2,15,NULL),
(8,1,8,3,15,1.50),
(8,1,10,3,25,2.50),
(8,2,9,2,25,2.00),
(8,2,11,2,15,NULL),
(8,3,10,3,15,NULL),
(8,3,12,3,25,3.50),
(9,1,9,2,25,2.50),
(9,1,11,2,15,NULL),
(9,2,10,3,15,NULL),
(9,2,12,3,25,4.00),
(9,3,1,2,15,2.50),
(9,3,11,2,25,3.50),
(10,1,10,3,15,NULL),
(10,1,12,3,25,4.50),
(10,2,1,2,15,3.00),
(10,2,11,2,25,4.00),
(10,3,2,3,25,3.50),
(10,3,12,3,15,4.50),
(11,1,1,2,15,3.50),
(11,1,11,2,25,4.50),
(11,2,2,3,25,4.00),
(11,2,12,3,15,5.00),
(11,3,1,2,25,3.50),
(11,3,3,2,15,4.50),
(12,1,2,3,25,4.50),
(12,1,12,3,15,1.50),
(12,2,1,2,25,4.00),
(12,2,3,2,15,5.00),
(12,3,2,3,15,4.50),
(12,3,4,3,25,1.50),
(13,1,1,2,25,4.50),
(13,1,3,2,15,1.50),
(13,2,2,3,15,5.00),
(13,2,4,3,25,2.00),
(13,3,3,2,25,1.50),
(13,3,5,2,15,NULL),
(14,1,2,3,15,1.50),
(14,1,4,3,25,2.50),
(14,2,3,2,25,2.00),
(14,2,5,2,15,NULL),
(14,3,4,3,15,NULL),
(14,3,6,3,25,3.50),
(15,1,3,2,25,2.50),
(15,1,5,2,15,NULL),
(15,2,4,3,15,NULL),
(15,2,6,3,25,4.00),
(15,3,5,2,25,3.50),
(15,3,7,2,15,4.50),
(16,1,4,3,15,NULL),
(16,1,6,3,25,4.50),
(16,2,5,2,25,4.00),
(16,2,7,2,15,5.00),
(16,3,6,3,15,4.50),
(16,3,8,3,25,1.50),
(17,1,5,2,25,4.50),
(17,1,7,2,15,1.50),
(17,2,6,3,15,5.00),
(17,2,8,3,25,2.00),
(17,3,7,2,25,1.50),
(17,3,9,2,15,2.50),
(18,1,6,3,15,1.50),
(18,1,8,3,25,2.50),
(18,2,7,2,25,2.00),
(18,2,9,2,15,3.00),
(18,3,8,3,15,2.50),
(18,3,10,3,25,3.50),
(19,1,7,2,25,2.50),
(19,1,9,2,15,3.50),
(19,2,8,3,15,3.00),
(19,2,10,3,25,4.00),
(19,3,9,2,25,3.50),
(19,3,11,2,15,4.50),
(20,1,8,3,15,3.50),
(20,1,10,3,25,4.50),
(20,2,9,2,25,4.00),
(20,2,11,2,15,5.00),
(20,3,10,3,15,4.50),
(20,3,12,3,25,NULL),
(21,1,9,2,25,4.50),
(21,1,11,2,15,1.50),
(21,2,10,3,15,5.00),
(21,2,12,3,25,NULL),
(21,3,1,2,15,4.50),
(21,3,11,2,25,NULL),
(22,1,10,3,15,1.50),
(22,1,12,3,25,NULL),
(22,2,1,2,15,5.00),
(22,2,11,2,25,NULL),
(22,3,2,3,25,1.50),
(22,3,12,3,15,2.50),
(23,1,1,2,15,1.50),
(23,1,11,2,25,NULL),
(23,2,2,3,25,2.00),
(23,2,12,3,15,3.00),
(23,3,1,2,25,1.50),
(23,3,3,2,15,2.50),
(24,1,2,3,25,2.50),
(24,1,12,3,15,3.50),
(24,2,1,2,25,2.00),
(24,2,3,2,15,3.00),
(24,3,2,3,15,2.50),
(24,3,4,3,25,3.50),
(25,1,1,2,25,2.50),
(25,1,3,2,15,3.50),
(25,2,2,3,15,3.00),
(25,2,4,3,25,4.00),
(25,3,3,2,25,3.50),
(25,3,5,2,15,4.50),
(26,1,2,3,15,3.50),
(26,1,4,3,25,4.50),
(26,2,3,2,25,4.00),
(26,2,5,2,15,5.00),
(26,3,4,3,15,4.50),
(26,3,6,3,25,NULL),
(27,1,3,2,25,4.50),
(27,1,5,2,15,1.50),
(27,2,4,3,15,5.00),
(27,2,6,3,25,NULL),
(27,3,5,2,25,NULL),
(27,3,7,2,15,2.50),
(28,1,4,3,15,1.50),
(28,1,6,3,25,NULL),
(28,2,5,2,25,NULL),
(28,2,7,2,15,3.00),
(28,3,6,3,15,2.50),
(28,3,8,3,25,3.50),
(29,1,5,2,25,NULL),
(29,1,7,2,15,3.50),
(29,2,6,3,15,3.00),
(29,2,8,3,25,4.00),
(29,3,7,2,25,3.50),
(29,3,9,2,15,4.50),
(30,1,6,3,15,3.50),
(30,1,8,3,25,4.50),
(30,2,7,2,25,4.00),
(30,2,9,2,15,5.00),
(30,3,8,3,15,4.50),
(30,3,10,3,25,1.50),
(31,1,7,2,25,4.50),
(31,1,9,2,15,1.50),
(31,2,8,3,15,5.00),
(31,2,10,3,25,2.00),
(31,3,9,2,25,1.50),
(31,3,11,2,15,2.50),
(32,1,8,3,15,1.50),
(32,1,10,3,25,2.50),
(32,2,9,2,25,2.00),
(32,2,11,2,15,3.00),
(32,3,10,3,15,2.50),
(32,3,12,3,25,3.50),
(33,1,9,2,25,2.50),
(33,1,11,2,15,3.50),
(33,2,10,3,15,3.00),
(33,2,12,3,25,4.00),
(33,3,1,2,15,2.50),
(33,3,11,2,25,3.50),
(34,1,10,3,15,3.50),
(34,1,12,3,25,4.50),
(34,2,1,2,15,3.00),
(34,2,11,2,25,4.00),
(34,3,2,3,25,3.50),
(34,3,12,3,15,NULL),
(35,1,1,2,15,3.50),
(35,1,11,2,25,4.50),
(35,2,2,3,25,4.00),
(35,2,12,3,15,NULL),
(35,3,1,2,25,3.50),
(35,3,3,2,15,4.50),
(36,1,2,3,25,4.50),
(36,1,12,3,15,NULL),
(36,2,1,2,25,4.00),
(36,2,3,2,15,5.00),
(36,3,2,3,15,4.50),
(36,3,4,3,25,1.50),
(37,1,1,2,25,4.50),
(37,1,3,2,15,1.50),
(37,2,2,3,15,5.00),
(37,2,4,3,25,2.00),
(37,3,3,2,25,1.50),
(37,3,5,2,15,2.50),
(38,1,2,3,15,1.50),
(38,1,4,3,25,2.50),
(38,2,3,2,25,2.00),
(38,2,5,2,15,3.00),
(38,3,4,3,15,2.50),
(38,3,6,3,25,3.50),
(39,1,3,2,25,2.50),
(39,1,5,2,15,3.50),
(39,2,4,3,15,3.00),
(39,2,6,3,25,4.00),
(39,3,5,2,25,3.50),
(39,3,7,2,15,NULL),
(40,1,4,3,15,3.50),
(40,1,6,3,25,4.50),
(40,2,5,2,25,4.00),
(40,2,7,2,15,NULL),
(40,3,6,3,15,NULL),
(40,3,8,3,25,1.50);

INSERT INTO avaliacao_fisica (data_avaliacao,nivel_dor,amplitude_movimento,observacoes,id_paciente) VALUES
('2026-01-04',3,'reduzida','Sem observações adicionais.',1),
('2026-02-07',6,'moderadamente reduzida','Sem observações adicionais.',2),
('2026-03-10',9,'aumentada','Sem observações adicionais.',3),
('2026-04-13',1,'normal','Sem observações adicionais.',4),
('2026-05-16',4,'reduzida','Paciente orientado a manter exercícios em casa.',5),
('2026-06-19',7,'moderadamente reduzida','Sem observações adicionais.',6),
('2026-07-22',10,'aumentada','Sem observações adicionais.',7),
('2026-08-25',2,'normal','Sem observações adicionais.',8),
('2026-01-03',5,'reduzida','Sem observações adicionais.',9),
('2026-02-06',8,'moderadamente reduzida','Paciente orientado a manter exercícios em casa.',10),
('2026-03-09',0,'aumentada','Sem observações adicionais.',11),
('2026-04-12',3,'normal','Sem observações adicionais.',12),
('2026-05-15',6,'reduzida','Sem observações adicionais.',13),
('2026-06-18',9,'moderadamente reduzida','Sem observações adicionais.',14),
('2026-07-21',1,'aumentada','Paciente orientado a manter exercícios em casa.',15),
('2026-08-24',4,'normal','Sem observações adicionais.',16),
('2026-01-02',7,'reduzida','Sem observações adicionais.',17),
('2026-02-05',10,'moderadamente reduzida','Sem observações adicionais.',18),
('2026-03-08',2,'aumentada','Sem observações adicionais.',19),
('2026-04-11',5,'normal','Paciente orientado a manter exercícios em casa.',20),
('2026-05-14',8,'reduzida','Sem observações adicionais.',21),
('2026-06-17',0,'moderadamente reduzida','Sem observações adicionais.',22),
('2026-07-20',3,'aumentada','Sem observações adicionais.',23),
('2026-08-23',6,'normal','Sem observações adicionais.',24),
('2026-01-01',9,'reduzida','Paciente orientado a manter exercícios em casa.',25),
('2026-02-04',1,'moderadamente reduzida','Sem observações adicionais.',26),
('2026-03-07',4,'aumentada','Sem observações adicionais.',27),
('2026-04-10',7,'normal','Sem observações adicionais.',28),
('2026-05-13',10,'reduzida','Sem observações adicionais.',29),
('2026-06-16',2,'moderadamente reduzida','Paciente orientado a manter exercícios em casa.',30),
('2026-07-19',5,'aumentada','Sem observações adicionais.',31),
('2026-08-22',8,'normal','Sem observações adicionais.',32),
('2026-01-25',0,'reduzida','Sem observações adicionais.',33),
('2026-02-03',3,'moderadamente reduzida','Sem observações adicionais.',34),
('2026-03-06',6,'aumentada','Paciente orientado a manter exercícios em casa.',35),
('2026-04-09',9,'normal','Sem observações adicionais.',36),
('2026-05-12',1,'reduzida','Sem observações adicionais.',37),
('2026-06-15',4,'moderadamente reduzida','Sem observações adicionais.',38),
('2026-07-18',7,'aumentada','Sem observações adicionais.',39),
('2026-08-21',10,'normal','Paciente orientado a manter exercícios em casa.',40);


-- Conferência rápida da carga:
SELECT 'PACIENTE' AS tabela, COUNT(*) AS quantidade FROM paciente
UNION ALL SELECT 'PROFISSIONAL', COUNT(*) FROM profissional
UNION ALL SELECT 'FISIOTERAPEUTA', COUNT(*) FROM fisioterapeuta
UNION ALL SELECT 'ESTAGIARIO', COUNT(*) FROM estagiario
UNION ALL SELECT 'TRATAMENTO', COUNT(*) FROM tratamento
UNION ALL SELECT 'SESSAO', COUNT(*) FROM sessao
UNION ALL SELECT 'EVOLUCAO', COUNT(*) FROM evolucao
UNION ALL SELECT 'EXERCICIO', COUNT(*) FROM exercicio
UNION ALL SELECT 'APLICACAO_EXERCICIO', COUNT(*) FROM aplicacao_exercicio
UNION ALL SELECT 'AVALIACAO_FISICA', COUNT(*) FROM avaliacao_fisica;

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
-- Pergunta: Quais pacientes possuem "Ana" no nome?
-- ============================================================
SELECT id_paciente, nome
FROM paciente
WHERE nome LIKE '%Ana%';

-- ============================================================
-- 5. BÁSICA — BETWEEN / IN / NULL
-- Pergunta: Quais pacientes nasceram entre 1985 e 1995 e não possuem telefone informado?
-- ============================================================
SELECT id_paciente, nome, data_nascimento, telefone
FROM paciente
WHERE data_nascimento BETWEEN '1985-01-01' AND '1995-12-31'
  AND id_convenio IN (1, 2, 3, 4)
  AND telefone IS NULL;

-- ============================================================
-- 6. JUNÇÃO — três tabelas
-- Pergunta: Quais tratamentos estão vinculados a quais pacientes,
-- fisioterapeutas e especialidades?
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
ORDER BY quantidade_tratamentos DESC;

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
ORDER BY quantidade_tratamentos DESC;

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
-- Pergunta: Quais pacientes possuem uma avaliação cuja dor é maior
-- que a média das avaliações daquele mesmo paciente?
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
-- Pergunta: Quais fisioterapeutas possuem pelo menos uma habilitação
-- registrada em especialidade?
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
    WHERE h.id_profissional = f.id_profissional
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
    AVG(a.nivel_dor) AS media_dor
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
ORDER BY media_dor DESC;

-- ============================================================
-- 15. AVANÇADA — pergunta não trivial
-- Pergunta: Quais fisioterapeutas possuem mais tratamentos do que
-- a média de tratamentos por fisioterapeuta?
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
ORDER BY quantidade_tratamentos DESC;

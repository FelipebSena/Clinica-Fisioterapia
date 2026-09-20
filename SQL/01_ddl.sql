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

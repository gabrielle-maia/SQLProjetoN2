CREATE DATABASE IF NOT EXISTS colegio_saber_total;
USE colegio_saber_total;

-- TABELA GRUPO_USUARIO
CREATE TABLE GRUPO_USUARIO (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(50) NOT NULL UNIQUE
);

-- TABELA USUARIO
CREATE TABLE USUARIO (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_grupo INT NOT NULL,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    senha CHAR(60) NOT NULL,
    ativo BOOLEAN DEFAULT TRUE,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_grupo) REFERENCES GRUPO_USUARIO(id)
);

-- TABELA ALUNO
CREATE TABLE ALUNO (
    id_aluno INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    data_nascimento DATE,
    responsavel VARCHAR(100),
    telefone VARCHAR(15),
    email VARCHAR(100) UNIQUE,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- TABELA TURMA
CREATE TABLE TURMA (
    id_turma INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(50) NOT NULL UNIQUE,
    ano_letivo YEAR NOT NULL,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- TABELA PROFESSOR
CREATE TABLE PROFESSOR (
    id_professor INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    telefone VARCHAR(15),
    email VARCHAR(100) UNIQUE,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- TABELA HORARIO
CREATE TABLE HORARIO (
    id_horario INT AUTO_INCREMENT PRIMARY KEY,
    id_turma INT NOT NULL,
    id_professor INT NOT NULL,
    disciplina VARCHAR(50) NOT NULL,
    dia_semana ENUM('SEG','TER','QUA','QUI','SEX','SAB') NOT NULL,
    faixa_horario TIME NOT NULL,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_turma) REFERENCES TURMA(id_turma),
    FOREIGN KEY (id_professor) REFERENCES PROFESSOR(id_professor)
);

-- TABELA CHAMADO
CREATE TABLE CHAMADO (
    id_chamado INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario_abertura INT NOT NULL,
    id_aluno INT NOT NULL,
    codigo_protocolo VARCHAR(20) UNIQUE,
    descricao TEXT NOT NULL,
    assunto VARCHAR(100),
    status ENUM('Aberto','Em Atendimento','Concluído','Cancelado') DEFAULT 'Aberto',
    prioridade ENUM('Baixa','Média','Alta') DEFAULT 'Média',
    data_abertura DATETIME DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario_abertura) REFERENCES USUARIO(id),
    FOREIGN KEY (id_aluno) REFERENCES ALUNO(id_aluno)
);

-- TABELA MATRICULA (N:M ALUNO x TURMA)
CREATE TABLE MATRICULA (
    id_aluno INT NOT NULL,
    id_turma INT NOT NULL,
    data_matricula DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_aluno, id_turma),
    FOREIGN KEY (id_aluno) REFERENCES ALUNO(id_aluno),
    FOREIGN KEY (id_turma) REFERENCES TURMA(id_turma)
);

-- TABELA LIVRO
CREATE TABLE LIVRO (
    id INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(255) NOT NULL,
    autor VARCHAR(100),
    categoria VARCHAR(50),
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ÍNDICES
CREATE INDEX idx_usuario_grupo     ON USUARIO(id_grupo);
CREATE INDEX idx_chamado_usuario   ON CHAMADO(id_usuario_abertura);
CREATE INDEX idx_chamado_aluno     ON CHAMADO(id_aluno);
CREATE INDEX idx_horario_turma     ON HORARIO(id_turma);
CREATE INDEX idx_horario_professor ON HORARIO(id_professor);

-- TRIGGER: gera código de protocolo do chamado
DELIMITER //
CREATE TRIGGER trg_chamado_codigo
BEFORE INSERT ON CHAMADO
FOR EACH ROW
BEGIN
    IF NEW.codigo_protocolo IS NULL THEN
        SET NEW.codigo_protocolo = CONCAT(
            'CS',
            YEAR(NOW()),
            LPAD(
                (SELECT COALESCE(MAX(id_chamado), 0) + 1 FROM CHAMADO),
                5,
                '0'
            )
        );
    END IF;
END//
DELIMITER ;

-- TRIGGER: atualiza data_atualizacao quando houver alteração relevante
DELIMITER //
CREATE TRIGGER trg_chamado_update
BEFORE UPDATE ON CHAMADO
FOR EACH ROW
BEGIN
    IF NEW.status <> OLD.status
       OR NEW.descricao <> OLD.descricao
       OR NEW.prioridade <> OLD.prioridade THEN
        SET NEW.data_atualizacao = NOW();
    END IF;
END//
DELIMITER ;

-- VIEW: chamados em aberto
CREATE VIEW vw_chamados_abertos AS
SELECT
    C.id_chamado,
    C.codigo_protocolo,
    A.nome AS nome_aluno,
    C.assunto,
    C.status,
    C.data_abertura,
    C.data_atualizacao
FROM CHAMADO C
JOIN ALUNO A ON C.id_aluno = A.id_aluno
WHERE C.status IN ('Aberto','Em Atendimento');

-- VIEW: total de ocorrências por aluno e assunto
CREATE VIEW vw_total_ocorrencias AS
SELECT
    A.nome AS nome_aluno,
    COUNT(C.id_chamado) AS total_ocorrencias_por_aluno,
    C.assunto AS categoria
FROM ALUNO A
JOIN CHAMADO C ON A.id_aluno = C.id_aluno
GROUP BY A.nome, C.assunto
ORDER BY total_ocorrencias_por_aluno DESC;

-- TABELA DE AUDITORIA DE ACESSO
CREATE TABLE AUDITORIA_ACESSO (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    acao VARCHAR(255) NOT NULL,
    data_hora DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES USUARIO(id)
);

-- FUNCTION: calcular_idade
DELIMITER //
CREATE FUNCTION calcular_idade (data_nasc DATE)
RETURNS INT
DETERMINISTIC
BEGIN
    RETURN TIMESTAMPDIFF(YEAR, data_nasc, CURDATE());
END//
DELIMITER ;

-- PROCEDURE: registrar_acesso
DELIMITER //
CREATE PROCEDURE registrar_acesso(
    IN p_usuario_id INT,
    IN p_acao VARCHAR(255)
)
BEGIN
    INSERT INTO AUDITORIA_ACESSO (id_usuario, acao)
    VALUES (p_usuario_id, p_acao);
END//
DELIMITER ;
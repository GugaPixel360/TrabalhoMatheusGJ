DROP DATABASE IF EXISTS assistencia_tecnica;
CREATE DATABASE IF NOT EXISTS assistencia_tecnica;

USE assistencia_tecnica;


CREATE TABLE cliente (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(120) NOT NULL,
    cpf_cnpj VARCHAR(18) NOT NULL,
    telefone VARCHAR(20) NOT NULL,
    email VARCHAR(120) NULL,
    endereco VARCHAR(200) NULL,
    data_cadastro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE funcionario (
    id_funcionario INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(120) NOT NULL,
    cpf VARCHAR(14) NOT NULL,
    cargo VARCHAR(60) NOT NULL,
    email VARCHAR(120) NULL,
    data_admissao DATE NOT NULL,
    ativo INT NOT NULL DEFAULT 1
);

CREATE TABLE tipo_equipamento (
    id_tipo INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(50) NOT NULL
);

CREATE TABLE categoria_problema (
    id_categoria_problema INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(60) NOT NULL
);

CREATE TABLE forma_pagamento (
    id_forma_pagamento INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(40) NOT NULL
);

-- Catálogo de serviços oferecidos (valor_padrao é apenas o preço de tabela)
CREATE TABLE servico (
    id_servico INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    descricao VARCHAR(255) NULL,
    valor_padrao DECIMAL(10,2) NOT NULL
);

-- Estoque de peças: quantidade_estoque nunca pode ficar negativa
CREATE TABLE peca (
    id_peca INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(30) NOT NULL,
    nome VARCHAR(100) NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,
    quantidade_estoque INT NOT NULL,
    estoque_minimo INT NOT NULL,
    ativo INT NOT NULL DEFAULT 1
);

-- ---------------------------------------------------------------------
-- 3.2 Tabelas com chave estrangeira
-- ---------------------------------------------------------------------

-- Um cliente (1) possui vários equipamentos (N)
CREATE TABLE equipamento (
    id_equipamento INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    fk_equipamento_cliente INT NOT NULL,
    fk_equipamento_tipo INT NOT NULL,
    marca VARCHAR(60) NOT NULL,
    modelo VARCHAR(80) NOT NULL,
    numero_serie VARCHAR(60) NOT NULL,
    descricao VARCHAR(255) NULL,
    data_cadastro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (fk_equipamento_cliente) REFERENCES cliente (id_cliente),
    FOREIGN KEY (fk_equipamento_tipo) REFERENCES tipo_equipamento (id_tipo)
);

-- Ordem de serviço: um equipamento (1) tem várias OS (N);
-- cada OS tem exatamente um funcionário responsável.
CREATE TABLE ordem_servico (
    id_os INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    FK_id_equipamento INT NOT NULL,
    FK_id_funcionario INT NOT NULL,
    FK_id_categoria_problema INT NOT NULL,
    problema_relatado TEXT NOT NULL,
    diagnostico_tecnico TEXT NULL,
    data_entrada DATETIME  NULL DEFAULT CURRENT_TIMESTAMP,
    data_conclusao DATETIME NULL,
    situacao ENUM('ABERTA','EM_ANDAMENTO','CONCLUIDA','CANCELADA') NOT NULL DEFAULT 'ABERTA',

    FOREIGN KEY (FK_id_equipamento) REFERENCES equipamento (id_equipamento),
    FOREIGN KEY (FK_id_funcionario) REFERENCES funcionario (id_funcionario),
    FOREIGN KEY (FK_id_categoria_problema) REFERENCES categoria_problema (id_categoria_problema)

);

CREATE TABLE historico_servicos (
    id_historico INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    FK_id_os INT NOT NULL,
    FK_id_servico INT NOT NULL,
    FK_id_funcionario INT NOT NULL,
    quantidade INT NOT NULL,
    valor_cobrado DECIMAL(10,2) NOT NULL,
    observacao VARCHAR(255) NULL,
    data_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (FK_id_os) REFERENCES ordem_servico (id_os),
    FOREIGN KEY (FK_id_servico) REFERENCES servico (id_servico),
    FOREIGN KEY (FK_id_funcionario) REFERENCES funcionario (id_funcionario)

);  

CREATE TABLE os_servico (
    id_os_servico INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    FK_id_os INT NOT NULL,
    FK_id_servico INT NOT NULL,
    quantidade INT NOT NULL DEFAULT 1,
    valor_cobrado DECIMAL(10,2) NOT NULL,
    observacao VARCHAR(255) NULL,

    FOREIGN KEY (FK_id_os) REFERENCES ordem_servico (id_os),
    FOREIGN KEY (FK_id_servico) REFERENCES servico (id_servico)
);

-- OS (N) <-> Peça (N): peças consumidas em cada OS (zero, uma ou várias).
-- valor_unitario guarda o preço da peça no momento do uso.
CREATE TABLE os_peca (
    id_os_peca INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    FK_id_os INT NOT NULL,
    FK_id_peca INT NOT NULL,
    quantidade INT NOT NULL,
    valor_unitario DECIMAL(10,2) NOT NULL,

    FOREIGN KEY (FK_id_os) REFERENCES ordem_servico (id_os),
    FOREIGN KEY (FK_id_peca) REFERENCES peca (id_peca)
);

-- Pagamentos: uma OS (1) pode ter vários pagamentos (N) -> permite pagamento parcial.
CREATE TABLE pagamento (
    id_pagamento INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    FK_id_os INT NOT NULL,
    FK_id_forma_pagamento INT NOT NULL,
    valor DECIMAL(10,2) NOT NULL,
    data_pagamento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacao VARCHAR(255) NULL,

    FOREIGN KEY (FK_id_os) REFERENCES ordem_servico (id_os),
    FOREIGN KEY (FK_id_forma_pagamento) REFERENCES forma_pagamento (id_forma_pagamento)
);




--------------
---TRIGGERS---
--------------



DELIMITER $$

-- =====================================================
-- 1. PECA
-- =====================================================

DROP TRIGGER IF EXISTS trg_peca_beforeInsert$$
CREATE TRIGGER trg_peca_beforeInsert
BEFORE INSERT ON peca
FOR EACH ROW
BEGIN
    IF NEW.quantidade_estoque < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Estoque nao pode ser negativo.';
    END IF;

    IF NEW.preco_unitario < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Valor da peca nao pode ser negativo.';
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_peca_beforeUpdate$$
CREATE TRIGGER trg_peca_beforeUpdate
BEFORE UPDATE ON peca
FOR EACH ROW
BEGIN
    IF NEW.quantidade_estoque < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Estoque nao pode ser negativo.';
    END IF;

    IF NEW.preco_unitario < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Valor da peca nao pode ser negativo.';
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_peca_beforeDelete$$
CREATE TRIGGER trg_peca_beforeDelete
BEFORE DELETE ON peca
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM os_peca
        WHERE FK_id_peca = OLD.id_peca
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Peca utilizada em OS: exclusao bloqueada.';
    END IF;
END$$


-- =====================================================
-- 2. ORDEM_SERVICO
-- =====================================================

DROP TRIGGER IF EXISTS trg_os_beforeInsert$$
CREATE TRIGGER trg_os_beforeInsert
BEFORE INSERT ON ordem_servico
FOR EACH ROW
BEGIN
    IF NEW.situacao IS NULL THEN
        SET NEW.situacao = 'ABERTA';
    END IF;

    IF NEW.situacao NOT IN ('ABERTA', 'EM_ANDAMENTO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Uma OS deve ser criada como ABERTA ou EM_ANDAMENTO.';
    END IF;

    IF NEW.data_entrada IS NULL THEN
        SET NEW.data_entrada = CURRENT_TIMESTAMP;
    END IF;

    SET NEW.data_conclusao = NULL;
END$$


DROP TRIGGER IF EXISTS trg_os_beforeUpdate$$
CREATE TRIGGER trg_os_beforeUpdate
BEFORE UPDATE ON ordem_servico
FOR EACH ROW
BEGIN
    -- OS concluida ou cancelada nao pode ser alterada
    IF OLD.situacao IN ('CONCLUIDA', 'CANCELADA') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'OS concluida ou cancelada nao pode ser alterada.';
    END IF;

    -- Impede transicoes invalidas
    IF OLD.situacao = 'ABERTA'
       AND NEW.situacao = 'CONCLUIDA' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'A OS precisa passar por EM_ANDAMENTO antes de concluir.';
    END IF;

    -- Verifica data de conclusao
    IF NEW.data_conclusao IS NOT NULL
       AND NEW.data_conclusao < NEW.data_entrada THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data de conclusao anterior a data de entrada.';
    END IF;

    -- Exige pelo menos um servico para concluir
    IF NEW.situacao = 'CONCLUIDA' THEN

        IF NOT EXISTS (
            SELECT 1
            FROM os_servico
            WHERE FK_id_os = OLD.id_os
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Nao e possivel concluir uma OS sem servicos.';
        END IF;

        IF NEW.data_conclusao IS NULL THEN
            SET NEW.data_conclusao = CURRENT_TIMESTAMP;
        END IF;
    END IF;

    -- Ao cancelar, registra a data
    IF NEW.situacao = 'CANCELADA'
       AND NEW.data_conclusao IS NULL THEN
        SET NEW.data_conclusao = CURRENT_TIMESTAMP;
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_os_afterUpdate$$
CREATE TRIGGER trg_os_afterUpdate
AFTER UPDATE ON ordem_servico
FOR EACH ROW
BEGIN
    -- Devolve as pecas ao estoque quando a OS e cancelada
    IF NEW.situacao = 'CANCELADA'
       AND OLD.situacao <> 'CANCELADA' THEN

        UPDATE peca p
        JOIN os_peca op
            ON op.FK_id_peca = p.id_peca
        SET p.quantidade_estoque =
            p.quantidade_estoque + op.quantidade
        WHERE op.FK_id_os = NEW.id_os;

    END IF;
END$$


DROP TRIGGER IF EXISTS trg_os_beforeDelete$$
CREATE TRIGGER trg_os_beforeDelete
BEFORE DELETE ON ordem_servico
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'OS nao pode ser excluida. Altere sua situacao para CANCELADA.';
END$$


-- =====================================================
-- 3. OS_PECA
-- =====================================================

DROP TRIGGER IF EXISTS trg_os_peca_beforeInsert$$
CREATE TRIGGER trg_os_peca_beforeInsert
BEFORE INSERT ON os_peca
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_estoque INT;
    DECLARE v_preco DECIMAL(10,2);

    SELECT situacao
    INTO v_status
    FROM ordem_servico
    WHERE id_os = NEW.FK_id_os;

    IF v_status IS NULL
       OR v_status NOT IN ('ABERTA', 'EM_ANDAMENTO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'So e possivel utilizar pecas em OS aberta ou em andamento.';
    END IF;

    IF NEW.quantidade IS NULL OR NEW.quantidade <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Quantidade deve ser maior que zero.';
    END IF;

    SELECT quantidade_estoque, preco_unitario
    INTO v_estoque, v_preco
    FROM peca
    WHERE id_peca = NEW.FK_id_peca;

    IF v_estoque IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Peca inexistente.';
    END IF;

    IF NEW.quantidade > v_estoque THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Estoque insuficiente.';
    END IF;

    -- Guarda o preco da peca no momento da utilizacao
    SET NEW.valor_unitario = v_preco;
END$$


DROP TRIGGER IF EXISTS trg_os_peca_afterInsert$$
CREATE TRIGGER trg_os_peca_afterInsert
AFTER INSERT ON os_peca
FOR EACH ROW
BEGIN
    UPDATE peca
    SET quantidade_estoque = quantidade_estoque - NEW.quantidade
    WHERE id_peca = NEW.FK_id_peca;
END$$


DROP TRIGGER IF EXISTS trg_os_peca_beforeUpdate$$
CREATE TRIGGER trg_os_peca_beforeUpdate
BEFORE UPDATE ON os_peca
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_estoque INT;

    IF NEW.FK_id_os <> OLD.FK_id_os
       OR NEW.FK_id_peca <> OLD.FK_id_peca THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nao e permitido trocar a OS ou a peca.';
    END IF;

    SELECT situacao
    INTO v_status
    FROM ordem_servico
    WHERE id_os = OLD.FK_id_os;

    IF v_status NOT IN ('ABERTA', 'EM_ANDAMENTO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'OS finalizada: itens nao podem ser alterados.';
    END IF;

    IF NEW.quantidade <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Quantidade deve ser maior que zero.';
    END IF;

    IF NEW.quantidade > OLD.quantidade THEN

        SELECT quantidade_estoque
        INTO v_estoque
        FROM peca
        WHERE id_peca = OLD.FK_id_peca;

        IF (NEW.quantidade - OLD.quantidade) > v_estoque THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Estoque insuficiente para aumentar a quantidade.';
        END IF;
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_os_peca_afterUpdate$$
CREATE TRIGGER trg_os_peca_afterUpdate
AFTER UPDATE ON os_peca
FOR EACH ROW
BEGIN
    UPDATE peca
    SET quantidade_estoque =
        quantidade_estoque - (NEW.quantidade - OLD.quantidade)
    WHERE id_peca = NEW.FK_id_peca;
END$$


DROP TRIGGER IF EXISTS trg_os_peca_beforeDelete$$
CREATE TRIGGER trg_os_peca_beforeDelete
BEFORE DELETE ON os_peca
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);

    SELECT situacao
    INTO v_status
    FROM ordem_servico
    WHERE id_os = OLD.FK_id_os;

    IF v_status NOT IN ('ABERTA', 'EM_ANDAMENTO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'OS finalizada: itens nao podem ser removidos.';
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_os_peca_afterDelete$$
CREATE TRIGGER trg_os_peca_afterDelete
AFTER DELETE ON os_peca
FOR EACH ROW
BEGIN
    UPDATE peca
    SET quantidade_estoque = quantidade_estoque + OLD.quantidade
    WHERE id_peca = OLD.FK_id_peca;
END$$


-- =====================================================
-- 4. OS_SERVICO
-- =====================================================

DROP TRIGGER IF EXISTS trg_os_servico_beforeInsert$$
CREATE TRIGGER trg_os_servico_beforeInsert
BEFORE INSERT ON os_servico
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_valor DECIMAL(10,2);

    SELECT situacao
    INTO v_status
    FROM ordem_servico
    WHERE id_os = NEW.FK_id_os;

    IF v_status IS NULL
       OR v_status NOT IN ('ABERTA', 'EM_ANDAMENTO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'So e possivel registrar servicos em OS aberta ou em andamento.';
    END IF;

    IF NEW.quantidade <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Quantidade do servico deve ser maior que zero.';
    END IF;

    IF NEW.valor_cobrado IS NULL THEN
        SELECT valor_padrao
        INTO v_valor
        FROM servico
        WHERE id_servico = NEW.FK_id_servico;

        SET NEW.valor_cobrado = v_valor;
    END IF;

    IF NEW.valor_cobrado < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Valor cobrado nao pode ser negativo.';
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_os_servico_beforeUpdate$$
CREATE TRIGGER trg_os_servico_beforeUpdate
BEFORE UPDATE ON os_servico
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);

    SELECT situacao
    INTO v_status
    FROM ordem_servico
    WHERE id_os = OLD.FK_id_os;

    IF v_status NOT IN ('ABERTA', 'EM_ANDAMENTO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'OS finalizada: servicos nao podem ser alterados.';
    END IF;

    IF NEW.FK_id_os <> OLD.FK_id_os THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nao e permitido trocar a OS do servico.';
    END IF;

    IF NEW.quantidade <= 0 OR NEW.valor_cobrado < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Quantidade ou valor do servico invalido.';
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_os_servico_beforeDelete$$
CREATE TRIGGER trg_os_servico_beforeDelete
BEFORE DELETE ON os_servico
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);

    SELECT situacao
    INTO v_status
    FROM ordem_servico
    WHERE id_os = OLD.FK_id_os;

    IF v_status NOT IN ('ABERTA', 'EM_ANDAMENTO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'OS finalizada: servicos nao podem ser removidos.';
    END IF;
END$$


-- =====================================================
-- 5. HISTORICO_SERVICOS
-- =====================================================

DROP TRIGGER IF EXISTS trg_historico_servicos_afterInsert$$
CREATE TRIGGER trg_historico_servicos_afterInsert
AFTER INSERT ON os_servico
FOR EACH ROW
BEGIN
    DECLARE v_funcionario INT;

    SELECT FK_id_funcionario
    INTO v_funcionario
    FROM ordem_servico
    WHERE id_os = NEW.FK_id_os;

    INSERT INTO historico_servicos (
        FK_id_os,
        FK_id_servico,
        FK_id_funcionario,
        quantidade,
        valor_cobrado,
        observacao
    )
    VALUES (
        NEW.FK_id_os,
        NEW.FK_id_servico,
        v_funcionario,
        NEW.quantidade,
        NEW.valor_cobrado,
        NEW.observacao
    );
END$$


-- =====================================================
-- 6. PAGAMENTO
-- =====================================================

DROP TRIGGER IF EXISTS trg_pagamento_beforeInsert$$
CREATE TRIGGER trg_pagamento_beforeInsert
BEFORE INSERT ON pagamento
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_total DECIMAL(12,2);
    DECLARE v_pago DECIMAL(12,2);

    SELECT situacao
    INTO v_status
    FROM ordem_servico
    WHERE id_os = NEW.FK_id_os;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'OS inexistente.';
    END IF;

    IF v_status <> 'CONCLUIDA' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Pagamento so pode ser registrado para OS concluida.';
    END IF;

    IF NEW.valor <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Valor do pagamento deve ser maior que zero.';
    END IF;

    -- Calcula o valor total dos servicos e pecas
    SELECT
        COALESCE((
            SELECT SUM(quantidade * valor_cobrado)
            FROM os_servico
            WHERE FK_id_os = NEW.FK_id_os
        ), 0)
        +
        COALESCE((
            SELECT SUM(quantidade * valor_unitario)
            FROM os_peca
            WHERE FK_id_os = NEW.FK_id_os
        ), 0)
    INTO v_total;

    -- Soma os pagamentos ja registrados
    SELECT COALESCE(SUM(valor), 0)
    INTO v_pago
    FROM pagamento
    WHERE FK_id_os = NEW.FK_id_os;

    IF v_pago + NEW.valor > v_total THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Pagamento excede o valor total da OS.';
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_pagamento_beforeUpdate$$
CREATE TRIGGER trg_pagamento_beforeUpdate
BEFORE UPDATE ON pagamento
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Pagamento registrado nao pode ser alterado.';
END$$


DROP TRIGGER IF EXISTS trg_pagamento_beforeDelete$$
CREATE TRIGGER trg_pagamento_beforeDelete
BEFORE DELETE ON pagamento
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Pagamento registrado nao pode ser excluido.';
END$$


-- =====================================================
-- 7. PROTECAO DOS CADASTROS
-- =====================================================

DROP TRIGGER IF EXISTS trg_cliente_beforeDelete$$
CREATE TRIGGER trg_cliente_beforeDelete
BEFORE DELETE ON cliente
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM equipamento
        WHERE fk_equipamento_cliente = OLD.id_cliente
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cliente possui equipamentos cadastrados.';
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_equipamento_beforeDelete$$
CREATE TRIGGER trg_equipamento_beforeDelete
BEFORE DELETE ON equipamento
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM ordem_servico
        WHERE FK_id_equipamento = OLD.id_equipamento
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Equipamento possui OS vinculadas.';
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_funcionario_beforeDelete$$
CREATE TRIGGER trg_funcionario_beforeDelete
BEFORE DELETE ON funcionario
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM ordem_servico
        WHERE FK_id_funcionario = OLD.id_funcionario
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Funcionario possui OS vinculadas.';
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_categoria_beforeDelete$$
CREATE TRIGGER trg_categoria_beforeDelete
BEFORE DELETE ON categoria_problema
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM ordem_servico
        WHERE FK_id_categoria_problema = OLD.id_categoria_problema
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Categoria possui OS vinculadas.';
    END IF;
END$$


DROP TRIGGER IF EXISTS trg_servico_beforeDelete$$
CREATE TRIGGER trg_servico_beforeDelete
BEFORE DELETE ON servico
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM os_servico
        WHERE FK_id_servico = OLD.id_servico
    ) OR EXISTS (
        SELECT 1
        FROM historico_servicos
        WHERE FK_id_servico = OLD.id_servico
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Servico possui registros historicos e nao pode ser excluido.';
    END IF;
END$$


DELIMITER ;
-- =====================================================================
-- 7. STORED PROCEDURES
-- As regras de negócio ficam nos triggers/constraints; as procedures
-- fazem a orquestração (valores padrão, transação e retorno de IDs).
-- =====================================================================
DELIMITER $$

-- 7.1 Cadastrar cliente
CREATE PROCEDURE sp_cadastrar_cliente (
    IN  p_nome      VARCHAR(120),
    IN  p_cpf_cnpj  VARCHAR(18),
    IN  p_telefone  VARCHAR(20),
    IN  p_email     VARCHAR(120),
    IN  p_endereco  VARCHAR(200),
    OUT p_id_cliente INT UNSIGNED
)
BEGIN
    IF p_nome IS NULL OR TRIM(p_nome) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O nome do cliente é obrigatório.';
    END IF;

    INSERT INTO cliente (nome, cpf_cnpj, telefone, email, endereco)
    VALUES (TRIM(p_nome), p_cpf_cnpj, p_telefone, p_email, p_endereco);

    SET p_id_cliente = LAST_INSERT_ID();
END$$

-- 7.2 Cadastrar equipamento (FKs e UNIQUE do número de série são validados pelo banco)
CREATE PROCEDURE sp_cadastrar_equipamento (
    IN  p_id_cliente   INT UNSIGNED,
    IN  p_id_tipo      INT UNSIGNED,
    IN  p_marca        VARCHAR(60),
    IN  p_modelo       VARCHAR(80),
    IN  p_numero_serie VARCHAR(60),
    IN  p_descricao    VARCHAR(255),
    OUT p_id_equipamento INT UNSIGNED
)
BEGIN
    INSERT INTO equipamento (id_cliente, id_tipo, marca, modelo, numero_serie, descricao)
    VALUES (p_id_cliente, p_id_tipo, p_marca, p_modelo, p_numero_serie, p_descricao);

    SET p_id_equipamento = LAST_INSERT_ID();
END$$

-- 7.3 Abrir ordem de serviço (situação ABERTA e data de entrada automáticas)
CREATE PROCEDURE sp_abrir_os (
    IN  p_id_equipamento        INT UNSIGNED,
    IN  p_id_funcionario        INT UNSIGNED,
    IN  p_id_categoria_problema INT UNSIGNED,
    IN  p_problema_relatado     TEXT,
    OUT p_id_os                 INT UNSIGNED
)
BEGIN
    IF p_problema_relatado IS NULL OR TRIM(p_problema_relatado) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe o problema relatado pelo cliente.';
    END IF;

    INSERT INTO ordem_servico (id_equipamento, id_funcionario, id_categoria_problema, problema_relatado)
    VALUES (p_id_equipamento, p_id_funcionario, p_id_categoria_problema, TRIM(p_problema_relatado));

    SET p_id_os = LAST_INSERT_ID();
END$$

-- 7.4 Registrar serviço realizado (valor NULL = usa o valor padrão do catálogo)
CREATE PROCEDURE sp_registrar_servico (
    IN p_id_os         INT UNSIGNED,
    IN p_id_servico    INT UNSIGNED,
    IN p_quantidade    INT,
    IN p_valor_cobrado DECIMAL(10,2),
    IN p_observacao    VARCHAR(255)
)
BEGIN
    DECLARE v_valor DECIMAL(10,2);

    IF p_valor_cobrado IS NULL THEN
        SELECT valor_padrao INTO v_valor FROM servico WHERE id_servico = p_id_servico;
        IF v_valor IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Serviço inexistente no catálogo.';
        END IF;
    ELSE
        SET v_valor = p_valor_cobrado;
    END IF;

    INSERT INTO os_servico (id_os, id_servico, quantidade, valor_cobrado, observacao)
    VALUES (p_id_os, p_id_servico, IFNULL(p_quantidade, 1), v_valor, p_observacao);
END$$

-- 7.5 Registrar utilização de peça. Preço vem do cadastro da peça.
-- Validação de estoque e baixa ficam nos triggers; aqui há transação
-- para manter a trava da linha da peça até o COMMIT.
CREATE PROCEDURE sp_utilizar_peca (
    IN p_id_os      INT UNSIGNED,
    IN p_id_peca    INT UNSIGNED,
    IN p_quantidade INT
)
BEGIN
    DECLARE v_preco DECIMAL(10,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT preco_unitario INTO v_preco FROM peca WHERE id_peca = p_id_peca;
    IF v_preco IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Peça inexistente.';
    END IF;

    INSERT INTO os_peca (id_os, id_peca, quantidade, valor_unitario)
    VALUES (p_id_os, p_id_peca, p_quantidade, v_preco);

    COMMIT;
END$$

-- 7.6 Alterar situação da OS (andamento, conclusão ou cancelamento).
-- As transições permitidas são validadas pelo trigger trg_ordem_servico_bu.
CREATE PROCEDURE sp_alterar_situacao_os (
    IN p_id_os          INT UNSIGNED,
    IN p_nova_situacao  VARCHAR(20),
    IN p_diagnostico    TEXT
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;

    IF p_nova_situacao NOT IN ('ABERTA','EM_ANDAMENTO','CONCLUIDA','CANCELADA') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Situação informada é inválida.';
    END IF;

    SELECT COUNT(*) INTO v_existe FROM ordem_servico WHERE id_os = p_id_os;
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ordem de serviço inexistente.';
    END IF;

    UPDATE ordem_servico
       SET situacao = p_nova_situacao,
           diagnostico_tecnico = COALESCE(p_diagnostico, diagnostico_tecnico)
     WHERE id_os = p_id_os;
END$$

-- 7.7 Registrar pagamento e devolver a posição financeira da OS
CREATE PROCEDURE sp_registrar_pagamento (
    IN p_id_os             INT UNSIGNED,
    IN p_id_forma_pagamento INT UNSIGNED,
    IN p_valor             DECIMAL(10,2),
    IN p_observacao        VARCHAR(255)
)
BEGIN
    INSERT INTO pagamento (id_os, id_forma_pagamento, valor, observacao)
    VALUES (p_id_os, p_id_forma_pagamento, p_valor, p_observacao);

    SELECT id_os, valor_total, valor_pago, saldo_pendente, situacao_pagamento
      FROM vw_os_financeiro
     WHERE id_os = p_id_os;
END$$

-- 7.8 Consultar histórico de manutenção de um equipamento
CREATE PROCEDURE sp_historico_equipamento (
    IN p_id_equipamento INT UNSIGNED
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM equipamento WHERE id_equipamento = p_id_equipamento) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Equipamento inexistente.';
    END IF;

    SELECT os.id_os, os.data_entrada, os.data_conclusao, os.situacao,
           f.nome AS tecnico, cp.nome AS categoria_problema,
           os.problema_relatado, os.diagnostico_tecnico,
           fin.valor_mao_obra, fin.valor_pecas, fin.valor_total,
           fin.valor_pago, fin.situacao_pagamento
      FROM ordem_servico os
      INNER JOIN funcionario f          ON f.id_funcionario = os.id_funcionario
      INNER JOIN categoria_problema cp  ON cp.id_categoria_problema = os.id_categoria_problema
      INNER JOIN vw_os_financeiro fin   ON fin.id_os = os.id_os
     WHERE os.id_equipamento = p_id_equipamento
     ORDER BY os.data_entrada;
END$$

-- 7.9 Repor estoque (entrada de peças compradas)
CREATE PROCEDURE sp_repor_estoque (
    IN p_id_peca    INT UNSIGNED,
    IN p_quantidade INT
)
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A quantidade de reposição deve ser maior que zero.';
    END IF;

    UPDATE peca SET quantidade_estoque = quantidade_estoque + p_quantidade
     WHERE id_peca = p_id_peca;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Peça inexistente.';
    END IF;
END$$

DELIMITER ;



-- =====================================================
-- 1. TIPOS DE EQUIPAMENTO
-- =====================================================

INSERT INTO tipo_equipamento (nome) VALUES
('Notebook'),
('Computador desktop'),
('Monitor'),
('Tablet'),
('Impressora');


-- =====================================================
-- 2. CATEGORIAS DE PROBLEMAS
-- =====================================================

INSERT INTO categoria_problema (nome) VALUES
('Não liga'),
('Lentidão / desempenho'),
('Tela / imagem'),
('Superaquecimento'),
('Falha de armazenamento'),
('Vírus / software'),
('Bateria / carregamento'),
('Falha de impressão');


-- =====================================================
-- 3. FORMAS DE PAGAMENTO
-- =====================================================

INSERT INTO forma_pagamento (nome) VALUES
('Dinheiro'),
('PIX'),
('Cartão de crédito'),
('Cartão de débito'),
('Boleto bancário');


-- =====================================================
-- 4. SERVIÇOS
-- =====================================================

INSERT INTO servico (nome, descricao, valor_padrao) VALUES
('Diagnóstico técnico', 'Avaliação completa do equipamento', 60.00),
('Formatação e instalação do sistema', 'Backup, formatação e instalação do SO', 120.00),
('Limpeza interna e pasta térmica', 'Limpeza de componentes e troca de pasta', 90.00),
('Troca de tela', 'Mão de obra para substituição de tela', 150.00),
('Troca de SSD/HD', 'Substituição de unidade de armazenamento', 80.00),
('Troca de bateria ou carregador', 'Substituição de bateria ou fonte externa', 60.00),
('Remoção de vírus e otimização', 'Limpeza de malware e ajustes de desempenho', 100.00),
('Reparo em placa-mãe', 'Reparo em nível de componente', 250.00),
('Manutenção de impressora', 'Limpeza, desobstrução e calibração', 110.00),
('Troca de fonte de alimentação', 'Substituição da fonte de computador desktop', 70.00);


-- =====================================================
-- 5. PEÇAS
-- =====================================================

INSERT INTO peca
(codigo, nome, preco_unitario, quantidade_estoque, estoque_minimo) VALUES
('PC-SSD240', 'SSD 240GB SATA', 189.90, 15, 5),
('PC-SSD480', 'SSD 480GB SATA', 299.90, 4, 5),
('PC-RAM8D4', 'Memória RAM 8GB DDR4', 159.90, 12, 5),
('PC-RAM8D3', 'Memória RAM 8GB DDR3L SODIMM', 169.90, 3, 5),
('PC-TELA156', 'Tela LED 15.6 para notebook', 389.00, 6, 3),
('PC-BAT-DL', 'Bateria para notebook Dell', 279.00, 5, 3),
('PC-PASTA4', 'Pasta térmica 4g', 24.90, 40, 10),
('PC-FONTE500', 'Fonte ATX 500W', 229.90, 7, 3),
('PC-COOLNB', 'Cooler para notebook', 59.90, 10, 4),
('PC-CARG65', 'Carregador universal 65W', 119.90, 9, 4),
('PC-TINTA-EP', 'Refil de tinta para impressora', 59.90, 20, 6),
('PC-TECLNB', 'Teclado para notebook ABNT2', 89.90, 0, 3);


-- =====================================================
-- 6. CLIENTES
-- =====================================================

INSERT INTO cliente
(nome, cpf_cnpj, telefone, email, endereco) VALUES
('Ana Paula Ribeiro', '111.444.777-35',
 '(47) 99111-0001', 'ana.ribeiro@email.com', 'Rua das Flores, 120'),

('Carlos Eduardo Moreira', '529.982.247-25',
 '(47) 99111-0002', 'carlos.moreira@email.com', 'Av. Central, 450'),

('Tech Solutions Ltda', '12.345.678/0001-95',
 '(47) 3333-0003', 'contato@techsol.com.br', 'Rua Industrial, 800'),

('Mariana Souza Lima', '390.533.447-05',
 '(47) 99111-0004', 'mariana.lima@email.com', 'Travessa do Sol, 33'),

('João Pedro Alves', '168.995.350-09',
 '(47) 99111-0005', NULL, 'Rua Bela Vista, 77'),

('Escola Municipal Aurora', '98.765.432/0001-10',
 '(47) 3333-0006', 'secretaria@aurora.edu.br', 'Av. das Escolas, 1000');


-- =====================================================
-- 7. FUNCIONÁRIOS
-- =====================================================

INSERT INTO funcionario
(nome, cpf, cargo, email, data_admissao, ativo) VALUES
('Roberto Mendes', '210.320.430-01',
 'Técnico Sênior', 'roberto@assistec.com', '2020-03-02', 1),

('Fernanda Costa', '210.320.430-02',
 'Técnica de Hardware', 'fernanda@assistec.com', '2021-06-14', 1),

('Lucas Pereira', '210.320.430-03',
 'Técnico de Software', 'lucas@assistec.com', '2022-01-10', 1),

('Patrícia Gomes', '210.320.430-04',
 'Atendente', 'patricia@assistec.com', '2023-04-03', 1),

('Diego Santos', '210.320.430-05',
 'Técnico Júnior', 'diego@assistec.com', '2025-02-17', 1);


-- =====================================================
-- 8. EQUIPAMENTOS
-- =====================================================

INSERT INTO equipamento
(fk_equipamento_cliente, fk_equipamento_tipo,
 marca, modelo, numero_serie, descricao) VALUES

(1, 1, 'Dell', 'Inspiron 15 3520',
 'SN-DL-0001', 'Notebook preto, 8GB RAM'),

(1, 2, 'Positivo', 'Master D3',
 'SN-PS-0002', 'Desktop torre'),

(2, 1, 'Lenovo', 'IdeaPad 3',
 'SN-LN-0003', 'Notebook cinza'),

(3, 1, 'Acer', 'Aspire 5',
 'SN-AC-0004', 'Notebook corporativo'),

(3, 2, 'HP', 'ProDesk 400',
 'SN-HP-0005', 'Desktop corporativo'),

(3, 3, 'LG', '24MK430H',
 'SN-LG-0006', 'Monitor 24 polegadas'),

(4, 1, 'Samsung', 'Book E30',
 'SN-SM-0007', 'Notebook prata'),

(5, 4, 'Samsung', 'Galaxy Tab A8',
 'SN-TB-0008', 'Tablet 10.5 polegadas'),

(6, 5, 'Epson', 'L3250',
 'SN-EP-0009', 'Multifuncional tanque de tinta'),

(6, 2, 'Dell', 'OptiPlex 3080',
 'SN-DL-0010', 'Desktop do laboratório');


-- =====================================================
-- 9. ORDENS DE SERVIÇO
-- =====================================================

INSERT INTO ordem_servico
(FK_id_equipamento, FK_id_funcionario,
 FK_id_categoria_problema, problema_relatado, data_entrada) VALUES

(1, 1, 2, 'Notebook muito lento para iniciar e abrir programas.',
 '2026-08-05 09:10:00'),

(3, 2, 4, 'Notebook desliga sozinho por aquecimento.',
 '2026-08-18 10:20:00'),

(4, 1, 3, 'Tela trincada após queda.',
 '2026-09-02 08:40:00'),

(5, 3, 1, 'Computador não liga.',
 '2026-09-10 13:00:00'),

(3, 2, 7, 'Bateria não carrega.',
 '2026-10-01 15:10:00'),

(7, 3, 6, 'Muitos anúncios e travamentos.',
 '2026-10-05 09:30:00'),

(9, 5, 8, 'Impressora com listras e falhas na impressão.',
 '2026-10-08 11:00:00'),

(1, 1, 2, 'Travamentos frequentes mesmo após a troca do SSD.',
 '2026-10-28 09:00:00'),

(10, 3, 5, 'Barulho no HD e falha de inicialização.',
 '2026-10-20 14:20:00'),

(2, 2, 2, 'Computador lento e com travadas.',
 '2026-10-22 10:10:00'),

(6, 5, 3, 'Monitor com linhas na imagem.',
 '2026-08-25 16:30:00'),

(8, 5, 3, 'Tela do tablet quebrada.',
 '2026-10-12 10:00:00'),

(7, 1, 1, 'Notebook não liga.',
 '2026-10-18 09:45:00'),

(4, 2, 4, 'Aquecimento excessivo novamente.',
 '2026-11-03 08:50:00');


-- =====================================================
-- 10. SERVIÇOS EXECUTADOS
-- =====================================================

INSERT INTO os_servico
(FK_id_os, FK_id_servico, quantidade, valor_cobrado, observacao) VALUES

(1, 1, 1, 60.00, 'Teste de disco e memória'),
(1, 5, 1, 80.00, 'Substituição por SSD 240GB'),

(2, 1, 1, 60.00, NULL),
(2, 3, 1, 90.00, 'Limpeza completa e troca de pasta térmica'),

(3, 1, 1, 60.00, NULL),
(3, 4, 1, 150.00, 'Troca da tela trincada'),

(4, 1, 1, 60.00, 'Fonte sem resposta'),
(4, 10, 1, 70.00, 'Instalação de nova fonte'),

(5, 1, 1, 60.00, NULL),
(5, 6, 1, 60.00, 'Substituição do carregador'),

(6, 7, 1, 100.00, 'Remoção de adwares e otimização'),

(7, 9, 1, 110.00, 'Limpeza de cabeçote e refil de tinta'),

(8, 1, 1, 60.00, 'Diagnóstico em andamento'),

(9, 1, 1, 60.00, 'HD com setores defeituosos'),

(12, 1, 1, 60.00, 'Orçamento de reparo apresentado'),

(13, 1, 1, 60.00, 'Orçamento apresentado');


-- =====================================================
-- 11. PEÇAS UTILIZADAS
-- =====================================================

INSERT INTO os_peca
(FK_id_os, FK_id_peca, quantidade, valor_unitario) VALUES

(1, 1, 1, 189.90),
(2, 7, 1, 24.90),
(2, 9, 1, 59.90),
(3, 5, 1, 389.00),
(4, 8, 1, 229.90),
(5, 10, 1, 119.90),
(7, 11, 2, 59.90),
(8, 3, 2, 159.90),
(9, 2, 1, 299.90),
(13, 10, 1, 119.90);


-- =====================================================
-- 12. ATUALIZAÇÃO DAS SITUAÇÕES DAS OS
-- =====================================================

-- Primeiro, passam para EM_ANDAMENTO
UPDATE ordem_servico
SET situacao = 'EM_ANDAMENTO'
WHERE id_os IN (1,2,3,4,5,6,7,8,9,12,13);


-- Diagnósticos técnicos
UPDATE ordem_servico
SET diagnostico_tecnico =
'Memória RAM insuficiente; análise de substituição em andamento.'
WHERE id_os = 8;

UPDATE ordem_servico
SET diagnostico_tecnico =
'HD defeituoso substituído por SSD 480GB; reinstalação pendente.'
WHERE id_os = 9;


-- =====================================================
-- 13. CONCLUSÕES
-- =====================================================

UPDATE ordem_servico
SET situacao = 'CONCLUIDA',
    data_conclusao = '2026-08-07 16:30:00',
    diagnostico_tecnico = 'SSD antigo com setores defeituosos; substituído.'
WHERE id_os = 1;

UPDATE ordem_servico
SET situacao = 'CONCLUIDA',
    data_conclusao = '2026-08-20 11:00:00',
    diagnostico_tecnico = 'Ventoinha travada e pasta ressecada.'
WHERE id_os = 2;

UPDATE ordem_servico
SET situacao = 'CONCLUIDA',
    data_conclusao = '2026-09-06 17:10:00',
    diagnostico_tecnico = 'Painel de tela danificado; trocado.'
WHERE id_os = 3;

UPDATE ordem_servico
SET situacao = 'CONCLUIDA',
    data_conclusao = '2026-09-12 15:00:00',
    diagnostico_tecnico = 'Fonte de alimentação queimada.'
WHERE id_os = 4;

UPDATE ordem_servico
SET situacao = 'CONCLUIDA',
    data_conclusao = '2026-10-03 10:30:00',
    diagnostico_tecnico = 'Carregador original com defeito.'
WHERE id_os = 5;

UPDATE ordem_servico
SET situacao = 'CONCLUIDA',
    data_conclusao = '2026-10-06 12:00:00',
    diagnostico_tecnico = 'Presença de adwares; sistema limpo.'
WHERE id_os = 6;

UPDATE ordem_servico
SET situacao = 'CONCLUIDA',
    data_conclusao = '2026-10-10 16:00:00',
    diagnostico_tecnico = 'Cabeçote obstruído; limpeza e refil.'
WHERE id_os = 7;


-- =====================================================
-- 14. CANCELAMENTOS
-- =====================================================

UPDATE ordem_servico
SET situacao = 'CANCELADA',
    diagnostico_tecnico = 'Cliente recusou o orçamento.'
WHERE id_os = 12;

UPDATE ordem_servico
SET situacao = 'CANCELADA',
    diagnostico_tecnico = 'Cliente desistiu do reparo.'
WHERE id_os = 13;


-- =====================================================
-- 15. PAGAMENTOS
-- =====================================================

INSERT INTO pagamento
(FK_id_os, FK_id_forma_pagamento, valor, data_pagamento, observacao) VALUES

(1, 2, 329.90, '2026-08-07 16:45:00',
 'Pagamento integral via PIX'),

(2, 3, 100.00, '2026-08-20 11:10:00','Entrada no cartão; restante a combinar'),

(3, 3, 599.00, '2026-09-06 17:20:00',
'Pagamento integral no cartão'),

(4, 5, 200.00, '2026-09-30 09:00:00',
 'Primeira parcela em boleto'),

(6, 1, 100.00, '2026-10-06 12:10:00',
 'Pagamento em dinheiro'),

(7, 2, 229.80, '2026-10-11 10:00:00',
 'Pagamento integral via PIX');



-- =====================================================================
-- TESTES RAPIDOS (descomente para gerar as evidencias)
-- =====================================================================
-- 1) Baixa automatica de estoque
--    SELECT qtd_estoque FROM peca WHERE id_peca = 1;
--    INSERT INTO os_peca (id_os, id_peca, quantidade) VALUES (1, 1, 2);
--    SELECT qtd_estoque FROM peca WHERE id_peca = 1;
--
-- 2) Estoque insuficiente (deve dar erro)
--    INSERT INTO os_peca (id_os, id_peca, quantidade) VALUES (1, 1, 9999);
--
-- 3) Concluir OS sem servico (deve dar erro)
--    UPDATE ordem_servico SET status = 'concluida' WHERE id_os = 2;
--
-- 4) Cancelar OS devolve pecas ao estoque
--    UPDATE ordem_servico SET status = 'cancelada' WHERE id_os = 1;
--    SELECT qtd_estoque FROM peca WHERE id_peca = 1;
--
-- 5) Excluir OS (deve dar erro)
--    DELETE FROM ordem_servico WHERE id_os = 1;
--
-- 6) Pagamento acima do total (deve dar erro)
--    INSERT INTO pagamento (id_os, id_forma_pagamento, valor, situacao)
--    VALUES (3, 1, 999999, 'pago');
















DELIMITER $$

CREATE PROCEDURE sp_executar_testes_invalidos ()
	BEGIN
    DECLARE v_msg   VARCHAR(500) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT NULL;
    DECLARE v_dummy INT UNSIGNED;

    -- Captura o erro e continua o roteiro de testes
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    END;

    DROP TEMPORARY TABLE IF EXISTS tmp_resultado_testes;
    CREATE TEMPORARY TABLE tmp_resultado_testes (
        ordem     INT AUTO_INCREMENT PRIMARY KEY,
        teste     VARCHAR(120),
        erro_mysql INT,
        mensagem  VARCHAR(500)
    );

    -- N1. Consumir mais peças do que o estoque (peça 2 tem 3; pedimos 10) na OS 10 (aberta)
    SET v_msg = NULL, v_errno = NULL;
    CALL sp_utilizar_peca(10, 2, 10);
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N1 Estoque insuficiente', v_errno, v_msg);

    -- N2. Chave estrangeira inexistente (cliente 9999)
    SET v_msg = NULL, v_errno = NULL;
    INSERT INTO equipamento (id_cliente, id_tipo, marca, modelo, numero_serie)
    VALUES (9999, 1, 'X', 'Y', 'SN-FK-TESTE');
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N2 FK inexistente (equipamento)', v_errno, v_msg);

    -- N3. Serviço em OS inexistente
    SET v_msg = NULL, v_errno = NULL;
    CALL sp_registrar_servico(9999, 1, 1, NULL, NULL);
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N3 FK inexistente (os_servico)', v_errno, v_msg);

    -- N4. Quantidade negativa de peça
    SET v_msg = NULL, v_errno = NULL;
    INSERT INTO os_peca (id_os, id_peca, quantidade, valor_unitario) VALUES (10, 1, -3, 189.90);
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N4 Quantidade negativa (CHECK)', v_errno, v_msg);

    -- N5. Estoque negativo direto na tabela
    SET v_msg = NULL, v_errno = NULL;
    UPDATE peca SET quantidade_estoque = -1 WHERE id_peca = 1;
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N5 Estoque negativo (CHECK)', v_errno, v_msg);

    -- N6. Usar peça em OS concluída (OS 1)
    SET v_msg = NULL, v_errno = NULL;
    CALL sp_utilizar_peca(1, 1, 1);
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N6 Peça em OS concluída', v_errno, v_msg);

    -- N7. Pagamento em OS não concluída (OS 10 está ABERTA)
    SET v_msg = NULL, v_errno = NULL;
    CALL sp_registrar_pagamento(10, 2, 50.00, 'teste');
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N7 Pagamento em OS não concluída', v_errno, v_msg);

    -- N8. Pagamento acima do saldo (OS 1 já está quitada)
    SET v_msg = NULL, v_errno = NULL;
    CALL sp_registrar_pagamento(1, 2, 10.00, 'teste');
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N8 Pagamento acima do saldo', v_errno, v_msg);

    -- N9. Transição inválida: OS ABERTA direto para CONCLUIDA
    SET v_msg = NULL, v_errno = NULL;
    UPDATE ordem_servico SET situacao = 'CONCLUIDA' WHERE id_os = 10;
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N9 Transição ABERTA -> CONCLUIDA', v_errno, v_msg);

    -- N10. Alterar OS cancelada (OS 12)
    SET v_msg = NULL, v_errno = NULL;
    UPDATE ordem_servico SET diagnostico_tecnico = 'alteração indevida' WHERE id_os = 12;
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N10 Alterar OS cancelada', v_errno, v_msg);

    -- N11. Excluir OS (histórico deve ser preservado)
    SET v_msg = NULL, v_errno = NULL;
    DELETE FROM ordem_servico WHERE id_os = 1;
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N11 Excluir OS', v_errno, v_msg);

    -- N12. Alterar utilização de peça já registrada
    SET v_msg = NULL, v_errno = NULL;
    UPDATE os_peca SET quantidade = 99 WHERE id_os = 1;
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N12 Alterar os_peca registrada', v_errno, v_msg);

    -- N13. Cliente com CPF/CNPJ duplicado
    SET v_msg = NULL, v_errno = NULL;
    CALL sp_cadastrar_cliente('Duplicado', '111.444.777-35', '(47) 90000-0000', NULL, NULL, v_dummy);
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N13 CPF duplicado (UNIQUE)', v_errno, v_msg);

    -- N14. Concluir OS sem nenhum serviço registrado (OS nova em andamento, sem serviços)
    SET v_msg = NULL, v_errno = NULL;
    CALL sp_abrir_os(10, 2, 2, 'OS de teste sem serviços', v_dummy);
    UPDATE ordem_servico SET situacao = 'EM_ANDAMENTO' WHERE id_os = v_dummy;
    UPDATE ordem_servico SET situacao = 'CONCLUIDA'    WHERE id_os = v_dummy;
    INSERT INTO tmp_resultado_testes (teste, erro_mysql, mensagem)
    VALUES ('N14 Concluir OS sem serviço', v_errno, v_msg);

    -- Quadro final: PASSOU = o banco recusou a operação
    SELECT ordem, teste, erro_mysql, mensagem,
           IF(erro_mysql IS NULL, 'FALHOU (nenhum erro)', 'PASSOU') AS resultado
      FROM tmp_resultado_testes
     ORDER BY ordem;
END$$

DELIMITER ;

CALL sp_executar_testes_invalidos();

-- Verificação de que nada foi alterado pelas tentativas inválidas.
-- Esperado: peça 2 continua com 3 unidades e a peça 1 com 14 unidades.
SELECT id_peca, nome, quantidade_estoque FROM peca WHERE id_peca IN (1, 2);

-- Esperado: as demais verificações abaixo mostram a OS 1 intacta (CONCLUIDA).
SELECT id_os, situacao FROM ordem_servico WHERE id_os = 1;


    
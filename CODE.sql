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
    ativo INT NOT NULL DEFAULT 1,
):

CREATE TABLE tipo_equipamento (
    id_tipo INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(50) NOT NULL,
):

CREATE TABLE categoria_problema (
    id_categoria_problema INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(60) NOT NULL,
);

CREATE TABLE forma_pagamento (
    id_forma_pagamento INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(40) NOT NULL,
):

-- Catálogo de serviços oferecidos (valor_padrao é apenas o preço de tabela)
CREATE TABLE servico (
    id_servico INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    descricao VARCHAR(255) NULL,
    valor_padrao DECIMAL(10,2) NOT NULL,
);

-- Estoque de peças: quantidade_estoque nunca pode ficar negativa
CREATE TABLE peca (
    id_peca INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(30) NOT NULL,
    nome VARCHAR(100) NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,
    quantidade_estoque INT NOT NULL,
    estoque_minimo INT NOT NULL,
    ativo INT NOT NULL DEFAULT 1,
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


-- =====================================================================
-- 1) PECA  (integridade do estoque)
-- =====================================================================
-- Trigger Antes do insert 
DROP TRIGGER IF EXISTS trg_peca_beforeInsert$$
CREATE TRIGGER trg_peca_beforeInsert BEFORE INSERT ON peca
FOR EACH ROW
BEGIN
    IF NEW.qtd_estoque < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estoque nao pode ser negativo.';
    END IF;
    IF NEW.valor_unitario < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valor da peca nao pode ser negativo.';
    END IF;
END$$

-- Trigger Antes do update
DROP TRIGGER IF EXISTS trg_peca_beforeUpdate$$
CREATE TRIGGER trg_peca_beforeUpdate BEFORE UPDATE ON peca
FOR EACH ROW
BEGIN
    IF NEW.qtd_estoque < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estoque insuficiente: a quantidade nao pode ficar negativa.';
    END IF;
    IF NEW.valor_unitario < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valor da peca nao pode ser negativo.';
    END IF;
END$$

-- Trigger Antes do delete
DROP TRIGGER IF EXISTS trg_peca_beforeDelete$$
CREATE TRIGGER trg_peca_beforeDelete BEFORE DELETE ON peca
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM os_peca WHERE id_peca = OLD.id_peca) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Peca ja utilizada em OS: exclusao bloqueada para preservar o historico.';
    END IF;
END$$


-- =====================================================================
-- 2) ORDEM_SERVICO  (status, datas e historico)
-- =====================================================================
-- Trigger Antes do insert
DROP TRIGGER IF EXISTS trg_os_beforeInsert$$
CREATE TRIGGER trg_os_beforeInsert BEFORE INSERT ON ordem_servico
FOR EACH ROW
BEGIN
    -- toda OS nasce aberta
    IF NEW.status IS NULL THEN
        SET NEW.status = 'aberta';
    END IF;
    IF NEW.status NOT IN ('aberta','em_andamento') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Uma OS so pode ser criada como aberta ou em andamento.';
    END IF;
    IF NEW.data_entrada IS NULL THEN
        SET NEW.data_entrada = CURDATE();
    END IF;
    IF NEW.valor_mao_obra IS NULL THEN
        SET NEW.valor_mao_obra = 0;
    END IF;
    IF NEW.valor_mao_obra < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mao de obra nao pode ser negativa.';
    END IF;
    SET NEW.data_conclusao = NULL;
END$$

-- trigger Antes do update
DROP TRIGGER IF EXISTS trg_os_beforeUpdate$$
CREATE TRIGGER trg_os_beforeUpdate BEFORE UPDATE ON ordem_servico
FOR EACH ROW
BEGIN
    -- OS finalizada nao pode mais ser alterada (historico preservado)
    IF OLD.status IN ('concluida','cancelada') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'OS concluida ou cancelada nao pode ser alterada.';
    END IF;

    IF NEW.valor_mao_obra < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mao de obra nao pode ser negativa.';
    END IF;

    IF NEW.data_conclusao IS NOT NULL AND NEW.data_conclusao < NEW.data_entrada THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data de conclusao anterior a data de entrada.';
    END IF;

    -- ao concluir: exige pelo menos um servico e carimba a data
    IF NEW.status = 'concluida' THEN
        IF NOT EXISTS (SELECT 1 FROM os_servico WHERE id_os = OLD.id_os) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nao e possivel concluir uma OS sem servicos registrados.';
        END IF;
        IF NEW.data_conclusao IS NULL THEN
            SET NEW.data_conclusao = CURDATE();
        END IF;
    END IF;

    -- ao cancelar: carimba a data
    IF NEW.status = 'cancelada' AND NEW.data_conclusao IS NULL THEN
        SET NEW.data_conclusao = CURDATE();
    END IF;
END$$

-- trigger Depois do update
-- cancelamento devolve as pecas ao estoque (os_peca permanece como historico)
DROP TRIGGER IF EXISTS trg_os_afterUpdate$$
CREATE TRIGGER trg_os_afterUpdate AFTER UPDATE ON ordem_servico
FOR EACH ROW
BEGIN
    IF NEW.status = 'cancelada' AND OLD.status <> 'cancelada' THEN
        UPDATE peca p
          JOIN os_peca op ON op.id_peca = p.id_peca
           SET p.qtd_estoque = p.qtd_estoque + op.quantidade
         WHERE op.id_os = NEW.id_os;
    END IF;
END$$

-- nunca apagar OS: historico deve ser preservado (use status 'cancelada')
DROP TRIGGER IF EXISTS trg_os_beforeDelete$$
CREATE TRIGGER trg_os_beforeDelete  BEFORE DELETE ON ordem_servico
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'OS nao pode ser excluida. Altere o status para cancelada.';
END$$


-- =====================================================================
-- 3) OS_PECA  (consumo e baixa de estoque)
-- =====================================================================
DROP TRIGGER IF EXISTS trg_os_peca_beforeInsert$$
CREATE TRIGGER trg_os_peca_beforeInsert  0 BEFORE INSERT ON os_peca
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_estoque INT;
    DECLARE v_valor DECIMAL(10,2);

    SELECT status INTO v_status FROM ordem_servico WHERE id_os = NEW.id_os;
    IF v_status IS NULL OR v_status NOT IN ('aberta','em_andamento') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'So e possivel usar pecas em OS aberta ou em andamento.';
    END IF;

    IF NEW.quantidade IS NULL OR NEW.quantidade <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantidade deve ser maior que zero.';
    END IF;

    SELECT qtd_estoque, valor_unitario INTO v_estoque, v_valor
      FROM peca WHERE id_peca = NEW.id_peca FOR UPDATE;

    IF v_estoque IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Peca inexistente.';
    END IF;
    IF NEW.quantidade > v_estoque THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estoque insuficiente para a quantidade solicitada.';
    END IF;

    -- congela o preco da peca no momento do uso (preserva historico)
    IF NEW.valor_unitario IS NULL THEN
        SET NEW.valor_unitario = v_valor;
    END IF;
END$$

-- trigger Depois do insert: baixa de estoque
DROP TRIGGER IF EXISTS trg_os_peca_afterInsert$$
CREATE TRIGGER trg_os_peca_afterInsert AFTER INSERT ON os_peca
FOR EACH ROW
BEGIN
    UPDATE peca
       SET qtd_estoque = qtd_estoque - NEW.quantidade
     WHERE id_peca = NEW.id_peca;
END$$

-- trigger Antes do update: nao permite trocar a OS ou a peca, nem aumentar a quantidade alem do estoque
DROP TRIGGER IF EXISTS trg_os_peca_beforeUpdate$$
CREATE TRIGGER trg_os_peca_beforeUpdate BEFORE UPDATE ON os_peca
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_estoque INT;

    IF NEW.id_os <> OLD.id_os OR NEW.id_peca <> OLD.id_peca THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nao e permitido trocar a OS ou a peca. Exclua e insira novamente.';
    END IF;

    SELECT status INTO v_status FROM ordem_servico WHERE id_os = OLD.id_os;
    IF v_status NOT IN ('aberta','em_andamento') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'OS finalizada: itens nao podem ser alterados.';
    END IF;

    IF NEW.quantidade <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantidade deve ser maior que zero.';
    END IF;

    IF NEW.quantidade > OLD.quantidade THEN
        SELECT qtd_estoque INTO v_estoque FROM peca WHERE id_peca = OLD.id_peca FOR UPDATE;
        IF (NEW.quantidade - OLD.quantidade) > v_estoque THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estoque insuficiente para aumentar a quantidade.';
        END IF;
    END IF;
END$$

-- trigger Depois do update: ajusta o estoque conforme a diferenca (devolucao se diminuir a quantidade)
DROP TRIGGER IF EXISTS trg_os_peca_afterUpdate$$
CREATE TRIGGER trg_os_peca_afterUpdate AFTER UPDATE ON os_peca
FOR EACH ROW
BEGIN
    -- ajusta so a diferenca (diferenca negativa devolve ao estoque)
    UPDATE peca
       SET qtd_estoque = qtd_estoque - (NEW.quantidade - OLD.quantidade)
     WHERE id_peca = NEW.id_peca;
END$$

-- trigger Antes do delete: nao permite apagar itens de OS finalizada
DROP TRIGGER IF EXISTS trg_os_peca_beforeDelete$$
CREATE TRIGGER trg_os_peca_beforeDelete BEFORE DELETE ON os_peca
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    SELECT status INTO v_status FROM ordem_servico WHERE id_os = OLD.id_os;
    IF v_status NOT IN ('aberta','em_andamento') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'OS finalizada: itens nao podem ser removidos (historico preservado).';
    END IF;
END$$

-- trigger Depois do delete: devolve ao estoque
DROP TRIGGER IF EXISTS trg_os_peca_afterDelete$$
CREATE TRIGGER trg_os_peca_afterDelete AFTER DELETE ON os_peca
FOR EACH ROW
BEGIN
    -- item removido de OS ainda aberta: devolve ao estoque
    UPDATE peca
       SET qtd_estoque = qtd_estoque + OLD.quantidade
     WHERE id_peca = OLD.id_peca;
END$$


-- =====================================================================
-- 4) OS_SERVICO
-- =====================================================================
-- trigger Antes do insert: exige OS aberta ou em andamento, e valor cobrado nao pode ser negativo
DROP TRIGGER IF EXISTS trg_os_servico_beforeInsert$$
CREATE TRIGGER trg_os_servico_beforeInsert BEFORE INSERT ON os_servico
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_padrao DECIMAL(10,2);

    SELECT status INTO v_status FROM ordem_servico WHERE id_os = NEW.id_os;
    IF v_status IS NULL OR v_status NOT IN ('aberta','em_andamento') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'So e possivel registrar servicos em OS aberta ou em andamento.';
    END IF;

    -- se nao informar valor, usa o valor padrao do catalogo
    IF NEW.valor_cobrado IS NULL THEN
        SELECT valor_padrao INTO v_padrao FROM servico WHERE id_servico = NEW.id_servico;
        SET NEW.valor_cobrado = COALESCE(v_padrao, 0);
    END IF;
    IF NEW.valor_cobrado < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valor cobrado nao pode ser negativo.';
    END IF;
END$$

-- trigger Antes do update: nao permite trocar a OS, exige OS aberta ou em andamento, e valor cobrado nao pode ser negativo
DROP TRIGGER IF EXISTS trg_os_servico_beforeUpdate$$
CREATE TRIGGER trg_os_servico_beforeUpdate BEFORE UPDATE ON os_servico
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    SELECT status INTO v_status FROM ordem_servico WHERE id_os = OLD.id_os;
    IF v_status NOT IN ('aberta','em_andamento') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'OS finalizada: servicos nao podem ser alterados.';
    END IF;
    IF NEW.id_os <> OLD.id_os THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nao e permitido trocar a OS do servico.';
    END IF;
    IF NEW.valor_cobrado < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valor cobrado nao pode ser negativo.';
    END IF;
END$$

-- trigger Antes do delete: nao permite apagar servicos de OS finalizada
DROP TRIGGER IF EXISTS trg_os_servico_beforeDelete$$
CREATE TRIGGER trg_os_servico_beforeDelete BEFORE DELETE ON os_servico
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    SELECT status INTO v_status FROM ordem_servico WHERE id_os = OLD.id_os;
    IF v_status NOT IN ('aberta','em_andamento') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'OS finalizada: servicos nao podem ser removidos (historico preservado).';
    END IF;
END$$


-- =====================================================================
-- 5) PAGAMENTO
-- =====================================================================
-- trigger Antes do insert: exige OS existente, nao cancelada, valor positivo, e nao exceder o total da OS
DROP TRIGGER IF EXISTS trg_pagamento_beforeInsert$$
CREATE TRIGGER trg_pagamento_beforeInsert BEFORE INSERT ON pagamento
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_pago DECIMAL(12,2);

    SELECT status INTO v_status FROM ordem_servico WHERE id_os = NEW.id_os;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'OS inexistente.';
    END IF;
    IF v_status = 'cancelada' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nao e possivel registrar pagamento de OS cancelada.';
    END IF;
    IF NEW.valor <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valor do pagamento deve ser maior que zero.';
    END IF;

    IF NEW.situacao IS NULL THEN
        SET NEW.situacao = 'pendente';
    END IF;

    -- pagamento efetivado: exige OS concluida, data e nao pode exceder o total
    IF NEW.situacao = 'pago' THEN
        IF v_status <> 'concluida' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento so pode ser efetivado para OS concluida.';
        END IF;
        IF NEW.data_pagamento IS NULL THEN
            SET NEW.data_pagamento = CURDATE();
        END IF;
        SELECT COALESCE(SUM(valor), 0) INTO v_pago
          FROM pagamento WHERE id_os = NEW.id_os AND situacao = 'pago';
        IF v_pago + NEW.valor > fn_total_os(NEW.id_os) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento excede o valor total da OS.';
        END IF;
    ELSE
        SET NEW.data_pagamento = NULL;
    END IF;
END$$

-- trigger Antes do update: nao permite trocar a OS, nem alterar pagamento ja efetivado, nem exceder o total da OS
DROP TRIGGER IF EXISTS trg_pagamento_beforeUpdate$$
CREATE TRIGGER trg_pagamento_beforeUpdate BEFORE UPDATE ON pagamento
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_pago DECIMAL(12,2);

    IF NEW.id_os <> OLD.id_os THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nao e permitido trocar a OS de um pagamento.';
    END IF;
    IF OLD.situacao = 'pago' AND (NEW.valor <> OLD.valor OR NEW.situacao <> 'pago') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento ja efetivado nao pode ser alterado.';
    END IF;
    IF NEW.valor <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valor do pagamento deve ser maior que zero.';
    END IF;

    -- pendente -> pago
    IF OLD.situacao = 'pendente' AND NEW.situacao = 'pago' THEN
        SELECT status INTO v_status FROM ordem_servico WHERE id_os = NEW.id_os;
        IF v_status <> 'concluida' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento so pode ser efetivado para OS concluida.';
        END IF;
        SELECT COALESCE(SUM(valor), 0) INTO v_pago
          FROM pagamento WHERE id_os = NEW.id_os AND situacao = 'pago';
        IF v_pago + NEW.valor > fn_total_os(NEW.id_os) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento excede o valor total da OS.';
        END IF;
        IF NEW.data_pagamento IS NULL THEN
            SET NEW.data_pagamento = CURDATE();
        END IF;
    END IF;
END$$

-- trigger Antes do delete: nao permite apagar pagamento ja efetivado
DROP TRIGGER IF EXISTS trg_pagamento_beforeDelete$$
CREATE TRIGGER trg_pagamento_beforeDelete BEFORE DELETE ON pagamento
FOR EACH ROW
BEGIN
    IF OLD.situacao = 'pago' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento efetivado nao pode ser excluido (historico financeiro).';
    END IF;
END$$


-- =====================================================================
-- 6) CADASTROS  (protecao de historico / integridade)
-- =====================================================================
-- trigger Antes do delete: nao permite apagar cliente com equipamentos cadastrados
DROP TRIGGER IF EXISTS trg_cliente_beforeDelete$$
CREATE TRIGGER trg_cliente_beforeDelete BEFORE DELETE ON cliente
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM equipamento WHERE id_cliente = OLD.id_cliente) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente possui equipamentos cadastrados: exclusao bloqueada.';
    END IF;
END$$


-- trigger Antes do delete: nao permite apagar equipamento com OS vinculadas
DROP TRIGGER IF EXISTS trg_equipamento_beforeDelete$$
CREATE TRIGGER trg_equipamento_beforeDelete BEFORE DELETE ON equipamento
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM ordem_servico WHERE id_equipamento = OLD.id_equipamento) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Equipamento possui OS: exclusao bloqueada para preservar o historico.';
    END IF;
END$$

-- trigger Antes do delete: nao permite apagar funcionario com OS vinculadas
DROP TRIGGER IF EXISTS trg_funcionario_beforeDelete$$
CREATE TRIGGER trg_funcionario_beforeDelete BEFORE DELETE ON funcionario
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM ordem_servico WHERE id_funcionario = OLD.id_funcionario) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Funcionario possui OS vinculadas: exclusao bloqueada.';
    END IF;
END$$

-- trigger Antes do delete: nao permite apagar categoria de problema com OS vinculadas
DROP TRIGGER IF EXISTS trg_servico_beforeDelete$$
CREATE TRIGGER trg_servico_beforeDelete BEFORE DELETE ON servico
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM os_servico WHERE id_servico = OLD.id_servico) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Servico ja utilizado em OS: exclusao bloqueada.';
    END IF;
END$$

DELIMITER ;





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

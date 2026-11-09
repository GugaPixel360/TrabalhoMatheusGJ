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



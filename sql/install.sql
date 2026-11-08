-- Opcional: o resource cria esta tabela sozinho ao iniciar (CREATE TABLE IF NOT EXISTS).
CREATE TABLE IF NOT EXISTS `mads_sd_journal` (
  `rid` BIGINT NOT NULL AUTO_INCREMENT,
  `tx_id` VARCHAR(96) NOT NULL,
  `seq` BIGINT NOT NULL,
  `state` VARCHAR(24) NOT NULL,
  `ts` BIGINT NOT NULL,
  `data` MEDIUMTEXT NULL,
  `note` VARCHAR(160) NULL,
  `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`rid`),
  KEY `idx_tx` (`tx_id`),
  KEY `idx_created` (`created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

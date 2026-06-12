CREATE TABLE IF NOT EXISTS `gang_sprays` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `gang_id` VARCHAR(64) DEFAULT NULL,
    `gang_name` VARCHAR(64) NOT NULL,
    `coords` LONGTEXT NOT NULL,
    `normal` LONGTEXT DEFAULT NULL,
    `heading` DOUBLE NOT NULL DEFAULT 0,
    `turf_id` VARCHAR(64) DEFAULT NULL,
    `is_contested` TINYINT(1) NOT NULL DEFAULT 0,
    `contested_by` VARCHAR(64) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_gang_name` (`gang_name`),
    KEY `idx_turf_id` (`turf_id`)
);

CREATE TABLE IF NOT EXISTS `gang_spray_discoveries` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `gang_name` VARCHAR(64) NOT NULL,
    `spray_id` INT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_gang_spray` (`gang_name`, `spray_id`),
    KEY `idx_spray_id` (`spray_id`)
);

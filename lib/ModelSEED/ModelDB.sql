-- SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
-- SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
-- SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';
-- DEFAULT CHARACTER SET latin1 COLLATE latin1_swedish_ci;
-- CREATE DATABASE IF NOT EXISTS `ModelDB`;
-- USE `ModelDB`;

-- -----------------------------------------------------
-- Table `compartments`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compartments` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `id` VARCHAR(2) NOT NULL,
  `name` VARCHAR(255) DEFAULT '',
  PRIMARY KEY (`uuid`),
  INDEX `compartments_id` (`id`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reactions`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reactions` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `id` VARCHAR(32) NOT NULL,
  `name` VARCHAR(255) DEFAULT '',
  `abbreviation` VARCHAR(255) DEFAULT '',
  `cksum` VARCHAR(255) DEFAULT '',
  `equation` TEXT DEFAULT '',
  `deltaG` DOUBLE NULL,              
  `deltaGErr` DOUBLE NULL,           
  `reversibility` CHAR(1) DEFAULT '=',
  `thermoReversibility` CHAR(1) NULL, 
  `defaultProtons` DOUBLE NULL,       
  `compartment_uuid` CHAR(36) NULL,
  `defaultTransproton` DOUBLE NULL,  
  PRIMARY KEY (`uuid`),
  INDEX `reactions_id` (`id`),
  INDEX `reactions_cksum` (`cksum`),
  INDEX `reactions_compartment_uuid_fk` (`compartment_uuid`),
  CONSTRAINT `reactions_compartment_uuid_fk`
    FOREIGN KEY (`compartment_uuid`)
    REFERENCES `compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistries`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistries` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `public` TINYINT(1)  NULL,
  `name` VARCHAR(255) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `biochemistries_public` (`public`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `compounds`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compounds` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `abbreviation` VARCHAR(255) NULL,
  `cksum` VARCHAR(255) NULL,
  `unchargedFormula` VARCHAR(255) NULL,
  `formula` VARCHAR(255) NULL,
  `mass` DOUBLE NULL,
  `defaultCharge` DOUBLE NULL,
  `deltaG` DOUBLE NULL,       
  `deltaGErr` DOUBLE NULL,    
  PRIMARY KEY (`uuid`),
  INDEX `compounds_cksum` (`cksum`),
  INDEX `compounds_id` (`id`),
  INDEX `compounds_name` (`name`),
  INDEX `compounds_formula` (`formula`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_compounds`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_compounds` (
  `biochemistry_uuid` CHAR(36) NOT NULL,
  `compound_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry_uuid`, `compound_uuid`),
  INDEX `biochemistry_compounds_compound_uuid_fk` (`compound_uuid`),
  INDEX `biochemistry_compounds_biochemistry_uuid_fk` (`biochemistry_uuid`),
  CONSTRAINT `biochemistry_compounds_biochemistry_uuid_fk`
    FOREIGN KEY (`biochemistry_uuid`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_compounds_compound_uuid_fk`
    FOREIGN KEY (`compound_uuid`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `complexes`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `complexes` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `searchname` VARCHAR(255) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `complexes_searchname` (`searchname`),
  INDEX `complexes_id` (`id`),
  INDEX `complexes_name` (`name`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `media`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `media` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `type` CHAR(1) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `media_id` (`id`),
  INDEX `media_name` (`name`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `genomes`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `genomes` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `public` TINYINT(1)  NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(32) NULL,
  `source` VARCHAR(32) NULL,
  `type` VARCHAR(32) NULL,
  `taxonomy` VARCHAR(255) NULL,
  `cksum` VARCHAR(255) NULL,
  `size` INTEGER NULL,
  `genes` INTEGER NULL,
  `gc` DOUBLE NULL,
  `gramPositive` CHAR(1) NULL,
  `aerobic` CHAR(1) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `genomes_id` (`id`),
  INDEX `genomes_source` (`source`),
  INDEX `genomes_cksum` (`cksum`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `features`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `features` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `id` VARCHAR(32) NULL,
  `cksum` VARCHAR(255) NULL,
  `genome_uuid` CHAR(36) NOT NULL,
  `start` INTEGER NULL,
  `stop` INTEGER NULL,
  PRIMARY KEY (`uuid`),
  INDEX `features_id` (`id`),
  INDEX `features_cksum` (`cksum`),
  INDEX `features_genome_uuid_fk` (`genome_uuid`),
  CONSTRAINT `features_genome_uuid_fk`
    FOREIGN KEY (`genome_uuid`)
    REFERENCES `genomes` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `roles`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `roles` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `searchname` VARCHAR(255) NULL,
  `feature_uuid` CHAR(36) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `roles_id` (`id`),
  INDEX `roles_name` (`name`),
  INDEX `roles_searchname` (`searchname`),
  INDEX `roles_feature_fk` (`feature_uuid`),
  CONSTRAINT `roles_feature_fk`
    FOREIGN KEY (`feature_uuid`)
    REFERENCES `features` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `complex_roles`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `complex_roles` (
  `complex_uuid` CHAR(36) NOT NULL,
  `role_uuid` CHAR(36) NOT NULL,
  `optional` TINYINT(1)  NULL,
  `type` CHAR(1) NULL,
  PRIMARY KEY (`complex_uuid`, `role_uuid`),
  INDEX `complex_role_role_fk` (`role_uuid`),
  INDEX `complex_role_complex_fk` (`complex_uuid`),
  CONSTRAINT `complex_role_complex_fk`
    FOREIGN KEY (`complex_uuid`)
    REFERENCES `complexes` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `complex_role_role_fk`
    FOREIGN KEY (`role_uuid`)
    REFERENCES `roles` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_reactions`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_reactions` (
  `biochemistry_uuid` CHAR(36) NOT NULL,
  `reaction_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry_uuid`, `reaction_uuid`),
  INDEX `biochemistry_reactions_reaction_fk` (`reaction_uuid`),
  INDEX `biochemistry_reactions_biochemistry_fk` (`biochemistry_uuid`),
  CONSTRAINT `biochemistry_reactions_biochemistry_fk`
    FOREIGN KEY (`biochemistry_uuid`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_reactions_reaction_fk`
    FOREIGN KEY (`reaction_uuid`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reaction_rules`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reaction_rules` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `reaction_uuid` CHAR(36) NOT NULL,
  `compartment_uuid` CHAR(36) NOT NULL,
  `direction` CHAR(1) NULL,
  `transprotonNature` CHAR(255) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `reaction_rules_reaction_fk` (`reaction_uuid`),
  INDEX `reaction_rules_compartment_fk` (`compartment_uuid`),
  CONSTRAINT `reaction_rules_reaction_fk`
    FOREIGN KEY (`reaction_uuid`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_rules_compartment_fk`
    FOREIGN KEY (`compartment_uuid`)
    REFERENCES `compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `complex_reaction_rules`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `complex_reaction_rules` (
  `reaction_rule_uuid` CHAR(36) NOT NULL,
  `complex_uuid` ChAR(36) NOT NULL,
  PRIMARY KEY (`reaction_rule_uuid`, `complex_uuid`), 
  INDEX `complex_reaction_rules_complex_fk` (`complex_uuid`),
  INDEX `complex_reaction_rules_reaction_rule_fk` (`reaction_rule_uuid`),
  CONSTRAINT `complex_reaction_rules_complex_fk`
    FOREIGN KEY (`complex_uuid`)
    REFERENCES `complexes` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `complex_reaction_rules_reaction_rule_fk`
    FOREIGN KEY (`reaction_rule_uuid`)
    REFERENCES `reaction_rules` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `reaction_rule_transports`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reaction_rule_transports` (
  `reaction_rule_uuid` CHAR(36) NOT NULL,
  `reaction_uuid`      CHAR(36) NOT NULL,
  `compound_uuid`      CHAR(36) NOT NULL,
  `compartmentIndex` INTEGER NOT NULL,
  `compartment_uuid` CHAR(36) NOT NULL,
  `transportCoefficient` INTEGER NOT NULL,
  `isImport` TINYINT(1) NULL,
  PRIMARY KEY (`reaction_rule_uuid`, `compound_uuid`, `compartmentIndex`),
  INDEX `reaction_rule_transports_reaction_rule_fk` (`reaction_rule_uuid`),
  INDEX `reaction_rule_transports_compartment_fk` (`compartment_uuid`),
  INDEX `reaction_rule_transports_reaction_fk` (`reaction_uuid`),
  INDEX `compound_rule_transports_compound_fk` (`compound_uuid`),
  CONSTRAINT `reaction_rule_transports_reaction_rule_fk`
    FOREIGN KEY (`reaction_rule_uuid`)
    REFERENCES `reaction_rules` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_rule_transports_compartment_fk`
    FOREIGN KEY (`compartment_uuid`)
    REFERENCES `compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_rule_transports_reaction_fk`
    FOREIGN KEY (`reaction_uuid`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_rule_transports_compound_fk`
    FOREIGN KEY (`compound_uuid`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `mapping_reaction_rules`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_reaction_rules` (
  `reaction_rule_uuid` CHAR(36) NOT NULL,
  `mapping_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`reaction_rule_uuid`, `mapping_uuid`),
  INDEX `mapping_reaction_rules_mapping_fk` (`mapping_uuid`),
  INDEX `mapping_reaction_rules_reaction_rule_fk` (`mapping_uuid`),
  CONSTRAINT `mapping_reaction_rules_reaction_rule_fk`
    FOREIGN KEY (`reaction_rule_uuid`)
    REFERENCES `reaction_rules` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `mapping_reaction_rules_mapping_fk`
    FOREIGN KEY (`mapping_uuid`)
    REFERENCES `mappings` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `compound_aliases`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compound_aliases` (
  `compound_uuid` CHAR(36) NOT NULL,
  `alias` VARCHAR(255) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `type` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`type`, `alias`),
  INDEX `compound_aliases_type` (`type`),
  INDEX `compound_aliases_compound_fk` (`compound_uuid`),
  CONSTRAINT `compound_aliases_compound_fk`
    FOREIGN KEY (`compound_uuid`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `compound_structures`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compound_structures` (
  `compound_uuid` CHAR(36) NOT NULL,
  `structure` TEXT NOT NULL,
  `cksum` VARCHAR(255) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `type` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`type`, `cksum`),
  INDEX `compound_structures_type` (`type`),
  INDEX `compound_structures_compound_fk` (`compound_uuid`),
  CONSTRAINT `compound_structures_compound_fk`
    FOREIGN KEY (`compound_uuid`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;



-- -----------------------------------------------------
-- Table `reaction_aliases`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reaction_aliases` (
  `reaction_uuid` CHAR(36) NOT NULL,
  `alias` VARCHAR(255) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `type` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`type`, `alias`),
  INDEX `compound_alias_type` (`type`),
  INDEX `reaction_fk` (`reaction_uuid`),
  CONSTRAINT `reaction_aliases_reaction_fk`
    FOREIGN KEY (`reaction_uuid`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mappings`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mappings` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `public` TINYINT(1)  NULL,
  `name` VARCHAR(255) NULL,
  `biochemistry_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`uuid`),
  INDEX `mappings_public` (`public`),
  INDEX `mappings_biochemistry_fk` (`biochemistry_uuid`),
  CONSTRAINT `mappings_biochemistry_fk`
    FOREIGN KEY (`biochemistry_uuid`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mapping_complexes`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_complexes` (
  `mapping_uuid` CHAR(36) NOT NULL,
  `complex_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`mapping_uuid`, `complex_uuid`),
  INDEX `mapping_complexes_complex_fk` (`complex_uuid`),
  INDEX `mapping_complexes_mapping_fk` (`mapping_uuid`),
  CONSTRAINT `mapping_complexes_mapping_fk`
    FOREIGN KEY (`mapping_uuid`)
    REFERENCES `mappings` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `mapping_complexes_complex_fk`
    FOREIGN KEY (`complex_uuid`)
    REFERENCES `complexes` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reagents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reagents` (
  `reaction_uuid` CHAR(36) NOT NULL,
  `compound_uuid` CHAR(36) NOT NULL,
  `compartmentIndex` INTEGER NOT NULL,
  `coefficient` FLOAT NULL,
  `cofactor` TINYINT(1) NULL, 
  PRIMARY KEY (`reaction_uuid`, `compound_uuid`, `compartmentIndex`),
  INDEX `reagents_compound_fk` (`compound_uuid`),
  INDEX `reagents_reaction_fk` (`reaction_uuid`),
  CONSTRAINT `reagents_reaction_fk`
    FOREIGN KEY (`reaction_uuid`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reagents_compound_fk`
    FOREIGN KEY (`compound_uuid`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `default_transported_reagents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `default_transported_reagents` (
    `reaction_uuid` CHAR(36) NOT NULL,
    `compound_uuid` CHAR(36) NOT NULL,
    `compartment_uuid` CHAR(36) NOT NULL,
    `compartmentIndex` INTEGER NOT NULL,
    `transportCoefficient` INTEGER NOT NULL,
    `isImport` TINYINT(1) NULL,
    PRIMARY KEY (`reaction_uuid`, `compartmentIndex`, `compound_uuid`),
    INDEX `default_transported_reagents_reaction_fk` (`reaction_uuid`),
    INDEX `default_transported_reagents_compartment_fk` (`compartment_uuid`),
    INDEX `default_transported_reagents_compound_fk` (`compound_uuid`),
    CONSTRAINT `default_transported_reagents_compartment_fk`
        FOREIGN KEY (`compartment_uuid`)
        REFERENCES `compartments` (`uuid`)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT `default_transported_reagents_reaction_fk`
        FOREIGN KEY (`reaction_uuid`)
        REFERENCES `reactions` (`uuid`)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT `default_transported_reagents_compound_fk`
        FOREIGN KEY (`compound_uuid`)
        REFERENCES `compounds` (`uuid`)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `reactionsets`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reactionsets` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `searchname` VARCHAR(255) NULL,
  `class` VARCHAR(255) NULL,
  `type` VARCHAR(32) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `reactionsets_id` (`id`),
  INDEX `reactionsets_name` (`name`),
  INDEX `reactionsets_searchname` (`searchname`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `annotations`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `annotations` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `name` VARCHAR(255) NULL,
  `genome_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`uuid`),
  INDEX `annotations_name` (`name`),
  INDEX `annotations_genome_fk` (`genome_uuid`),
  CONSTRAINT `annotations_genome_fk`
    FOREIGN KEY (`genome_uuid`)
    REFERENCES `genomes` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `models`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `models` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `public` TINYINT(1)  NULL,
  `id` VARCHAR(255) NULL,
  `name` VARCHAR(32) NULL,
  `version` INTEGER NULL,
  `type` VARCHAR(32) NULL,
  `status` VARCHAR(32) NULL,
  `reactions` INTEGER NULL,
  `compounds` INTEGER NULL,
  `annotations` INTEGER NULL,
  `growth` DOUBLE NULL,
  `current` TINYINT(1)  NULL,
  `mapping_uuid` CHAR(36) NOT NULL,
  `biochemistry_uuid` CHAR(36) NOT NULL,
  `annotation_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`uuid`),
  INDEX `models_mapping_fk` (`mapping_uuid`),
  INDEX `models_biochemistry_fk` (`biochemistry_uuid`),
  INDEX `models_annotation_fk` (`annotation_uuid`),
  CONSTRAINT `models_mapping_fk`
    FOREIGN KEY (`mapping_uuid`)
    REFERENCES `mappings` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `models_biochemistry_fk`
    FOREIGN KEY (`biochemistry_uuid`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `models_annotation_fk`
    FOREIGN KEY (`annotation_uuid`)
    REFERENCES `annotations` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `model_compartments`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model_compartments` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NOT NULL,
  `locked` TINYINT(1)  NULL,
  `model_uuid` CHAR(36) NOT NULL,
  `compartment_uuid` CHAR(36) NOT NULL,
  `compartmentIndex` INTEGER NOT NULL,
  `label` VARCHAR(255) NULL,
  `pH` DOUBLE NULL,
  `potential` DOUBLE NULL,
  PRIMARY KEY (`uuid`),
  UNIQUE INDEX `model_compartments_idx` (`model_uuid`, `compartment_uuid`, `compartmentIndex`),
  INDEX `model_compartments_compartment_fk` (`compartment_uuid`),
  INDEX `model_compartments_model_fk` (`model_uuid`),
  CONSTRAINT `model_compartments_model_fk`
    FOREIGN KEY (`model_uuid`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_compartments_compartment_fk`
    FOREIGN KEY (`compartment_uuid`)
    REFERENCES `compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `model_reactions`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model_reactions` (
  `model_uuid` CHAR(36) NOT NULL,
  `reaction_uuid` CHAR(36) NOT NULL,
  `reaction_rule_uuid` CHAR(36) NOT NULL,
  `direction` CHAR(1) NULL,
  `transproton` DOUBLE NULL,
  `protons` DOUBLE NULL,
  `model_compartment_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`model_uuid`, `reaction_uuid`),
  INDEX `model_reactions_reaction_fk` (`reaction_uuid`),
  INDEX `model_reactions_model_fk` (`model_uuid`),
  INDEX `model_reactions_modelCompartment_fk` (`model_compartment_uuid`),
  INDEX `model_reactions_reaction_rule_fk` (`reaction_rule_uuid`),
  CONSTRAINT `model_reactions_model_fk`
    FOREIGN KEY (`model_uuid`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_reactions_reaction_fk`
    FOREIGN KEY (`reaction_uuid`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_reactions_modelCompartment_fk`
    FOREIGN KEY (`model_compartment_uuid`)
    REFERENCES `model_compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_reactions_reaction_rule_fk`
    FOREIGN KEY (`reaction_rule_uuid`)
    REFERENCES `reaction_rules` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `model_transported_reagents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model_transported_reagents` (
  `model_uuid` CHAR(36) NOT NULL,
  `reaction_uuid` CHAR(36) NOT NULL,
  `compound_uuid` CHAR(36) NOT NULL,
  `transportIndex` INTEGER NOT NULL,
  `model_compartment_uuid` CHAR(36) NOT NULL,
  `transportCoefficient` INTEGER NOT NULL,
  `isImport` TINYINT(1) NULL,
  PRIMARY KEY (`model_uuid`, `reaction_uuid`, `transportIndex`),
  INDEX `model_transported_reagents_reaction_fk` (`reaction_uuid`),
  INDEX `model_transported_reagents_model_fk` (`model_uuid`),
  INDEX `model_transported_reagents_compound_fk` (`compound_uuid`),
  INDEX `model_transported_reagents_modelCompartment_fk` (`model_compartment_uuid`),
  CONSTRAINT `model_transported_reagents_model_fk`
    FOREIGN KEY (`model_uuid`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_transported_reagents_reaction_fk`
    FOREIGN KEY (`reaction_uuid`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_transported_reagents_compound_fk`
    FOREIGN KEY (`compound_uuid`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_transported_reagents_modelCompartment_fk`
    FOREIGN KEY (`model_compartment_uuid`)
    REFERENCES `model_compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `modelfbas`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `modelfbas` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `locked` TINYINT(1)  NULL,
  `model_uuid` CHAR(36) NOT NULL,
  `media_uuid` CHAR(36) NOT NULL,
  `options` VARCHAR(255) NULL,
  `geneko` VARCHAR(255) NULL,
  `reactionko` VARCHAR(255) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `modelfbas_model_fk` (`model_uuid`),
  INDEX `modelfbas_media_fk` (`media_uuid`),
  CONSTRAINT `modelfbas_model_fk`
    FOREIGN KEY (`model_uuid`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `modelfbas_media_fk`
    FOREIGN KEY (`media_uuid`)
    REFERENCES `media` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `media_compounds`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `media_compounds` (
  `media_uuid` CHAR(36) NOT NULL,
  `compound_uuid` CHAR(36) NOT NULL,
  `concentration` DOUBLE NULL,
  `minflux` DOUBLE NULL,
  `maxflux` DOUBLE NULL,
  PRIMARY KEY (`media_uuid`, `compound_uuid`),
  INDEX `media_compounds_compound_fk` (`compound_uuid`),
  INDEX `media_compounds_media_fk` (`media_uuid`),
  CONSTRAINT `media_compound_media_fk`
    FOREIGN KEY (`media_uuid`)
    REFERENCES `media` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `media_compound_compound_fk`
    FOREIGN KEY (`compound_uuid`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `modeless_features`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `modeless_features` (
  `modelfba_uuid` CHAR(36) NOT NULL,
  `feature_uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `growthFraction` DOUBLE NULL,
  `essential` TINYINT(1)  NULL,
  PRIMARY KEY (`modelfba_uuid`, `feature_uuid`),
  INDEX `modeless_features_feature_fk` (`feature_uuid`),
  INDEX `modeless_features_modelfba_fk` (`modelfba_uuid`),
  CONSTRAINT `modeless_features_modelfba_fk`
    FOREIGN KEY (`modelfba_uuid`)
    REFERENCES `modelfbas` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `modeless_features_feature_fk`
    FOREIGN KEY (`feature_uuid`)
    REFERENCES `features` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `annotation_features`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `annotation_features` (
  `annotation_uuid` CHAR(36) NOT NULL,
  `feature_uuid` CHAR(36) NOT NULL,
  `role_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`annotation_uuid`, `feature_uuid`, `role_uuid`),
  INDEX `annotation_features_feature_fk` (`feature_uuid`),
  INDEX `annotation_features_annotation_fk` (`annotation_uuid`),
  INDEX `annotation_features_role_fk` (`role_uuid`),
  CONSTRAINT `annotation_features_annotation_fk`
    FOREIGN KEY (`annotation_uuid`)
    REFERENCES `annotations` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `annotation_features_feature_fk`
    FOREIGN KEY (`feature_uuid`)
    REFERENCES `features` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `annotation_features_role_fk`
    FOREIGN KEY (`role_uuid`)
    REFERENCES `roles` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `rolesets`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `rolesets` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `public` TINYINT(1)  NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `searchname` VARCHAR(255) NULL,
  `class` VARCHAR(255) NULL,
  `subclass` VARCHAR(255) NULL,
  `type` VARCHAR(32) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `rolesets_id` (`id`),
  INDEX `rolesets_name` (`name`),
  INDEX `rolesets_searchname` (`searchname`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `roleset_roles`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `roleset_roles` (
  `roleset_uuid` CHAR(36) NOT NULL,
  `role_uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  PRIMARY KEY (`roleset_uuid`, `role_uuid`),
  INDEX `roleset_roles_role_fk` (`role_uuid`),
  INDEX `roleset_roles_roleset_fk` (`roleset_uuid`),
  CONSTRAINT `roleset_roles_roleset_fk`
    FOREIGN KEY (`roleset_uuid`)
    REFERENCES `rolesets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `roleset_roles_role_fk`
    FOREIGN KEY (`role_uuid`)
    REFERENCES `roles` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mapping_roles`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_roles` (
  `mapping_uuid` CHAR(36) NOT NULL,
  `role_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`mapping_uuid`, `role_uuid`),
  INDEX `mapping_roles_role_fk` (`role_uuid`),
  INDEX `mapping_roles_mapping_fk` (`mapping_uuid`),
  CONSTRAINT `mapping_roles_mapping_fk`
    FOREIGN KEY (`mapping_uuid`)
    REFERENCES `mappings` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `mapping_roles_role_fk`
    FOREIGN KEY (`role_uuid`)
    REFERENCES `roles` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_compartments`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_compartments` (
  `biochemistry_uuid` CHAR(36) NOT NULL,
  `compartment_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry_uuid`, `compartment_uuid`),
  INDEX `biochemistry_compartments_compartment_fk` (`compartment_uuid`),
  INDEX `biochemistry_compartments_biochemistry_fk` (`biochemistry_uuid`),
  CONSTRAINT `biochemistry_compartments_biochemistry_fk`
    FOREIGN KEY (`biochemistry_uuid`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_compartments_compartment_fk`
    FOREIGN KEY (`compartment_uuid`)
    REFERENCES `compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `compound_pks`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compound_pks` (
  `compound_uuid` CHAR(36) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `atom` INTEGER NULL,
  `pk` DOUBLE NULL,
  `type` CHAR(1) NULL,
  PRIMARY KEY (`compound_uuid`),
  INDEX `compound_pks_compound_fk` (`compound_uuid`),
  CONSTRAINT `compound_pks_compound_fk`
    FOREIGN KEY (`compound_uuid`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reactionset_reactions`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reactionset_reactions` (
  `reactionset_uuid` CHAR(36) NOT NULL,
  `reaction_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`reactionset_uuid`, `reaction_uuid`),
  INDEX `reactionset_reactions_reaction_fk` (`reaction_uuid`),
  INDEX `reactionset_reactions_reactionset_fk` (`reactionset_uuid`),
  CONSTRAINT `reactionset_reactions_reactionset_fk`
    FOREIGN KEY (`reactionset_uuid`)
    REFERENCES `reactionsets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reactionset_reactions_reaction_fk`
    FOREIGN KEY (`reaction_uuid`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `compoundsets`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compoundsets` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `searchname` VARCHAR(255) NULL,
  `class` VARCHAR(255) NULL,
  `type` VARCHAR(32) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `compoundsets_id` (`id`),
  INDEX `compoundsets_name` (`name`),
  INDEX `compoundsets_searchname` (`searchname`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `compoundset_compounds`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compoundset_compounds` (
  `compoundset_uuid` CHAR(36) NOT NULL,
  `compound_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`compoundset_uuid`, `compound_uuid`),
  INDEX `compoundset_compounds_compound_fk` (`compound_uuid`),
  INDEX `compoundset_compounds_compoundset_fk` (`compoundset_uuid`),
  CONSTRAINT `compoundset_compounds_compoundset_fk`
    FOREIGN KEY (`compoundset_uuid`)
    REFERENCES `compoundsets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `compoundset_compounds_compound_fk`
    FOREIGN KEY (`compound_uuid`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `modelfba_reactions`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `modelfba_reactions` (
  `modelfba_uuid` CHAR(36) NOT NULL,
  `reaction_uuid` CHAR(36) NOT NULL,
  `min` DOUBLE NULL,
  `max` DOUBLE NULL,
  `class` CHAR(1) NULL,
  PRIMARY KEY (`modelfba_uuid`, `reaction_uuid`),
  INDEX `modelfba_reactions_reaction_fk` (`reaction_uuid`),
  INDEX `modelfba_reactions_modelfba_fk` (`modelfba_uuid`),
  CONSTRAINT `modelfba_reactions_modelfba_fk`
    FOREIGN KEY (`modelfba_uuid`)
    REFERENCES `modelfbas` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `modelfba_reactions_reaction_fk`
    FOREIGN KEY (`reaction_uuid`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `modelfba_compounds`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `modelfba_compounds` (
  `modelfba_uuid` CHAR(36) NOT NULL,
  `compound_uuid` CHAR(36) NOT NULL,
  `min` DOUBLE NULL,
  `max` DOUBLE NULL,
  `class` CHAR(1) NULL,
  PRIMARY KEY (`modelfba_uuid`, `compound_uuid`),
  INDEX `modelfba_compounds_compound_fk` (`compound_uuid`),
  INDEX `modelfba_compounds_modelfba_fk` (`modelfba_uuid`),
  CONSTRAINT `modelfba_compounds_modelfba_fk`
    FOREIGN KEY (`modelfba_uuid`)
    REFERENCES `modelfbas` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `modelfba_compounds_compound_fk`
    FOREIGN KEY (`compound_uuid`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_media`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_media` (
  `biochemistry_uuid` CHAR(36) NOT NULL,
  `media_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry_uuid`, `media_uuid`),
  INDEX `biochemistry_media_media_fk` (`media_uuid`),
  INDEX `biochemistry_media_biochemistry_fk` (`biochemistry_uuid`),
  CONSTRAINT `biochemistry_media_biochemistry_fk`
    FOREIGN KEY (`biochemistry_uuid`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_media_media_fk`
    FOREIGN KEY (`media_uuid`)
    REFERENCES `media` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_reactionsets`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_reactionsets` (
  `biochemistry_uuid` CHAR(36) NOT NULL,
  `reactionset_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry_uuid`, `reactionset_uuid`),
  INDEX `biochemistry_reactionsets_reactionset_fk` (`reactionset_uuid`),
  INDEX `biochemistry_reactionsets_biochemistry_fk` (`biochemistry_uuid`),
  CONSTRAINT `biochemistry_reactionsets_biochemistry_fk`
    FOREIGN KEY (`biochemistry_uuid`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_reactionsets_reactionset_fk`
    FOREIGN KEY (`reactionset_uuid`)
    REFERENCES `reactionsets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_compoundsets`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_compoundsets` (
  `biochemistry_uuid` CHAR(36) NOT NULL,
  `compoundset_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry_uuid`, `compoundset_uuid`),
  INDEX `biochemistry_compoundsets_compoundset_fk` (`compoundset_uuid`),
  INDEX `biochemistry_compoundsets_biochemistry_fk` (`biochemistry_uuid`),
  CONSTRAINT `biochemistry_compoundsets_biochemistry_fk`
    FOREIGN KEY (`biochemistry_uuid`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_compoundsets_compoundset_fk`
    FOREIGN KEY (`compoundset_uuid`)
    REFERENCES `compoundsets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_parents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_parents` (
  `child_uuid` CHAR(36) NOT NULL,
  `parent_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`child_uuid`, `parent_uuid`),
  INDEX `biochemistry_parents_parent_fk` (`parent_uuid`),
  CONSTRAINT `biochemistry_parents_parent_fk`
    FOREIGN KEY (`parent_uuid`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `biochemistry_parents_child_fk` (`child_uuid`),
  CONSTRAINT `biochemistry_parents_child_fk`
    FOREIGN KEY (`child_uuid`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mapping_parents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_parents` (
  `child_uuid` CHAR(36) NOT NULL,
  `parent_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`child_uuid`, `parent_uuid`),
  INDEX `mapping_parents_parent_fk` (`parent_uuid`),
  CONSTRAINT `mapping_parents_parent_fk`
    FOREIGN KEY (`parent_uuid`)
    REFERENCES `mappings` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `mapping_parents_child_fk` (`child_uuid`),
  CONSTRAINT `mapping_parents_child_fk`
    FOREIGN KEY (`child_uuid`)
    REFERENCES `mappings` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `model_parents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model_parents` (
  `child_uuid` CHAR(36) NOT NULL,
  `parent_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`child_uuid`, `parent_uuid`),
  INDEX `model_parents_parent_fk` (`parent_uuid`),
  CONSTRAINT `model_parents_parent_fk`
    FOREIGN KEY (`parent_uuid`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `model_parents_child_fk` (`child_uuid`),
  CONSTRAINT `model_parents_child_fk`
    FOREIGN KEY (`child_uuid`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `annotation_parents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `annotation_parents` (
  `child_uuid` CHAR(36) NOT NULL,
  `parent_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`child_uuid`, `parent_uuid`),
  INDEX `annotation_parents_parent_fk` (`parent_uuid`),
  CONSTRAINT `annotation_parents_parent_fk`
    FOREIGN KEY (`parent_uuid`)
    REFERENCES `annotations` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `annotation_parents_child_fk` (`child_uuid`),
  CONSTRAINT `annotation_parents_child_fk`
    FOREIGN KEY (`child_uuid`)
    REFERENCES `annotations` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `roleset_parents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `roleset_parents` (
  `child_uuid` CHAR(36) NOT NULL,
  `parent_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY (`child_uuid`, `parent_uuid`),
  INDEX `roleset_parents_parent_fk` (`parent_uuid`),
  CONSTRAINT `roleset_parents_parent_fk`
    FOREIGN KEY (`parent_uuid`)
    REFERENCES `rolesets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `roleset_parents_child_fk` (`child_uuid`),
  CONSTRAINT `roleset_parents_child_fk`
    FOREIGN KEY (`child_uuid`)
    REFERENCES `rolesets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `permissions`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `permissions` (
  `object` CHAR(36) NOT NULL,
  `user` VARCHAR(255) NOT NULL,
  `read` TINYINT(1)  NULL,
  `write` TINYINT(1)  NULL,
  `admin` TINYINT(1)  NULL,
  PRIMARY KEY (`object`, `user`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biomasses`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biomasses` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `biomass_id` (`id`)
)
ENGINE = InnoDB;
    

-- -----------------------------------------------------
-- Table `model_biomass`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model_biomass` (
  `model_uuid` CHAR(36) NOT NULL,
  `biomass_uuid` CHAR(36) NOT NULL,
  PRIMARY KEY ( `model_uuid`, `biomass_uuid`),
  INDEX `model_biomass_biomass_fk` (`biomass_uuid`),
  CONSTRAINT `model_biomass_biomass_fk`
    FOREIGN KEY (`biomass_uuid`)
    REFERENCES `biomasses` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `model_biomass_model_fk` (`model_uuid`),
  CONSTRAINT `model_biomass_model_fk`
    FOREIGN KEY (`model_uuid`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biomass_compounds`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biomass_compounds` (
  `biomass_uuid` CHAR(36) NOT NULL,
  `compound_uuid` CHAR(36) NOT NULL,
  `compartment_uuid` CHAR(36) NOT NULL,
  `coefficient` DOUBLE NULL,
  PRIMARY KEY ( `biomass_uuid`, `compound_uuid`),
  INDEX `biomass_compounds_biomass_fk` (`biomass_uuid`),
  CONSTRAINT `biomass_compounds_biomass_fk`
    FOREIGN KEY (`biomass_uuid`)
    REFERENCES `biomasses` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION, 
  INDEX `biomass_compounds_compound_fk` (`compound_uuid`),
  CONSTRAINT `biomass_compounds_compound_fk`
    FOREIGN KEY (`compound_uuid`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION, 
  INDEX `biomass_compounds_compartment_fk` (`compartment_uuid`),
  CONSTRAINT `biomass_compounds_compartment_fk`
    FOREIGN KEY (`compartment_uuid`)
    REFERENCES `model_compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `biochemistry_aliases`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_aliases` (
    `biochemistry_uuid` CHAR(36) NOT NULL,
    `username` VARCHAR(255) NOT NULL,
    `id` VARCHAR(255) NOT NULL,
    PRIMARY KEY ( `username`, `id` ),
    INDEX `biochemistry_aliases_biochemistry_fk` (`biochemistry_uuid`),
    CONSTRAINT `biochemistry_aliases_biochemistry_fk`
        FOREIGN KEY (`biochemistry_uuid`)
        REFERENCES `biochemistries` (`uuid`)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `model_aliases`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model_aliases` (
    `model_uuid` CHAR(36) NOT NULL,
    `username` VARCHAR(255) NOT NULL,
    `id` VARCHAR(255) NOT NULL,
    PRIMARY KEY ( `username`, `id` ),
    INDEX `model_aliases_model_fk` (`model_uuid`),
    CONSTRAINT `model_aliases_model_fk`
        FOREIGN KEY (`model_uuid`)
        REFERENCES `models` (`uuid`)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION)
ENGINE = InnoDB;
        

-- -----------------------------------------------------
-- Table `mapping_aliases`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_aliases` (
    `mapping_uuid` CHAR(36) NOT NULL,
    `username` VARCHAR(255) NOT NULL,
    `id` VARCHAR(255) NOT NULL,
    PRIMARY KEY ( `username`, `id` ),
    INDEX `mapping_aliases_mapping_fk` (`mapping_uuid`),
    CONSTRAINT `mapping_aliases_mapping_fk`
        FOREIGN KEY (`mapping_uuid`)
        REFERENCES `mappings` (`uuid`)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- SET SQL_MODE=@OLD_SQL_MODE;
-- SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
-- SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

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
  `defaultCompartment` CHAR(36) NULL,
  `defaultTransproton` DOUBLE NULL,  
  PRIMARY KEY (`uuid`),
  INDEX `reactions_id` (`id`),
  INDEX `reactions_cksum` (`cksum`),
  INDEX `reactions_defaultCompartment_fk` (`defaultCompartment`),
  CONSTRAINT `reactions_defaultCompartment_fk`
    FOREIGN KEY (`defaultCompartment`)
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
-- Table `biochemistry_compound`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_compounds` (
  `biochemistry` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry`, `compound`),
  INDEX `biochemistry_compounds_compound_fk` (`compound`),
  INDEX `biochemistry_compounds_biochemistry_fk` (`biochemistry`),
  CONSTRAINT `biochemistry_compounds_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_compound_compound_fk`
    FOREIGN KEY (`compound`)
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
  `genome` CHAR(36) NOT NULL,
  `start` INTEGER NULL,
  `stop` INTEGER NULL,
  PRIMARY KEY (`uuid`),
  INDEX `features_id` (`id`),
  INDEX `features_cksum` (`cksum`),
  INDEX `features_genome_fk` (`genome`),
  CONSTRAINT `features_genome_fk`
    FOREIGN KEY (`genome`)
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
  `exemplar` CHAR(36) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `roles_id` (`id`),
  INDEX `roles_name` (`name`),
  INDEX `roles_searchname` (`searchname`),
  INDEX `roles_exemplar` (`exemplar`),
  INDEX `roles_feature_fk` (`exemplar`),
  CONSTRAINT `roles_feature_fk`
    FOREIGN KEY (`exemplar`)
    REFERENCES `features` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `complex_roles`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `complex_roles` (
  `complex` CHAR(36) NOT NULL,
  `role` CHAR(36) NOT NULL,
  `optional` TINYINT(1)  NULL,
  `type` CHAR(1) NULL,
  PRIMARY KEY (`complex`, `role`),
  INDEX `role_fk` (`role`),
  INDEX `complex_fk` (`complex`),
  CONSTRAINT `complex_roles_complex_fk`
    FOREIGN KEY (`complex`)
    REFERENCES `complexes` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `complex_roles_role_fk`
    FOREIGN KEY (`role`)
    REFERENCES `roles` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_reactions`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_reactions` (
  `biochemistry` CHAR(36) NOT NULL,
  `reaction` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry`, `reaction`),
  INDEX `biochemistry_reactions_reaction_fk` (`reaction`),
  INDEX `biochemistry_reactions_biochemistry_fk` (`biochemistry`),
  CONSTRAINT `biochemistry_reactions_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_reactions_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reaction_rules`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reaction_rules` (
  `reaction` CHAR(36) NOT NULL,
  `complex` CHAR(36) NOT NULL,
  `compartment` CHAR(36) NOT NULL,
  `direction` CHAR(1) NULL,
  `transprotonNature` CHAR(255) NULL,
  PRIMARY KEY (`reaction`, `complex`),
  INDEX `reaction_rules_complex_fk` (`complex`),
  INDEX `reaction_rules_reaction_fk` (`reaction`),
  INDEX `reaction_rules_compartment_fk` (`compartment`),
  CONSTRAINT `reaction_rules_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_rules_complex_fk`
    FOREIGN KEY (`complex`)
    REFERENCES `complexes` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_rules_compartment_fk`
    FOREIGN KEY (`compartment`)
    REFERENCES `compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `reaction_rule_transports`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reaction_rule_transports` (
  `reaction` CHAR(36) NOT NULL,
  `complex` CHAR(36) NOT NULL,
  `compartmentIndex` INTEGER NOT NULL,
  `compartment` CHAR(36) NOT NULL,
  PRIMARY KEY (`reaction`, `complex`, `compartmentIndex`),
  INDEX `reaction_rule_transports_complex_fk` (`complex`),
  INDEX `reaction_rule_transports_reaction_fk` (`reaction`),
  INDEX `reaction_rule_transports_compartment_fk` (`compartment`),
  CONSTRAINT `reaction_rule_transports_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_rule_transports_complex_fk`
    FOREIGN KEY (`complex`)
    REFERENCES `complexes` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_rule_transports_compartment_fk`
    FOREIGN KEY (`compartment`)
    REFERENCES `compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;



-- -----------------------------------------------------
-- Table `compound_aliases`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compound_aliases` (
  `compound` CHAR(36) NOT NULL,
  `alias` VARCHAR(255) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `type` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`type`, `alias`),
  INDEX `compound_aliases_type` (`type`),
  INDEX `compound_aliases_compound_fk` (`compound`),
  CONSTRAINT `compound_aliases_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `compound_structures`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compound_structures` (
  `compound` CHAR(36) NOT NULL,
  `structure` TEXT NOT NULL,
  `cksum` VARCHAR(255) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `type` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`type`, `cksum`),
  INDEX `compound_structures_type` (`type`),
  INDEX `compound_structures_compound_fk` (`compound`),
  CONSTRAINT `compound_structures_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;



-- -----------------------------------------------------
-- Table `reaction_aliases`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reaction_aliases` (
  `reaction` CHAR(36) NOT NULL,
  `alias` VARCHAR(255) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `type` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`type`, `alias`),
  INDEX `compound_alias_type` (`type`),
  INDEX `reaction_fk` (`reaction`),
  CONSTRAINT `reaction_aliases_reaction_fk`
    FOREIGN KEY (`reaction`)
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
  `biochemistry` CHAR(36) NOT NULL,
  PRIMARY KEY (`uuid`),
  INDEX `mappings_public` (`public`),
  INDEX `mappings_biochemistry_fk` (`biochemistry`),
  CONSTRAINT `mappings_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mapping_complexes`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_complexes` (
  `mapping` CHAR(36) NOT NULL,
  `complex` CHAR(36) NOT NULL,
  PRIMARY KEY (`mapping`, `complex`),
  INDEX `mapping_complexes_complex_fk` (`complex`),
  INDEX `mapping_complexes_mapping_fk` (`mapping`),
  CONSTRAINT `mapping_complexes_mapping_fk`
    FOREIGN KEY (`mapping`)
    REFERENCES `mappings` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `mapping_complexes_complex_fk`
    FOREIGN KEY (`complex`)
    REFERENCES `complexes` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reagents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reagents` (
  `reaction` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  `compartmentIndex` INTEGER NOT NULL,
  `coefficient` DOUBLE NULL,
  `cofactor` TINYINT(1) NULL, 
  PRIMARY KEY (`reaction`, `compound`, `compartmentIndex`),
  INDEX `reagents_compound_fk` (`compound`),
  INDEX `reagents_reaction_fk` (`reaction`),
  CONSTRAINT `reagents_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reagents_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reagent_trasports`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reagent_transports` (
    `reaction` CHAR(36) NOT NULL,
    `defaultCompartment` CHAR(36) NOT NULL,
    `compartmentIndex` INTEGER NOT NULL,
    PRIMARY KEY (`reaction`, `compartmentIndex`),
    INDEX `reagent_transports_reaction_fk` (`reaction`),
    INDEX `reagent_transports_defaultCompartment_fk` (`defaultCompartment`),
    CONSTRAINT `reagent_transports_reaction_fk`
        FOREIGN KEY (`reaction`)
        REFERENCES `reactions` (`uuid`)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT `reagent_transports_defaultCompartment_fk`
        FOREIGN KEY (`defaultCompartment`)
        REFERENCES `compartments` (`uuid`)
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
  `genome` CHAR(36) NOT NULL,
  PRIMARY KEY (`uuid`),
  INDEX `annotations_name` (`name`),
  INDEX `annotations_genome_fk` (`genome`),
  CONSTRAINT `annotations_genome_fk`
    FOREIGN KEY (`genome`)
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
  `mapping` CHAR(36) NOT NULL,
  `biochemistry` CHAR(36) NOT NULL,
  `annotation` CHAR(36) NOT NULL,
  PRIMARY KEY (`uuid`),
  INDEX `models_mapping_fk` (`mapping`),
  INDEX `models_biochemistry_fk` (`biochemistry`),
  INDEX `models_annotation_fk` (`annotation`),
  CONSTRAINT `models_mapping_fk`
    FOREIGN KEY (`mapping`)
    REFERENCES `mappings` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `models_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `models_annotation_fk`
    FOREIGN KEY (`annotation`)
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
  `model` CHAR(36) NOT NULL,
  `compartment` CHAR(36) NOT NULL,
  `compartmentIndex` INTEGER NOT NULL,
  `label` VARCHAR(255) NULL,
  `pH` DOUBLE NULL,
  `potential` DOUBLE NULL,
  PRIMARY KEY (`uuid`),
  UNIQUE INDEX `model_compartments_idx` (`model`, `compartment`, `compartmentIndex`),
  INDEX `model_compartments_compartment_fk` (`compartment`),
  INDEX `model_compartments_model_fk` (`model`),
  CONSTRAINT `model_compartments_model_fk`
    FOREIGN KEY (`model`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_compartments_compartment_fk`
    FOREIGN KEY (`compartment`)
    REFERENCES `compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `model_reactions`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model_reactions` (
  `model` CHAR(36) NOT NULL,
  `reaction` CHAR(36) NOT NULL,
  `direction` CHAR(1) NULL,
  `transproton` DOUBLE NULL,
  `protons` DOUBLE NULL,
  `modelCompartment` CHAR(36) NOT NULL,
  PRIMARY KEY (`model`, `reaction`),
  INDEX `model_reactions_reaction_fk` (`reaction`),
  INDEX `model_reactions_model_fk` (`model`),
  INDEX `model_reactions_modelCompartment_fk` (`modelCompartment`),
  CONSTRAINT `model_reactions_model_fk`
    FOREIGN KEY (`model`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_reactions_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_reactions_modelCompartment_fk`
    FOREIGN KEY (`modelCompartment`)
    REFERENCES `model_compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `model_reaction_transports`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model_reaction_transports` (
  `model` CHAR(36) NOT NULL,
  `reaction` CHAR(36) NOT NULL,
  `transportIndex` INTEGER NOT NULL,
  `modelCompartment` CHAR(36) NOT NULL,
  PRIMARY KEY (`model`, `reaction`, `transportIndex`),
  INDEX `model_reaction_transports_reaction_fk` (`reaction`),
  INDEX `model_reaction_transports_model_fk` (`model`),
  INDEX `model_reaction_transports_modelCompartment_fk` (`modelCompartment`),
  CONSTRAINT `model_reaction_transports_model_fk`
    FOREIGN KEY (`model`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_reaction_transports_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_reaction_transports_modelCompartment_fk`
    FOREIGN KEY (`modelCompartment`)
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
  `model` CHAR(36) NOT NULL,
  `media` CHAR(36) NOT NULL,
  `options` VARCHAR(255) NULL,
  `geneko` VARCHAR(255) NULL,
  `reactionko` VARCHAR(255) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `modelfbas_model_fk` (`model`),
  INDEX `modelfbas_media_fk` (`media`),
  CONSTRAINT `modelfbas_model_fk`
    FOREIGN KEY (`model`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `modelfbas_media_fk`
    FOREIGN KEY (`media`)
    REFERENCES `media` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `media_compounds`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `media_compounds` (
  `media` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  `concentration` DOUBLE NULL,
  `minflux` DOUBLE NULL,
  `maxflux` DOUBLE NULL,
  PRIMARY KEY (`media`, `compound`),
  INDEX `media_compounds_compound_fk` (`compound`),
  INDEX `media_compounds_media_fk` (`media`),
  CONSTRAINT `media_compound_media_fk`
    FOREIGN KEY (`media`)
    REFERENCES `media` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `media_compound_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `modeless_features`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `modeless_features` (
  `modelfba` CHAR(36) NOT NULL,
  `feature` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `growthFraction` DOUBLE NULL,
  `essential` TINYINT(1)  NULL,
  PRIMARY KEY (`modelfba`, `feature`),
  INDEX `modeless_features_feature_fk` (`feature`),
  INDEX `modeless_features_modelfba_fk` (`modelfba`),
  CONSTRAINT `modeless_features_modelfba_fk`
    FOREIGN KEY (`modelfba`)
    REFERENCES `modelfbas` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `modeless_features_feature_fk`
    FOREIGN KEY (`feature`)
    REFERENCES `features` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `annotation_features`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `annotation_features` (
  `annotation` CHAR(36) NOT NULL,
  `feature` CHAR(36) NOT NULL,
  `role` CHAR(36) NOT NULL,
  PRIMARY KEY (`annotation`, `feature`, `role`),
  INDEX `annotation_features_feature_fk` (`feature`),
  INDEX `annotation_features_annotation_fk` (`annotation`),
  INDEX `annotation_features_role_fk` (`role`),
  CONSTRAINT `annotation_features_annotation_fk`
    FOREIGN KEY (`annotation`)
    REFERENCES `annotations` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `annotation_features_feature_fk`
    FOREIGN KEY (`feature`)
    REFERENCES `features` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `annotation_features_role_fk`
    FOREIGN KEY (`role`)
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
  `roleset` CHAR(36) NOT NULL,
  `role` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  PRIMARY KEY (`roleset`, `role`),
  INDEX `roleset_roles_role_fk` (`role`),
  INDEX `roleset_roles_roleset_fk` (`roleset`),
  CONSTRAINT `roleset_roles_roleset_fk`
    FOREIGN KEY (`roleset`)
    REFERENCES `rolesets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `roleset_roles_role_fk`
    FOREIGN KEY (`role`)
    REFERENCES `roles` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mapping_roles`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_roles` (
  `mapping` CHAR(36) NOT NULL,
  `role` CHAR(36) NOT NULL,
  PRIMARY KEY (`mapping`, `role`),
  INDEX `mapping_roles_role_fk` (`role`),
  INDEX `mapping_roles_mapping_fk` (`mapping`),
  CONSTRAINT `mapping_roles_mapping_fk`
    FOREIGN KEY (`mapping`)
    REFERENCES `mappings` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `mapping_roles_role_fk`
    FOREIGN KEY (`role`)
    REFERENCES `roles` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mapping_compartments`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_compartments` (
  `mapping` CHAR(36) NOT NULL,
  `compartment` CHAR(36) NOT NULL,
  PRIMARY KEY (`mapping`, `compartment`),
  INDEX `mapping_compartments_compartment_fk` (`compartment`),
  INDEX `mapping_compartments_mapping_fk` (`mapping`),
  CONSTRAINT `mapping_compartments_mapping_fk`
    FOREIGN KEY (`mapping`)
    REFERENCES `mappings` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `mapping_compartments_compartment_fk`
    FOREIGN KEY (`compartment`)
    REFERENCES `compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `compound_pks`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compound_pks` (
  `compound` CHAR(36) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `atom` INTEGER NULL,
  `pk` DOUBLE NULL,
  `type` CHAR(1) NULL,
  PRIMARY KEY (`compound`),
  INDEX `compound_pks_compound_fk` (`compound`),
  CONSTRAINT `compound_pks_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reactionset_reactions`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reactionset_reactions` (
  `reactionset` CHAR(36) NOT NULL,
  `reaction` CHAR(36) NOT NULL,
  PRIMARY KEY (`reactionset`, `reaction`),
  INDEX `reactionset_reactions_reaction_fk` (`reaction`),
  INDEX `reactionset_reactions_reactionset_fk` (`reactionset`),
  CONSTRAINT `reactionset_reactions_reactionset_fk`
    FOREIGN KEY (`reactionset`)
    REFERENCES `reactionsets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reactionset_reactions_reaction_fk`
    FOREIGN KEY (`reaction`)
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
  `compoundset` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  PRIMARY KEY (`compoundset`, `compound`),
  INDEX `compoundset_compounds_compound_fk` (`compound`),
  INDEX `compoundset_compounds_compoundset_fk` (`compoundset`),
  CONSTRAINT `compoundset_compounds_compoundset_fk`
    FOREIGN KEY (`compoundset`)
    REFERENCES `compoundsets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `compoundset_compounds_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `modelfba_reactions`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `modelfba_reactions` (
  `modelfba` CHAR(36) NOT NULL,
  `reaction` CHAR(36) NOT NULL,
  `min` DOUBLE NULL,
  `max` DOUBLE NULL,
  `class` CHAR(1) NULL,
  PRIMARY KEY (`modelfba`, `reaction`),
  INDEX `modelfba_reactions_reaction_fk` (`reaction`),
  INDEX `modelfba_reactions_modelfba_fk` (`modelfba`),
  CONSTRAINT `modelfba_reactions_modelfba_fk`
    FOREIGN KEY (`modelfba`)
    REFERENCES `modelfbas` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `modelfba_reactions_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reactions` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `modelfba_compounds`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `modelfba_compounds` (
  `modelfba` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  `min` DOUBLE NULL,
  `max` DOUBLE NULL,
  `class` CHAR(1) NULL,
  PRIMARY KEY (`modelfba`, `compound`),
  INDEX `modelfba_compounds_compound_fk` (`compound`),
  INDEX `modelfba_compounds_modelfba_fk` (`modelfba`),
  CONSTRAINT `modelfba_compounds_modelfba_fk`
    FOREIGN KEY (`modelfba`)
    REFERENCES `modelfbas` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `modelfba_compounds_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_media`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_media` (
  `biochemistry` CHAR(36) NOT NULL,
  `media` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry`, `media`),
  INDEX `biochemistry_media_media_fk` (`media`),
  INDEX `biochemistry_media_biochemistry_fk` (`biochemistry`),
  CONSTRAINT `biochemistry_media_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_media_media_fk`
    FOREIGN KEY (`media`)
    REFERENCES `media` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_reactionsets`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_reactionsets` (
  `biochemistry` CHAR(36) NOT NULL,
  `reactionset` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry`, `reactionset`),
  INDEX `biochemistry_reactionsets_reactionset_fk` (`reactionset`),
  INDEX `biochemistry_reactionsets_biochemistry_fk` (`biochemistry`),
  CONSTRAINT `biochemistry_reactionsets_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_reactionsets_reactionset_fk`
    FOREIGN KEY (`reactionset`)
    REFERENCES `reactionsets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_compoundsets`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_compoundsets` (
  `biochemistry` CHAR(36) NOT NULL,
  `compoundset` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry`, `compoundset`),
  INDEX `biochemistry_compoundsets_compoundset_fk` (`compoundset`),
  INDEX `biochemistry_compoundsets_biochemistry_fk` (`biochemistry`),
  CONSTRAINT `biochemistry_compoundsets_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_compoundsets_compoundset_fk`
    FOREIGN KEY (`compoundset`)
    REFERENCES `compoundsets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_parents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_parents` (
  `child` CHAR(36) NOT NULL,
  `parent` CHAR(36) NOT NULL,
  PRIMARY KEY (`child`, `parent`),
  INDEX `biochemistry_parents_parent_fk` (`parent`),
  CONSTRAINT `biochemistry_parents_parent_fk`
    FOREIGN KEY (`parent`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `biochemistry_parents_child_fk` (`child`),
  CONSTRAINT `biochemistry_parents_child_fk`
    FOREIGN KEY (`child`)
    REFERENCES `biochemistries` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mapping_parents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_parents` (
  `child` CHAR(36) NOT NULL,
  `parent` CHAR(36) NOT NULL,
  PRIMARY KEY (`child`, `parent`),
  INDEX `mapping_parents_parent_fk` (`parent`),
  CONSTRAINT `mapping_parents_parent_fk`
    FOREIGN KEY (`parent`)
    REFERENCES `mappings` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `mapping_parents_child_fk` (`child`),
  CONSTRAINT `mapping_parents_child_fk`
    FOREIGN KEY (`child`)
    REFERENCES `mappings` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `model_parents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model_parents` (
  `child` CHAR(36) NOT NULL,
  `parent` CHAR(36) NOT NULL,
  PRIMARY KEY (`child`, `parent`),
  INDEX `model_parents_parent_fk` (`parent`),
  CONSTRAINT `model_parents_parent_fk`
    FOREIGN KEY (`parent`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `model_parents_child_fk` (`child`),
  CONSTRAINT `model_parents_child_fk`
    FOREIGN KEY (`child`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `annotation_parents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `annotation_parents` (
  `child` CHAR(36) NOT NULL,
  `parent` CHAR(36) NOT NULL,
  PRIMARY KEY (`child`, `parent`),
  INDEX `annotation_parents_parent_fk` (`parent`),
  CONSTRAINT `annotation_parents_parent_fk`
    FOREIGN KEY (`parent`)
    REFERENCES `annotations` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `annotation_parents_child_fk` (`child`),
  CONSTRAINT `annotation_parents_child_fk`
    FOREIGN KEY (`child`)
    REFERENCES `annotations` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `roleset_parents`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `roleset_parents` (
  `child` CHAR(36) NOT NULL,
  `parent` CHAR(36) NOT NULL,
  PRIMARY KEY (`child`, `parent`),
  INDEX `roleset_parents_parent_fk` (`parent`),
  CONSTRAINT `roleset_parents_parent_fk`
    FOREIGN KEY (`parent`)
    REFERENCES `rolesets` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `roleset_parents_child_fk` (`child`),
  CONSTRAINT `roleset_parents_child_fk`
    FOREIGN KEY (`child`)
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
  `model` CHAR(36) NOT NULL,
  `biomass` CHAR(36) NOT NULL,
  PRIMARY KEY ( `model`, `biomass`),
  INDEX `model_biomass_biomass_fk` (`biomass`),
  CONSTRAINT `model_biomass_biomass_fk`
    FOREIGN KEY (`biomass`)
    REFERENCES `biomasses` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `model_biomass_model_fk` (`model`),
  CONSTRAINT `model_biomass_model_fk`
    FOREIGN KEY (`model`)
    REFERENCES `models` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biomass_compounds`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biomass_compounds` (
  `biomass` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  `compartment` CHAR(36) NOT NULL,
  `coefficient` DOUBLE NULL,
  PRIMARY KEY ( `biomass`, `compound`),
  INDEX `biomass_compounds_biomass_fk` (`biomass`),
  CONSTRAINT `biomass_compounds_biomass_fk`
    FOREIGN KEY (`biomass`)
    REFERENCES `biomasses` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION, 
  INDEX `biomass_compounds_compound_fk` (`compound`),
  CONSTRAINT `biomass_compounds_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compounds` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION, 
  INDEX `biomass_compounds_compartment_fk` (`compartment`),
  CONSTRAINT `biomass_compounds_compartment_fk`
    FOREIGN KEY (`compartment`)
    REFERENCES `model_compartments` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `biochemistry_aliases`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_aliases` (
    `biochemistry` CHAR(36) NOT NULL,
    `username` CHAR(255) NOT NULL,
    `id` CHAR(255) NOT NULL,
    PRIMARY KEY ( `username`, `id` ),
    INDEX `biochemistry_aliases_biochemistry_fk` (`biochemistry`),
    CONSTRAINT `biochemistry_aliases_biochemistry_fk`
        FOREIGN KEY (`biochemistry`)
        REFERENCES `biochemistries` (`uuid`)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `model_aliases`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model_aliases` (
    `model` CHAR(36) NOT NULL,
    `username` CHAR(255) NOT NULL,
    `id` CHAR(255) NOT NULL,
    PRIMARY KEY ( `username`, `id` ),
    INDEX `model_aliases_model_fk` (`model`),
    CONSTRAINT `model_aliases_model_fk`
        FOREIGN KEY (`model`)
        REFERENCES `models` (`uuid`)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION)
ENGINE = InnoDB;
        

-- -----------------------------------------------------
-- Table `mapping_aliases`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_aliases` (
    `mapping` CHAR(36) NOT NULL,
    `username` CHAR(255) NOT NULL,
    `id` CHAR(255) NOT NULL,
    PRIMARY KEY ( `username`, `id` ),
    INDEX `mapping_aliases_mapping_fk` (`mapping`),
    CONSTRAINT `mapping_aliases_mapping_fk`
        FOREIGN KEY (`mapping`)
        REFERENCES `mappings` (`uuid`)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- SET SQL_MODE=@OLD_SQL_MODE;
-- SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
-- SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

CREATE SCHEMA IF NOT EXISTS `ModelDB`; -- DEFAULT CHARACTER SET latin1 COLLATE latin1_swedish_ci;
USE `ModelDB` ;

-- -----------------------------------------------------
-- Table `compartment`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compartment` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `id` VARCHAR(2) NOT NULL,
  `name` VARCHAR(255) DEFAULT "",
  PRIMARY KEY (`uuid`),
  INDEX `compartment_id` (`id`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reaction`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reaction` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `id` VARCHAR(32) NOT NULL,
  `name` VARCHAR(255) DEFAULT "",
  `abbreviation` VARCHAR(32) DEFAULT "",
  `cksum` VARCHAR(255) DEFAULT "",
  `equation` VARCHAR(255) DEFAULT "",
  `deltaG` DOUBLE NULL,              -- scheduled for removal
  `deltaGErr` DOUBLE NULL,           -- scheduled for removal
  `reversibility` CHAR(1) DEFAULT "=",
  `thermoReversibility` CHAR(1) NULL, -- scheduled for removal
  `defaultProtons` DOUBLE NULL,       -- scheduled for removal
  `defaultIN` CHAR(36) NULL,          -- scheduled for removal
  `defaultOUT` CHAR(36) NULL,         -- scheduled for removal
  `defaultTransproton` DOUBLE NULL,  -- scheduled for removal
  PRIMARY KEY (`uuid`),
  INDEX `reaction_id` (`id`),
  INDEX `reaction_cksum` (`cksum`),
  INDEX `reaction_equation` (`equation`),
  INDEX `reaction_defaultIN_fk` (`defaultIN`),
  INDEX `reaction_defaultOUT_fk` (`defaultOUT`),
  CONSTRAINT `reaction_defaultIN_fk`
    FOREIGN KEY (`defaultIN`)
    REFERENCES `compartment` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_defaultOUT_fk`
    FOREIGN KEY (`defaultOUT`)
    REFERENCES `compartment` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `public` TINYINT(1)  NULL,
  `name` VARCHAR(255) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `biochemistry_public` (`public`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `compound`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compound` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `abbreviation` VARCHAR(32) NULL,
  `cksum` VARCHAR(255) NULL,
  `unchargedFormula` VARCHAR(255) NULL,
  `formula` VARCHAR(255) NULL,
  `mass` DOUBLE NULL,
  `defaultCharge` DOUBLE NULL,-- scheduled for removal
  `deltaG` DOUBLE NULL,       -- scheduled for removal
  `deltaGErr` DOUBLE NULL,    -- scheduled for removal
  PRIMARY KEY (`uuid`),
  INDEX `compound_cksum` (`cksum`),
  INDEX `compound_id` (`id`),
  INDEX `compound_name` (`name`),
  INDEX `compound_formula` (`formula`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_compound`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_compound` (
  `biochemistry` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry`, `compound`),
  INDEX `compound_fk` (`compound`),
  INDEX `biochemistry_fk` (`biochemistry`),
  CONSTRAINT `biochemistry_compound_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistry` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_compound_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compound` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `complex`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `complex` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `searchname` VARCHAR(255) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `complex_searchname` (`searchname`),
  INDEX `complex_id` (`id`),
  INDEX `complex_name` (`name`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `media`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `media` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `type` CHAR(1) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `media_id` (`id`),
  INDEX `media_name` (`name`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `genome`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `genome` (
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
  `size` INT NULL,
  `genes` INT NULL,
  `gc` DOUBLE NULL,
  `gramPositive` CHAR(1) NULL,
  `aerobic` CHAR(1) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `genome_id` (`id`),
  INDEX `genome_source` (`source`),
  INDEX `genome_cksum` (`cksum`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `feature`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `feature` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `id` VARCHAR(32) NULL,
  `cksum` VARCHAR(255) NULL,
  `genome` CHAR(36) NOT NULL,
  `start` INT NULL,
  `stop` INT NULL,
  PRIMARY KEY (`uuid`),
  INDEX `feature_id` (`id`),
  INDEX `feature_cksum` (`cksum`),
  INDEX `feature_genome_fk` (`genome`),
  CONSTRAINT `feature_genome_fk`
    FOREIGN KEY (`genome`)
    REFERENCES `genome` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `role`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `role` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `searchname` VARCHAR(255) NULL,
  `exemplar` CHAR(36) NOT NULL,
  PRIMARY KEY (`uuid`),
  INDEX `role_id` (`id`),
  INDEX `role_name` (`name`),
  INDEX `role_searchname` (`searchname`),
  INDEX `role_exemplar` (`exemplar`),
  INDEX `role_feature_fk` (`exemplar`),
  CONSTRAINT `role_feature_fk`
    FOREIGN KEY (`exemplar`)
    REFERENCES `feature` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `complex_role`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `complex_role` (
  `complex` CHAR(36) NOT NULL,
  `role` CHAR(36) NOT NULL,
  `optional` TINYINT(1)  NULL,
  `type` CHAR(1) NULL,
  PRIMARY KEY (`complex`, `role`),
  INDEX `role_fk` (`role`),
  INDEX `complex_fk` (`complex`),
  CONSTRAINT `complex_role_complex_fk`
    FOREIGN KEY (`complex`)
    REFERENCES `complex` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `complex_role_role_fk`
    FOREIGN KEY (`role`)
    REFERENCES `role` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_reaction`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_reaction` (
  `biochemistry` CHAR(36) NOT NULL,
  `reaction` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry`, `reaction`),
  INDEX `biochemistry_reaction_reaction_fk` (`reaction`),
  INDEX `biochemistry_reaction_biochemistry_fk` (`biochemistry`),
  CONSTRAINT `biochemistry_reaction_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistry` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_reaction_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reaction` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reaction_complex`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reaction_complex` (
  `reaction` CHAR(36) NOT NULL,
  `complex` CHAR(36) NOT NULL,
  `primaryCompartment` CHAR(36) NOT NULL,
  `secondaryCompartment` CHAR(36) NOT NULL,
  `direction` CHAR(1) NULL,
  `transproton` DOUBLE NULL,
  PRIMARY KEY (`reaction`, `complex`),
  INDEX `reaction_complex_complex_fk` (`complex`),
  INDEX `reaction_complex_reaction_fk` (`reaction`),
  INDEX `reaction_complex_primaryCompartment_fk` (`primaryCompartment`),
  INDEX `reaction_complex_secondaryCompartment_fk` (`secondaryCompartment`),
  CONSTRAINT `reaction_complex_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reaction` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_complex_complex_fk`
    FOREIGN KEY (`complex`)
    REFERENCES `complex` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_complex_primaryCompartment_fk`
    FOREIGN KEY (`primaryCompartment`)
    REFERENCES `compartment` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_complex_secondaryCompartment_fk`
    FOREIGN KEY (`secondaryCompartment`)
    REFERENCES `compartment` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `compound_alias`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compound_alias` (
  `compound` CHAR(36) NOT NULL,
  `alias` VARCHAR(255) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `type` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`compound`, `alias`),
  INDEX `compound_alias_type` (`type`),
  INDEX `compound_alias_compound_fk` (`compound`),
  CONSTRAINT `compound_alias_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compound` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reaction_alias`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reaction_alias` (
  `reaction` CHAR(36) NOT NULL,
  `alias` VARCHAR(255) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `type` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`reaction`, `alias`),
  INDEX `compound_alias_type` (`type`),
  INDEX `reaction_fk` (`reaction`),
  CONSTRAINT `reaction_alias_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reaction` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mapping`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `public` TINYINT(1)  NULL,
  `name` VARCHAR(255) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `mapping_public` (`public`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mapping_complex`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_complex` (
  `mapping` CHAR(36) NOT NULL,
  `complex` CHAR(36) NOT NULL,
  PRIMARY KEY (`mapping`, `complex`),
  INDEX `mapping_complex_complex_fk` (`complex`),
  INDEX `mapping_complex_mapping_fk` (`mapping`),
  CONSTRAINT `mapping_complex_mapping_fk`
    FOREIGN KEY (`mapping`)
    REFERENCES `mapping` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `mapping_complex_complex_fk`
    FOREIGN KEY (`complex`)
    REFERENCES `complex` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reaction_compound`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reaction_compound` (
  `reaction` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  `coefficient` DOUBLE NULL,       -- negative implies reactant
  `cofactor` TINYINT(1) NULL, 
  `secondaryCompartment` TINYINT(1) NULL, -- if true, in secondary compartment
  PRIMARY KEY (`reaction`, `compound`, `secondaryCompartment`),
  INDEX `reaction_compound_compound_fk` (`compound`),
  INDEX `reaction_compound_reaction_fk` (`reaction`),
  CONSTRAINT `reaction_compound_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reaction` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reaction_compound_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compound` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reactionset`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reactionset` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `searchname` VARCHAR(255) NULL,
  `class` VARCHAR(255) NULL,
  `type` VARCHAR(32) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `reactionset_id` (`id`),
  INDEX `reactionset_name` (`name`),
  INDEX `reactionset_searchname` (`searchname`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `annotation`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `annotation` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `name` VARCHAR(255) NULL,
  `genome` CHAR(36) NOT NULL,
  PRIMARY KEY (`uuid`),
  INDEX `annotation_name` (`name`),
  INDEX `annotation_genome_fk` (`genome`),
  CONSTRAINT `annotation_genome_fk`
    FOREIGN KEY (`genome`)
    REFERENCES `genome` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `model`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `locked` TINYINT(1)  NULL,
  `public` TINYINT(1)  NULL,
  `id` VARCHAR(255) NULL,
  `name` VARCHAR(32) NULL,
  `version` INT NULL,
  `type` VARCHAR(32) NULL,
  `status` VARCHAR(32) NULL,
  `reactions` INT NULL,
  `compounds` INT NULL,
  `annotations` INT NULL,
  `growth` DOUBLE NULL,
  `current` TINYINT(1)  NULL,
  `mapping` CHAR(36) NOT NULL,
  `biochemistry` CHAR(36) NOT NULL,
  `annotation` CHAR(36) NOT NULL,
  PRIMARY KEY (`uuid`),
  INDEX `model_mapping_fk` (`mapping`),
  INDEX `model_biochemistry_fk` (`biochemistry`),
  INDEX `model_annotation_fk` (`annotation`),
  CONSTRAINT `model_mapping_fk`
    FOREIGN KEY (`mapping`)
    REFERENCES `mapping` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistry` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_annotation_fk`
    FOREIGN KEY (`annotation`)
    REFERENCES `annotation` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `model_compartment`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model_compartment` (
  `uuid` CHAR(36) NOT NULL,
  `model` CHAR(36) NOT NULL,
  `compartment` CHAR(36) NOT NULL,
  `compartment_index` INT NOT NULL,
  `label` VARCHAR(255) NULL,
  `pH` DOUBLE NULL,
  `potential` DOUBLE NULL,
  PRIMARY KEY (`uuid`),
  UNIQUE INDEX `model_compartment_idx` (`model`, `compartment`, `compartment_index`),
  INDEX `model_compartment_compartment_fk` (`compartment`),
  INDEX `model_compartment_model_fk` (`model`),
  CONSTRAINT `model_compartment_model_fk`
    FOREIGN KEY (`model`)
    REFERENCES `model` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_compartment_compartment_fk`
    FOREIGN KEY (`compartment`)
    REFERENCES `compartment` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `model_reaction`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `model_reaction` (
  `model` CHAR(36) NOT NULL,
  `reaction` CHAR(36) NOT NULL,
  `direction` CHAR(1) NULL,    -- one of <, >, or =
  `transproton` DOUBLE NULL,
  `protons` DOUBLE NULL,
  `primaryModelCompartment` CHAR(36) NOT NULL,
  `secondaryModelCompartment` CHAR(36) NULL,
  PRIMARY KEY (`model`, `reaction`),
  INDEX `model_reaction_reaction_fk` (`reaction`),
  INDEX `model_reaction_model_fk` (`model`),
  INDEX `model_reaction_primaryModelCompartment_fk` (`primaryModelCompartment`),
  INDEX `model_reaction_secondaryModelCompartment_fk` (`secondaryModelCompartment`),
  CONSTRAINT `model_reaction_model_fk`
    FOREIGN KEY (`model`)
    REFERENCES `model` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_reaction_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reaction` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_reaction_primaryModelCompartment_fk`
    FOREIGN KEY (`primaryModelCompartment`)
    REFERENCES `model_compartment` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `model_reaction_secondaryModelCompartment_fk`
    FOREIGN KEY (`secondaryModelCompartment`)
    REFERENCES `model_compartment` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `modelfba`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `modelfba` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `model` CHAR(36) NOT NULL,
  `media` CHAR(36) NOT NULL,
  `options` VARCHAR(255) NULL,
  `geneko` VARCHAR(255) NULL,
  `reactionko` VARCHAR(255) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `modelfba_model_fk` (`model`),
  INDEX `modelfba_media_fk` (`media`),
  CONSTRAINT `modelfba_model_fk`
    FOREIGN KEY (`model`)
    REFERENCES `model` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `modelfba_media_fk`
    FOREIGN KEY (`media`)
    REFERENCES `media` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `media_compound`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `media_compound` (
  `media` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  `concentration` DOUBLE NULL,
  `minflux` DOUBLE NULL,
  `maxflux` DOUBLE NULL,
  PRIMARY KEY (`media`, `compound`),
  INDEX `media_compound_compound_fk` (`compound`),
  INDEX `media_compound_media_fk` (`media`),
  CONSTRAINT `media_compound_media_fk`
    FOREIGN KEY (`media`)
    REFERENCES `media` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `media_compound_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compound` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `modeless_feature`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `modeless_feature` (
  `modelfba` CHAR(36) NOT NULL,
  `feature` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `growthFraction` DOUBLE NULL,
  `essential` TINYINT(1)  NULL,
  PRIMARY KEY (`modelfba`, `feature`),
  INDEX `modeless_feature_feature_fk` (`feature`),
  INDEX `modeless_feature_modelfba_fk` (`modelfba`),
  CONSTRAINT `modeless_feature_modelfba_fk`
    FOREIGN KEY (`modelfba`)
    REFERENCES `modelfba` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `modeless_feature_feature_fk`
    FOREIGN KEY (`feature`)
    REFERENCES `feature` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `annotation_feature`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `annotation_feature` (
  `annotation` CHAR(36) NOT NULL,
  `feature` CHAR(36) NOT NULL,
  `role` CHAR(36) NOT NULL,
  PRIMARY KEY (`annotation`, `feature`, `role`),
  INDEX `annotation_feature_feature_fk` (`feature`),
  INDEX `annotation_feature_annotation_fk` (`annotation`),
  INDEX `annotation_feature_role_fk` (`role`),
  CONSTRAINT `annotation_feature_annotation_fk`
    FOREIGN KEY (`annotation`)
    REFERENCES `annotation` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `annotation_feature_feature_fk`
    FOREIGN KEY (`feature`)
    REFERENCES `feature` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `annotation_feature_role_fk`
    FOREIGN KEY (`role`)
    REFERENCES `role` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `roleset`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `roleset` (
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
  INDEX `roleset_id` (`id`),
  INDEX `roleset_name` (`name`),
  INDEX `roleset_searchname` (`searchname`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `roleset_role`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `roleset_role` (
  `roleset` CHAR(36) NOT NULL,
  `role` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  PRIMARY KEY (`roleset`, `role`),
  INDEX `roleset_role_role_fk` (`role`),
  INDEX `roleset_role_roleset_fk` (`roleset`),
  CONSTRAINT `roleset_role_roleset_fk`
    FOREIGN KEY (`roleset`)
    REFERENCES `roleset` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `roleset_role_role_fk`
    FOREIGN KEY (`role`)
    REFERENCES `role` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mapping_role`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_role` (
  `mapping` CHAR(36) NOT NULL,
  `role` CHAR(36) NOT NULL,
  PRIMARY KEY (`mapping`, `role`),
  INDEX `mapping_role_role_fk` (`role`),
  INDEX `mapping_role_mapping_fk` (`mapping`),
  CONSTRAINT `mapping_role_mapping_fk`
    FOREIGN KEY (`mapping`)
    REFERENCES `mapping` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `mapping_role_role_fk`
    FOREIGN KEY (`role`)
    REFERENCES `role` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mapping_compartment`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mapping_compartment` (
  `mapping` CHAR(36) NOT NULL,
  `compartment` CHAR(36) NOT NULL,
  PRIMARY KEY (`mapping`, `compartment`),
  INDEX `mapping_compartment_compartment_fk` (`compartment`),
  INDEX `mapping_compartment_mapping_fk` (`mapping`),
  CONSTRAINT `mapping_compartment_mapping_fk`
    FOREIGN KEY (`mapping`)
    REFERENCES `mapping` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `mapping_compartment_compartment_fk`
    FOREIGN KEY (`compartment`)
    REFERENCES `compartment` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `compound_pk`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compound_pk` (
  `compound` CHAR(36) NOT NULL,
  `modDate` VARCHAR(45) NULL,
  `atom` INT NULL,
  `pk` DOUBLE NULL,
  `type` CHAR(1) NULL,
  PRIMARY KEY (`compound`),
  INDEX `compound_pk_compound_fk` (`compound`),
  CONSTRAINT `compound_pk_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compound` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `reactionset_reaction`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `reactionset_reaction` (
  `reactionset` CHAR(36) NOT NULL,
  `reaction` CHAR(36) NOT NULL,
  PRIMARY KEY (`reactionset`, `reaction`),
  INDEX `reactionset_reaction_reaction_fk` (`reaction`),
  INDEX `reactionset_reaction_reactionset_fk` (`reactionset`),
  CONSTRAINT `reactionset_reaction_reactionset_fk`
    FOREIGN KEY (`reactionset`)
    REFERENCES `reactionset` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `reactionset_reaction_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reaction` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `compoundset`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compoundset` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
  `id` VARCHAR(32) NULL,
  `name` VARCHAR(255) NULL,
  `searchname` VARCHAR(255) NULL,
  `class` VARCHAR(255) NULL,
  `type` VARCHAR(32) NULL,
  PRIMARY KEY (`uuid`),
  INDEX `compoundset_id` (`id`),
  INDEX `compoundset_name` (`name`),
  INDEX `compoundset_searchname` (`searchname`)
)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `compoundset_compound`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `compoundset_compound` (
  `compoundset` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  PRIMARY KEY (`compoundset`, `compound`),
  INDEX `compoundset_compound_compound_fk` (`compound`),
  INDEX `compoundset_compound_compoundset_fk` (`compoundset`),
  CONSTRAINT `compoundset_compound_compoundset_fk`
    FOREIGN KEY (`compoundset`)
    REFERENCES `compoundset` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `compoundset_compound_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compound` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `modelfba_reaction`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `modelfba_reaction` (
  `modelfba` CHAR(36) NOT NULL,
  `reaction` CHAR(36) NOT NULL,
  `min` DOUBLE NULL,
  `max` DOUBLE NULL,
  `class` CHAR(1) NULL,
  PRIMARY KEY (`modelfba`, `reaction`),
  INDEX `modelfba_reaction_reaction_fk` (`reaction`),
  INDEX `modelfba_reaction_modelfba_fk` (`modelfba`),
  CONSTRAINT `modelfba_reaction_modelfba_fk`
    FOREIGN KEY (`modelfba`)
    REFERENCES `modelfba` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `modelfba_reaction_reaction_fk`
    FOREIGN KEY (`reaction`)
    REFERENCES `reaction` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `modelfba_compound`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `modelfba_compound` (
  `modelfba` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  `min` DOUBLE NULL,
  `max` DOUBLE NULL,
  `class` CHAR(1) NULL,
  PRIMARY KEY (`modelfba`, `compound`),
  INDEX `modelfba_compound_compound_fk` (`compound`),
  INDEX `modelfba_compound_modelfba_fk` (`modelfba`),
  CONSTRAINT `modelfba_compound_modelfba_fk`
    FOREIGN KEY (`modelfba`)
    REFERENCES `modelfba` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `modelfba_compound_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compound` (`uuid`)
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
    REFERENCES `biochemistry` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_media_media_fk`
    FOREIGN KEY (`media`)
    REFERENCES `media` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_reactionset`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_reactionset` (
  `biochemistry` CHAR(36) NOT NULL,
  `reactionset` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry`, `reactionset`),
  INDEX `biochemistry_reactionset_reactionset_fk` (`reactionset`),
  INDEX `biochemistry_reactionset_biochemistry_fk` (`biochemistry`),
  CONSTRAINT `biochemistry_reactionset_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistry` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_reactionset_reactionset_fk`
    FOREIGN KEY (`reactionset`)
    REFERENCES `reactionset` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_compoundset`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_compoundset` (
  `biochemistry` CHAR(36) NOT NULL,
  `compoundset` CHAR(36) NOT NULL,
  PRIMARY KEY (`biochemistry`, `compoundset`),
  INDEX `biochemistry_compoundset_compoundset_fk` (`compoundset`),
  INDEX `biochemistry_compoundset_biochemistry_fk` (`biochemistry`),
  CONSTRAINT `biochemistry_compoundset_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistry` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_compoundset_compoundset_fk`
    FOREIGN KEY (`compoundset`)
    REFERENCES `compoundset` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_reaction_alias`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_reaction_alias` (
  `biochemistry` CHAR(36) NOT NULL,
  `reaction` CHAR(36) NOT NULL,
  `alias` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`biochemistry`, `reaction`, `alias`),
  INDEX `biochemistry_reaction_alias_reaction_alias_fk` (`reaction`, `alias`),
  INDEX `biochemistry_reaction_alias_biochemistry_fk` (`biochemistry`),
  CONSTRAINT `biochemistry_reaction_alias_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistry` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_reaction_alias_reaction_alias_fk`
    FOREIGN KEY (`reaction`, `alias`)
    REFERENCES `reaction_alias` (`reaction`, `alias`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biochemistry_compound_alias`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biochemistry_compound_alias` (
  `biochemistry` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  `alias` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`biochemistry`, `compound`, `alias`),
  INDEX `biochemistry_compound_alias_compound_alias_fk` (`compound`, `alias`),
  INDEX `biochemistry_compound_alias_biochemistry_fk` (`biochemistry`),
  CONSTRAINT `biochemistry_compound_alias_biochemistry_fk`
    FOREIGN KEY (`biochemistry`)
    REFERENCES `biochemistry` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `biochemistry_compound_alias_compound_alias_fk`
    FOREIGN KEY (`compound`, `alias`)
    REFERENCES `compound_alias` (`compound`, `alias`)
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
    REFERENCES `biochemistry` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `biochemistry_parents_child_fk` (`child`),
  CONSTRAINT `biochemistry_parents_child_fk`
    FOREIGN KEY (`child`)
    REFERENCES `biochemistry` (`uuid`)
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
    REFERENCES `mapping` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `mapping_parents_child_fk` (`child`),
  CONSTRAINT `mapping_parents_child_fk`
    FOREIGN KEY (`child`)
    REFERENCES `mapping` (`uuid`)
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
    REFERENCES `model` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `model_parents_child_fk` (`child`),
  CONSTRAINT `model_parents_child_fk`
    FOREIGN KEY (`child`)
    REFERENCES `model` (`uuid`)
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
    REFERENCES `annotation` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `annotation_parents_child_fk` (`child`),
  CONSTRAINT `annotation_parents_child_fk`
    FOREIGN KEY (`child`)
    REFERENCES `annotation` (`uuid`)
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
    REFERENCES `roleset` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `roleset_parents_child_fk` (`child`),
  CONSTRAINT `roleset_parents_child_fk`
    FOREIGN KEY (`child`)
    REFERENCES `roleset` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `permission`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `permission` (
  `object` CHAR(36) NOT NULL,
  `user` VARCHAR(255) NOT NULL,
  `read` TINYINT(1)  NULL,
  `write` TINYINT(1)  NULL,
  `admin` TINYINT(1)  NULL,
  PRIMARY KEY (`object`, `user`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biomass`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biomass` (
  `uuid` CHAR(36) NOT NULL,
  `modDate` DATETIME NULL,
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
    REFERENCES `biomass` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  INDEX `model_biomass_model_fk` (`model`),
  CONSTRAINT `model_biomass_model_fk`
    FOREIGN KEY (`model`)
    REFERENCES `model` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `biomass_compound`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `biomass_compound` (
  `biomass` CHAR(36) NOT NULL,
  `compound` CHAR(36) NOT NULL,
  `compartment` CHAR(36) NOT NULL,
  `coefficient` DOUBLE NULL,
  PRIMARY KEY ( `biomass`, `compound`),
  INDEX `biomass_compound_biomass_fk` (`biomass`),
  CONSTRAINT `biomass_compound_biomass_fk`
    FOREIGN KEY (`biomass`)
    REFERENCES `biomass` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION, 
  INDEX `biomass_compound_compound_fk` (`compound`),
  CONSTRAINT `biomass_compound_compound_fk`
    FOREIGN KEY (`compound`)
    REFERENCES `compound` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION, 
  INDEX `biomass_compound_compartment_fk` (`compartment`),
  CONSTRAINT `biomass_compound_compartment_fk`
    FOREIGN KEY (`compartment`)
    REFERENCES `model_compartment` (`uuid`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

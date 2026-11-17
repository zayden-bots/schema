ALTER TABLE deadlock_patches ADD COLUMN news boolean NOT NULL DEFAULT false;

ALTER TABLE deadlock_patch_announce ADD COLUMN include_news boolean NOT NULL DEFAULT false;

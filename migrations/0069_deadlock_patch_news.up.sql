ALTER TABLE deadlock_patches
    ADD COLUMN news boolean NOT NULL DEFAULT FALSE;

ALTER TABLE deadlock_patch_announce
    ADD COLUMN include_news boolean NOT NULL DEFAULT FALSE;


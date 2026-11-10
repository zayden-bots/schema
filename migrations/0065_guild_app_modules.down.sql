DROP TABLE application_status;

DROP TABLE application_modules;

DROP TABLE guild_app_modules;

ALTER TABLE guild_presence
    DROP COLUMN modules_seeded_at;


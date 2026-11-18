DELETE FROM deadlock_api_cache
WHERE kind = 'match';

ALTER TABLE deadlock_api_cache
    DROP CONSTRAINT deadlock_api_cache_kind_check,
    ADD CONSTRAINT deadlock_api_cache_kind_check CHECK (kind IN ('asset', 'analytics', 'build', 'patch'));

DROP TABLE deadlock_report_waits;

ALTER TABLE deadlock_user_settings
    DROP COLUMN match_fetch;

DROP TABLE deadlock_device_codes;

DROP TABLE deadlock_app_tokens;


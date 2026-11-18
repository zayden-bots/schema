CREATE TABLE deadlock_app_tokens (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    token_hash bytea NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
    discord_id bigint NOT NULL,
    device_name text NOT NULL CHECK (octet_length(device_name) <= 64),
    app_version text NOT NULL CHECK (octet_length(app_version) <= 64),
    created_at timestamptz NOT NULL DEFAULT now(),
    last_used_at timestamptz,
    revoked_at timestamptz
);

CREATE INDEX deadlock_app_tokens_live ON deadlock_app_tokens (discord_id)
WHERE
    revoked_at IS NULL;

CREATE TABLE deadlock_device_codes (
    device_code_hash bytea PRIMARY KEY CHECK (octet_length(device_code_hash) = 32),
    user_code text NOT NULL UNIQUE CHECK (user_code ~ '^[BCDFGHJKLMNPQRSTVWXZ]{8}$'),
    device_name text NOT NULL CHECK (octet_length(device_name) <= 64),
    app_version text NOT NULL CHECK (octet_length(app_version) <= 64),
    requested_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    interval_secs integer NOT NULL DEFAULT 5 CHECK (interval_secs > 0),
    last_polled_at timestamptz,
    approved_by bigint,
    approved_at timestamptz,
    denied_at timestamptz,
    granted_at timestamptz,
    CHECK ((approved_by IS NULL) = (approved_at IS NULL)),
    CHECK (approved_at IS NULL OR denied_at IS NULL),
    CHECK (granted_at IS NULL OR approved_at IS NOT NULL)
);

CREATE INDEX deadlock_device_codes_expires_at ON deadlock_device_codes (expires_at);

ALTER TABLE deadlock_user_settings
    ADD COLUMN match_fetch boolean NOT NULL DEFAULT TRUE;

CREATE TABLE deadlock_report_waits (
    account_id bigint NOT NULL,
    match_id bigint NOT NULL,
    discord_id bigint NOT NULL,
    ended_at timestamptz NOT NULL,
    reported_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    attempts integer NOT NULL DEFAULT 0,
    salts_at timestamptz,
    metadata_at timestamptz,
    finished_at timestamptz,
    outcome text CHECK (outcome IN ('ready', 'not_in_match', 'expired')),
    PRIMARY KEY (account_id, match_id),
    CHECK ((finished_at IS NULL) = (outcome IS NULL))
);

CREATE INDEX deadlock_report_waits_due ON deadlock_report_waits (next_attempt_at)
WHERE
    finished_at IS NULL;

CREATE INDEX deadlock_report_waits_discord_id ON deadlock_report_waits (discord_id, reported_at DESC);

ALTER TABLE deadlock_api_cache
    DROP CONSTRAINT deadlock_api_cache_kind_check,
    ADD CONSTRAINT deadlock_api_cache_kind_check CHECK (kind IN ('asset', 'analytics', 'build', 'patch', 'match'));


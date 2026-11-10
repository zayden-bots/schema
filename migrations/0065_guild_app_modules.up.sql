ALTER TABLE guild_presence
    ADD COLUMN modules_seeded_at timestamptz;

UPDATE
    guild_presence p
SET
    modules_seeded_at = COALESCE(p.joined_at, g.bot_joined_at)
FROM
    guilds g
WHERE
    g.id = p.guild_id
    AND g.bot_joined_at IS NOT NULL;

CREATE TABLE guild_app_modules (
    guild_id bigint NOT NULL REFERENCES guilds (id) ON DELETE CASCADE,
    application_id bigint NOT NULL,
    module text NOT NULL,
    enabled boolean NOT NULL,
    PRIMARY KEY (guild_id, application_id, module)
);

INSERT INTO guild_app_modules (guild_id, application_id, module, enabled)
SELECT
    m.guild_id,
    p.application_id,
    m.module,
    m.enabled
FROM
    guild_modules m
    JOIN guild_presence p ON p.guild_id = m.guild_id;

CREATE TABLE application_modules (
    application_id bigint NOT NULL,
    module text NOT NULL,
    PRIMARY KEY (application_id, module)
);

CREATE TABLE application_status (
    process text PRIMARY KEY,
    application_id bigint,
    build_sha text NOT NULL,
    started_at timestamptz NOT NULL,
    last_seen timestamptz NOT NULL
);


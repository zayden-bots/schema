CREATE TABLE applications (
    application_id bigint PRIMARY KEY,
    slot text NOT NULL CHECK (slot IN ('zayden', 'maria')),
    kind text NOT NULL CHECK (kind IN ('default', 'custom')),
    bot_user_id bigint NOT NULL,
    name text NOT NULL,
    avatar text,
    public_key text,
    token_ct bytea,
    token_nonce bytea,
    key_id smallint,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
    registered_by bigint,
    last_error text,
    created_at timestamptz NOT NULL DEFAULT now(),
    token_rotated_at timestamptz,
    UNIQUE (application_id, slot),
    CHECK ((token_ct IS NULL) = (token_nonce IS NULL) AND (token_ct IS NULL) = (key_id IS NULL)),
    CHECK (kind = 'default' OR (token_ct IS NOT NULL AND public_key IS NOT NULL AND registered_by IS NOT NULL))
);

CREATE UNIQUE INDEX applications_default_slot_idx ON applications (slot)
WHERE
    kind = 'default';

CREATE TABLE application_guilds (
    guild_id bigint NOT NULL REFERENCES guilds (id) ON DELETE CASCADE,
    slot text NOT NULL,
    application_id bigint NOT NULL,
    attached_by bigint NOT NULL,
    attached_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (guild_id, slot),
    FOREIGN KEY (application_id, slot) REFERENCES applications (application_id, slot) ON DELETE CASCADE
);

CREATE INDEX application_guilds_application_idx ON application_guilds (application_id);

INSERT INTO applications (application_id, slot, kind, bot_user_id, name, avatar, public_key, token_ct, token_nonce, key_id, status, registered_by, last_error, created_at, token_rotated_at)
SELECT
    application_id,
    'zayden',
    'custom',
    bot_user_id,
    name,
    avatar,
    public_key,
    token_ct,
    token_nonce,
    key_id,
    status,
    registered_by,
    last_error,
    created_at,
    token_rotated_at
FROM
    custom_bots;

INSERT INTO application_guilds (guild_id, slot, application_id, attached_by, attached_at)
SELECT
    guild_id,
    'zayden',
    application_id,
    attached_by,
    attached_at
FROM
    custom_bot_guilds;

CREATE FUNCTION custom_application (p_guild_id bigint, p_slot text)
    RETURNS bigint
    LANGUAGE sql
    STABLE
    AS $$
    SELECT
        a.application_id
    FROM
        application_guilds g
        JOIN applications a ON a.application_id = g.application_id
        JOIN guild_presence p ON p.guild_id = g.guild_id
            AND p.application_id = g.application_id
    WHERE
        g.guild_id = p_guild_id
        AND g.slot = p_slot
        AND a.kind = 'custom'
        AND a.status = 'active'
        AND p.left_at IS NULL
        AND custom_bot_entitled (p_guild_id)
$$;

CREATE FUNCTION serving_application (p_guild_id bigint, p_slot text)
    RETURNS bigint
    LANGUAGE sql
    STABLE
    AS $$
    SELECT
        COALESCE(custom_application (p_guild_id, p_slot), (
                SELECT
                    d.application_id
                FROM applications d
                WHERE
                    d.slot = p_slot
                    AND d.kind = 'default'))
$$;

CREATE FUNCTION notify_applications_changed ()
    RETURNS TRIGGER
    AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM
            pg_notify('custom_bots_changed', OLD.application_id::text);
    ELSE
        PERFORM
            pg_notify('custom_bots_changed', NEW.application_id::text);
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
        PERFORM
            pg_notify('serving_changed', g.guild_id::text)
        FROM
            application_guilds g
        WHERE
            g.application_id = NEW.application_id;
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER applications_notify_insert_delete
    AFTER INSERT OR DELETE ON applications
    FOR EACH ROW
    EXECUTE FUNCTION notify_applications_changed ();

CREATE TRIGGER applications_notify_update
    AFTER UPDATE ON applications
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.token_ct IS DISTINCT FROM NEW.token_ct OR OLD.key_id IS DISTINCT FROM NEW.key_id)
    EXECUTE FUNCTION notify_applications_changed ();

CREATE FUNCTION notify_application_guilds_changed ()
    RETURNS TRIGGER
    AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM
            pg_notify('serving_changed', OLD.guild_id::text);
        PERFORM
            pg_notify('custom_bots_changed', OLD.application_id::text);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM
            pg_notify('serving_changed', NEW.guild_id::text);
        PERFORM
            pg_notify('custom_bots_changed', NEW.application_id::text);
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER application_guilds_serving_notify
    AFTER INSERT OR UPDATE OR DELETE ON application_guilds
    FOR EACH ROW
    EXECUTE FUNCTION notify_application_guilds_changed ();


CREATE TABLE bot_tokens (
    token text PRIMARY KEY,
    name text NOT NULL
);

ALTER TABLE guilds
    ADD COLUMN bot_joined_at timestamptz;

CREATE TABLE guild_modules (
    guild_id bigint NOT NULL REFERENCES guilds (id) ON DELETE CASCADE,
    module text NOT NULL,
    enabled boolean NOT NULL,
    PRIMARY KEY (guild_id, module)
);

CREATE TABLE custom_bots (
    application_id bigint PRIMARY KEY,
    bot_user_id bigint NOT NULL,
    name text NOT NULL,
    avatar text,
    public_key text NOT NULL,
    token_ct bytea NOT NULL,
    token_nonce bytea NOT NULL,
    key_id smallint NOT NULL,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
    registered_by bigint NOT NULL,
    connected_at timestamptz,
    heartbeat_at timestamptz,
    last_error text,
    created_at timestamptz NOT NULL DEFAULT now(),
    token_rotated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE custom_bot_guilds (
    guild_id bigint PRIMARY KEY REFERENCES guilds (id) ON DELETE CASCADE,
    application_id bigint NOT NULL REFERENCES custom_bots (application_id) ON DELETE CASCADE,
    attached_by bigint NOT NULL,
    attached_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX custom_bot_guilds_application_idx ON custom_bot_guilds (application_id);

CREATE FUNCTION serving_application (p_guild_id bigint)
    RETURNS bigint
    LANGUAGE sql
    STABLE
    AS $$
    SELECT
        b.application_id
    FROM
        custom_bot_guilds g
        JOIN custom_bots b ON b.application_id = g.application_id
        JOIN guild_presence p ON p.guild_id = g.guild_id
            AND p.application_id = g.application_id
    WHERE
        g.guild_id = p_guild_id
        AND b.status = 'active'
        AND p.left_at IS NULL
        AND custom_bot_entitled (p_guild_id)
$$;

CREATE FUNCTION notify_custom_bots_changed ()
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
            custom_bot_guilds g
        WHERE
            g.application_id = NEW.application_id;
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER custom_bots_notify_insert_delete
    AFTER INSERT OR DELETE ON custom_bots
    FOR EACH ROW
    EXECUTE FUNCTION notify_custom_bots_changed ();

CREATE TRIGGER custom_bots_notify_update
    AFTER UPDATE ON custom_bots
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.token_ct IS DISTINCT FROM NEW.token_ct OR OLD.key_id IS DISTINCT FROM NEW.key_id OR OLD.connected_at IS DISTINCT FROM NEW.connected_at)
    EXECUTE FUNCTION notify_custom_bots_changed ();

CREATE OR REPLACE FUNCTION notify_serving_changed ()
    RETURNS TRIGGER
    AS $$
BEGIN
    IF TG_TABLE_NAME = 'entitlements' THEN
        IF TG_OP <> 'INSERT' AND OLD.scope_type = 'guild' THEN
            PERFORM
                pg_notify('serving_changed', OLD.scope_id::text);
        END IF;
        IF TG_OP <> 'DELETE' AND NEW.scope_type = 'guild' THEN
            PERFORM
                pg_notify('serving_changed', NEW.scope_id::text);
        END IF;
        RETURN NULL;
    END IF;
    IF TG_OP <> 'INSERT' THEN
        PERFORM
            pg_notify('serving_changed', OLD.guild_id::text);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM
            pg_notify('serving_changed', NEW.guild_id::text);
    END IF;
    IF TG_TABLE_NAME = 'custom_bot_guilds' THEN
        IF TG_OP = 'DELETE' THEN
            PERFORM
                pg_notify('custom_bots_changed', OLD.application_id::text);
        ELSE
            PERFORM
                pg_notify('custom_bots_changed', NEW.application_id::text);
        END IF;
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER custom_bot_guilds_serving_notify
    AFTER INSERT OR UPDATE OR DELETE ON custom_bot_guilds
    FOR EACH ROW
    EXECUTE FUNCTION notify_serving_changed ();


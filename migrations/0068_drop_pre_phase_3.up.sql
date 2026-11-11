DROP TABLE custom_bot_guilds;

DROP TABLE custom_bots;

DROP FUNCTION notify_custom_bots_changed ();

DROP FUNCTION serving_application (bigint);

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
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

DROP TABLE guild_modules;

ALTER TABLE guilds
    DROP COLUMN bot_joined_at;

DROP TABLE bot_tokens;


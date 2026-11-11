CREATE TABLE delivery_webhooks (
    channel_id bigint NOT NULL,
    application_id bigint NOT NULL,
    guild_id bigint NOT NULL,
    webhook_id bigint NOT NULL,
    token_ct bytea NOT NULL,
    token_nonce bytea NOT NULL,
    key_id smallint NOT NULL,
    broken_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (channel_id, application_id)
);

CREATE INDEX delivery_webhooks_guild_idx ON delivery_webhooks (guild_id, application_id);

ALTER TABLE youtube_announce
    ADD COLUMN delivery_application_id bigint;

ALTER TABLE patreon_announce
    ADD COLUMN delivery_application_id bigint;

ALTER TABLE marathon_announce
    ADD COLUMN delivery_application_id bigint;

ALTER TABLE deadlock_patch_announce
    ADD COLUMN delivery_application_id bigint;

ALTER TABLE deadlock_summary_channel
    ADD COLUMN delivery_application_id bigint;

ALTER TABLE deadlock_squad_channel
    ADD COLUMN delivery_application_id bigint;

ALTER TABLE deadlock_user_settings
    ADD COLUMN opt_in_guild_id bigint;

CREATE FUNCTION delivery_application (p_guild_id bigint, p_delivery_application_id bigint)
    RETURNS bigint
    LANGUAGE sql
    STABLE
    AS $$
    SELECT
        s.application_id
    FROM (
        SELECT
            COALESCE(p_delivery_application_id, serving_application (p_guild_id, 'zayden')) AS application_id) s
WHERE
    EXISTS (
        SELECT
            1
        FROM
            guild_presence p
        WHERE
            p.guild_id = p_guild_id
            AND p.application_id = s.application_id
            AND p.left_at IS NULL)
$$;

CREATE VIEW delivery_targets AS
SELECT
    t.guild_id,
    t.channel_id,
    t.delivery_application_id
FROM (
    SELECT
        guild_id,
        channel_id,
        delivery_application_id
    FROM
        youtube_announce
    UNION ALL
    SELECT
        guild_id,
        channel_id,
        delivery_application_id
    FROM
        patreon_announce
    UNION ALL
    SELECT
        guild_id,
        channel_id,
        delivery_application_id
    FROM
        marathon_announce
    UNION ALL
    SELECT
        guild_id,
        channel_id,
        delivery_application_id
    FROM
        deadlock_patch_announce
    UNION ALL
    SELECT
        guild_id,
        channel_id,
        delivery_application_id
    FROM
        deadlock_summary_channel
    UNION ALL
    SELECT
        guild_id,
        channel_id,
        delivery_application_id
    FROM
        deadlock_squad_channel) t
WHERE
    t.channel_id <> 0;

CREATE FUNCTION notify_delivery_changed ()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM
            pg_notify('delivery_changed', OLD.guild_id::text);
    ELSE
        PERFORM
            pg_notify('delivery_changed', NEW.guild_id::text);
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER youtube_announce_delivery
    AFTER INSERT OR DELETE OR UPDATE OF channel_id,
    delivery_application_id ON youtube_announce
    FOR EACH ROW
    EXECUTE FUNCTION notify_delivery_changed ();

CREATE TRIGGER patreon_announce_delivery
    AFTER INSERT OR DELETE OR UPDATE OF channel_id,
    delivery_application_id ON patreon_announce
    FOR EACH ROW
    EXECUTE FUNCTION notify_delivery_changed ();

CREATE TRIGGER marathon_announce_delivery
    AFTER INSERT OR DELETE OR UPDATE OF channel_id,
    delivery_application_id ON marathon_announce
    FOR EACH ROW
    EXECUTE FUNCTION notify_delivery_changed ();

CREATE TRIGGER deadlock_patch_announce_delivery
    AFTER INSERT OR DELETE OR UPDATE OF channel_id,
    delivery_application_id ON deadlock_patch_announce
    FOR EACH ROW
    EXECUTE FUNCTION notify_delivery_changed ();

CREATE TRIGGER deadlock_summary_channel_delivery
    AFTER INSERT OR DELETE OR UPDATE OF channel_id,
    delivery_application_id ON deadlock_summary_channel
    FOR EACH ROW
    EXECUTE FUNCTION notify_delivery_changed ();

CREATE TRIGGER deadlock_squad_channel_delivery
    AFTER INSERT OR DELETE OR UPDATE OF channel_id,
    delivery_application_id ON deadlock_squad_channel
    FOR EACH ROW
    EXECUTE FUNCTION notify_delivery_changed ();

CREATE FUNCTION notify_webhook_broken ()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM
        pg_notify('webhook_broken', NEW.guild_id::text || ':' || NEW.channel_id::text || ':' || NEW.application_id::text);
    RETURN NULL;
END;
$$;

CREATE TRIGGER delivery_webhooks_broken
    AFTER UPDATE OF broken_at ON delivery_webhooks
    FOR EACH ROW
    WHEN (OLD.broken_at IS NULL AND NEW.broken_at IS NOT NULL)
    EXECUTE FUNCTION notify_webhook_broken ();


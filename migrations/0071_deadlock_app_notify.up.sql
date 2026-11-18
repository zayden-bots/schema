CREATE FUNCTION notify_deadlock_app_link ()
    RETURNS TRIGGER
    AS $$
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') AND OLD.provider = 'steam' THEN
        PERFORM
            pg_notify('deadlock_app', json_build_object('type', 'link_changed', 'discord_id', OLD.discord_id)::text);
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') AND NEW.provider = 'steam' THEN
        PERFORM
            pg_notify('deadlock_app', json_build_object('type', 'link_changed', 'discord_id', NEW.discord_id)::text);
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER account_links_deadlock_app_notify
    AFTER INSERT OR DELETE ON account_links
    FOR EACH ROW
    EXECUTE FUNCTION notify_deadlock_app_link ();

CREATE TRIGGER account_links_deadlock_app_notify_update
    AFTER UPDATE ON account_links
    FOR EACH ROW
    WHEN (OLD.external_id IS DISTINCT FROM NEW.external_id OR OLD.discord_id IS DISTINCT FROM NEW.discord_id OR OLD.provider IS DISTINCT FROM NEW.provider)
    EXECUTE FUNCTION notify_deadlock_app_link ();

CREATE FUNCTION notify_deadlock_app_token ()
    RETURNS TRIGGER
    AS $$
BEGIN
    PERFORM
        pg_notify('deadlock_app', json_build_object('type', 'token_revoked', 'token_id', OLD.id)::text);
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER deadlock_app_tokens_revoke_notify
    AFTER UPDATE OF revoked_at ON deadlock_app_tokens
    FOR EACH ROW
    WHEN (OLD.revoked_at IS NULL AND NEW.revoked_at IS NOT NULL)
    EXECUTE FUNCTION notify_deadlock_app_token ();

CREATE TRIGGER deadlock_app_tokens_delete_notify
    AFTER DELETE ON deadlock_app_tokens
    FOR EACH ROW
    WHEN (OLD.revoked_at IS NULL)
    EXECUTE FUNCTION notify_deadlock_app_token ();


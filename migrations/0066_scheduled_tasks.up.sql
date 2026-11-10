CREATE TABLE scheduled_tasks (
    id bigserial PRIMARY KEY,
    application_id bigint NOT NULL,
    kind text NOT NULL,
    key text NOT NULL,
    run_at timestamptz NOT NULL,
    payload jsonb NOT NULL,
    claimed_at timestamptz,
    attempts smallint NOT NULL DEFAULT 0,
    UNIQUE (application_id, kind, key)
);

CREATE INDEX scheduled_tasks_due_idx ON scheduled_tasks (application_id, run_at)
WHERE
    claimed_at IS NULL;

CREATE FUNCTION notify_task_scheduled ()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM
        pg_notify('task_scheduled', NEW.application_id::text);
    RETURN NULL;
END;
$$;

CREATE TRIGGER scheduled_tasks_notify
    AFTER INSERT OR UPDATE OF run_at ON scheduled_tasks
    FOR EACH ROW
    EXECUTE FUNCTION notify_task_scheduled ();

ALTER TABLE lfg_posts
    ADD COLUMN application_id bigint;

ALTER TABLE support_thread_activity
    ADD COLUMN application_id bigint;

ALTER TABLE hosted_servers
    ADD COLUMN application_id bigint;

ALTER TABLE jellyfin_parties
    ADD COLUMN application_id bigint;

ALTER TABLE jellyfin_game_rounds
    ADD COLUMN application_id bigint;

CREATE FUNCTION entity_author_backfill (p_guild_id bigint)
    RETURNS bigint
    LANGUAGE sql
    STABLE
    AS $$
    SELECT
        COALESCE(custom_application (p_guild_id, 'zayden'), (
                SELECT
                    p.application_id
                FROM guild_presence p
                WHERE
                    p.guild_id = p_guild_id
                    AND p.left_at IS NULL
                    AND NOT EXISTS (
                        SELECT
                            1
                        FROM applications a
                        WHERE
                            a.application_id = p.application_id
                            AND a.kind = 'custom')
                ORDER BY p.application_id LIMIT 1))
$$;

UPDATE
    support_thread_activity
SET
    application_id = entity_author_backfill (guild_id);

UPDATE
    hosted_servers
SET
    application_id = entity_author_backfill (guild_id)
WHERE
    guild_id IS NOT NULL;

UPDATE
    jellyfin_parties
SET
    application_id = entity_author_backfill (guild_id);

UPDATE
    jellyfin_game_rounds
SET
    application_id = entity_author_backfill (guild_id);

DROP FUNCTION entity_author_backfill (bigint);


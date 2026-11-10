ALTER TABLE jellyfin_game_rounds
    DROP COLUMN application_id;

ALTER TABLE jellyfin_parties
    DROP COLUMN application_id;

ALTER TABLE hosted_servers
    DROP COLUMN application_id;

ALTER TABLE support_thread_activity
    DROP COLUMN application_id;

ALTER TABLE lfg_posts
    DROP COLUMN application_id;

DROP TABLE scheduled_tasks;

DROP FUNCTION notify_task_scheduled ();


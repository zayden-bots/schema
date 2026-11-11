DROP TRIGGER deadlock_squad_channel_delivery ON deadlock_squad_channel;

DROP TRIGGER deadlock_summary_channel_delivery ON deadlock_summary_channel;

DROP TRIGGER deadlock_patch_announce_delivery ON deadlock_patch_announce;

DROP TRIGGER marathon_announce_delivery ON marathon_announce;

DROP TRIGGER patreon_announce_delivery ON patreon_announce;

DROP TRIGGER youtube_announce_delivery ON youtube_announce;

DROP FUNCTION notify_delivery_changed ();

DROP VIEW delivery_targets;

DROP FUNCTION delivery_application (bigint, bigint);

ALTER TABLE deadlock_user_settings
    DROP COLUMN opt_in_guild_id;

ALTER TABLE deadlock_squad_channel
    DROP COLUMN delivery_application_id;

ALTER TABLE deadlock_summary_channel
    DROP COLUMN delivery_application_id;

ALTER TABLE deadlock_patch_announce
    DROP COLUMN delivery_application_id;

ALTER TABLE marathon_announce
    DROP COLUMN delivery_application_id;

ALTER TABLE patreon_announce
    DROP COLUMN delivery_application_id;

ALTER TABLE youtube_announce
    DROP COLUMN delivery_application_id;

DROP TABLE delivery_webhooks;

DROP FUNCTION notify_webhook_broken ();


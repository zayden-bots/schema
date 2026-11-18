DROP TRIGGER deadlock_app_tokens_delete_notify ON deadlock_app_tokens;

DROP TRIGGER deadlock_app_tokens_revoke_notify ON deadlock_app_tokens;

DROP FUNCTION notify_deadlock_app_token ();

DROP TRIGGER account_links_deadlock_app_notify_update ON account_links;

DROP TRIGGER account_links_deadlock_app_notify ON account_links;

DROP FUNCTION notify_deadlock_app_link ();


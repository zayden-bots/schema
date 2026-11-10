DROP TRIGGER application_guilds_serving_notify ON application_guilds;

DROP FUNCTION notify_application_guilds_changed ();

DROP TRIGGER applications_notify_update ON applications;

DROP TRIGGER applications_notify_insert_delete ON applications;

DROP FUNCTION notify_applications_changed ();

DROP FUNCTION serving_application (bigint, text);

DROP FUNCTION custom_application (bigint, text);

DROP TABLE application_guilds;

DROP TABLE applications;


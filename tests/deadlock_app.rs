use schema::migrator;
use sqlx::PgPool;

const DISCORD_ID: i64 = 1;

#[sqlx::test(migrations = false)]
async fn deadlock_app_migration_reverts_and_reapplies(pool: PgPool) {
    let migrator = migrator();
    migrator.run(&pool).await.unwrap();
    migrator.undo(&pool, 69).await.unwrap();
    migrator.run(&pool).await.unwrap();
}

#[sqlx::test(migrator = "schema::MIGRATOR")]
async fn device_codes_accept_only_the_consonant_alphabet(pool: PgPool) {
    let insert = |hash: Vec<u8>, user_code: &'static str| {
        sqlx::query!(
            "INSERT INTO deadlock_device_codes
                 (device_code_hash, user_code, device_name, app_version, expires_at)
             VALUES ($1, $2, 'pc', '0.1.0', now() + interval '10 minutes')",
            hash,
            user_code
        )
        .execute(&pool)
    };

    insert(vec![1; 32], "BCDFGHJK").await.unwrap();
    assert!(insert(vec![2; 32], "ABCDEFGH").await.is_err());
    assert!(insert(vec![3; 32], "bcdfghjk").await.is_err());
    assert!(insert(vec![4; 32], "BCDF-GHJ").await.is_err());
    assert!(insert(vec![5; 31], "LMNPQRST").await.is_err());
}

#[sqlx::test(migrator = "schema::MIGRATOR")]
async fn device_code_cannot_be_granted_unapproved_or_approved_and_denied(
    pool: PgPool,
) {
    sqlx::query!(
        "INSERT INTO deadlock_device_codes
             (device_code_hash, user_code, device_name, app_version, expires_at)
         VALUES ($1, 'BCDFGHJK', 'pc', '0.1.0', now() + interval '10 minutes')",
        vec![1_u8; 32]
    )
    .execute(&pool)
    .await
    .unwrap();

    let granted = sqlx::query!(
        "UPDATE deadlock_device_codes SET granted_at = now() WHERE user_code = 'BCDFGHJK'"
    )
    .execute(&pool)
    .await;
    assert!(granted.is_err());

    let both = sqlx::query!(
        "UPDATE deadlock_device_codes
         SET approved_by = $1, approved_at = now(), denied_at = now()
         WHERE user_code = 'BCDFGHJK'",
        DISCORD_ID
    )
    .execute(&pool)
    .await;
    assert!(both.is_err());
}

#[sqlx::test(migrator = "schema::MIGRATOR")]
async fn match_fetch_defaults_on(pool: PgPool) {
    sqlx::query!(
        "INSERT INTO account_links (discord_id, provider, external_id)
         VALUES ($1, 'steam', '76561197960265729')",
        DISCORD_ID
    )
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query!(
        "INSERT INTO deadlock_user_settings (discord_id) VALUES ($1)",
        DISCORD_ID
    )
    .execute(&pool)
    .await
    .unwrap();

    let match_fetch = sqlx::query_scalar!(
        "SELECT match_fetch FROM deadlock_user_settings WHERE discord_id = $1",
        DISCORD_ID
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    assert!(match_fetch);
}

#[sqlx::test(migrator = "schema::MIGRATOR")]
async fn api_cache_accepts_match_kind(pool: PgPool) {
    sqlx::query!(
        "INSERT INTO deadlock_api_cache (key, kind, body, expires_at)
         VALUES ('proxy:/v1/matches/1/metadata?disable_steam=true', 'match', '{}', now())"
    )
    .execute(&pool)
    .await
    .unwrap();
}

#[sqlx::test(migrator = "schema::MIGRATOR")]
async fn report_wait_outcome_needs_finished_at(pool: PgPool) {
    let insert = |match_id: i64, finished: bool, outcome: Option<&'static str>| {
        sqlx::query!(
            "INSERT INTO deadlock_report_waits
                 (account_id, match_id, discord_id, ended_at, expires_at, finished_at, outcome)
             VALUES (1, $1, $2, now(), now() + interval '24 hours',
                     CASE WHEN $3 THEN now() END, $4)",
            match_id,
            DISCORD_ID,
            finished,
            outcome
        )
        .execute(&pool)
    };

    insert(1, false, None).await.unwrap();
    insert(2, true, Some("ready")).await.unwrap();
    assert!(insert(3, true, None).await.is_err());
    assert!(insert(4, false, Some("expired")).await.is_err());
    assert!(insert(5, true, Some("done")).await.is_err());
}

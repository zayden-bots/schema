use sqlx::PgPool;
use sqlx::postgres::PgListener;

const STEAM_A: &str = "76561197960265729";
const STEAM_B: &str = "76561197960265730";

async fn listen(pool: &PgPool) -> PgListener {
    let mut listener = PgListener::connect_with(pool).await.unwrap();
    listener.listen("deadlock_app").await.unwrap();
    listener
}

async fn next(listener: &mut PgListener) -> String {
    let payload = listener.recv().await.unwrap().payload().to_owned();
    payload.split_whitespace().collect()
}

async fn assert_silent(pool: &PgPool, listener: &mut PgListener) {
    sqlx::query!("SELECT pg_notify('deadlock_app', 'sentinel')")
        .execute(pool)
        .await
        .unwrap();
    assert_eq!(next(listener).await, "sentinel");
}

async fn link(pool: &PgPool, discord_id: i64, external_id: &str) {
    sqlx::query!(
        "INSERT INTO account_links (discord_id, provider, external_id)
         VALUES ($1, 'steam', $2)",
        discord_id,
        external_id
    )
    .execute(pool)
    .await
    .unwrap();
}

async fn token(pool: &PgPool, hash: u8) -> i64 {
    sqlx::query_scalar!(
        "INSERT INTO deadlock_app_tokens (token_hash, discord_id, device_name, app_version)
         VALUES ($1, 41, 'pc', '0.1.0')
         RETURNING id",
        vec![hash; 32]
    )
    .fetch_one(pool)
    .await
    .unwrap()
}

fn link_changed(discord_id: i64) -> String {
    format!(r#"{{"type":"link_changed","discord_id":{discord_id}}}"#)
}

fn token_revoked(token_id: i64) -> String {
    format!(r#"{{"type":"token_revoked","token_id":{token_id}}}"#)
}

#[sqlx::test(migrator = "schema::MIGRATOR")]
async fn linking_steam_notifies_link_changed(pool: PgPool) {
    let mut listener = listen(&pool).await;

    link(&pool, 41, STEAM_A).await;

    assert_eq!(next(&mut listener).await, link_changed(41));
}

#[sqlx::test(migrator = "schema::MIGRATOR")]
async fn relinking_to_another_steam_id_notifies(pool: PgPool) {
    link(&pool, 41, STEAM_A).await;
    let mut listener = listen(&pool).await;

    sqlx::query!(
        "UPDATE account_links SET external_id = $1
         WHERE discord_id = 41 AND provider = 'steam'",
        STEAM_B
    )
    .execute(&pool)
    .await
    .unwrap();

    assert_eq!(next(&mut listener).await, link_changed(41));
}

#[sqlx::test(migrator = "schema::MIGRATOR")]
async fn relinking_the_same_steam_id_is_silent(pool: PgPool) {
    link(&pool, 41, STEAM_A).await;
    let mut listener = listen(&pool).await;

    sqlx::query!(
        "UPDATE account_links SET linked_at = now()
         WHERE discord_id = 41 AND provider = 'steam'"
    )
    .execute(&pool)
    .await
    .unwrap();

    assert_silent(&pool, &mut listener).await;
}

#[sqlx::test(migrator = "schema::MIGRATOR")]
async fn transferring_a_steam_id_notifies_both_users(pool: PgPool) {
    link(&pool, 43, STEAM_A).await;
    let mut listener = listen(&pool).await;

    let mut tx = pool.begin().await.unwrap();
    sqlx::query!(
        "DELETE FROM account_links WHERE provider = 'steam' AND external_id = $1",
        STEAM_A
    )
    .execute(&mut *tx)
    .await
    .unwrap();
    sqlx::query!(
        "INSERT INTO account_links (discord_id, provider, external_id)
         VALUES (41, 'steam', $1)",
        STEAM_A
    )
    .execute(&mut *tx)
    .await
    .unwrap();
    tx.commit().await.unwrap();

    let mut payloads = vec![next(&mut listener).await, next(&mut listener).await];
    payloads.sort();
    let mut expected = vec![link_changed(43), link_changed(41)];
    expected.sort();
    assert_eq!(payloads, expected);
}

#[sqlx::test(migrator = "schema::MIGRATOR")]
async fn unlinking_steam_notifies_link_changed(pool: PgPool) {
    link(&pool, 41, STEAM_A).await;
    let mut listener = listen(&pool).await;

    sqlx::query!("DELETE FROM account_links WHERE discord_id = 41")
        .execute(&pool)
        .await
        .unwrap();

    assert_eq!(next(&mut listener).await, link_changed(41));
}

#[sqlx::test(migrator = "schema::MIGRATOR")]
async fn revoking_a_token_notifies_once(pool: PgPool) {
    let id = token(&pool, 1).await;
    let mut listener = listen(&pool).await;

    sqlx::query!(
        "UPDATE deadlock_app_tokens SET revoked_at = now() WHERE id = $1",
        id
    )
    .execute(&pool)
    .await
    .unwrap();
    assert_eq!(next(&mut listener).await, token_revoked(id));

    sqlx::query!(
        "UPDATE deadlock_app_tokens SET revoked_at = now() WHERE id = $1",
        id
    )
    .execute(&pool)
    .await
    .unwrap();
    assert_silent(&pool, &mut listener).await;
}

#[sqlx::test(migrator = "schema::MIGRATOR")]
async fn deleting_a_live_token_notifies(pool: PgPool) {
    let live = token(&pool, 1).await;
    let revoked = token(&pool, 2).await;
    sqlx::query!(
        "UPDATE deadlock_app_tokens SET revoked_at = now() WHERE id = $1",
        revoked
    )
    .execute(&pool)
    .await
    .unwrap();
    let mut listener = listen(&pool).await;

    sqlx::query!("DELETE FROM deadlock_app_tokens WHERE id = $1", live)
        .execute(&pool)
        .await
        .unwrap();
    assert_eq!(next(&mut listener).await, token_revoked(live));

    sqlx::query!("DELETE FROM deadlock_app_tokens WHERE id = $1", revoked)
        .execute(&pool)
        .await
        .unwrap();
    assert_silent(&pool, &mut listener).await;
}

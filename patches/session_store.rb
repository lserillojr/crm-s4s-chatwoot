# Override do session_store nativo do Chatwoot (que era :cookie_store).
#
# Motivo: o fluxo SSO OIDC estoura o cookie de sessao (CookieOverflow > 4KB) porque o
# devise_token_auth guarda o omniauth.auth (id_token JWT + userinfo do Keycloak) na sessao
# entre /omniauth/openid_connect/callback e /auth/openid_connect/callback. Cookie nao cabe.
#
# Fix: sessao server-side no Redis (que o Chatwoot ja roda; REDIS_URL no compose), via uma
# instancia DEDICADA de RedisCacheStore (namespace proprio) — NAO mexe no Rails.cache da app.
# Sem gem nova: RedisCacheStore vem do ActiveSupport e o gem `redis` ja e dependencia do Chatwoot.

Rails.application.config.session_store ActionDispatch::Session::CacheStore,
  cache: ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch('REDIS_URL', 'redis://redis:6379'),
    namespace: 'cw:session',
    expires_in: 2.hours
  ),
  key: '_chatwoot_session',
  same_site: :lax,
  expire_after: 2.hours

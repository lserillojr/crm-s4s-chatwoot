# Imagem custom do Chatwoot da S4S — Community v4.13.0 + SSO OIDC (Keycloak realm s4s).
# A MESMA imagem serve DEV/HML/PROD; a config OIDC vem por env var em runtime
# (OIDC_ISSUER / OIDC_CLIENT_ID / OIDC_CLIENT_SECRET / FRONTEND_URL).
#
# Por que custom: v4.13 NAO traz a gem omniauth_openid_connect (so omniauth-saml,
# omniauth-oauth2, omniauth-google-oauth2). SAML nao esta registrado em omniauth.rb
# (Enterprise/per-account), entao OIDC via gem e o caminho (decisao SP0 Alternativa B).
# O callback DeviseOverrides::OmniauthCallbacksController#omniauth_success ja e
# provider-agnostico (find-by-email -> sign_in com sso_auth_token | AccountBuilder),
# entao o unico patch de codigo e a allowlist :openid_connect no model User.
#
# Build + push manual (CI faz automatico — ver .github/workflows/build-push.yml):
#   docker build -t ghcr.io/lserillojr/crm-s4s-chatwoot:v4.13.0 -t ghcr.io/lserillojr/crm-s4s-chatwoot:latest .
#   docker push ghcr.io/lserillojr/crm-s4s-chatwoot:v4.13.0
#   docker push ghcr.io/lserillojr/crm-s4s-chatwoot:latest

FROM chatwoot/chatwoot:v4.13.0

USER root

# 1) Adiciona a gem OIDC ao bundle. Destrava o lockfile 'frozen' antes (imagem release).
RUN bundle config set frozen false \
 && echo "gem 'omniauth_openid_connect', '~> 0.8'" >> Gemfile \
 && bundle install

# 2) Allowlist :openid_connect no model User (Devise valida o provider contra essa lista).
#    grep || exit 1 faz o build FALHAR ALTO se o sed nao casar (formato do devise mudou),
#    em vez de gerar imagem silenciosamente quebrada.
RUN sed -i 's/omniauth_providers: \[:google_oauth2, :saml\]/omniauth_providers: [:google_oauth2, :saml, :openid_connect]/' app/models/user.rb \
 && grep -q ":openid_connect" app/models/user.rb || (echo "PATCH FALHOU: app/models/user.rb nao casou o padrao esperado" && exit 1)

# 3) Initializer OIDC espelhando o provider :google_oauth2 nativo (lido por env vars em runtime).
COPY patches/omniauth_openid_connect.rb config/initializers/omniauth_openid_connect.rb

# 4) Override do session_store: cookie -> Redis (server-side). Evita CookieOverflow no callback OIDC
#    (id_token+userinfo do Keycloak nao cabem nos 4KB do cookie). Sobrescreve o arquivo nativo.
COPY patches/session_store.rb config/initializers/session_store.rb

# 5) Rota de iniciacao SSO same-origin (Plano E Fase 2). O Portal (web-simples) so
#    linka pra GET /sso/openid_connect/start; o form com authenticity_token vive
#    AQUI (same-origin) pra o omniauth-rails_csrf_protection aceitar o request phase.
COPY patches/sso_openid_connect_controller.rb app/controllers/sso_openid_connect_controller.rb
COPY patches/sso_openid_connect_start.html.erb app/views/sso_openid_connect/start.html.erb
COPY patches/sso_openid_connect_routes.rb config/initializers/sso_openid_connect_routes.rb
RUN test -f app/controllers/sso_openid_connect_controller.rb \
 && test -f app/views/sso_openid_connect/start.html.erb \
 && test -f config/initializers/sso_openid_connect_routes.rb \
 || (echo "PATCH FALHOU: arquivos da rota SSO start ausentes" && exit 1)

# Sem callback controller custom: omniauth_success ja e provider-agnostico.

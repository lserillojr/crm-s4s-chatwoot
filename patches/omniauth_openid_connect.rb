# frozen_string_literal: true

# Initializer OIDC pra SSO Chatwoot <-> Keycloak (realm s4s).
# Espelha o padrao do `provider :google_oauth2` que ja existe em
# config/initializers/omniauth.rb (Chatwoot v4.13.0). Tudo lido por env vars.
#
# devise_token_auth monta o OmniAuth com path_prefix '/omniauth' (o /auth/openid_connect
# so redireciona pra /omniauth/openid_connect). Logo o callback do OmniAuth fica em
# <FRONTEND_URL>/omniauth/openid_connect/callback — o redirect_uri TEM que apontar pra la.
# O callback em si (DeviseOverrides::OmniauthCallbacksController#omniauth_success)
# e provider-agnostico: find-by-email -> sign_in (sso_auth_token) | AccountBuilder.
# Obs: request phase exige POST (OmniAuth 2.x) + authenticity token (omniauth-rails_csrf_protection).

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid_connect, {
    name: :openid_connect,
    issuer: ENV.fetch('OIDC_ISSUER'),                  # ex: https://dev-auth.staff4solutions.com.br/realms/s4s
    discovery: true,                                   # le authz/token/userinfo/jwks do .well-known
    scope: %i[openid email profile],
    response_type: :code,
    uid_field: 'email',
    client_options: {
      identifier: ENV.fetch('OIDC_CLIENT_ID'),         # ex: chatwoot
      secret: ENV.fetch('OIDC_CLIENT_SECRET'),
      redirect_uri: "#{ENV.fetch('FRONTEND_URL')}/omniauth/openid_connect/callback"
    }
  }
end

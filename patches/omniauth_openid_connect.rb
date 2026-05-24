# frozen_string_literal: true

# Initializer OIDC pra SSO Chatwoot <-> Keycloak (realm s4s).
# Espelha o padrao do `provider :google_oauth2` que ja existe em
# config/initializers/omniauth.rb (Chatwoot v4.13.0). Tudo lido por env vars.
#
# O OmniAuth.config.full_host ja e setado pelo omniauth.rb nativo (= FRONTEND_URL),
# entao o callback resolve pra <FRONTEND_URL>/auth/openid_connect/callback.
# O callback em si (DeviseOverrides::OmniauthCallbacksController#omniauth_success)
# e provider-agnostico: find-by-email -> sign_in (sso_auth_token) | AccountBuilder.

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
      redirect_uri: "#{ENV.fetch('FRONTEND_URL')}/auth/openid_connect/callback"
    }
  }
end

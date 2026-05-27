# frozen_string_literal: true

# Registra a rota de iniciacao SSO same-origin SEM tocar o config/routes.rb
# nativo do Chatwoot (padrao dos demais patches: tudo em initializers/COPY).
# routes.append adiciona ao fim do route set ja montado no boot.
Rails.application.routes.append do
  get 'sso/openid_connect/start', to: 'sso_openid_connect#start'
end

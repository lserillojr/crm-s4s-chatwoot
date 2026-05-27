# frozen_string_literal: true

# Inicia o SSO OIDC (Keycloak) de forma same-origin. O OmniAuth 2.x exige
# POST + authenticity_token no request phase (omniauth-rails_csrf_protection),
# e o Chatwoot Community NAO renderiza botao pro provider custom. Um form POST
# cross-origin a partir do Portal nao funciona (o token pertence a sessao do
# Chatwoot). Esta rota serve a pagina com o token correto da sessao local.
#
# Herda de ActionController::Base de proposito: nao queremos os before_action
# de autenticacao do ApplicationController (a rota tem que responder a anonimo).
# Chamar form_authenticity_token na view semeia session[:_csrf_token]; o
# middleware do omniauth-rails_csrf_protection valida esse token no POST seguinte.
class SsoOpenidConnectController < ActionController::Base
  # A view ja e um documento HTML completo (<!DOCTYPE html>). layout false evita
  # que o Rails a embrulhe no layout do Chatwoot (HTML duplo) ou estoure
  # MissingTemplate se nao houver layout convencional pra um controller nao-SPA.
  layout false
  protect_from_forgery with: :exception

  def start
    # renderiza app/views/sso_openid_connect/start.html.erb
  end
end

# crm-s4s-chatwoot

Imagem custom do **Chatwoot Community v4.13.0** da S4S, com **SSO OIDC** contra o Keycloak (realm `s4s`). Mesma imagem serve DEV/HML/PROD — a config vem por env var em runtime.

Segue o mesmo padrão do [`crm-s4s-keycloak`](https://github.com/lserillojr/crm-s4s-keycloak): Dockerfile na raiz + CI (`build-push`) que publica no GHCR.

## Por que custom

O Chatwoot v4.13 Community **não** traz a gem `omniauth_openid_connect` (só `omniauth-saml`, `omniauth-oauth2`, `omniauth-google-oauth2`), e o SAML **não** está registrado em `config/initializers/omniauth.rb` (é feature Enterprise/per-account). Decisão SP0 = **Alternativa B** (OIDC via gem). O custom faz só 3 coisas, mínimas:

1. Adiciona `gem 'omniauth_openid_connect'` ao bundle.
2. Acrescenta `:openid_connect` à allowlist `omniauth_providers` do model `User` (via `sed`, com verificação que falha o build se o padrão não casar).
3. Copia um initializer que registra `provider :openid_connect` espelhando o `provider :google_oauth2` nativo.

**Não há callback controller custom:** o `DeviseOverrides::OmniauthCallbacksController#omniauth_success` já é provider-agnóstico (find-by-email → `sign_in` com `sso_auth_token`; senão `AccountBuilder` cria conta+user).

## Imagem

`ghcr.io/lserillojr/crm-s4s-chatwoot:v4.13.0` (+ `:latest`)

## Env vars necessárias (runtime, por ambiente)

| Var | Exemplo (DEV) |
|---|---|
| `OIDC_ISSUER` | `https://dev-auth.staff4solutions.com.br/realms/s4s` |
| `OIDC_CLIENT_ID` | `chatwoot` |
| `OIDC_CLIENT_SECRET` | (secret do client `chatwoot` no realm `s4s`) |
| `FRONTEND_URL` | `https://dev-chat.staff4solutions.com.br` |

> O callback OIDC resolve pra `<FRONTEND_URL>/auth/openid_connect/callback` (devise_token_auth montado em `at: 'auth'`). Esse path deve estar nos *Valid redirect URIs* do client Keycloak.

## Build manual (CI faz automático)

```bash
docker build -t ghcr.io/lserillojr/crm-s4s-chatwoot:v4.13.0 -t ghcr.io/lserillojr/crm-s4s-chatwoot:latest .
docker push ghcr.io/lserillojr/crm-s4s-chatwoot:v4.13.0
docker push ghcr.io/lserillojr/crm-s4s-chatwoot:latest
```

## Upgrade do Chatwoot

Bumpar a tag base no `Dockerfile` (`FROM chatwoot/chatwoot:vX.Y.Z`) e as tags no CI. Conferir que o `sed` da allowlist ainda casa o formato do `devise` no `app/models/user.rb` da nova versão (o build falha alto se não casar).

## Contexto

Parte do **Portal Único SP4** (SSO mandatório pro MVP). Plano: `crm-s4s-product/docs/superpowers/plans/2026-05-24-portal-sp4-A-chatwoot-oidc-poc.md`.

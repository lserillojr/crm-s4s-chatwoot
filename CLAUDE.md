# crm-s4s-chatwoot — guia operacional

Imagem custom do **Chatwoot Community v4.13.0** com SSO OIDC (Keycloak realm `s4s`) e modo
embed para o Portal Único. A mesma imagem serve DEV/HML/PROD; toda config sensível vem por
env var em runtime.

> Contexto de produto/ambiente (stack, regras de isolamento, MEI) vem da memória do Claude —
> aqui fica só o **como mexer neste repo**.

## Comandos

```bash
# build local (CI faz automático — ver .github/workflows/build-push.yml)
docker build \
  -t ghcr.io/lserillojr/crm-s4s-chatwoot:v4.13.0 \
  -t ghcr.io/lserillojr/crm-s4s-chatwoot:latest \
  .

# push manual (exige `docker login ghcr.io`)
docker push ghcr.io/lserillojr/crm-s4s-chatwoot:v4.13.0
docker push ghcr.io/lserillojr/crm-s4s-chatwoot:latest
```

- O CI (`build-push.yml`) dispara no push em `main` **quando** `Dockerfile`, `patches/**` ou o
  próprio workflow mudam, e publica as tags `v4.13.0`, `v4.13.0-sso2` e `latest` no GHCR
  (`ghcr.io/lserillojr/crm-s4s-chatwoot`).
- `workflow_dispatch` disponível para rebuild manual sem alteração de código.

### Patches aplicados no build (em ordem)

| # | Arquivo em `patches/` | O que faz |
|---|---|---|
| 1 | *(Gemfile inline)* | Adiciona `gem 'omniauth_openid_connect', '~> 0.8'` ao bundle |
| 2 | *(sed inline)* | Acrescenta `:openid_connect` à allowlist `omniauth_providers` em `app/models/user.rb` |
| 3 | `omniauth_openid_connect.rb` | Initializer que registra `provider :openid_connect` com vars `OIDC_*` |
| 4 | `session_store.rb` | Override: cookie_store → Redis (`cw:session`, 2h) para evitar CookieOverflow no callback OIDC |
| 5 | `sso_openid_connect_controller.rb` + `_routes.rb` + `start.html.erb` | Rota `GET /sso/openid_connect/start` same-origin que entrega o form com `authenticity_token` (OmniAuth 2.x exige POST + CSRF) |
| 6 | `embed_s4s.rb` + `embed_s4s.css` | Middleware Rack gated por `?embed=s4s`: seta cookie `s4s_embed=1`, injeta snippet de chrome-off no `<head>`, libera `frame-ancestors` para `S4S_PORTAL_ORIGIN` |

### Env vars de runtime obrigatórias

| Var | Exemplo (DEV) |
|---|---|
| `OIDC_ISSUER` | `https://dev-auth.staff4solutions.com.br/realms/s4s` |
| `OIDC_CLIENT_ID` | `chatwoot` |
| `OIDC_CLIENT_SECRET` | (secret do client `chatwoot` no realm) |
| `FRONTEND_URL` | `https://dev-chat.staff4solutions.com.br` |
| `REDIS_URL` | `redis://redis:6379` (já existe no compose) |
| `S4S_PORTAL_ORIGIN` | `https://dev-app.staff4solutions.com.br` (embed) |
| `RAILS_SERVE_STATIC_FILES` | `true` (necessário para servir `public/embed_s4s.css`) |

O callback OmniAuth fica em `<FRONTEND_URL>/omniauth/openid_connect/callback` — esse path
deve constar nos *Valid redirect URIs* do client Keycloak (não `/auth/…`, que é só alias
do devise_token_auth).

## Deploy

- **Não há CD** que faça deploy automático nos ambientes. O CI só publica a imagem no GHCR.
- **DEV/HML** — trocar o `image:` do serviço `chatwoot` no stack Portainer para a nova tag
  (ou digest) e forçar redeploy com pull. **Sempre usar tag imutável** (`v4.13.0-sso2` ou
  digest `sha256:…`) — nunca apontar para `:latest` em produção.
- Atualizar a env `S4S_PORTAL_ORIGIN` via Portainer UI antes de redeployar se o origin
  do Portal mudou (ex.: HML tem domínio diferente de DEV).
- Após redeploy, validar smoke: login SSO Keycloak → dashboard Chatwoot, e embed no Portal.

### Upgrade do Chatwoot base

1. Bumpar `FROM chatwoot/chatwoot:vX.Y.Z` no `Dockerfile` e as tags no `build-push.yml`.
2. Verificar que o `sed` da allowlist ainda casa o `app/models/user.rb` da nova versão
   (o build falha alto com `grep || exit 1` se não casar — investigar e ajustar o padrão).
3. Conferir se o session_store nativo da nova versão mudou (para não sobrescrever desnecessariamente).

## Gotchas deste repo

- **Callback OmniAuth fica em `/omniauth/…`, não `/auth/…`.** O `devise_token_auth` monta com
  `path_prefix '/omniauth'`; o `/auth/openid_connect/callback` é só um alias. Configurar o
  Keycloak com o path `/omniauth/openid_connect/callback`.

- **Agent Bot nativo do Chatwoot 4.x está quebrado** (issues upstream marcadas NOT PLANNED).
  A IA usa **User regular + Automation Rule** — não configurar Agent Bot no Chatwoot.

- **Não expor "Chatwoot" na UI do MEI.** O título da aba e qualquer texto visível ao MEI
  não pode revelar o nome do produto base. Ajustado via middleware embed (chrome-off) e
  configurações do Portal. Ver regra de produto na memória do Claude.

- **`RAILS_SERVE_STATIC_FILES=true` é obrigatório** para o `embed_s4s.css` ser servido
  (arquivo em `public/`). Sem isso, o chrome-off não funciona silenciosamente.

- **`S4S_PORTAL_ORIGIN` controla o `frame-ancestors`.** Sem ela, o iframe fica branco
  sem erro visível. Deve ser o origin exato do Portal (sem trailing slash).

- **Reset de senha admin via SQL** (DB `chatwoot48`; Devise sem pepper, `stretches=11`):
  não há forma nativa de reset via UI para o admin SSO. Gerar o hash pelo Devise fora do
  container e fazer `UPDATE users SET encrypted_password = '...' WHERE email = '...'`.

- **`GlobalConfigService` do Chatwoot bloqueia ENVs** que foram persistidas como
  `installation_configs` em branco. Se uma env OIDC não for lida em runtime, checar se
  há registro em branco na tabela; DELETE para forçar releitura do ENV.

- **Portainer Swarm trunca `=` em env base64.** Secrets gerados com `base64` têm `+/=`
  que chegam truncados. Gerar `OIDC_CLIENT_SECRET` e similares com `openssl rand -hex 32`.
